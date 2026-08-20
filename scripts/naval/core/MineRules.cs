#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

// 水雷实体（设计 13.2）：300 生命、护甲 1。
// 同一格至多一颗雷（BattleMap.Mines 以 GridPos 为键），故以格为唯一身份。
public sealed class Mine
{
    public GridPos Cell { get; set; }
    public int HitPoints { get; set; } = 300;
    public int ArmorLevel { get; set; } = 1;
    // 发现状态（设计 13.1）：敌方（相对 OwnerFaction）最近格距 ≤ 2 时置真，永久保持（离开探测范围不重新隐藏）。
    public bool Revealed { get; set; }
    public FactionId OwnerFaction { get; set; }
}

// Task 12：水雷（设计文档第 13 节 + 简报 Task 12）。
// 放置（13.1）：每技能位每场 2 次（SkillUsesLeft["mine"]，初始值由装配层配置，skills.json mine UsesPerSlot=2）；
//               目标格须与布雷舰某船体格正交相邻且非正前方（侧面/尾部邻格）；界内、非残骸、非舰船占用、无水雷；消耗攻击动作。
// 探测（13.1）：敌方与水雷最近格距 ≤ 2（欧氏 d2 ≤ 4）发现；发现后永久保持可见。
// 正常触发（13.1）：挂在 MovementRules.TryTranslate 成功平移后；敌舰任一船体格经过雷格即触发，
//               只对触雷舰造成最大生命 30% 的无视护甲伤害，不产生范围爆炸；水雷触发后立即移除；
//               触雷舰未沉且仍有移动点可继续移动，再次遇雷重复触发。友军移动不触发。
// 击破爆炸（13.2）：被允许伤害源（箭雨/砲击/火炮/水雷爆炸）降至 0 生命 → 九宫格爆炸（自身格+周围 8 格），
//               每格 350 可被护甲减免、不分敌我；多格舰每个被覆盖船体格分别受一次；可伤害其他水雷（护甲1 → 315）
//               并被击破 → 连锁爆炸；连锁用队列 + 已处理集合（每雷只爆一次）；被击破并爆炸的水雷在结算后移除。
// 禁用伤害源（火油/连锁弹/撞击/接舷）不经过本模块结算，天然不能伤害水雷。
public static class MineRules
{
    public const int NormalTriggerDamagePercent = 30; // 正常触雷：最大生命 30%（设计 13.1）
    public const int ExplosionDamage = 350;           // 击破爆炸：每格 350（设计 13.2）
    public const int DetectSquaredRange = 4;          // 探测：最近格距 ≤ 2 → d2 ≤ 4（设计 13.1）

    // —— 放置（设计 13.1）——

    // 只读查询（T13）：当前舰可布雷格集合（UI 布雷按钮可用性 + 目标格高亮复用，不重复实现规则）。
    // 复用 CanPlaceAt（侧/后邻格、界内空格）；次数/动作校验经 ValidatePlace 在按钮可用性处判定。
    // UX-1 性能优化：CanPlaceAt 只允许与某船体格曼哈顿距离 1 的侧/后邻格 → 半径 1 窗口即可覆盖全部候选
    //（正前格也在窗口内但由 CanPlaceAt 排除），结果集与全图扫描一致（纯性能优化）。
    public static List<GridPos> QueryMineCells(BattleState battle, ShipState ship)
    {
        var result = new List<GridPos>();
        if (ship is null || ship.HitPoints <= 0) return result;
        var (minX, maxX, minY, maxY) = GeometryRules.ScanWindow(ship, 1, battle.Map);
        for (var x = minX; x <= maxX; x++)
            for (var y = minY; y <= maxY; y++)
            {
                var cell = new GridPos(x, y);
                if (CanPlaceAt(battle, ship, cell)) result.Add(cell);
            }
        return result;
    }

    // 校验：返回 null 表示合法，否则为拒绝原因 key（ActionResolver 用；非法不耗动作/次数）
    public static string? ValidatePlace(BattleState battle, PlaceMineCommand cmd)
    {
        var ship = battle.ShipOrNull(cmd.ShipId);
        if (ship is null || ship.HitPoints <= 0) return "action.unknown_ship";
        if (ship.Faction != battle.CurrentFaction) return "action.unknown_ship";
        if (ship.HasAttacked) return "action.attack_ended_movement";
        if (ship.SkillUsesLeft.GetValueOrDefault("mine", 0) < 1) return "skill.no_uses";
        if (ship.Boarding is not null) return "boarding.locked"; // 接舷中禁独立动作
        if (!CanPlaceAt(battle, ship, cmd.TargetCell)) return "mine.invalid_cell";
        return null;
    }

    public static BattleEvent[] ResolvePlace(BattleState battle, PlaceMineCommand cmd)
    {
        if (ValidatePlace(battle, cmd) is not null) return Array.Empty<BattleEvent>();
        var ship = battle.ShipOrNull(cmd.ShipId)!;
        ship.SkillUsesLeft["mine"] -= 1;
        var mine = new Mine { Cell = cmd.TargetCell, OwnerFaction = ship.Faction };
        battle.Map.PlaceMine(mine);
        // 放置后刷新探测：若敌方已在探测范围内则当场发现（设计 13.1）
        UpdateReveal(battle);
        return new BattleEvent[] { new MinePlacedEvent(ship.Id, mine.Cell) };
    }

    // 侧/后邻格（裁定 5）：目标格与某船体格正交相邻（曼哈顿距离 1）且不是该格的"正前方格"（c + 船头方向）。
    // 即前向排除、侧向/尾向均合法；"空格"=界内 + 非残骸 + 非舰船占用 + 无水雷（裁定 6，不限地形）。
    public static bool CanPlaceAt(BattleState battle, ShipState ship, GridPos cell)
    {
        if (!battle.Map.InBounds(cell)) return false;
        if (battle.Map.IsWreck(cell)) return false;
        if (battle.Map.MineAt(cell) is not null) return false;
        if (battle.Ships.Values.Any(s => s.HitPoints > 0 && s.OccupiedCells().Contains(cell))) return false;
        var front = ship.Facing.Vector();
        foreach (var c in ship.OccupiedCells())
        {
            if (c + front == cell) continue; // 正前方排除（侧面/尾部合法）
            var d = cell - c;
            if (Math.Abs(d.X) + Math.Abs(d.Y) == 1) return true;
        }
        return false;
    }

    // —— 探测（设计 13.1）——

    // 敌方（相对雷主阵营）任一活舰最近格距 ≤ 2 → 永久发现。成功平移后与放置后调用；标志只置真不回退。
    public static void UpdateReveal(BattleState battle)
    {
        foreach (var mine in battle.Map.Mines.Values)
        {
            if (mine.Revealed) continue;
            foreach (var ship in battle.Ships.Values)
            {
                if (ship.HitPoints <= 0 || ship.Faction == mine.OwnerFaction) continue; // 仅敌方触发探测
                if (GeometryRules.NearestSquaredDistance(ship.OccupiedCells(), new List<GridPos> { mine.Cell }) <= DetectSquaredRange)
                {
                    mine.Revealed = true;
                    break;
                }
            }
        }
    }

    // —— 正常触发（设计 13.1；挂在 MovementRules.TryTranslate 成功平移后）——

    // 敌舰任一船体格经过水雷格立即触发：30% 最大生命无视护甲，不产生范围爆炸；水雷触发后立即移除。
    // 不阻塞移动：触雷舰未沉且仍有移动点可继续移动；再次遇雷重复触发。友军（与雷主同阵营）不触发。
    public static BattleEvent[] AfterShipMoved(BattleState battle, ShipState ship)
    {
        UpdateReveal(battle);
        return TriggerForShip(battle, ship);
    }

    // 任意成功位移（转向 / 撞击推动 / 接舷组合平移）后的统一刷新（评审修复：这些路径此前不触发也不探测）。
    // = 先 UpdateReveal 全图探测，再对每艘敌舰当前占格做"经过"触发判定；语义与 AfterShipMoved 完全一致
    //   （友军不触发、30% 最大生命无视护甲、触发即移除、不阻塞位移本身、多雷逐雷重复触发、爆炸仍走既有队列）。
    // 返回 MineEvents 供命令结果并入事件流（与 MoveOutcome.MineEvents 同语义）。
    public static BattleEvent[] RefreshMines(BattleState battle)
    {
        UpdateReveal(battle);
        var events = new List<BattleEvent>();
        foreach (var ship in battle.Ships.Values)
        {
            if (ship.HitPoints <= 0) continue;
            events.AddRange(TriggerForShip(battle, ship));
        }
        return events.ToArray();
    }

    // 单舰当前占格的"经过"触发判定：敌舰任一船体格压上雷格即触发。被 AfterShipMoved/RefreshMines 复用。
    private static BattleEvent[] TriggerForShip(BattleState battle, ShipState ship)
    {
        // CHG（海怪 Boss 战）：MineImmune（海怪01）水雷免疫，压上雷格不触发、不消耗雷。
        if (ship.Definition.MineImmune) return Array.Empty<BattleEvent>();
        var events = new List<BattleEvent>();
        foreach (var cell in ship.OccupiedCells())
        {
            var mine = battle.Map.MineAt(cell);
            if (mine is null || mine.OwnerFaction == ship.Faction) continue; // 友军不触发
            battle.Map.RemoveMine(mine); // 触发后立即移除
            // CHG（海怪 Boss 战）：伤害按舰型 MineDamagePercent（默认 0.30 = 旧 30% 行为）。
            var amount = DamageRules.Calculate(
                new DamagePacket(ship.MaxHp * ship.Definition.MineDamagePercent, ship.ArmorLevel, IgnoresArmor: true)).FinalDamage;
            ship.HitPoints -= amount;
            events.Add(new MineTriggeredEvent(ship.Id, cell, amount, ship.HitPoints));
            // 水雷伤害打断损管（设计 12.3 明列"水雷"，裁定 3）
            if (StatusRules.InterruptRepairs(ship)) events.Add(new RepairsInterruptedEvent(ship.Id));
            if (ship.HitPoints <= 0) events.Add(new ShipSunkEvent(ship.Id));
        }
        return events.ToArray();
    }

    // —— 击破爆炸（设计 13.2）——

    // 水雷因攻击降至 0 生命 → 九宫格爆炸（自身格 + 周围 8 格），每格 350 可被护甲减免、不分敌我。
    // 可伤害其他水雷（护甲 1 → 315）并被击破 → 连锁爆炸；连锁用队列 + 已处理集合（每雷只爆一次，裁定 7）。
    // 被击破并爆炸的水雷在结算后移除。事件：逐格 MineExplodedEvent + 逐格 ShipDamagedEvent + 按舰去重沉没/打断。
    public static BattleEvent[] ResolveMineExplosion(BattleState battle, Mine mine)
    {
        var events = new List<BattleEvent>();
        var queue = new Queue<Mine>();
        var processed = new HashSet<GridPos>();
        var damagedShips = new HashSet<string>();
        queue.Enqueue(mine);
        while (queue.Count > 0)
        {
            var current = queue.Dequeue();
            if (!processed.Add(current.Cell)) continue; // 每雷只爆一次
            battle.Map.RemoveMine(current); // 被击破并爆炸的水雷在结算后移除
            foreach (var cell in NineGridCells(current.Cell))
            {
                if (!battle.Map.InBounds(cell)) continue;
                var dmg = 0;
                var ship = battle.Ships.Values.FirstOrDefault(s => s.HitPoints > 0 && s.OccupiedCells().Contains(cell));
                if (ship is not null)
                {
                    dmg = DamageRules.Calculate(new DamagePacket(ExplosionDamage, ship.ArmorLevel, IgnoresArmor: false)).FinalDamage;
                    ship.HitPoints -= dmg;
                    events.Add(new ShipDamagedEvent(ship.Id, dmg, ship.HitPoints));
                    damagedShips.Add(ship.Id);
                }
                else
                {
                    var other = battle.Map.MineAt(cell);
                    if (other is not null)
                    {
                        var mineDmg = DamageRules.Calculate(new DamagePacket(ExplosionDamage, other.ArmorLevel, IgnoresArmor: false)).FinalDamage; // 护甲1 → 315
                        other.HitPoints -= mineDmg;
                        dmg = mineDmg;
                        events.Add(new MineDamagedEvent(cell, mineDmg, other.HitPoints));
                        if (other.HitPoints <= 0) queue.Enqueue(other); // 连锁（重复入队由 processed 在出队时去重）
                    }
                }
                events.Add(new MineExplodedEvent(current.Cell, cell, dmg)); // 九宫爆炸逐格事件
            }
        }
        // 沉没/打断按舰去重（跨连锁；每舰一条）
        foreach (var shipId in damagedShips)
        {
            var ship = battle.ShipOrNull(shipId)!;
            if (StatusRules.InterruptRepairs(ship)) events.Add(new RepairsInterruptedEvent(ship.Id));
            if (ship.HitPoints <= 0) events.Add(new ShipSunkEvent(ship.Id));
        }
        return events.ToArray();
    }

    // 九宫格：自身格 + 周围 8 格（含对角线，设计 13.2"自身格和周围8格"）
    private static IEnumerable<GridPos> NineGridCells(GridPos center)
    {
        for (var dx = -1; dx <= 1; dx++)
            for (var dy = -1; dy <= 1; dy++)
                yield return center + new GridPos(dx, dy);
    }
}
