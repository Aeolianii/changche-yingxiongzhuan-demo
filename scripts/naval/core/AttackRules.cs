#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

// Task 7：视野与三种远程攻击（箭雨/砲击/火炮）。
// 规则依据设计文档第 7/8/9 节；伤害统一走 DamageRules.Calculate（护甲减免、.5 AwayFromZero、至少 1）。

// 远程武器弧（T13）：射界弧分色用。优先级 = 结算顺序（箭雨→砲击→火炮）。
public enum WeaponKind { ArrowRain, Bombardment, Cannon }

// 射界弧格：Cell=目标格，Kind=该格首个合法武器，HasTarget=当前是否有敌舰占格（实弹格 vs 盲射空格）。
public readonly record struct AttackArcOption(GridPos Cell, WeaponKind Kind, bool HasTarget);

public static class AttackRules
{
    public const int BaseVisionRadius = 9;
    // V-3（CHG-20260810-fx-vision-recall）：视野滞留回合数——离开侦察范围的格保持可见的完整回合数（新鲜度 ≤3）。
    public const int VisionRecallTurns = 3;

    // —— 视野（设计 7.2）——

    // 天气视野修正：阴/雨 −1，台风 −3
    public static int VisionModifier(Weather weather) => weather switch
    {
        Weather.Clear => 0,
        Weather.Cloudy => -1,
        Weather.Rainy => -1,
        Weather.Typhoon => -3,
        _ => 0
    };

    // 每格视野成本：陆地（同山地）−3，其余（深水/浅滩/礁石/陆河）−1（U-2a：陆地挡视线）
    private static int CellVisionCost(TerrainType t) => TerrainRules.BlocksLineOfSight(t) ? 3 : 1;

    // 观察船头到目标格是否可见（设计 7.1/7.2），两者都过才可见：
    // ① 圆形外边界（欧氏距离）：dx²+dy² ≤ budget²，budget = 基础9 + 天气修正（阴/雨 −1、台风 −3）。
    //    圆检查在前，视野外边界是圆形（L2）而非菱形（L∞）——平地全平时线格数 max(|dx|,|dy|) ≤ 欧氏距离
    //    ≤ budget，地形累计检查不会额外拒绝；有山地时由 ② 沿射线削减可见性。
    // ② 地形视野损失沿观察射线累计：平地/浅滩/礁石每格 −1、山地 −3（CellVisionCost），累计 > budget 即不可见。
    // 舰不挡射线。
    public static bool CellVisible(BattleState battle, GridPos observer, GridPos target)
    {
        if (observer == target) return true;
        var budget = BaseVisionRadius + VisionModifier(battle.Weather);
        var dx = target.X - observer.X;
        var dy = target.Y - observer.Y;
        if (dx * dx + dy * dy > budget * budget) return false; // 欧氏圆边界（设计 7.1）
        var cost = 0;
        foreach (var cell in LineCells(observer, target))
        {
            if (!battle.Map.InBounds(cell)) continue;
            cost += CellVisionCost(battle.Map.TerrainAt(cell)); // 地形沿射线累计（设计 7.2）
            if (cost > budget) return false;
        }
        return true;
    }

    // 阵营当前可见的敌舰：任一己方活舰的船头能看到敌舰任一占格（几何判定，设计 7.2）。
    public static List<ShipState> VisibleEnemies(BattleState battle, FactionId faction)
    {
        var result = new List<ShipState>();
        foreach (var observer in battle.Ships.Values)
        {
            if (observer.Faction != faction || observer.HitPoints <= 0) continue;
            foreach (var enemy in battle.Ships.Values)
            {
                if (enemy.Faction == faction || enemy.HitPoints <= 0) continue;
                if (result.Contains(enemy)) continue;
                if (enemy.OccupiedCells().Any(c => CellVisible(battle, observer.Bow, c)))
                    result.Add(enemy);
            }
        }
        return result;
    }

    // 盲射命中判定（设计 7.2「视野外敌舰完全隐藏」/ 7.3）：目标当前是否被任一己方活舰视野看到任一占格；
    // 不在当前视野内 = 隐藏。几何判定，无"永知/已揭示"状态，敌舰离开视野即重新隐藏。攻击本身不揭示。
    public static bool IsHidden(BattleState battle, FactionId faction, ShipState ship)
        => !VisibleEnemies(battle, faction).Contains(ship);

    // F-6：该阵营当前可见的全部格集合（设计 7.2 视野）。只读查询，供表现层迷雾覆盖绘制——
    // 视野外格子画暗色迷雾，UI 不重复实现视野规则。语义与 VisibleEnemies 同口径（同一 CellVisible）：
    // 任一己方活舰船头能看到该格即计入；己方舰船头格恒可见（CellVisible(observer, observer)==true）；
    // 可见敌舰的全部占格并入集合（可见性定义 = 任一占格被看到即整舰可见，其视图整舰渲染，占格不应被迷雾盖住）。
    public static HashSet<GridPos> VisibleCells(BattleState battle, FactionId faction)
    {
        var visible = new HashSet<GridPos>();
        foreach (var observer in battle.Ships.Values)
        {
            if (observer.Faction != faction || observer.HitPoints <= 0) continue;
            for (var x = 0; x < battle.Map.Width; x++)
                for (var y = 0; y < battle.Map.Height; y++)
                {
                    var cell = new GridPos(x, y);
                    if (CellVisible(battle, observer.Bow, cell)) visible.Add(cell);
                }
        }
        // 可见敌舰整体入集合（见上方语义注释）：避免多格敌舰的远格被迷雾盖住造成"半艘舰在雾里"。
        foreach (var enemy in VisibleEnemies(battle, faction))
            foreach (var cell in enemy.OccupiedCells())
                visible.Add(cell);
        return visible;
    }

    // V-3（CHG-20260810-fx-vision-recall）："已揭示"格集合 = 当前可见格 ∪ 滞留期内的格（迷雾数据源）。
    // 语义：离开侦察范围的格在 PlayerVisionFreshness 中计数 ≤3（保持可见 3 个完整回合）时仍计入，
    // 供表现层迷雾覆盖绘制（迷雾 = 当前可见 ∪ 滞留 3 回合内的格）；舰船可见性仍由 VisibleEnemies 几何判定。
    // 仅对玩家观测启用滞留（PlayerVisionFreshness 只维护玩家）；其它阵营退化为当前可见格。
    public static HashSet<GridPos> RevealedCells(BattleState battle, FactionId faction)
    {
        var cells = VisibleCells(battle, faction);
        if (faction == FactionId.Player)
            foreach (var (cell, freshness) in battle.PlayerVisionFreshness)
                if (freshness <= VisionRecallTurns)
                    cells.Add(cell);
        return cells;
    }

    // V-3：视野滞留推进——每完整回合（玩家回合开始）调用一次。
    // 当前可见格置新鲜度 0（含重新进入视野的格重置为 0）；不在当前视野的滞留格新鲜度 +1；
    // 超过 VisionRecallTurns 移除（归为迷雾）。语义：离开视野的格保持可见 3 个回合，
    // 第 4 次更新（新鲜度 4 > 3）移除归为迷雾；途中再看到就重置为 0。
    // 战斗开始须先种子化一次（见 NavalBattleController.StartBattle），否则首回合开过的足迹在首次回合边界即瞬间归雾。
    public static void AdvanceVisionRecall(BattleState battle)
    {
        var current = VisibleCells(battle, FactionId.Player);
        var next = new Dictionary<GridPos, int>();
        foreach (var cell in current)
            next[cell] = 0; // 当前可见（含重新进入视野）→ 新鲜度 0
        foreach (var (cell, freshness) in battle.PlayerVisionFreshness)
        {
            if (current.Contains(cell)) continue; // 重新进入视野的格已在上面置 0
            var age = freshness + 1;
            if (age <= VisionRecallTurns) next[cell] = age; // 超过 3 移除（归为迷雾）
        }
        battle.PlayerVisionFreshness.Clear();
        foreach (var (cell, freshness) in next)
            battle.PlayerVisionFreshness[cell] = freshness;
    }

    // 射界查询（T8，只读）：返回某舰当前可选的远程攻击目标格集合（箭雨/砲击/火炮任一合法即入选）。
    // UI 射界显示直接复用本查询，不重复实现规则；Level 取 1（演示等级），具体结算仍由 Validate/Resolve 决定。
    public static List<GridPos> QueryAttackTargets(BattleState battle, ShipState ship)
    {
        var result = new List<GridPos>();
        foreach (var arc in QueryAttackArcs(battle, ship))
            result.Add(arc.Cell);
        return result;
    }

    // 射界弧查询（T13，只读）：按结算优先级（箭雨→砲击→火炮，与 TryRangedAttack 一致）取该格首个合法武器，
    // 并标注该格当前是否有敌舰可命中（HasTarget）。
    // T8 遗留（简报 C）：空箭雨格（范围内无任何目标可命中）此前也显示为可点红格，点击落空还耗动作。
    // 现区分：实弹格（当前有敌舰占格，命中确定）与盲射空格（无目标，点击=盲射消耗动作），UI 分色 + 空心描边提示。
    public static List<AttackArcOption> QueryAttackArcs(BattleState battle, ShipState ship)
    {
        var result = new List<AttackArcOption>();
        if (ship is null || ship.HasAttacked || ship.HitPoints <= 0) return result;
        // T13 修复（评审 Important-2）：HasTarget 只对当前可见敌舰生效。几何迷雾下隐藏敌舰仍可被盲射命中，
        // 但其占格必须标为空心（盲射提示），实心弧只给可见敌舰——否则实心弧会泄露隐藏敌舰位置。
        var visibleEnemies = VisibleEnemies(battle, ship.Faction);
        // UX-1 性能优化：以攻击舰占格为中心、最大射程为半径的窗口内扫描（48×36 下全图 O(W×H) 每格 3 次 Validate 过重）。
        // 窗口必含全部可能合法格（超窗格距任一占格 > 最大射程，各 Validate 仍按原样拒绝），结果集与优化前完全一致。
        var (minX, maxX, minY, maxY) = GeometryRules.ScanWindow(ship, AttackRadius(ship), battle.Map);
        for (var x = minX; x <= maxX; x++)
        {
            for (var y = minY; y <= maxY; y++)
            {
                var cell = new GridPos(x, y);
                WeaponKind? kind = null;
                if (ValidateArrowRain(battle, new ArrowRainCommand(ship.Id, cell)) is null) kind = WeaponKind.ArrowRain;
                else if (ValidateBombardment(battle, new BombardmentCommand(ship.Id, cell, 1)) is null) kind = WeaponKind.Bombardment;
                else if (ValidateCannon(battle, new CannonCommand(ship.Id, cell, 1)) is null) kind = WeaponKind.Cannon;
                if (kind is null) continue;
                var hasTarget = visibleEnemies.Any(s => s.OccupiedCells().Contains(cell));
                result.Add(new AttackArcOption(cell, kind.Value, hasTarget));
            }
        }
        return result;
    }

    // 单武器射界弧查询（UX-7，只读）：按指定武器（箭雨/砲击/火炮）单独返回该攻击方式的可攻击范围格，
    // 口径与 QueryAttackArcs 一致（同扫描窗口、同实心/空心标注）。区别于 QueryAttackArcs 的"每格取首个合法武器"：
    // 距4-5 的侧舷格同时合法于砲击与火炮，若按 kind 过滤首个合法武器会漏掉火炮格——这里只校验指定武器。
    public static List<AttackArcOption> QueryWeaponArcs(BattleState battle, ShipState ship, WeaponKind kind)
    {
        var result = new List<AttackArcOption>();
        if (ship is null || ship.HasAttacked || ship.HitPoints <= 0) return result;
        var visibleEnemies = VisibleEnemies(battle, ship.Faction);
        var (minX, maxX, minY, maxY) = GeometryRules.ScanWindow(ship, AttackRadius(ship), battle.Map);
        for (var x = minX; x <= maxX; x++)
        {
            for (var y = minY; y <= maxY; y++)
            {
                var cell = new GridPos(x, y);
                string? reason = kind switch
                {
                    WeaponKind.ArrowRain => ValidateArrowRain(battle, new ArrowRainCommand(ship.Id, cell)),
                    WeaponKind.Bombardment => ValidateBombardment(battle, new BombardmentCommand(ship.Id, cell, 1)),
                    WeaponKind.Cannon => ValidateCannon(battle, new CannonCommand(ship.Id, cell, 1)),
                    _ => "action.unknown_weapon",
                };
                if (reason is not null) continue;
                var hasTarget = visibleEnemies.Any(s => s.OccupiedCells().Contains(cell));
                result.Add(new AttackArcOption(cell, kind, hasTarget));
            }
        }
        return result;
    }

    // 该舰可及的最大射程（决定扫描窗口半径）：火炮 6 > 砲击 5 > 箭雨 2。含其中任一武器即覆盖其下所有武器上限。
    private static int AttackRadius(ShipState ship)
    {
        if (ship.WeaponCounts.GetValueOrDefault("cannon", 0) > 0) return 6;
        if (ship.WeaponCounts.GetValueOrDefault("bombardment", 0) > 0) return 5;
        return 2;
    }

    // CHG：倭寇军旗 → 射程半径 +1 格（RangeBonus>0），最大射程平方距离。
    public static int ScaledMaxD2(BattleState battle, int d2max)
    {
        var radius = (int)Math.Sqrt(d2max);
        var scaled = radius + (battle.RangeBonus > 0 ? 1 : 0);
        return scaled * scaled;
    }

    // —— 校验（ActionResolver 用；null = 合法，否则为拒绝原因 key）——

    // 箭雨（设计 9.1）：最近格距 ≤ 2，抛射可越山。
    // 强化（Task 11 火油）：Enhanced 时额外要求装有火油且剩余次数 ≥ 1，否则拒绝（不消耗动作）。
    public static string? ValidateArrowRain(BattleState battle, ArrowRainCommand cmd)
    {
        var attacker = battle.ShipOrNull(cmd.ShipId);
        if (attacker is null || attacker.HitPoints <= 0) return "action.unknown_ship";
        if (attacker.HasAttacked) return "action.attack_ended_movement";
        if (NearestSquaredDistance(attacker.OccupiedCells(), cmd.Target) > ScaledMaxD2(battle, 4)) return "action.out_of_range";
        if (cmd.Enhanced && attacker.SkillUsesLeft.GetValueOrDefault("fire_oil", 0) < 1) return "skill.no_uses";
        return null;
    }

    // 砲击（设计 9.2）：最近格距 3–5，已装砲击 ≥1，抛射可越山
    public static string? ValidateBombardment(BattleState battle, BombardmentCommand cmd)
    {
        var attacker = battle.ShipOrNull(cmd.ShipId);
        if (attacker is null || attacker.HitPoints <= 0) return "action.unknown_ship";
        if (attacker.HasAttacked) return "action.attack_ended_movement";
        if (attacker.WeaponCounts.GetValueOrDefault("bombardment", 0) < 1) return "action.no_weapon";
        var d2 = NearestSquaredDistance(attacker.OccupiedCells(), cmd.Target);
        // 砲击：下限 9 不变，上限按军旗 +1 格。
        if (d2 < 9 || d2 > ScaledMaxD2(battle, 25)) return "action.out_of_range";
        return null;
    }

    // 火炮（设计 9.3）：最近格距 4–6，仅侧舷，已装火炮 ≥1，平射射线不被山地阻挡
    public static string? ValidateCannon(BattleState battle, CannonCommand cmd)
    {
        var attacker = battle.ShipOrNull(cmd.ShipId);
        if (attacker is null || attacker.HitPoints <= 0) return "action.unknown_ship";
        if (attacker.HasAttacked) return "action.attack_ended_movement";
        if (attacker.WeaponCounts.GetValueOrDefault("cannon", 0) < 1) return "action.no_weapon";
        var d2 = NearestSquaredDistance(attacker.OccupiedCells(), cmd.Target);
        // 火炮：下限 16 不变，上限按军旗 +1 格。
        if (d2 < 16 || d2 > ScaledMaxD2(battle, 36)) return "action.out_of_range";
        if (!IsBroadside(attacker, cmd.Target)) return "action.not_broadside";
        if (MountainBlocksFlatPath(battle, attacker, cmd.Target)) return "action.blocked_by_terrain";
        return null;
    }

    // —— 结算（输出 BattleEvent[]）——

    public static BattleEvent[] ResolveArrowRain(BattleState battle, ArrowRainCommand cmd)
    {
        if (ValidateArrowRain(battle, cmd) is not null) return Array.Empty<BattleEvent>();
        var attacker = battle.ShipOrNull(cmd.ShipId)!;
        // 强化（Task 11 火油强化箭雨，设计 12.2）：消耗 1 次火油，即时伤害 ×1.5，命中舰附加 2 回合烧伤
        if (cmd.Enhanced)
        {
            attacker.SkillUsesLeft["fire_oil"] -= 1;
            return ResolveArea(battle, attacker, CircleCells(cmd.Target, 1),
                (_cell, _ship) => attacker.Definition.ArrowRainDamage * 1.5, burnRounds: 2);
        }
        // 普通箭雨：舰型固定伤害（ShipDefinition.ArrowRainDamage），不受装备影响，行为不变
        return ResolveArea(battle, attacker, CircleCells(cmd.Target, 1), (_cell, _ship) => attacker.Definition.ArrowRainDamage);
    }

    public static BattleEvent[] ResolveBombardment(BattleState battle, BombardmentCommand cmd)
    {
        if (ValidateBombardment(battle, cmd) is not null) return Array.Empty<BattleEvent>();
        var attacker = battle.ShipOrNull(cmd.ShipId)!;
        var baseDmg = WeaponPerUnitDamage(battle, attacker, "bombardment", cmd.Level)
            * attacker.WeaponCounts.GetValueOrDefault("bombardment", 0);
        if (baseDmg <= 0) return Array.Empty<BattleEvent>();
        return ResolveArea(battle, attacker, CircleCells(cmd.Target, 1), (_cell, _ship) => baseDmg);
    }

    public static BattleEvent[] ResolveCannon(BattleState battle, CannonCommand cmd)
    {
        if (ValidateCannon(battle, cmd) is not null) return Array.Empty<BattleEvent>();
        var attacker = battle.ShipOrNull(cmd.ShipId)!;
        var baseDmg = WeaponPerUnitDamage(battle, attacker, "cannon", cmd.Level)
            * attacker.WeaponCounts.GetValueOrDefault("cannon", 0);
        if (baseDmg <= 0) return Array.Empty<BattleEvent>();
        var dist = Distance(attacker.OccupiedCells(), cmd.Target);
        // 距4 单格全额；距5 平行船身3格各60%；距6 平行船身5格各 40% × 随机(0.3-1.2)
        var cells = dist <= 4
            ? new List<GridPos> { cmd.Target }
            : dist <= 5
                ? StripCells(cmd.Target, attacker.Facing, 1)
                : StripCells(cmd.Target, attacker.Facing, 2);
        var mult = dist <= 4 ? 1.0 : dist <= 5 ? 0.6 : 0.4;
        // ShipState? 参数：水雷格用 null（无目标舰时取该格基础伤害，见 ResolveArea）
        Func<GridPos, ShipState?, double> preArmor = dist >= 6
            ? (_cell, _ship) => baseDmg * mult * (0.3 + battle.Random.NextDouble() * 0.9) // 逐格独立随机
            : (_cell, _ship) => baseDmg * mult;
        return ResolveArea(battle, attacker, cells, preArmor);
    }

    // 通用范围结算：逐格判定占用，跳过自身/友军；多格舰被覆盖多格时每格独立一次伤害。
    // 命中隐藏舰发 HiddenHitEvent（盲射，不揭示）；命中可见舰发 AreaDamageEvent 并补一个 RevealShipEvent 给表现层揭示确认；沉没补 ShipSunkEvent。
    // burnRounds > 0（Task 11 强化箭雨）：对命中的敌舰附加烧伤（按舰去重一次）。
    // Task 12：水雷格在舰船判定之前处理（设计 13.2）：范围攻击打到水雷格即对水雷造成伤害
    //（"不伤友军"只约束舰船，水雷作为无阵营物件打到即受伤）；水雷降至 0 → 九宫爆炸（不分敌我、可连锁）。
    private static BattleEvent[] ResolveArea(BattleState battle, ShipState attacker, List<GridPos> cells, Func<GridPos, ShipState?, double> preArmorDamage, int burnRounds = 0)
    {
        var events = new List<BattleEvent>();
        var hit = new List<(ShipState Ship, bool Visible)>();
        foreach (var cell in cells)
        {
            if (!battle.Map.InBounds(cell)) continue;
            // 水雷优先：同格被攻击时先结算水雷（无阵营物件，不分敌我）
            var mine = battle.Map.MineAt(cell);
            if (mine is not null)
            {
                var mineDmg = DamageRules.Calculate(new DamagePacket(preArmorDamage(cell, null), mine.ArmorLevel, IgnoresArmor: false)).FinalDamage;
                mine.HitPoints -= mineDmg;
                events.Add(new MineDamagedEvent(cell, mineDmg, mine.HitPoints));
                if (mine.HitPoints <= 0)
                    events.AddRange(MineRules.ResolveMineExplosion(battle, mine)); // 击破 → 九宫爆炸（含连锁）
                continue;
            }
            var occupant = battle.Ships.Values
                .FirstOrDefault(s => s.HitPoints > 0 && s.OccupiedCells().Contains(cell));
            if (occupant is null || occupant.Faction == attacker.Faction) continue; // 范围攻击不伤友军/自身
            var visible = !IsHidden(battle, attacker.Faction, occupant); // 命中瞬间判定几何可见性
            var dmg = DamageRules.Calculate(new DamagePacket(preArmorDamage(cell, occupant), occupant.ArmorLevel, IgnoresArmor: false)).FinalDamage;
            occupant.HitPoints -= dmg;
            events.Add(visible
                ? new AreaDamageEvent(cell, occupant.Id, dmg, occupant.HitPoints)
                : new HiddenHitEvent(cell, occupant.Id, dmg, occupant.HitPoints));
            hit.Add((occupant, visible));
        }
        // 沉没/揭示/烧伤/打断事件按舰去重：多格舰被覆盖多格时，每舰只发一次（逐格伤害已在第一循环各发一条）
        var seen = new HashSet<string>();
        foreach (var (ship, visible) in hit)
        {
            if (!seen.Add(ship.Id)) continue;
            // Task 11：敌方武器伤害打断该舰损管（设计 12.3）；仅命中敌舰（hit 已跳过友军/自身）
            if (StatusRules.InterruptRepairs(ship)) events.Add(new RepairsInterruptedEvent(ship.Id));
            if (burnRounds > 0 && StatusRules.ApplyBurn(ship, burnRounds)) events.Add(new BurnAppliedEvent(ship.Id, burnRounds));
            if (ship.HitPoints <= 0) events.Add(new ShipSunkEvent(ship.Id));
            if (visible) events.Add(new RevealShipEvent(ship.Id)); // 命中可见舰 → 表现层揭示确认
        }
        // Task 12：沉没事件按舰去重归一——范围攻击与水雷九宫爆炸（含连锁）可能多次命中同一舰，
        // 每舰只发一条 ShipSunkEvent（保留首次出现）。
        var sunkSeen = new HashSet<string>();
        var result = new List<BattleEvent>(events.Count);
        foreach (var e in events)
        {
            if (e is ShipSunkEvent sunk && !sunkSeen.Add(sunk.ShipId)) continue;
            result.Add(e);
        }
        return result.ToArray();
    }

    // —— 几何辅助 ——

    private static int NearestSquaredDistance(List<GridPos> cells, GridPos target)
        => GeometryRules.NearestSquaredDistance(cells, new List<GridPos> { target });

    private static double Distance(List<GridPos> cells, GridPos target)
        => Math.Sqrt(NearestSquaredDistance(cells, target));

    // 圆形区域：半径 r 内所有格（dx² + dy² ≤ r²）
    private static List<GridPos> CircleCells(GridPos center, int r)
    {
        var cells = new List<GridPos>();
        for (var dx = -r; dx <= r; dx++)
            for (var dy = -r; dy <= r; dy++)
                if (dx * dx + dy * dy <= r * r)
                    cells.Add(center + new GridPos(dx, dy));
        return cells;
    }

    // 火炮条带：以目标格为中心、平行于攻击舰船身的 2*span+1 格（E/W 船身沿 X 轴，N/S 船身沿 Y 轴）
    private static List<GridPos> StripCells(GridPos center, CardinalDirection facing, int span)
    {
        var horizontal = facing == CardinalDirection.East || facing == CardinalDirection.West;
        var cells = new List<GridPos>();
        for (var k = -span; k <= span; k++)
            cells.Add(horizontal
                ? new GridPos(center.X + k, center.Y)
                : new GridPos(center.X, center.Y + k));
        return cells;
    }

    // 仅侧舷：目标格与攻击舰某船体格在平行轴同坐标、且在垂直于船头的方向
    private static bool IsBroadside(ShipState attacker, GridPos target)
    {
        var horizontal = attacker.Facing == CardinalDirection.East || attacker.Facing == CardinalDirection.West;
        foreach (var cell in attacker.OccupiedCells())
        {
            if (horizontal)
            {
                if (target.X == cell.X && target.Y != cell.Y) return true;
            }
            else
            {
                if (target.Y == cell.Y && target.X != cell.X) return true;
            }
        }
        return false;
    }

    // 陆地阻挡平射：最近船体格到目标的射线经过任一陆地形格即被挡（箭雨/砲击抛射忽略；U-2a：陆地同山地）
    private static bool MountainBlocksFlatPath(BattleState battle, ShipState attacker, GridPos target)
    {
        var from = NearestCell(attacker.OccupiedCells(), target);
        foreach (var cell in LineCells(from, target))
        {
            if (cell == from || cell == target) continue;
            if (!battle.Map.InBounds(cell)) continue;
            if (TerrainRules.BlocksLineOfSight(battle.Map.TerrainAt(cell))) return true;
        }
        return false;
    }

    private static GridPos NearestCell(List<GridPos> cells, GridPos target)
    {
        var best = cells[0];
        var bestD2 = int.MaxValue;
        foreach (var c in cells)
        {
            var d2 = c.SquaredDistance(target);
            if (d2 < bestD2) { bestD2 = d2; best = c; }
        }
        return best;
    }

    // 观察射线：从 from 之后逐格走到 to（含 to），Bresenham 直线
    public static IEnumerable<GridPos> LineCells(GridPos from, GridPos to)
    {
        var x0 = from.X; var y0 = from.Y;
        var x1 = to.X; var y1 = to.Y;
        var dx = Math.Abs(x1 - x0); var dy = Math.Abs(y1 - y0);
        var sx = x0 < x1 ? 1 : -1;
        var sy = y0 < y1 ? 1 : -1;
        var err = dx - dy;
        while (x0 != x1 || y0 != y1)
        {
            var e2 = 2 * err;
            if (e2 > -dy) { err -= dy; x0 += sx; }
            if (e2 < dx) { err += dx; y0 += sy; }
            yield return new GridPos(x0, y0);
        }
    }

    // CHG-20260819（F-1 讨伐饰品）：玩家旗舰装备贯日神枪 → FlagshipBombardmentLevel=4 →
    // 旗舰砲击单发伤害取 Lv4（weapons.json DamageByLevel[3]=420，复用取数路径）。
    public static int WeaponPerUnitDamage(BattleState battle, ShipState attacker, string weaponId, int level)
    {
        if (weaponId == "bombardment" && battle.FlagshipBombardmentLevel > 0
            && attacker.Faction == FactionId.Player
            && FlagshipRules.ResolveFlagshipId(battle, FactionId.Player) == attacker.Id)
            level = battle.FlagshipBombardmentLevel;
        var weapon = battle.Config.Weapons.FirstOrDefault(w => w.Id == weaponId);
        if (weapon is null || weapon.DamageByLevel.Length == 0) return 0;
        var idx = Math.Clamp(level - 1, 0, weapon.DamageByLevel.Length - 1);
        return weapon.DamageByLevel[idx];
    }
}
