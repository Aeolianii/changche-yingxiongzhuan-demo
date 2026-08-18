#nullable enable

namespace NavalCombat.Core;

// Task 16：离场舰的移除原因（BattleState.RemovedShips 日志分类依据）。
public enum ShipRemovalReason
{
    Escaped,    // 逃脱：任占格触出口边界（BattleEndRules.SettleAfterCommand 自动移出）
    Captured,   // 被俘：接舷俘获成功（BoardingRules.ResolveExchange）
    SelfSunk,   // 礁石/深海主动自沉：命令即时移除（BattleEndRules.ResolveSelfSink）
    Delivered,  // 投降交付：玩家被劝降按 ⌊符合舰÷3⌋ 交付（SurrenderRules.ResolveAccept）
}

// 离场舰快照：规则层在任何"命令中途移出 battle.Ships"的移除点登记。
// BattleResult.From 据此构造离场舰的结局分类与最终生命/状态。
public sealed record RemovedShipRecord(
    string DefinitionId,
    FactionId Faction,
    int FinalHitPoints,
    int MaxHp,
    bool SelfSunk,
    ShipRemovalReason Reason);
