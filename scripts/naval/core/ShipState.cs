#nullable enable
using System.Collections.Generic;

namespace NavalCombat.Core;

public sealed class ShipState
{
    public required string Id { get; init; }
    public required ShipDefinition Definition { get; init; }
    public FactionId Faction { get; set; }
    public GridPos Bow { get; set; }
    public CardinalDirection Facing { get; set; } = CardinalDirection.North;
    public int HitPoints { get; set; }
    public int ArmorLevel { get; set; }
    public bool SelfSunk { get; set; }
    // Task 14：自沉舰被击毁后原占格残骸已放置标记（BattleEndRules.SettleAfterCommand 防重复放置）。
    public bool WreckSettled { get; set; }
    public bool HasAttacked { get; set; }
    public int RemainingMovement { get; set; }
    public int SpentMovement { get; set; }
    // F-1：本回合首次移动前船头位置（风向修正起点快照，设计 6 顺/逆风 ±1）。
    // 阵营回合开始时由 EndTurn/ConfirmDeployment 拍快照；无风或未记录时为 null（TryTranslate 退化为原点=当前位置）。
    public GridPos? TurnStartBow { get; set; }
    // Task 9：本回合最后一次成功平移的方向（撞击资格判定，设计 10）。默认 null；转向/回合刷新会清空。
    public CardinalDirection? LastMoveDirection { get; set; }

    // 装备与持续状态（数据结构先定义，行为由 Task 10/11 补充）
    public Dictionary<string, int> WeaponCounts { get; } = new();   // 武器类型ID → 数量
    public Dictionary<string, int> SkillUsesLeft { get; } = new();  // 技能类型ID → 剩余次数
    // F-5：布阵前技能配置（技能类型ID → 槽位数）。SkillSeeding.Seed 按槽位数 × skills.json 每场次数播种 SkillUsesLeft。
    public Dictionary<string, int> SkillLoadout { get; } = new();
    public List<TimedSpeedPenalty> SpeedPenalties { get; } = new();
    public List<BurnStatus> Burns { get; } = new();
    public List<RepairOverTime> Repairs { get; } = new();
    public BoardingLink? Boarding { get; set; }
    // Task 16：敌降加入我方的舰（SurrenderRules.SettleEnemySurrender 标记）。供 BattleResult 分类"投降移交"，
    // 且战后维修（RepairService）对投降移交舰照常免费修满。
    public bool JoinedBySurrender { get; set; }
    // Task 10：俘获（设计 11）。俘获成功时标记并立即移出 battle.Ships（不能本场转友军）；战后计入俘获（Task 16）。
    public bool Captured { get; set; }
    // Task 10：脱离后保留的俘获进度（原发起方持有；目标舰Id → 进度）。每完整回合降一级，归零移除；重新接舷继承。
    public Dictionary<string, int> RetainedCaptureProgress { get; } = new();

    public int Length => Definition.Length;
    public int MaxHp => Definition.MaxHp;

    // 占格：船头在最前，向后延伸到船尾（index 0 = 船头）
    public List<GridPos> OccupiedCells()
    {
        var cells = new List<GridPos>(Length);
        for (var i = 0; i < Length; i++)
            cells.Add(Bow - Facing.Vector() * i);
        return cells;
    }
}

// 持续状态数据结构（行为规则见 Task 10/11 的 StatusRules/BoardingRules）
public sealed record TimedSpeedPenalty(int RoundsLeft);
public sealed record BurnStatus(int RoundsLeft);
public sealed record RepairOverTime(int TicksLeft);

public sealed class BoardingLink
{
    public required string InitiatorId { get; init; }
    public required string DefenderId { get; init; }
    public bool DefenderControlsPair { get; set; }
    public int CaptureProgress { get; set; } // 0/25/50/100（衰减中途可为 75）
    public int NoAdvantageRounds { get; set; }
    // Task 10：组合平移预算（2 格/防守方回合），防守方阵营回合开始时重置（设计 11.1）
    public int PairMovesUsed { get; set; }
}
