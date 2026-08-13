#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;
using NavalCombat.Core;

namespace NavalCombat.Integration;

// Task 16（spec 8）：剧情层 ↔ 海战层网关。
// Start(BattleRequest)：装配 BattleState 并启动战斗（宿主回调挂接表现层战斗场景）；
// Finalize(battle)：战斗结束清理（设计 17）+ 生成 BattleResult。不向剧情层暴露战斗场景内部节点。
public sealed class NavalBattleGateway
{
    private readonly Action<BattleState>? _onLaunch;

    public NavalBattleGateway(Action<BattleState>? onLaunch = null) => _onLaunch = onLaunch;

    // 启动：装配状态 → 触发宿主启动回调（表现层在此把 BattleState 交给战斗场景）。
    public BattleState Start(BattleRequest request)
    {
        var battle = BuildBattleState(request);
        _onLaunch?.Invoke(battle);
        return battle;
    }

    // 收尾：清除临时状态（设计 17）→ 生成结果。幂等（战斗结束后仍可安全调用）。
    public static BattleResult Finalize(BattleState battle)
    {
        BattleCleanup.ClearTemporaryStates(battle);
        return BattleResult.From(battle);
    }

    // 纯装配：请求 → BattleState（不依赖表现层）。位置/朝向/装备/技能/指挥舰/金币/地图/配置/回合初值。
    public static BattleState BuildBattleState(BattleRequest request)
    {
        var battle = new BattleState
        {
            Map = request.Map,
            Config = request.Config,
            Random = request.RandomSeed is int seed ? new SeedRandomSource(seed) : new UnseededRandomSource(),
        };
        battle.PlayerGold = request.InitialGold ?? SurrenderRules.SurrenderGoldCost;

        var snapshots = new List<(ShipRequestSnapshot Req, FactionId Faction)>();
        foreach (var s in request.PlayerShips) snapshots.Add((s, FactionId.Player));
        foreach (var s in request.EnemyShips) snapshots.Add((s, FactionId.Enemy));

        // 舰船装配：舰型/位置/朝向/生命/装备（配置即权威，未知舰型忽略）；登记"已部署"与指挥舰。
        foreach (var (req, faction) in snapshots)
        {
            var def = request.Config.Ships.FirstOrDefault(d => d.Id == req.DefinitionId);
            if (def is null) continue;
            var ship = new ShipState
            {
                Id = req.Id,
                Definition = def,
                Faction = faction,
                Bow = req.Bow,
                Facing = req.Facing,
                HitPoints = req.HitPoints ?? def.MaxHp,
            };
            foreach (var (k, v) in req.WeaponCounts) ship.WeaponCounts[k] = v;
            battle.Ships[req.Id] = ship;
            battle.FactionsEverDeployed.Add(faction);
            if (req.IsFlagship) battle.Flagships[faction] = req.Id;
        }

        // 技能：先按舰型布局默认播种（与布阵 ConfirmDeployment 一致），请求显式携带的技能覆盖默认。
        SkillSeeding.Seed(battle);
        foreach (var (req, _) in snapshots)
            foreach (var (k, v) in req.SkillUsesLeft)
                if (battle.ShipOrNull(req.Id) is { } ship) ship.SkillUsesLeft[k] = v;

        // 首回合移动点（天气/载重结算）；指定先手阵营。
        foreach (var s in battle.Ships.Values)
        {
            s.RemainingMovement = WeatherRules.CurrentMovementPoints(battle, s);
            s.TurnStartBow = s.Bow; // F-1：风向修正起点快照（与首回合移动点一致）
        }
        if (request.FirstFaction is FactionId first) battle.CurrentFaction = first;
        return battle;
    }
}

// 战斗结束清理（设计 17）：清除 烧伤/连锁弹减速/损管持续恢复/接舷链接/保留俘获进度/水雷/投降状态 等临时状态。
// 残骸为永久地图特征保留（再来一局经场景重载重建新图）；自沉永久固定（火力点）属舰船状态保留。
public static class BattleCleanup
{
    public static void ClearTemporaryStates(BattleState battle)
    {
        foreach (var s in battle.Ships.Values)
        {
            s.Burns.Clear();
            s.SpeedPenalties.Clear();
            s.Repairs.Clear();
            s.RetainedCaptureProgress.Clear();
            s.Boarding = null;
        }
        battle.Map.Mines.Clear();
        // 修复（评审 Important）：投降相关跨命令状态同为临时状态——若同 BattleState 复用第二场战斗，
        // 层数/待决/每回合劝降门禁会从旧战泄漏到新战（投降优势/成功率/每回合一次门禁被污染）。一并重置。
        battle.SurrenderTiers.Clear();
        battle.PendingSurrenderFrom = null;
        battle.LastOfferedRounds.Clear();
    }
}
