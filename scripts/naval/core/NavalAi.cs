#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

// Task 17：基线 AI（设计 20「首版AI只需生成合法操作并完成基础攻击、逃跑和投降」）。
// 纯规则层组件，不依赖 Godot；随机只来自规则层结算（伤害/劝降/火焰），本类不掷骰。
// 策略与裁定见 docs/changes/CHG-20260807-ai.md。
public static class NavalAi
{
    // 为指定阵营当前回合选择下一个合法命令。调用方执行后若仍为该阵营回合则再次调用（分段移动自然支持）。
    // 每次返回的命令均复刻规则层校验，保证被 ActionResolver.TryExecute 接受。
    public static BattleCommand ChooseNext(BattleState battle, FactionId faction)
    {
        // 0. 被劝降响应：对方已成功劝降我方、我方（AI）回合 → AI 决定接受/拒绝（策略见下）。
        if (battle.PendingSurrenderFrom is { } offering && offering != faction)
            return RespondToSurrender(battle, faction, offering);

        // 1. 攻击：任一己方舰能攻击可见目标 → 发攻击命令（目标/舰确定性排序）。
        var attack = ChooseAttack(battle, faction);
        if (attack is not null) return attack;

        // 2. 逃跑：明显劣势（己方留场存活舰数 ×2 ≤ 对方）→ 向出口逃跑（裁定 1：先于移动）。
        if (ClearlyDisadvantaged(battle, faction))
        {
            var escape = ChooseEscapeStep(battle, faction);
            if (escape is not null) return escape;
        }

        // 3. 劝降：三条件全满足且本回合未发起过 → 发起劝降（裁定 2：先于移动）。
        if (CanOfferLegally(battle, faction))
            return new OfferSurrenderCommand(faction);

        // 4. 移动：向最近可见敌舰逼近（无可见则向最近任意敌舰导航）。
        var move = ChooseApproachStep(battle, faction);
        if (move is not null) return move;

        // 5. 无合法进展 → 结束本阵营回合。
        return new EndFactionTurnCommand();
    }

    // —— 被劝降响应（设计 16.2「我方满足被劝降条件时由敌方AI发起，玩家可以拒绝」的 AI 侧）——
    // 策略：明显劣势（我方存活 ×2 ≤ 对方）→ 接受；否则拒绝继续战斗（裁定 3）。
    // 规则层仅「敌方劝降我方（目标=Player）」会置 PendingSurrenderFrom，故交付逻辑按 Player 阵营天然成立。
    private static BattleCommand RespondToSurrender(BattleState battle, FactionId faction, FactionId offering)
    {
        // 防御：战斗已结束则待决作废走 Reject（Reject 只需待决非空即可，恒合法）
        if (battle.BattleEnded) return new RejectSurrenderCommand();
        var clearlyWorse = BattleEndRules.SurvivingShips(battle, faction) * 2 <= BattleEndRules.SurvivingShips(battle, offering);
        if (!clearlyWorse) return new RejectSurrenderCommand();
        // 持有 ≥500 金 → 支付保全（不交付）；不足 → 交付 ⌊符合条件现存舰数÷3⌋（HP 最低、Id 序确定性选取）
        if (battle.PlayerGold >= SurrenderRules.SurrenderGoldCost)
            return new AcceptSurrenderCommand(Array.Empty<string>());
        var eligible = SurrenderRules.EligibleForDelivery(battle)
            .OrderBy(s => s.HitPoints)
            .ThenBy(s => s.Id)
            .ToList();
        var count = eligible.Count / 3;
        return new AcceptSurrenderCommand(eligible.Take(count).Select(s => s.Id).ToArray());
    }

    // —— 攻击（优先级 1）——

    private static BattleCommand? ChooseAttack(BattleState battle, FactionId faction)
    {
        var visible = AttackRules.VisibleEnemies(battle, faction).ToList();
        if (visible.Count == 0) return null;
        foreach (var ship in OwnShips(battle, faction).Where(s => !s.HasAttacked))
        {
            var targets = visible
                .OrderBy(e => GeometryRules.NearestSquaredDistance(ship.OccupiedCells(), e.OccupiedCells()))
                .ThenBy(e => e.HitPoints)
                .ThenBy(e => e.Id);
            foreach (var enemy in targets)
            {
                // 敌舰占格按与攻击舰最近格距升序尝试（多格舰攻击最近格优先）
                var cells = enemy.OccupiedCells()
                    .OrderBy(c => GeometryRules.NearestSquaredDistance(ship.OccupiedCells(), new List<GridPos> { c }))
                    .ThenBy(c => c.X)
                    .ThenBy(c => c.Y);
                foreach (var cell in cells)
                {
                    if (AttackRules.ValidateArrowRain(battle, new ArrowRainCommand(ship.Id, cell)) is null)
                        return new ArrowRainCommand(ship.Id, cell);
                    if (AttackRules.ValidateBombardment(battle, new BombardmentCommand(ship.Id, cell, 1)) is null)
                        return new BombardmentCommand(ship.Id, cell, 1);
                    if (AttackRules.ValidateCannon(battle, new CannonCommand(ship.Id, cell, 1)) is null)
                        return new CannonCommand(ship.Id, cell, 1);
                }
            }
        }
        return null;
    }

    // —— 逃跑（优先级 2）——

    private static bool ClearlyDisadvantaged(BattleState battle, FactionId faction)
        => BattleEndRules.SurvivingShips(battle, faction) * 2 <= BattleEndRules.SurvivingShips(battle, Other(faction));

    private static BattleCommand? ChooseEscapeStep(BattleState battle, FactionId faction)
    {
        if (battle.Map.ExitCells.Count == 0) return null;
        foreach (var ship in OwnShips(battle, faction))
        {
            // Task 11 收口（Task 8 评审 forward Minor）：城寨/炮台等 Immovable 舰不可移动，跳过逃跑（防 MoveCommand 被
            // MovementRules.TryTranslate 的 movement.immovable 拒绝 → 冒烟死循环）。
            if (ship.HasAttacked || ship.RemainingMovement < 1 || ship.Definition.Immovable) continue;
            var nearestExit = battle.Map.ExitCells
                .OrderBy(c => c.SquaredDistance(ship.Bow))
                .ThenBy(c => c.X)
                .ThenBy(c => c.Y)
                .First();
            var best = BestStep(battle, ship, b => b.SquaredDistance(nearestExit));
            if (best is null) continue;
            var newBow = ship.Bow + best.Value.Vector();
            if (newBow.SquaredDistance(nearestExit) < ship.Bow.SquaredDistance(nearestExit))
                return new MoveCommand(ship.Id, best.Value);
        }
        return null;
    }

    // —— 移动（优先级 4）——

    private static BattleCommand? ChooseApproachStep(BattleState battle, FactionId faction)
    {
        var visible = AttackRules.VisibleEnemies(battle, faction).ToList();
        foreach (var ship in OwnShips(battle, faction))
        {
            // Task 11 收口：城寨/炮台等 Immovable 舰不可移动，跳过逼近（防 movement.immovable 拒绝 → 死循环）。
            if (ship.HasAttacked || ship.RemainingMovement < 1 || ship.Definition.Immovable) continue;
            // 目标：最近可见敌舰；无可见 → 最近任意敌舰（基线导航近似：攻击仍只打可见，裁定 5）
            var candidates = visible.Count > 0
                ? visible
                : battle.Ships.Values.Where(s => s.Faction != faction && s.HitPoints > 0);
            var enemy = candidates
                .OrderBy(e => GeometryRules.NearestSquaredDistance(ship.OccupiedCells(), e.OccupiedCells()))
                .ThenBy(e => e.Id)
                .FirstOrDefault();
            if (enemy is null) continue; // 无任何敌舰（战斗本应已结束）
            var target = enemy.OccupiedCells()
                .OrderBy(c => c.SquaredDistance(ship.Bow))
                .ThenBy(c => c.X)
                .ThenBy(c => c.Y)
                .First();
            // 目标格：可达范围里离 target 最近的一格（可能等于当前位置 → 本回合已无进展）
            var range = ActionResolver.QueryMoveRange(battle, ship.Id);
            var goal = range
                .OrderBy(c => c.SquaredDistance(target))
                .ThenBy(c => c.X)
                .ThenBy(c => c.Y)
                .FirstOrDefault();
            if (goal == ship.Bow) continue;
            var best = BestStep(battle, ship, b => b.SquaredDistance(goal));
            if (best is null) continue;
            var newBow = ship.Bow + best.Value.Vector();
            if (newBow.SquaredDistance(goal) < ship.Bow.SquaredDistance(goal))
                return new MoveCommand(ship.Id, best.Value);
        }
        return null;
    }

    // —— 劝降合法性（优先级 3）——

    // 复刻 ResolveOffer 全部门禁，保证返回的 OfferSurrenderCommand 必被 TryExecute 接受。
    private static bool CanOfferLegally(BattleState battle, FactionId faction)
    {
        if (battle.BattleEnded) return false;
        if (battle.PendingSurrenderFrom is not null) return false;
        if (!SurrenderRules.CanOfferSurrender(battle, faction)) return false;
        if (battle.LastOfferedRounds.TryGetValue(faction, out var last) && last == battle.Round) return false;
        return true;
    }

    // —— 共享辅助 ——

    private static List<ShipState> OwnShips(BattleState battle, FactionId faction)
        => battle.Ships.Values
            .Where(s => s.Faction == faction && s.HitPoints > 0)
            .OrderBy(s => s.Id)
            .ToList();

    private static FactionId Other(FactionId f) => f == FactionId.Player ? FactionId.Enemy : FactionId.Player;

    // 单步移动合法性：复刻 MovementRules.TryTranslate（自沉/已攻击/移动点）+
    // ActionResolver.Move（接舷禁独立平移）+ FootprintValid（其他舰船/地形/残骸/界内），保证 MoveCommand 必被接受。
    private static bool CanStep(BattleState battle, ShipState ship, CardinalDirection dir)
    {
        // Task 11 收口：Immovable 舰不可移动（MovementRules.TryTranslate 会拒），单步合法性与方法级一致跳过。
        if (ship.SelfSunk || ship.HasAttacked || ship.RemainingMovement < 1 || ship.Boarding is not null || ship.Definition.Immovable)
            return false;
        var destination = ship.OccupiedCells().Select(c => c + dir.Vector()).ToList();
        return MovementRules.FootprintValid(battle, destination, ship);
    }

    // 四个方向中使评分最小且可合法移动的一步；并列取方向枚举序（North<East<South<West）保证确定性。
    private static CardinalDirection? BestStep(BattleState battle, ShipState ship, Func<GridPos, int> score)
    {
        CardinalDirection? best = null;
        var bestScore = int.MaxValue;
        foreach (var dir in new[] { CardinalDirection.North, CardinalDirection.East, CardinalDirection.South, CardinalDirection.West })
        {
            if (!CanStep(battle, ship, dir)) continue;
            var newBow = ship.Bow + dir.Vector();
            var s = score(newBow);
            if (s < bestScore) { bestScore = s; best = dir; }
        }
        return best;
    }
}
