#nullable enable
using System.Collections.Generic;

namespace NavalCombat.Core;

// 战斗容器：Task 4 由最小容器充实为完整回合状态（阵营/回合/天气/风向/指挥舰/胜负）
public sealed class BattleState
{
    public required BattleMap Map { get; init; }
    public required NavalRulesConfig Config { get; init; }
    public required IRandomSource Random { get; init; }
    public Dictionary<string, ShipState> Ships { get; } = new();
    public FactionId CurrentFaction { get; set; } = FactionId.Player;
    public int Round { get; set; } = 1;
    public Weather Weather { get; set; } = Weather.Clear;
    public CardinalDirection? Wind { get; set; }
    public Dictionary<FactionId, string> Flagships { get; } = new();
    public bool BattleEnded { get; set; }
    // Task 14：曾派出舰船的阵营集合（终局判定防误触发：某阵营从无舰船时不应判"全没"结束战斗）。
    public HashSet<FactionId> FactionsEverDeployed { get; } = new();
    // Task 15：各阵营"开战舰数"（投降优势 16.2 条件1 分母）。按 BattleEndRules.EnsureDeployedCounts 每命令后扫描取
    // 该阵营并发最大舰数登记；自沉即时移除前 / 被俘移除时 / 投降交付移出前补登记，防扫描前已移出舰使分母偏小。
    public Dictionary<FactionId, int> DeployedShipCounts { get; } = new();
    // Task 15：玩家持有金币（投降结算 16.3：≥500 支付保全、不足则交付舰船）。Demo 初始值=投降金（500），
    // 表现层可在创建战斗时配置其他初始值（测试可设 500+/不足 500 两种）。
    public int PlayerGold { get; set; } = SurrenderRules.SurrenderGoldCost;
    // Task 15：投降层数（每优势阵营 0..4 → 成功率 20/40/60/80/100）。完整回合末条件仍成立 +1、失效 -1（最低 0）。
    public Dictionary<FactionId, int> SurrenderTiers { get; } = new();
    // Task 15：玩家被成功劝降后的待决状态（OfferingFaction=发起劝降的优势方）。Accept/Reject 消费，
    // 玩家（被劝降方）回合结束时由 SurrenderRules.ProcessPlayerTurnEnd 作废（审查 Important-1 修复：给被劝降方一整轮应答窗口）。
    public FactionId? PendingSurrenderFrom { get; set; }
    // Task 15 修复（审查 Important-2）：各优势方"最近发起劝降的回合号"。同一回合（battle.Round 相等）内
    // 已发起过 → 拒绝再发（设计 16.2"优势方每回合可选择是否发起劝降"，防反复重掷刷成功率）。
    // 以"记录回合号 + 与 battle.Round 比较"实现每回合一次，回合推进后自动放开，无需显式重置。
    public Dictionary<FactionId, int> LastOfferedRounds { get; } = new();
    // V-1 修复（CHG-20260810-fix-surrender-end）：玩家投降认输（AcceptSurrender 成功）后的投降方阵营。
    // 投降即战斗失败结束（设计 16.2/16.3）——与"一方全没"终局（SettleAfterCommand 按留场存活舰定胜者）区分：
    // 玩家支付/交付后仍留场舰，不能据此定胜者；BattleResult.From 有本字段时胜者=对方阵营。
    public FactionId? SurrenderLoser { get; set; }
    // Task 16：离场舰登记（逃脱/被俘/礁石深海自沉即时移除/投降交付）。规则层任何"命令中途移出 battle.Ships"
    // 的移除点都须写入本日志（含离场时快照），BattleResult.From 据此构造离场舰的结果分类，不依赖请求快照。
    public Dictionary<string, RemovedShipRecord> RemovedShips { get; } = new();
    // 舰船可见性为几何判定（AttackRules.VisibleEnemies/CellVisible，设计 7.2），不维护"已知/永知"状态集。
    // V-3 修复（CHG-20260810-fx-vision-recall）：玩家阵营"最近可见格 + 滞留计数"（视野滞留机制，迷雾回归）。
    // 值 = 距上次被看到的完整回合数；≤3 表示仍在滞留可见期内（RevealedCells 计入），>3 移除归为迷雾。
    // 仅维护玩家观测（迷雾只对玩家绘制）；敌舰可见性仍为几何判定，不因滞留揭示隐藏舰。
    public Dictionary<GridPos, int> PlayerVisionFreshness { get; } = new();
    // CHG（海怪 Boss 战）：NoSurrender 关闭本场投降（Boss 战）；
    // RangeBonus 全舰队射程 +1 格（倭寇军旗 → 1；RangeBonus>0 时半径 +1）；
    // FishHuntRound/FishHuntLockedTarget 海怪02 猎杀循环与锁定目标。
    public bool NoSurrender { get; set; }
    public int RangeBonus { get; set; }
    public int FishHuntRound { get; set; }
    public string? FishHuntLockedTarget { get; set; }
    // CHG-20260819（F-1 讨伐饰品）：玩家旗舰武器升级等级（0=无升级）。
    // 海怪之角 → FlagshipRamLevel=4（撞角系数 1.8）；贯日神枪 → FlagshipBombardmentLevel=4（砲击 420 伤害）。
    // 规则层仅在「玩家旗舰 + 对应饰品已装备」时以本等级取数（weapons.json 已含 Lv4 数据），见 RamRules/AttackRules。
    public int FlagshipRamLevel { get; set; }
    public int FlagshipBombardmentLevel { get; set; }

    public ShipState? ShipOrNull(string id) => Ships.TryGetValue(id, out var s) ? s : null;
}
