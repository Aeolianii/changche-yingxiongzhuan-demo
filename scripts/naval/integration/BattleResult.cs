#nullable enable
using System.Collections.Generic;
using System.Linq;
using NavalCombat.Core;

namespace NavalCombat.Integration;

// Task 16（设计 17/18）：海战层 → 剧情层的战斗结果。胜负（或平局）+ 每舰结局分类 + 最终生命/状态 + 金币结余。
// 构造自 BattleState（BattleResult.From）：在场舰按 存活/沉没/自沉永久固定/投降移交（敌降加入我方）分类，
// 离场舰靠 BattleState.RemovedShips 日志（逃脱/被俘/投降交付/自沉即时移除）。不依赖开战请求快照。
public sealed class BattleResult
{
    public required BattleOutcome Outcome { get; init; }
    // 胜方（平局为 null）。
    public FactionId? Winner { get; init; }
    public List<ShipLossRecord> Ships { get; } = new();
    // 战斗结束时的金币结余（含投降支付等）——剧情层据此恢复舰队资源。
    public int PlayerGoldRemaining { get; init; }

    public static BattleResult From(BattleState battle)
    {
        // 胜负（设计 16.1 复用）：一方无留场存活舰即负（未出场阵营视同全灭）；双方皆无 → 平局。
        // V-1 修复（CHG-20260810-fix-surrender-end）：投降结果优先——玩家投降认输时胜者=对方（敌方），
        // 即使支付/交付后仍留场舰（投降即战斗失败结束，设计 16.2/16.3）。
        var playerAlive = battle.Ships.Values.Any(s => s.Faction == FactionId.Player && s.HitPoints > 0);
        var enemyAlive = battle.Ships.Values.Any(s => s.Faction == FactionId.Enemy && s.HitPoints > 0);
        // 评审修复（Important-2）：击沉即胜优先——IsVictoryTarget 沉没且已触发胜利结算（VictoryClaimed）→
        // 胜者=该舰敌方（玩家最后一舰与城寨同沉时仍判玩家胜，与 BattleEndRules 击沉即胜一致，不按在场存活重算）。
        // 未击沉胜利目标则回退既有 投降→playerAlive→enemyAlive 逻辑。
        var sunkTarget = battle.Ships.Values
            .FirstOrDefault(s => s.Definition.IsVictoryTarget && s.HitPoints <= 0 && s.VictoryClaimed);
        var winner = sunkTarget is not null
            ? (sunkTarget.Faction == FactionId.Player ? (FactionId?)FactionId.Enemy : FactionId.Player)
            : battle.SurrenderLoser is { } loser
                ? (loser == FactionId.Player ? (FactionId?)FactionId.Enemy : FactionId.Player)
                : playerAlive ? (FactionId?)FactionId.Player : enemyAlive ? (FactionId?)FactionId.Enemy : null;
        var outcome = winner switch
        {
            FactionId.Player => BattleOutcome.PlayerVictory,
            FactionId.Enemy => BattleOutcome.EnemyVictory,
            _ => BattleOutcome.Draw,
        };

        var result = new BattleResult { Outcome = outcome, Winner = winner, PlayerGoldRemaining = battle.PlayerGold };
        foreach (var s in battle.Ships.Values)
            result.Ships.Add(new ShipLossRecord(s.Id, ClassifyOnField(s), s.Definition.Id, s.Faction, s.HitPoints, s.MaxHp, s.SelfSunk));
        // 离场舰：ShipId = 日志字典键（原舰 Id），DefinitionId = 快照字段。
        foreach (var (shipId, r) in battle.RemovedShips)
            result.Ships.Add(new ShipLossRecord(shipId, ClassifyRemoved(r), r.DefinitionId, r.Faction, r.FinalHitPoints, r.MaxHp, r.SelfSunk));
        return result;
    }

    // 在场舰分类：投降移交（敌降加入我方，保留生命进维修）优先于自沉/存活。
    private static ShipLossKind ClassifyOnField(ShipState s)
    {
        if (s.JoinedBySurrender) return ShipLossKind.Surrendered;
        if (s.HitPoints <= 0) return ShipLossKind.Sunk;
        if (s.SelfSunk) return ShipLossKind.Permanent;
        return ShipLossKind.Survived;
    }

    // 离场舰分类：依移除原因——逃脱/被俘直译；投降交付=投降移交；礁石深海自沉即时移除=沉没。
    private static ShipLossKind ClassifyRemoved(RemovedShipRecord r) => r.Reason switch
    {
        ShipRemovalReason.Escaped => ShipLossKind.Escaped,
        ShipRemovalReason.Captured => ShipLossKind.Captured,
        ShipRemovalReason.Delivered => ShipLossKind.Surrendered,
        _ => ShipLossKind.Sunk,
    };
}

// 战斗胜负（剧情层据此推进剧情/奖励）。
public enum BattleOutcome
{
    PlayerVictory,
    EnemyVictory,
    Draw,
}

// 每舰结局分类：存活 / 沉没 / 逃脱 / 被俘 / 投降移交（敌降加入与玩家交付）/ 自沉永久固定。
public enum ShipLossKind
{
    Survived,
    Sunk,
    Escaped,
    Captured,
    Surrendered,
    Permanent,
}

// 每舰结局明细：剧情层据此决定 损失扣减 / 维修范围 / 展示。
public sealed record ShipLossRecord(
    string ShipId,
    ShipLossKind Kind,
    string DefinitionId,
    FactionId Faction,
    int FinalHitPoints,
    int MaxHp,
    bool SelfSunk);
