namespace NavalCombat.Core;

public abstract record BattleCommand;
public sealed record MoveCommand(string ShipId, CardinalDirection Direction) : BattleCommand;
public sealed record TurnCommand(string ShipId, TurnDirection Direction) : BattleCommand;
public sealed record MarkAttackCommand(string ShipId) : BattleCommand;
// Task 7：三种远程攻击。Level 为武器等级（1-3），Target 为范围中心格（玩家瞄准格）。
// Enhanced（Task 11 火油强化箭雨）：装备火油时置 true，消耗 1 次火油、即时伤害 ×1.5、命中舰附加 2 回合烧伤。
public sealed record ArrowRainCommand(string ShipId, GridPos Target, bool Enhanced = false) : BattleCommand;
public sealed record BombardmentCommand(string ShipId, GridPos Target, int Level) : BattleCommand;
public sealed record CannonCommand(string ShipId, GridPos Target, int Level) : BattleCommand;
// Task 9：撞击（设计 10）。TargetId 为目标舰；资格要求最后一段平移为船头朝目标的接近移动。
public sealed record RamCommand(string ShipId, string TargetId) : BattleCommand;
// Task 10：接舷（设计 11）。ShipId=发起方，TargetId=被接舷方；要求平行且间隔 0（最近占格距离 1）。
public sealed record BoardCommand(string ShipId, string TargetId) : BattleCommand;
// Task 10：接舷伤害交换（任一方可消耗该舰动作触发，双方同时受各自接舷伤；原发起方触发时含俘获判定）。
public sealed record BoardingExchangeCommand(string ShipId) : BattleCommand;
// Task 10：脱离。原发起方必定脱离；防守方按成功率掷随机；任一方尝试都消耗动作并立即结束本舰回合。
public sealed record DisengageCommand(string ShipId) : BattleCommand;
// Task 10：接舷组合平移（设计 11.1）。ShipId=原被接舷方（防守方），仅防守方在其阵营回合控制组合整体平移。
public sealed record BoardPairMoveCommand(string ShipId, CardinalDirection Direction) : BattleCommand;
// Task 11：技能（设计 12）。连锁弹/火油为格目标（与远程攻击一致）；损管无目标（作用于自身）。
public sealed record ChainShotCommand(string ShipId, GridPos Target) : BattleCommand;
public sealed record FireOilCommand(string ShipId, GridPos Target) : BattleCommand;
public sealed record DamageControlCommand(string ShipId) : BattleCommand;
// Task 12：布雷（设计 13.1）。每技能位每场 2 次（SkillUsesLeft["mine"]）；TargetCell 为布雷舰侧/后相邻空格；消耗本舰攻击动作。
public sealed record PlaceMineCommand(string ShipId, GridPos TargetCell) : BattleCommand;
// Task 14：主动自沉（设计 15）。DeploymentPhase=true 表示布阵阶段（浅滩自沉不损失生命）。
public sealed record SelfSinkCommand(string ShipId, bool DeploymentPhase = false) : BattleCommand;
// Task 15：指挥舰/投降（设计 14、16.2、16.3）。
// OfferingFaction=发起劝降的优势方（掷成功率骰；被劝降方为对侧阵营）。敌降成功即时结算；我降成功置待决（玩家 Accept/Reject）。
public sealed record OfferSurrenderCommand(FactionId OfferingFaction) : BattleCommand;
// 玩家接受劝降（仅我方被成功劝降且待决时合法）。持有≥500金 → 支付保全（DeliveredShipIds 必须为空）；
// 不足 → 交付 DeliveredShipIds 指定舰（数量=⌊符合条件现存舰数÷3⌋，玩家指定、不随机）。
public sealed record AcceptSurrenderCommand(string[] DeliveredShipIds) : BattleCommand;
// 玩家拒绝劝降：清除待决并继续战斗。
public sealed record RejectSurrenderCommand : BattleCommand;
public sealed record EndFactionTurnCommand : BattleCommand;
// CHG（海怪 Boss 战）：海怪01 触手与移动。TentacleKind 区分一阶段多目标线/二阶段单目标线。
public enum TentacleKind { MultiThree, SingleFive }
public sealed record TentacleStrikeCommand(string ShipId, GridPos Target, TentacleKind Kind) : BattleCommand;
// 海怪移动预告（免费动作）：Path 计划路径（含终点），SurfaceMove=true 水面（仅二阶段）。设 PendingMonsterMovePreview。
public sealed record MonsterDeclareMoveCommand(string ShipId, GridPos[] Path, bool SurfaceMove) : BattleCommand;
// 海怪移动执行（占动作）：Destination 终点；校验 = 预告路径终点一致。执行位移 + 路径伤害/落点伤害+推开。
public sealed record MonsterMoveCommand(string ShipId, GridPos Destination) : BattleCommand;
// CHG（海怪 Boss 战）：海怪02 冲撞与飞越。
public sealed record FishChargeCommand(string ShipId, CardinalDirection Direction) : BattleCommand;
public sealed record FishLeapMoveCommand(string ShipId, CardinalDirection Direction) : BattleCommand;
