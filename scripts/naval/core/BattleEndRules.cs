#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

// Task 14：自沉、残骸、逃跑与终局判定（设计文档 15、16.1）。
// 规则要点见 docs/changes/CHG-20260807-battle-end.md"简报与设计歧义裁定"。
public static class BattleEndRules
{
    // 战斗中浅滩自沉损失最大生命比例（设计 15）。
    public const double SelfSinkHpLossRatio = 0.15;

    // 存活舰数（设计 15/16.2）：该阵营 HitPoints>0 的在场舰数。
    // 自沉舰生命>0 计入、归零不计；被俘/逃脱/礁石深海自沉已移除不计；沉没舰（HP<=0）不计。
    public static int SurvivingShips(BattleState battle, FactionId faction)
        => battle.Ships.Values.Count(s => s.Faction == faction && s.HitPoints > 0);

    // "开战舰数"（Task 15，投降优势 16.2 条件1 分母）登记：扫描当前在场舰，取该阵营并发最大舰数，
    // 并登记该阵营"已部署"。多次调用取并集（idempotent 上限语义）。
    // 注意：必须在任何"命令中途移出舰船"的移除点之前调用（自沉即时移除 / 被俘移除 / 投降交付移出），
    // 否则扫描时已移出舰会使某阵营分母偏小——与 FactionsEverDeployed 同源（Task 14 修复经验）。
    public static void EnsureDeployedCounts(BattleState battle)
    {
        foreach (var group in battle.Ships.Values.GroupBy(s => s.Faction))
        {
            battle.FactionsEverDeployed.Add(group.Key);
            var existing = battle.DeployedShipCounts.GetValueOrDefault(group.Key);
            if (group.Count() > existing) battle.DeployedShipCounts[group.Key] = group.Count();
        }
    }

    // —— 主动自沉（设计 15）——

    // 校验：返回 null 表示合法，否则为拒绝原因 key（ActionResolver 用；非法不耗动作）。
    public static string? ValidateSelfSink(BattleState battle, SelfSinkCommand cmd)
    {
        var ship = battle.ShipOrNull(cmd.ShipId);
        if (ship is null || ship.HitPoints <= 0) return "action.unknown_ship";
        if (ship.SelfSunk) return "self_sink.already_sunk";
        if (ship.Captured) return "self_sink.captured";
        if (ship.Boarding is not null) return "self_sink.boarding"; // 裁定 6：接舷中禁自沉
        if (!cmd.DeploymentPhase && ship.Faction != battle.CurrentFaction) return "action.unknown_ship";
        // 通过性 1 或 2（设计 15"通过性1或2的舰船可在浅滩主动自沉"；FreeAll=3 排除，裁定 3）
        if (ship.Definition.Passability == Passability.FreeAll) return "self_sink.passability";
        // 地形按船头格判定（裁定 4）：浅滩/陆河→固定火力点；礁石→直接沉没+残骸；深水→直接沉没无残骸
        // （U-2a：陆河按浅滩类似并入浅水分支——通过性≥2 舰可在陆河自沉成火力点）
        var terrain = battle.Map.TerrainAt(ship.Bow);
        if (terrain != TerrainType.Shallow && terrain != TerrainType.River
            && terrain != TerrainType.Reef && terrain != TerrainType.DeepWater)
            return "self_sink.wrong_terrain";
        return null;
    }

    public static BattleEvent[] ResolveSelfSink(BattleState battle, SelfSinkCommand cmd)
    {
        if (ValidateSelfSink(battle, cmd) is not null) return Array.Empty<BattleEvent>();
        var ship = battle.ShipOrNull(cmd.ShipId)!;
        var terrain = battle.Map.TerrainAt(ship.Bow);
        var events = new List<BattleEvent>();
        if (terrain == TerrainType.Shallow || terrain == TerrainType.River)
        {
            // 浅滩/陆河（U-2a 陆河按浅滩类似）：成为固定火力点（保留生命/朝向/占格/每回合一次攻击；永失移动转向由 MovementRules 拦 SelfSunk）
            var hpLost = 0;
            if (!cmd.DeploymentPhase)
            {
                hpLost = (int)Math.Round(ship.MaxHp * SelfSinkHpLossRatio, MidpointRounding.AwayFromZero); // .5 向上，与 15% 入礁统一（Task 18 B5）
                ship.HitPoints -= hpLost;
            }
            ship.SelfSunk = true;
            events.Add(new ShipSelfSunkEvent(ship.Id, hpLost, LeftWreck: false));
            // 生命不足以支付 15% → 自沉即沉没；残骸由 SettleAfterCommand 按"自沉被击毁"统一补
            if (ship.HitPoints <= 0) events.Add(new ShipSunkEvent(ship.Id));
            return events.ToArray();
        }
        // 礁石/深海：命令即时结算（裁定 1）——直接沉没；礁石留残骸、深海不留
        var leftWreck = terrain == TerrainType.Reef;
        ship.SelfSunk = true;
        // 修复（评审 Important）：移除前登记该阵营"已部署"+"开战舰数"（EnsureDeployedCounts 同时覆盖 FactionsEverDeployed）——
        // 否则该阵营唯一舰在战斗首条命令即自沉时，SettleAfterCommand 主循环已见不到它，FactionsEverDeployed 缺失 →
        // playerGone/enemyGone 恒 false，战斗永不结束（违反设计 16.1）；且投降优势 16.2 条件1 分母会偏小。
        EnsureDeployedCounts(battle);
        if (leftWreck) foreach (var c in ship.OccupiedCells()) battle.Map.Wrecks.Add(c);
        // Task 16：离场前登记（自沉即时移除；保留 SelfSunk 快照），供 BattleResult 分类（自沉沉没）。
        battle.RemovedShips[ship.Id] = new RemovedShipRecord(ship.Definition.Id, ship.Faction, ship.HitPoints, ship.MaxHp, SelfSunk: true, ShipRemovalReason.SelfSunk);
        battle.Ships.Remove(ship.Id);
        events.Add(new ShipSelfSunkEvent(ship.Id, 0, leftWreck));
        events.Add(new ShipSunkEvent(ship.Id));
        return events.ToArray();
    }

    // —— 统一结算（ActionResolver 每条成功命令后调用）——

    // 顺序：记部署阵营 → 逃跑（任一占格触出口即移出）→ 残骸（自沉被击毁补残骸）→ 终局（一方全没）。
    public static ActionResult SettleAfterCommand(BattleState battle, ActionResult result)
    {
        if (!result.Success) return result; // 命令被拒绝，无状态变化
        var extra = new List<BattleEvent>();
        // 先记录"曾派出舰船的阵营"+"开战舰数"（含本命令即将逃脱移除的舰，此时仍在 Ships）：终局判定要求该阵营
        // 确有舰船，防从无舰误判；投降优势 16.2 条件1 分母需含即将逃脱移除的舰。
        // 修复（评审 Important）：被俘方阵营改由 BoardingRules.ResolveExchange 在移除前登记（与自沉/交付同模式），
        // 不再从 ShipCapturedEvent.CaptorId 反推对侧阵营（未来新增俘获路径需同步，脆弱）。
        EnsureDeployedCounts(battle);

        // 1. 逃跑（设计 16.1，裁定 2 纯自动）：任一存活舰的任一占格触碰出口边界 → 整舰立即移出战场。
        // 挂在每条成功命令后（覆盖移动/转向/撞击推动/接舷组合平移任意占格变化路径），无显式 EscapeCommand。
        var escapers = battle.Ships.Values
            .Where(s => s.HitPoints > 0 && s.OccupiedCells().Any(c => battle.Map.ExitCells.Contains(c)))
            .ToList();
        foreach (var s in escapers)
        {
            // Task 16：离场前登记（含离场时生命快照），供 BattleResult 分类"逃脱"。
            battle.RemovedShips[s.Id] = new RemovedShipRecord(s.Definition.Id, s.Faction, s.HitPoints, s.MaxHp, s.SelfSunk, ShipRemovalReason.Escaped);
            battle.Ships.Remove(s.Id);
            extra.Add(new ShipEscapedEvent(s.Id));
        }

        // 2. 残骸（设计 15，裁定 1）：自沉舰被击毁（HP<=0）→ 原船体格留不可通行残骸（WreckSettled 防重复）。
        // 正常沉没舰不置 SelfSunk → 天然不留残骸。
        foreach (var s in battle.Ships.Values.Where(s => s.SelfSunk && s.HitPoints <= 0 && !s.WreckSettled))
        {
            foreach (var c in s.OccupiedCells()) battle.Map.Wrecks.Add(c);
            s.WreckSettled = true;
        }

        // 3. 终局（设计 16.1）：任一方所有留场舰船均已沉没/被俘/逃离 → 立即结束；双方同时全没（同归于尽）无胜者。
        if (!battle.BattleEnded)
        {
            var playerAlive = battle.Ships.Values.Any(s => s.Faction == FactionId.Player && s.HitPoints > 0);
            var enemyAlive = battle.Ships.Values.Any(s => s.Faction == FactionId.Enemy && s.HitPoints > 0);
            var playerGone = !playerAlive && battle.FactionsEverDeployed.Contains(FactionId.Player);
            var enemyGone = !enemyAlive && battle.FactionsEverDeployed.Contains(FactionId.Enemy);
            if (playerGone || enemyGone)
            {
                battle.BattleEnded = true;
                FactionId? winner = playerAlive ? FactionId.Player : enemyAlive ? FactionId.Enemy : null;
                extra.Add(new BattleEndedEvent(winner));
            }
        }
        return extra.Count > 0 ? result with { Events = result.Events.Concat(extra).ToArray() } : result;
    }
}
