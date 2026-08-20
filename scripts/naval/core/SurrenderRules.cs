#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

// Task 15：投降优势、层数与结算（设计 16.2、16.3）。
// 规则要点与简报歧义裁定见 docs/changes/CHG-20260807-surrender.md。
public static class SurrenderRules
{
    // 玩家投降需支付的金额（设计 16.3）。Demo 金币模型：BattleState.PlayerGold 初始=本值（表现层可配置）。
    public const int SurrenderGoldCost = 500;

    // 层数 0..4 → 成功率 20/40/60/80/100（设计 16.2：首次满足 20%，每完整回合末 +1 依次 40/60/80/100）。
    private static readonly int[] SuccessRates = { 20, 40, 60, 80, 100 };

    // 当前劝降成功率（%）：按该优势方层数取表；层数越界钳制到 0..4。
    public static int CurrentRate(BattleState battle, FactionId offeringFaction)
    {
        var tier = battle.SurrenderTiers.GetValueOrDefault(offeringFaction);
        return SuccessRates[Math.Clamp(tier, 0, SuccessRates.Length - 1)];
    }

    // 投降优势（设计 16.2）：三条件同时满足（advantage=优势方，target=被劝降方）：
    //  1. 对方留场存活舰数 ≤ 其开战舰数 50%（≤ 即恰好一半也算）；
    //  2. 对方指挥舰已沉没；
    //  3. 优势方留场存活舰数 > 对方。
    public static bool CanOfferSurrender(BattleState battle, FactionId advantage)
    {
        // CHG（海怪 Boss 战）：NoSurrender 关闭本场投降（Boss 战/海怪场景）。
        if (battle.NoSurrender) return false;
        if (battle.BattleEnded) return false;
        // 先登记"开战舰数/已部署阵营"（直接调用未走命令也可用）
        BattleEndRules.EnsureDeployedCounts(battle);
        var target = advantage == FactionId.Player ? FactionId.Enemy : FactionId.Player;
        // 防御：目标阵营必须确实开战过（防止把从未出场的阵营当成劝降对象）
        if (!battle.FactionsEverDeployed.Contains(target)) return false;

        var targetSurviving = BattleEndRules.SurvivingShips(battle, target);
        var targetDeployed = battle.DeployedShipCounts.GetValueOrDefault(target);
        // 条件1：targetSurviving ≤ targetDeployed × 0.5（整数化：×2 比较，避免浮点）
        if (targetSurviving * 2 > targetDeployed) return false;
        // 条件2：对方指挥舰已沉没
        if (!FlagshipRules.FlagshipSunk(battle, target)) return false;
        // 条件3：优势方留场存活舰数 > 对方
        if (BattleEndRules.SurvivingShips(battle, advantage) <= targetSurviving) return false;
        return true;
    }

    // —— 劝降命令（16.2）——

    public static ActionResult ResolveOffer(BattleState battle, FactionId offeringFaction)
    {
        if (battle.BattleEnded) return ActionResult.Rejected("surrender.battle_ended");
        if (battle.PendingSurrenderFrom is not null) return ActionResult.Rejected("surrender.pending");
        if (!CanOfferSurrender(battle, offeringFaction)) return ActionResult.Rejected("surrender.not_advantaged");
        // 每回合一次门禁（设计 16.2"优势方每回合可选择是否发起劝降"，审查 Important-2）：
        // 记录本回合（battle.Round）已发起过劝降；同回合再发起 → 拒绝，防反复重掷刷成功率；回合推进后自动放开。
        if (battle.LastOfferedRounds.TryGetValue(offeringFaction, out var lastRound) && lastRound == battle.Round)
            return ActionResult.Rejected("surrender.already_offered");
        battle.LastOfferedRounds[offeringFaction] = battle.Round;
        var target = offeringFaction == FactionId.Player ? FactionId.Enemy : FactionId.Player;
        var tier = battle.SurrenderTiers.GetValueOrDefault(offeringFaction);
        var rate = CurrentRate(battle, offeringFaction);
        // 成功率判定统一走 battle.Random（IRandomSource，设计 18 可复现）
        var success = battle.Random.NextDouble() < rate / 100.0;
        var events = new List<BattleEvent> { new SurrenderOfferedEvent(offeringFaction, target, tier, rate, success) };
        if (success)
        {
            if (target == FactionId.Enemy)
            {
                // 敌降成功：即时结算（仍在战场且存活的敌舰加入我方）
                events.AddRange(SettleEnemySurrender(battle));
            }
            else
            {
                // 我降成功：敌方 AI 发起 → 挂起等待玩家 Accept/Reject（设计 16.2 末、简报 C）
                battle.PendingSurrenderFrom = offeringFaction;
            }
        }
        return ActionResult.Ok(events.ToArray());
    }

    // —— 投降结算（16.3）——

    // 敌降：仍在战场且存活的敌舰加入我方（阵营改 Player、保留投降时生命值，进入战后维修 T16）。
    // 已逃脱/沉没/先前被俘移除的敌舰不在 battle.Ships → 天然排除。终局由调用方 SettleAfterCommand 处理。
    public static BattleEvent[] SettleEnemySurrender(BattleState battle)
    {
        var joiners = battle.Ships.Values
            .Where(s => s.Faction == FactionId.Enemy && s.HitPoints > 0)
            .ToList();
        foreach (var s in joiners)
        {
            s.Faction = FactionId.Player;
            // Task 16：标记敌降加入我方（供 BattleResult 分类"投降移交"、战后免费修满）。
            s.JoinedBySurrender = true;
        }
        return new BattleEvent[] { new EnemySurrenderedEvent(joiners.Select(s => s.Id).ToArray()) };
    }

    // 玩家可交付（交付范围）舰：Player 且 HP>0 且非自沉。已逃脱/被俘舰不在 Ships 天然排除（设计 16.3）。
    // CHG（海怪 Boss 战）：CannotSurrender（城寨/海怪）不入交付候选。
    public static List<ShipState> EligibleForDelivery(BattleState battle)
        => battle.Ships.Values
            .Where(s => s.Faction == FactionId.Player && s.HitPoints > 0 && !s.SelfSunk && !s.Definition.CannotSurrender)
            .ToList();

    // 玩家接受投降（仅我方被成功劝降且待决时合法）。持有 ≥500 金 → 支付保全；不足 → 交付 ⌊符合舰数÷3⌋（玩家指定）。
    public static ActionResult ResolveAccept(BattleState battle, AcceptSurrenderCommand cmd)
    {
        if (battle.PendingSurrenderFrom is null) return ActionResult.Rejected("surrender.not_offered");
        if (battle.BattleEnded) return ActionResult.Rejected("surrender.battle_ended");

        if (battle.PlayerGold >= SurrenderGoldCost)
        {
            // 持有 ≥500 金 → 支付 500 并保全留场舰船（交付列表必须为空）
            if (cmd.DeliveredShipIds.Length > 0) return ActionResult.Rejected("surrender.gold_path_no_delivery");
            battle.PlayerGold -= SurrenderGoldCost;
            battle.PendingSurrenderFrom = null;
            // V-1 修复（CHG-20260810-fix-surrender-end）：玩家投降认输 → 战斗立即失败结束、胜者为敌方。
            // 支付是投降代价，不改变"战斗已结束"的事实（设计 16.2/16.3）。与"一方全没"终局（SettleAfterCommand）
            // 区分：支付后玩家仍留场舰，须显式置 BattleEnded + 发 BattleEndedEvent(Enemy)，表现层走结算收尾。
            EndBattleByPlayerSurrender(battle);
            return ActionResult.Ok(
                new PlayerSurrenderedEvent(Array.Empty<string>(), SurrenderGoldCost, PaidGold: true),
                new BattleEndedEvent(FactionId.Enemy));
        }

        // 持有不足 500 金 → 不扣现有金币，交付 ⌊符合条件现存舰数÷3⌋（向下取整）
        var eligible = EligibleForDelivery(battle);
        var deliverCount = eligible.Count / 3;
        if (cmd.DeliveredShipIds.Length != deliverCount)
            return ActionResult.Rejected("surrender.delivery_count_mismatch");

        var deliveredSet = new HashSet<string>(cmd.DeliveredShipIds);
        if (deliveredSet.Count != cmd.DeliveredShipIds.Length)
            return ActionResult.Rejected("surrender.duplicate_delivery");
        foreach (var id in cmd.DeliveredShipIds)
        {
            var ship = battle.ShipOrNull(id);
            if (ship is null || ship.Faction != FactionId.Player || ship.HitPoints <= 0 || ship.SelfSunk)
                return ActionResult.Rejected("surrender.ineligible_delivery");
        }

        // 交付舰移出战场前登记"开战舰数"（含交付舰），避免此后该阵营 50% 分母被低估
        BattleEndRules.EnsureDeployedCounts(battle);
        foreach (var id in cmd.DeliveredShipIds)
        {
            // Task 16：离场前登记（投降交付），供 BattleResult 分类"投降移交"。
            if (battle.ShipOrNull(id) is { } ship)
                battle.RemovedShips[id] = new RemovedShipRecord(ship.Definition.Id, ship.Faction, ship.HitPoints, ship.MaxHp, ship.SelfSunk, ShipRemovalReason.Delivered);
            battle.Ships.Remove(id);
        }
        battle.PendingSurrenderFrom = null;
        // V-1 修复：交付是投降代价，交付后战斗立即失败结束、胜者为敌方（同支付路径；交付后未交付舰仍留场，须显式置终局）。
        EndBattleByPlayerSurrender(battle);
        return ActionResult.Ok(
            new PlayerSurrenderedEvent(cmd.DeliveredShipIds, 0, PaidGold: false),
            new BattleEndedEvent(FactionId.Enemy));
    }

    // V-1 修复：玩家投降认输的终局标记——置 BattleEnded + 记录投降方（BattleResult.From 据此定胜者=对方）。
    private static void EndBattleByPlayerSurrender(BattleState battle)
    {
        battle.BattleEnded = true;
        battle.SurrenderLoser = FactionId.Player;
    }

    // 玩家拒绝劝降：清除待决并继续战斗。
    public static ActionResult ResolveReject(BattleState battle)
    {
        if (battle.PendingSurrenderFrom is null) return ActionResult.Rejected("surrender.not_offered");
        var offering = battle.PendingSurrenderFrom.Value;
        battle.PendingSurrenderFrom = null;
        return ActionResult.Ok(new PlayerSurrenderRejectedEvent(offering));
    }

    // —— 完整回合末：层数调整（设计 16.2）——

    // 每个完整回合结束调用：对双方阵营各自独立——条件仍成立 层数+1（封顶 4=100%）、条件不成立 层数-1（最低 0）。
    // 注意（审查 Important-1 修复）：不再在此清除未决投降——待决的作废时机改为"被劝降方（玩家）自己回合结束时"，
    // 由 ProcessPlayerTurnEnd 处理，给被劝降方一整轮应答窗口。
    public static BattleEvent[] ProcessRoundEnd(BattleState battle)
    {
        var events = new List<BattleEvent>();
        foreach (var faction in new[] { FactionId.Player, FactionId.Enemy })
        {
            var before = battle.SurrenderTiers.GetValueOrDefault(faction);
            var held = CanOfferSurrender(battle, faction);
            var after = held
                ? Math.Min(before + 1, SuccessRates.Length - 1)
                : Math.Max(before - 1, 0);
            battle.SurrenderTiers[faction] = after;
            if (after != before)
                events.Add(new SurrenderTierChangedEvent(faction, after, SuccessRates[after]));
        }
        return events.ToArray();
    }

    // 玩家（被劝降方）回合结束时调用：清除未决投降（审查 Important-1 修复，设计 16.2"玩家可以拒绝并继续战斗"）。
    // 时序：敌方在其自己回合内劝降成功 → 完整回合边界（敌方 EndTurn）不再作废 → 玩家在自己整个回合内可接受/拒绝 →
    // 玩家回合结束（应答窗口关闭）时才作废。Accept/Reject 命令本身在消费时清除，此方法只处理"窗口期未作答"的作废。
    public static void ProcessPlayerTurnEnd(BattleState battle)
    {
        battle.PendingSurrenderFrom = null;
    }
}
