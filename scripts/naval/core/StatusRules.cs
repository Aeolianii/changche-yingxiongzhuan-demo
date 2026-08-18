#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

// Task 11：持续状态与技能（设计文档第 12 节 + 简报 Task 11）。
// 连锁弹：每技能位 2 次、最近格距 3-5，命中目标减速一级持续 3 回合、最低 V1（EffectiveSpeedTier 已处理），
//         多次命中叠加、每层独立计时（SpeedPenalties 每条 TimedSpeedPenalty，每目标阵营回合开始递减，归零移除），
//         不造成直接伤害；格内无敌方活舰（空格/友舰）为落空但仍消耗动作与次数（设计 7.3 盲射语义）。
// 火油：每技能位 1 次、最近格距 3-4，作用区 = 目标轴向 2 格 + 末端后方延伸 1 格（共 3 格直线），方向取攻击舰
//        最近格到目标的主导轴并沿远离攻击舰的方向（裁定 2）；命中附 3 回合烧伤，直接使用无即时伤害。
//        强化箭雨（ArrowRainCommand Enhanced: true）消耗 1 次火油：即时伤害 ×1.5 + 命中舰附 2 回合烧伤。
// 烧伤：每舰至多一条，施加时刷新取当前与新效果的较大值（不叠加伤害）；目标阵营回合开始固定 50 点无视护甲伤害
//        （可击沉）；雨天先伤害再 50% 熄灭判定（走 battle.Random）；台风可施加但下一次烧伤造成伤害后必熄；
//        其余天气每回合递减、归零燃尽。烧伤为敌方造成 → 打断损管。
// 损管：每技能位 3 次；消耗动作 + 1 次技能次数，立即恢复最大生命 15%（round AwayFromZero、封顶 MaxHp）并清除烧伤，
//        此后 5 个己方阵营回合开始每回合恢复最大生命 2%（Repairs 每条 RepairOverTime(5)）；多次损管独立叠加。
//        所有敌方造成的伤害（武器/撞击/接舷/烧伤）结算后清空该舰 Repairs；礁石/台风等环境伤害不打断（裁定 8）。
// 回合结算：ProcessFactionTurnStart 在阵营回合开始时（EndTurn 切换到新阵营后）结算该阵营舰船：
//        烧伤伤害+熄灭（先于回血，烧伤伤害打断损管）、损管回血 tick 递减、连锁弹计时递减。
public static class StatusRules
{
    public const int BurnDamagePerTick = 50;       // 设计 12.2：烧伤每回合固定 50 无视护甲
    public const double RainExtinguishChance = 0.50; // 雨天先伤害再 50% 熄灭判定（裁定 7）

    // —— 技能参数（读 battle.Config.Skills，缺失时回退设计文档默认值）——

    private static SkillDefinition? SkillOf(BattleState battle, string id)
        => battle.Config.Skills.FirstOrDefault(s => s.Id == id);

    private static int SlowRoundsOf(BattleState battle) => SkillOf(battle, "chain_shot")?.SlowRounds ?? 3;
    private static int BurnRoundsOf(BattleState battle) => SkillOf(battle, "fire_oil")?.BurnRounds ?? 3;
    private static int InstantHealPercentOf(BattleState battle) => SkillOf(battle, "damage_control")?.InstantHealPercent ?? 15;
    private static int RegenRoundsOf(BattleState battle) => SkillOf(battle, "damage_control")?.RegenRounds ?? 5;
    private static int RegenPercentOf(BattleState battle) => SkillOf(battle, "damage_control")?.RegenPercent ?? 2;

    // —— 校验（ActionResolver 用；null = 合法，否则为拒绝原因 key）——

    public static string? ValidateChainShot(BattleState battle, ChainShotCommand cmd)
    {
        var attacker = battle.ShipOrNull(cmd.ShipId);
        if (attacker is null || attacker.HitPoints <= 0) return "action.unknown_ship";
        if (attacker.Faction != battle.CurrentFaction) return "action.unknown_ship";
        if (attacker.HasAttacked) return "action.attack_ended_movement";
        if (attacker.SkillUsesLeft.GetValueOrDefault("chain_shot", 0) < 1) return "skill.no_uses";
        var d2 = GeometryRules.NearestSquaredDistance(attacker.OccupiedCells(), new List<GridPos> { cmd.Target });
        if (d2 < 9 || d2 > 25) return "action.out_of_range"; // 最近格距 3-5（设计 12.1）
        return null;
    }

    // 只读查询（T13）：连锁弹当前合法目标格集合（UI 连锁弹按钮可用性 + 目标格高亮复用，不重复实现规则）。
    // 复用 ValidateChainShot（含 HasAttacked/次数/射程校验）。
    // UX-1 性能优化：射程 3-5 → 以攻击舰占格为中心、半径 5 的窗口扫描（48×36 下全图 O(W×H) 过重）。
    // 距任一占格 > 5 的格必在射程外被 ValidateChainShot 拒绝，结果集与全图扫描一致（纯性能优化）。
    public static List<GridPos> QueryChainShotCells(BattleState battle, ShipState ship)
    {
        var result = new List<GridPos>();
        if (ship is null || ship.HitPoints <= 0) return result;
        var (minX, maxX, minY, maxY) = GeometryRules.ScanWindow(ship, 5, battle.Map);
        for (var x = minX; x <= maxX; x++)
            for (var y = minY; y <= maxY; y++)
            {
                var cell = new GridPos(x, y);
                if (ValidateChainShot(battle, new ChainShotCommand(ship.Id, cell)) is null)
                    result.Add(cell);
            }
        return result;
    }

    // 只读查询（T13）：火油当前合法目标格集合（UI 火油按钮可用性 + 目标格高亮复用）。
    // UX-1 性能优化：射程 3-4 → 半径 4 窗口（同 QueryChainShotCells 口径，结果集不变）。
    public static List<GridPos> QueryFireOilCells(BattleState battle, ShipState ship)
    {
        var result = new List<GridPos>();
        if (ship is null || ship.HitPoints <= 0) return result;
        var (minX, maxX, minY, maxY) = GeometryRules.ScanWindow(ship, 4, battle.Map);
        for (var x = minX; x <= maxX; x++)
            for (var y = minY; y <= maxY; y++)
            {
                var cell = new GridPos(x, y);
                if (ValidateFireOil(battle, new FireOilCommand(ship.Id, cell)) is null)
                    result.Add(cell);
            }
        return result;
    }

    public static string? ValidateFireOil(BattleState battle, FireOilCommand cmd)
    {
        var attacker = battle.ShipOrNull(cmd.ShipId);
        if (attacker is null || attacker.HitPoints <= 0) return "action.unknown_ship";
        if (attacker.Faction != battle.CurrentFaction) return "action.unknown_ship";
        if (attacker.HasAttacked) return "action.attack_ended_movement";
        if (attacker.SkillUsesLeft.GetValueOrDefault("fire_oil", 0) < 1) return "skill.no_uses";
        var d2 = GeometryRules.NearestSquaredDistance(attacker.OccupiedCells(), new List<GridPos> { cmd.Target });
        if (d2 < 9 || d2 > 16) return "action.out_of_range"; // 最近格距 3-4（设计 12.2）
        return null;
    }

    public static string? ValidateDamageControl(BattleState battle, DamageControlCommand cmd)
    {
        var ship = battle.ShipOrNull(cmd.ShipId);
        if (ship is null || ship.HitPoints <= 0) return "action.unknown_ship";
        if (ship.Faction != battle.CurrentFaction) return "action.unknown_ship";
        if (ship.HasAttacked) return "action.attack_ended_movement";
        if (ship.SkillUsesLeft.GetValueOrDefault("damage_control", 0) < 1) return "skill.no_uses";
        return null;
    }

    // —— 结算（输出 BattleEvent[]；ActionResolver 在成功后置 HasAttacked = true）——

    // 连锁弹：只施加减速状态，不造成直接伤害。格内无敌方活舰（空格/友舰/自身）= 落空，但次数已在校验后由本方法消耗。
    public static BattleEvent[] ResolveChainShot(BattleState battle, ChainShotCommand cmd)
    {
        if (ValidateChainShot(battle, cmd) is not null) return Array.Empty<BattleEvent>();
        var attacker = battle.ShipOrNull(cmd.ShipId)!;
        attacker.SkillUsesLeft["chain_shot"] -= 1;
        var target = battle.Ships.Values.FirstOrDefault(s =>
            s.HitPoints > 0 && s.Faction != attacker.Faction && s.OccupiedCells().Contains(cmd.Target));
        if (target is null) return Array.Empty<BattleEvent>(); // 盲射落空：次数已消耗，无效果事件
        var rounds = SlowRoundsOf(battle);
        target.SpeedPenalties.Add(new TimedSpeedPenalty(rounds)); // 叠加：每条独立计时（设计 12.1）
        return new BattleEvent[] { new ChainShotAppliedEvent(target.Id, cmd.Target, rounds) };
    }

    // 火油：对作用区内每个敌方活舰附加 3 回合烧伤（按舰去重一次），无即时伤害。
    public static BattleEvent[] ResolveFireOil(BattleState battle, FireOilCommand cmd)
    {
        if (ValidateFireOil(battle, cmd) is not null) return Array.Empty<BattleEvent>();
        var attacker = battle.ShipOrNull(cmd.ShipId)!;
        attacker.SkillUsesLeft["fire_oil"] -= 1;
        var cells = FireOilAreaCells(attacker.OccupiedCells(), cmd.Target);
        var rounds = BurnRoundsOf(battle);
        var events = new List<BattleEvent>();
        var seen = new HashSet<string>();
        foreach (var cell in cells)
        {
            if (!battle.Map.InBounds(cell)) continue;
            var ship = battle.Ships.Values.FirstOrDefault(s =>
                s.HitPoints > 0 && s.Faction != attacker.Faction && s.OccupiedCells().Contains(cell));
            if (ship is null || !seen.Add(ship.Id)) continue;
            if (ApplyBurn(ship, rounds)) events.Add(new BurnAppliedEvent(ship.Id, rounds));
        }
        return events.ToArray();
    }

    // 损管：消耗动作 + 1 次技能次数（由 ActionResolver/本方法），立即恢复最大生命 15% 并清除烧伤，
    // 再添加 5 回合持续恢复（每己方阵营回合开始回 2%）。多次损管相互独立可叠加。
    public static BattleEvent[] ResolveDamageControl(BattleState battle, DamageControlCommand cmd)
    {
        if (ValidateDamageControl(battle, cmd) is not null) return Array.Empty<BattleEvent>();
        var ship = battle.ShipOrNull(cmd.ShipId)!;
        ship.SkillUsesLeft["damage_control"] -= 1;
        var events = new List<BattleEvent>();
        var heal = (int)Math.Round(ship.MaxHp * InstantHealPercentOf(battle) / 100.0, MidpointRounding.AwayFromZero);
        ship.HitPoints = Math.Min(ship.MaxHp, ship.HitPoints + heal);
        if (ship.Burns.Count > 0)
        {
            ship.Burns.Clear();
            events.Add(new BurnEndedEvent(ship.Id));
        }
        ship.Repairs.Add(new RepairOverTime(RegenRoundsOf(battle)));
        events.Add(new ShipHealedEvent(ship.Id, heal, ship.HitPoints));
        return events.ToArray();
    }

    // —— 状态规则（供各结算路径复用）——

    // 施加烧伤：每舰至多一条，刷新取当前与新效果的较大值（设计 12.2"刷新不叠加"，裁定 6）。
    // 返回 true 表示状态发生变化（新施加或刷新为更大值），供事件层判断是否发 BurnAppliedEvent。
    public static bool ApplyBurn(ShipState ship, int rounds)
    {
        if (ship.Burns.Count == 0)
        {
            ship.Burns.Add(new BurnStatus(rounds));
            return true;
        }
        var current = ship.Burns[0].RoundsLeft;
        if (rounds <= current) return false;
        ship.Burns[0] = ship.Burns[0] with { RoundsLeft = rounds };
        return true;
    }

    // 敌方伤害打断损管：清空该舰 Repairs。返回 true 表示确实清空（供事件层判断是否发 RepairsInterruptedEvent）。
    public static bool InterruptRepairs(ShipState ship)
    {
        if (ship.Repairs.Count == 0) return false;
        ship.Repairs.Clear();
        return true;
    }

    // 火油作用区：目标轴向 2 格 + 末端后方延伸 1 格（共 3 格直线），方向 = 攻击舰最近格指向目标的主导轴，
    // 并沿远离攻击舰的方向延伸（裁定 2）。公开供几何测试直接断言。
    public static List<GridPos> FireOilAreaCells(List<GridPos> attackerCells, GridPos target)
    {
        var nearest = attackerCells[0];
        var bestD2 = int.MaxValue;
        foreach (var c in attackerCells)
        {
            var d2 = c.SquaredDistance(target);
            if (d2 < bestD2) { bestD2 = d2; nearest = c; }
        }
        var dx = target.X - nearest.X;
        var dy = target.Y - nearest.Y;
        CardinalDirection dir;
        if (Math.Abs(dx) >= Math.Abs(dy)) dir = dx >= 0 ? CardinalDirection.East : CardinalDirection.West;
        else dir = dy >= 0 ? CardinalDirection.South : CardinalDirection.North;
        var v = dir.Vector();
        return new List<GridPos> { target, target + v, target + v * 2 };
    }

    // —— 阵营回合开始结算（设计 12；EndTurn 切换到新阵营后调用）——
    // 顺序（裁定 7）：先烧伤（伤害 + 打断损管），再损管回血，再连锁弹计时递减。
    // 只处理该阵营的活舰；烧伤伤害可击沉（沉没后不再回血/计时）。
    public static BattleEvent[] ProcessFactionTurnStart(BattleState battle, FactionId faction)
    {
        var events = new List<BattleEvent>();
        foreach (var ship in battle.Ships.Values)
        {
            if (ship.Faction != faction || ship.HitPoints <= 0) continue;

            // 1. 烧伤：固定 50 无视护甲（设计 12.2）；敌方造成 → 打断损管（先于回血，裁定 7）
            if (ship.Burns.Count > 0)
            {
                ship.HitPoints -= BurnDamagePerTick;
                events.Add(new BurnTickEvent(ship.Id, BurnDamagePerTick, ship.HitPoints));
                if (InterruptRepairs(ship)) events.Add(new RepairsInterruptedEvent(ship.Id));
                if (ship.HitPoints <= 0)
                {
                    events.Add(new ShipSunkEvent(ship.Id));
                    ship.Burns.Clear();
                    events.Add(new BurnEndedEvent(ship.Id));
                    continue; // 沉没舰不再回血/计时
                }
                // 台风：下一次烧伤造成伤害后必熄；雨天：先伤害再 50% 熄灭判定（走 battle.Random）
                var extinguish = battle.Weather == Weather.Typhoon
                    || (battle.Weather == Weather.Rainy && battle.Random.NextDouble() < RainExtinguishChance);
                if (extinguish)
                {
                    ship.Burns.Clear();
                    events.Add(new BurnEndedEvent(ship.Id));
                }
                else
                {
                    ship.Burns.RemoveAll(b => b.RoundsLeft - 1 <= 0); // 归零燃尽
                    for (var i = 0; i < ship.Burns.Count; i++)
                        ship.Burns[i] = ship.Burns[i] with { RoundsLeft = ship.Burns[i].RoundsLeft - 1 };
                    if (ship.Burns.Count == 0) events.Add(new BurnEndedEvent(ship.Id));
                }
            }

            // 2. 损管持续恢复：每个 RepairOverTime 各回 2% 最大生命（封顶 MaxHp），随后各自递减（多条独立叠加）
            if (ship.Repairs.Count > 0 && ship.HitPoints > 0)
            {
                foreach (var _ in ship.Repairs)
                {
                    var heal = (int)Math.Round(ship.MaxHp * RegenPercentOf(battle) / 100.0, MidpointRounding.AwayFromZero);
                    ship.HitPoints = Math.Min(ship.MaxHp, ship.HitPoints + heal);
                    events.Add(new ShipHealedEvent(ship.Id, heal, ship.HitPoints));
                }
                ship.Repairs.RemoveAll(r => r.TicksLeft - 1 <= 0); // 到期移除
                for (var i = 0; i < ship.Repairs.Count; i++)
                    ship.Repairs[i] = ship.Repairs[i] with { TicksLeft = ship.Repairs[i].TicksLeft - 1 };
            }

            // 3. 连锁弹计时：每层独立递减，归零移除（设计 12.1）
            ship.SpeedPenalties.RemoveAll(p => p.RoundsLeft - 1 <= 0);
            for (var i = 0; i < ship.SpeedPenalties.Count; i++)
                ship.SpeedPenalties[i] = ship.SpeedPenalties[i] with { RoundsLeft = ship.SpeedPenalties[i].RoundsLeft - 1 };
        }
        return events.ToArray();
    }
}
