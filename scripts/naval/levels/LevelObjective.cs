#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// L-1 关卡目标类型。判定逻辑 L-3 实现（实时按 battle/追踪器计算）。
public enum LevelObjectiveType
{
    ReachCell,          // 抵达目标格（TargetCell）
    SinkAllEnemies,     // 击沉全部敌舰
    SinkWithWeapon,     // 用指定武器（WeaponId，空=任意武器）击沉 Count 艘敌舰
    CaptureShip,        // 俘获 Count 艘敌舰
    UseAllSkills,       // 全部技能各使用一次（SkillId 给定则只用该技能；空=玩家已装全部技能各一次）
    Escape,             // 指挥舰队逃离战场（任意玩家舰触出口格离场）
    SurviveRounds,      // 存活 Rounds 回合
    WinBattle,          // 正常获胜（敌方全没/逃跑/投降）
}

// L-3 关卡目标：Type + 按需参数 + 实时判定与进度。
//   IsComplete(battle, tracker)    目标达成判定（不触发状态变更；达成后由上层 ResolveLevelEnd 收尾）。
//   DescribeProgress(battle, tracker)  实时进度文本（如"已击沉 2/3"），顶栏目标条展示。
//   MaxRounds                     回合上限；battle.Round 超过即判负（ExceededMaxRounds，null=无上限）。
public sealed record LevelObjective(
    LevelObjectiveType Type,
    GridPos? TargetCell = null,
    int? Count = null,
    int? Rounds = null,
    string? WeaponId = null,
    string? SkillId = null,
    int? MaxRounds = null)
{
    // 目标达成判定：对"战斗结束才成立"的类型（WinBattle）依赖 battle.BattleEnded；
    // 其余类型只依赖场上/追踪器状态（可在战斗中实时达成，达成后由上层强制收尾）。
    public bool IsComplete(BattleState battle, LevelObjectiveTracker tracker)
    {
        switch (Type)
        {
            case LevelObjectiveType.ReachCell:
                return TargetCell is { } target
                    && AnyPlayerAlive(battle, s => s.OccupiedCells().Contains(target));
            case LevelObjectiveType.SinkAllEnemies:
                // 敌舰曾布阵才判定（空敌舰队关卡不秒赢）；场上无存活敌舰即达成。
                if (!battle.FactionsEverDeployed.Contains(FactionId.Enemy)) return false;
                return !battle.Ships.Values.Any(s => s.Faction == FactionId.Enemy && s.HitPoints > 0);
            case LevelObjectiveType.SinkWithWeapon:
            {
                var kills = WeaponId is { } wid
                    ? tracker.EnemySunkByWeapon.GetValueOrDefault(wid, 0)
                    : tracker.EnemySunkByWeapon.Values.Sum();
                return kills >= (Count ?? 1);
            }
            case LevelObjectiveType.CaptureShip:
                return tracker.PlayerCaptures >= (Count ?? 1);
            case LevelObjectiveType.UseAllSkills:
                return AllSkillsUsed(battle, tracker);
            case LevelObjectiveType.Escape:
                return battle.RemovedShips.Values.Any(r =>
                    r.Faction == FactionId.Player && r.Reason == ShipRemovalReason.Escaped);
            case LevelObjectiveType.SurviveRounds:
                // Round-1 = 已完整度过的回合数（第 1 回合开始时 = 0）。
                return battle.Round - 1 >= (Rounds ?? 1);
            case LevelObjectiveType.WinBattle:
                if (!battle.BattleEnded) return false;
                if (battle.SurrenderLoser == FactionId.Player) return false;
                return battle.Ships.Values.Any(s => s.Faction == FactionId.Player && s.HitPoints > 0);
            default:
                throw new ArgumentOutOfRangeException(nameof(Type));
        }
    }

    // 回合上限判负（战斗未结束时超限）：battle.Round 超过 MaxRounds → 失败。null=无上限（恒 false）。
    public bool ExceededMaxRounds(BattleState battle)
        => MaxRounds is { } m && battle.Round > m;

    // 实时进度文本（顶栏目标条追加显示）。达成后带 ✓ 前缀（与结算面板语义一致）。
    public string DescribeProgress(BattleState battle, LevelObjectiveTracker tracker)
    {
        var done = IsComplete(battle, tracker);
        var prefix = done ? "✓ " : "";
        return Type switch
        {
            LevelObjectiveType.ReachCell => TargetCell is { } c
                ? $"{prefix}抵达目标格 ({c.X},{c.Y})"
                : $"{prefix}抵达目标格",
            LevelObjectiveType.SinkAllEnemies =>
                $"{prefix}击沉全部敌舰 {EnemySunkCount(battle)}/{TotalEnemyCount(battle)}",
            LevelObjectiveType.SinkWithWeapon =>
                $"{prefix}用「{WeaponDisplayName(battle, WeaponId)}」击沉 {SunkByWeapon(battle, tracker)}/{Count ?? 1} 艘",
            LevelObjectiveType.CaptureShip =>
                $"{prefix}俘获敌舰 {tracker.PlayerCaptures}/{Count ?? 1} 艘",
            LevelObjectiveType.UseAllSkills =>
                SkillId is { } sid
                    ? $"{prefix}使用「{SkillDisplayName(battle, sid)}」一次"
                    : $"{prefix}技能各用一次 {UsedSkillCount(battle, tracker)}/{EquippedSkillCount(battle)}",
            LevelObjectiveType.Escape =>
                $"{prefix}逃离战场 {EscapedPlayerCount(battle)}/{PlayerFleetTotal(battle)}",
            LevelObjectiveType.SurviveRounds =>
                $"{prefix}存活 {Math.Max(0, battle.Round - 1)}/{Rounds ?? 1} 回合",
            LevelObjectiveType.WinBattle => $"{prefix}赢得战斗",
            _ => throw new ArgumentOutOfRangeException(nameof(Type)),
        };
    }

    // ---- 进度统计辅助 ----

    private static bool AnyPlayerAlive(BattleState battle, Func<ShipState, bool> predicate)
        => battle.Ships.Values.Any(s => s.Faction == FactionId.Player && s.HitPoints > 0 && predicate(s));

    // 已沉敌舰 = 离场登记的（自沉/被俘/逃脱/移交）+ 仍留场但 HP<=0 的（普通击沉不移出 Ships，仅 HP 归零）。
    // 与 IsComplete（场上无存活敌舰）口径一致，避免全灭时进度显示"0/0"。
    private static int EnemySunkCount(BattleState battle)
        => battle.RemovedShips.Values.Count(r => r.Faction == FactionId.Enemy)
           + battle.Ships.Values.Count(s => s.Faction == FactionId.Enemy && s.HitPoints <= 0);

    private static int TotalEnemyCount(BattleState battle)
        => EnemySunkCount(battle)
           + battle.Ships.Values.Count(s => s.Faction == FactionId.Enemy && s.HitPoints > 0);

    private int SunkByWeapon(BattleState battle, LevelObjectiveTracker tracker)
        => WeaponId is { } wid
            ? tracker.EnemySunkByWeapon.GetValueOrDefault(wid, 0)
            : tracker.EnemySunkByWeapon.Values.Sum();

    private static int EscapedPlayerCount(BattleState battle)
        => battle.RemovedShips.Values.Count(r => r.Faction == FactionId.Player && r.Reason == ShipRemovalReason.Escaped);

    // 玩家舰队总规模 ≈ 仍存活玩家舰 + 已离场玩家舰（含逃脱；不含被俘/沉没后的后续估计——进度展示用，够用）。
    private static int PlayerFleetTotal(BattleState battle)
        => EscapedPlayerCount(battle)
           + battle.Ships.Values.Count(s => s.Faction == FactionId.Player && s.HitPoints > 0);

    private static int EquippedSkillCount(BattleState battle)
        => battle.Ships.Values
            .Where(s => s.Faction == FactionId.Player && s.HitPoints > 0)
            .SelectMany(s => s.SkillLoadout.Keys)
            .Distinct()
            .Count();

    private int UsedSkillCount(BattleState battle, LevelObjectiveTracker tracker)
    {
        var equipped = battle.Ships.Values
            .Where(s => s.Faction == FactionId.Player && s.HitPoints > 0)
            .SelectMany(s => s.SkillLoadout.Keys)
            .ToHashSet();
        return equipped.Count(tracker.SkillsUsed.Contains);
    }

    private bool AllSkillsUsed(BattleState battle, LevelObjectiveTracker tracker)
    {
        if (SkillId is { } sid) return tracker.SkillsUsed.Contains(sid);
        var equipped = battle.Ships.Values
            .Where(s => s.Faction == FactionId.Player && s.HitPoints > 0)
            .SelectMany(s => s.SkillLoadout.Keys)
            .ToHashSet();
        if (equipped.Count == 0) return false; // 无技能可练 → 不达成（避免 0/0 秒赢）
        return equipped.All(tracker.SkillsUsed.Contains);
    }

    private static string WeaponDisplayName(BattleState battle, string? id)
        => id is null ? "任意武器" : battle.Config.Weapons.FirstOrDefault(w => w.Id == id)?.DisplayName ?? id;

    private static string SkillDisplayName(BattleState battle, string id)
        => battle.Config.Skills.FirstOrDefault(s => s.Id == id)?.DisplayName ?? id;
}
