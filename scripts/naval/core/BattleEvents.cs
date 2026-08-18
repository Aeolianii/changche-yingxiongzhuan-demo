namespace NavalCombat.Core;

public abstract record BattleEvent;
public sealed record ShipMovedEvent(string ShipId, GridPos Bow, int RemainingMovement) : BattleEvent;
public sealed record ShipTurnedEvent(string ShipId, CardinalDirection Facing, int RemainingMovement) : BattleEvent;
public sealed record ShipMarkedAttackEvent(string ShipId) : BattleEvent;
public sealed record FactionTurnEndedEvent(FactionId Faction) : BattleEvent;
public sealed record RoundAdvancedEvent(int Round) : BattleEvent;
// Task 7：可辨识（可见）目标的伤害事件统一基类；HiddenHitEvent 不在其中（隐藏命中不显示舰）。
public abstract record DamageEvent(string ShipId, int Amount, int HitPoints) : BattleEvent;
public sealed record ShipDamagedEvent(string ShipId, int Amount, int HitPoints) : DamageEvent(ShipId, Amount, HitPoints);
public sealed record AreaDamageEvent(GridPos Cell, string ShipId, int Amount, int HitPoints) : DamageEvent(ShipId, Amount, HitPoints);
public sealed record ShipSunkEvent(string ShipId) : BattleEvent;
// Task 7：盲射命中隐藏舰（只显示命中反馈不显示舰）。可见性为几何判定（设计 7.2），无"首次发现"持久状态。
// RevealShipEvent 由"命中可见舰"触发，供表现层揭示/确认目标位置；盲射隐藏命中不发。
public sealed record HiddenHitEvent(GridPos Cell, string ShipId, int Amount, int HitPoints) : BattleEvent;
public sealed record RevealShipEvent(string ShipId) : BattleEvent;
// Task 9：撞击（设计 10）。碰撞类型按撞击舰船头接触的目标占格段判定（索引 0=船头、末格=船尾、其余=船身）。
public enum RamCollisionKind { BowToBow, BowToHull, BowToStern }
// 撞击事件派生自 DamageEvent（ShipId=目标舰，Amount=目标实际所受撞击伤害，HitPoints=目标剩余生命）。
// 额外携带撞击方反伤、碰撞类型、是否推动/受阻/入礁、礁石伤害；沉没仍另发 ShipSunkEvent。
public sealed record RamHitEvent(
    string ShipId,
    int Amount,
    int HitPoints,
    int RammerDamage,
    int RammerHitPoints,
    RamCollisionKind Kind,
    bool Pushed,
    bool PushBlocked,
    bool IntoReef,
    int ReefDamage) : DamageEvent(ShipId, Amount, HitPoints);

// Task 10：接舷/脱离/俘获（设计 11）。
// 接舷发起：双方立即受各自舰型固定接舷伤（无视护甲），携带双方伤害与结算后生命。
public sealed record BoardingLinkedEvent(
    string InitiatorId,
    string DefenderId,
    int InitiatorDamage,
    int InitiatorHitPoints,
    int DefenderDamage,
    int DefenderHitPoints) : BattleEvent;

// 接舷伤害交换（任一方触发）。Captured: null=未判定（防守方交换/进度 0/沉没），true/false=原发起方判定结果。
public sealed record BoardingDamageEvent(
    string ActorId,
    int InitiatorDamage,
    int InitiatorHitPoints,
    int DefenderDamage,
    int DefenderHitPoints,
    bool? Captured) : BattleEvent;

public sealed record BoardingDisengagedEvent(string ActorId, bool Success, double SuccessRate) : BattleEvent;

public sealed record BoardingPairMovedEvent(string DefenderId, GridPos InitiatorBow, GridPos DefenderBow, int PairMovesUsed) : BattleEvent;

// 俘获成功：目标立即移出战场（不能本场转友军）；战后计入俘获（Task 16 结果）。
public sealed record ShipCapturedEvent(string ShipId, string CaptorId) : BattleEvent;

// 完整回合边界俘获进度变化（表现层状态图标用）。Reason: "advantage"（晋级）/"decay"（衰减）。
public sealed record CaptureProgressChangedEvent(string InitiatorId, string DefenderId, int Progress, string Reason) : BattleEvent;

// Task 11：技能与持续状态（设计 12）。
// 连锁弹命中：目标舰被施加减速持续状态（RoundsLeft = 施加时的持续回合数，此后每目标阵营回合开始递减）。
public sealed record ChainShotAppliedEvent(string ShipId, GridPos Cell, int SlowRoundsLeft) : BattleEvent;
// 火油/强化箭雨命中：目标舰被附加烧伤（Rounds = 施加时的持续回合数）。
public sealed record BurnAppliedEvent(string ShipId, int Rounds) : BattleEvent;
// 烧伤 tick：目标阵营回合开始时固定 50 点无视护甲伤害（Amount=本回合烧伤伤害，HitPoints=结算后生命）。
public sealed record BurnTickEvent(string ShipId, int Amount, int HitPoints) : BattleEvent;
// 烧伤燃尽/被熄灭/被损管清除。
public sealed record BurnEndedEvent(string ShipId) : BattleEvent;
// 损管/持续恢复回血（Amount=本回合回复量，HitPoints=结算后生命）。
public sealed record ShipHealedEvent(string ShipId, int Amount, int HitPoints) : BattleEvent;
// 敌方伤害打断损管：该舰 Repairs 全部清空（环境伤害不触发）。
public sealed record RepairsInterruptedEvent(string ShipId) : BattleEvent;

// Task 12：水雷（设计 13）。
// 布雷成功（ShipId=布雷舰，Cell=雷格）。
public sealed record MinePlacedEvent(string ShipId, GridPos Cell) : BattleEvent;
// 正常触雷（设计 13.1）：ShipId=触雷舰，Cell=水雷格，Amount=最大生命 30% 无视护甲伤害，HitPoints=结算后生命。
public sealed record MineTriggeredEvent(string ShipId, GridPos Cell, int Amount, int HitPoints) : BattleEvent;
// 水雷被伤害（范围攻击/水雷爆炸命中水雷格且未被移除）：Amount=护甲减免后伤害，HitPoints=水雷剩余生命。
public sealed record MineDamagedEvent(GridPos Cell, int Amount, int HitPoints) : BattleEvent;
// 水雷九宫爆炸逐格（设计 13.2）：Center=爆炸水雷格，Cell=被覆盖格（含自身格），Damage=该格所受伤害（0=无目标）。
public sealed record MineExplodedEvent(GridPos Center, GridPos Cell, int Damage) : BattleEvent;

// Task 14：自沉/残骸/逃跑/终局（设计 15、16.1）。
// 主动自沉：HpLost=布阵 0 / 战斗浅滩最大生命 15%（舍入）；LeftWreck=true 表示命令即时留下残骸（礁石自沉）。
public sealed record ShipSelfSunkEvent(string ShipId, int HpLost, bool LeftWreck) : BattleEvent;
// 逃跑成功：任一占格触碰出口边界，整舰立即移出战场。
public sealed record ShipEscapedEvent(string ShipId) : BattleEvent;
// 终局：任一方所有留场舰船均已沉没/被俘/逃离。Winner=存活方；双方同时全没（如撞击同归于尽）为 null。
public sealed record BattleEndedEvent(FactionId? Winner) : BattleEvent;

// Task 15：指挥舰/投降（设计 16.2/16.3）。
// 劝降掷骰结果：OfferingFaction=优势方，TargetFaction=被劝降方，Tier/SuccessRate=本次判定所用层数与成功率(%)，Success=掷骰通过。
public sealed record SurrenderOfferedEvent(FactionId OfferingFaction, FactionId TargetFaction, int Tier, int SuccessRate, bool Success) : BattleEvent;
// 敌降成功：JoinedShipIds=加入我方的原敌舰（保留投降时生命值，进入战后维修 T16）。
public sealed record EnemySurrenderedEvent(string[] JoinedShipIds) : BattleEvent;
// 玩家接受投降：PaidGold=true → GoldPaid=支付的 500 金并保全留场舰船；PaidGold=false → DeliveredShipIds=交付舰（已移出战场），GoldPaid=0。
public sealed record PlayerSurrenderedEvent(string[] DeliveredShipIds, int GoldPaid, bool PaidGold) : BattleEvent;
// 玩家拒绝劝降：继续战斗。
public sealed record PlayerSurrenderRejectedEvent(FactionId OfferingFaction) : BattleEvent;
// 完整回合末投降层数变化（表现层成功率进度图标用）。Tier/SuccessRate=调整后层数与成功率。
public sealed record SurrenderTierChangedEvent(FactionId OfferingFaction, int Tier, int SuccessRate) : BattleEvent;
