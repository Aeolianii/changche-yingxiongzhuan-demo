#nullable enable
using System.Collections.Generic;
using NavalCombat.Core;

namespace NavalCombat.Integration;

// Task 16（spec 8）：剧情层 → 海战层的开战请求。双方舰队快照 + 地图 + 配置 + 可选初始金币/随机种子。
// 快照只含开战所需信息（舰型/装备/技能/位置/朝向/指挥舰），战斗过程由海战层自建 BattleState 推进。
public sealed class BattleRequest
{
    public required BattleMap Map { get; init; }
    public required NavalRulesConfig Config { get; init; }
    public List<ShipRequestSnapshot> PlayerShips { get; } = new();
    public List<ShipRequestSnapshot> EnemyShips { get; } = new();
    // null → 默认 500（SurrenderRules.SurrenderGoldCost，投降金/金币模型默认）。
    public int? InitialGold { get; init; }
    // null → 非确定性随机（不可复现）；给定 → SeedRandomSource，结果可复现（设计 18）。
    public int? RandomSeed { get; init; }
    // null → 默认我方先行（BattleState.CurrentFaction 初值 Player）。
    public FactionId? FirstFaction { get; init; }
}

// 单舰快照：剧情层给出 舰型ID/位置/朝向/生命(可选)/装备/技能(可选覆盖默认播种)/指挥舰标记。
public sealed class ShipRequestSnapshot
{
    public string Id { get; set; } = "";
    public string DefinitionId { get; set; } = "";
    public GridPos Bow { get; set; }
    public CardinalDirection Facing { get; set; } = CardinalDirection.East;
    // null → 取定义最大生命。
    public int? HitPoints { get; set; }
    public bool IsFlagship { get; set; }
    public Dictionary<string, int> WeaponCounts { get; } = new();
    public Dictionary<string, int> SkillUsesLeft { get; } = new();
}
