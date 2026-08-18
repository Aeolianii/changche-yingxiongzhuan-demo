#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

// Task 9：撞击与强制位移（设计文档第 10 节 + 第 3/8 节）。
// 资格：目标任一占格在撞击舰船头前方一格，且最后一段平移为船头朝目标的接近移动（LastMoveDirection == Facing）。
// 基础伤害 = 实际负载 × 撞角系数 × 20，受护甲减免；碰撞几何/推动/受阻/礁石/自沉按设计逐条实现。
public static class RamRules
{
    public const double BaseDamageMultiplier = 20.0;
    public const double BlockedPushBonus = 0.25;      // 受阻追加 25% 撞击基础伤害，护甲减免前加在几何伤害之外（设计 10"额外承受25%撞击基础伤害"）
    public const double SternDamageRatio = 0.5;       // 船头追撞船尾目标承受 50%

    // 撞角系数回退默认（配置未提供 ram 时）：0=未装 0.5，1/2/3 级 = 1.0/1.2/1.5
    private static readonly double[] DefaultRamCoefficients = { 0.5, 1.0, 1.2, 1.5 };

    // 校验：返回 null 表示合法，否则为拒绝原因 key（ActionResolver 用；非法不耗动作）
    public static string? Validate(BattleState battle, RamCommand cmd)
    {
        var rammer = battle.ShipOrNull(cmd.ShipId);
        if (rammer is null || rammer.HitPoints <= 0) return "action.unknown_ship";
        if (rammer.Faction != battle.CurrentFaction) return "action.unknown_ship";
        if (rammer.HasAttacked) return "action.attack_ended_movement";
        if (rammer.SelfSunk) return "action.self_sunk_immobile";
        var target = battle.ShipOrNull(cmd.TargetId);
        if (target is null || target.HitPoints <= 0) return "ram.target_not_found";
        if (target.Faction == rammer.Faction) return "ram.target_is_friendly";
        // 目标任一占格在撞击舰船头前方一格（撞击方必须与目标相邻）
        if (!target.OccupiedCells().Contains(rammer.Bow + rammer.Facing.Vector())) return "ram.target_not_in_front";
        // 最后一段平移必须是船头朝目标的接近移动（原地转向会清空资格）
        if (rammer.LastMoveDirection != rammer.Facing) return "ram.requires_approach_move";
        return null;
    }

    // 只读查询（T13）：当前舰合法撞击目标舰集合（UI 撞击按钮可用性与目标高亮复用，不重复实现规则）。
    public static List<string> QueryRamTargets(BattleState battle, string shipId)
    {
        var ship = battle.ShipOrNull(shipId);
        if (ship is null || ship.HitPoints <= 0) return new List<string>();
        var result = new List<string>();
        foreach (var other in battle.Ships.Values)
        {
            if (other.Id == shipId || other.HitPoints <= 0) continue;
            if (Validate(battle, new RamCommand(shipId, other.Id)) is null)
                result.Add(other.Id);
        }
        return result;
    }

    public static BattleEvent[] Resolve(BattleState battle, RamCommand cmd)
    {
        if (Validate(battle, cmd) is not null) return Array.Empty<BattleEvent>();
        var rammer = battle.ShipOrNull(cmd.ShipId)!;
        var target = battle.ShipOrNull(cmd.TargetId)!;

        // 碰撞几何：撞击舰船头接触的目标占格段（索引 0=船头、末格=船尾、其余=船身；单格舰按船头）
        var targetCells = target.OccupiedCells();
        var contactCell = rammer.Bow + rammer.Facing.Vector();
        var contactIndex = targetCells.FindIndex(c => c == contactCell);
        var kind = contactIndex switch
        {
            0 => RamCollisionKind.BowToBow,
            var i when i == targetCells.Count - 1 && targetCells.Count > 1 => RamCollisionKind.BowToStern,
            _ => RamCollisionKind.BowToHull
        };

        // 实际负载（TotalLoad(0, ArmorLevel, ram, bombardment, cannon)）与基础伤害
        var rammerLoad = WeatherRules.CurrentLoad(rammer);
        var targetLoad = WeatherRules.CurrentLoad(target);
        var baseDamage = rammerLoad * RamCoefficient(battle, rammer) * BaseDamageMultiplier;

        // 推动判定：仅船头对船头/船头对船尾；撞击方实际负载 > 目标实际负载；自沉目标永不被推动
        var pushableGeometry = kind is RamCollisionKind.BowToBow or RamCollisionKind.BowToStern;
        var pushable = pushableGeometry && rammerLoad > targetLoad && !target.SelfSunk;
        // 受阻：本可推动但受地形/舰船/空间阻挡（复用通过性判定）；自沉目标不进入受阻判定
        var blocked = pushable && !PushFootprintValid(battle, target, rammer.Facing);

        // 几何伤害比例：船头追船尾 50%，其余全额
        var ratio = kind == RamCollisionKind.BowToStern ? SternDamageRatio : 1.0;
        // 受阻追加：在几何伤害之外，额外承受 25% 撞击基础伤害（护甲减免前加法，非乘入几何倍率）。
        // 船头对船头受阻 = 1.0×base + 0.25×base = 1.25×base；船头追船尾受阻 = 0.5×base + 0.25×base = 0.75×base。
        var blockedBonus = blocked ? baseDamage * BlockedPushBonus : 0.0;
        var targetDamage = DamageRules.Calculate(new DamagePacket(baseDamage * ratio + blockedBonus, target.ArmorLevel, IgnoresArmor: false)).FinalDamage;
        target.HitPoints -= targetDamage;

        // 推动：目标沿撞击方向（撞击舰 Facing）推 1 格；进入礁石（通过性2）推动成功并触发 15% 最大生命
        var pushed = false;
        var intoReef = false;
        var reefDamage = 0;
        if (pushable && !blocked)
        {
            var pushDir = rammer.Facing.Vector();
            var destination = target.OccupiedCells().Select(c => c + pushDir).ToList();
            if (destination.Any(c => battle.Map.InBounds(c)
                && battle.Map.TerrainAt(c) == TerrainType.Reef
                && target.Definition.Passability == Passability.ReefDamaging))
                intoReef = true;
            target.Bow = destination[0];
            pushed = true;
        }
        if (intoReef)
        {
            reefDamage = (int)Math.Round(target.MaxHp * 0.15, MidpointRounding.AwayFromZero); // 与移动入礁一致，无视护甲，.5 向上（Task 18 B5）
            target.HitPoints -= reefDamage;
        }

        // 反伤：船头对船头 = 目标实际所受伤害的一半（舍入 AwayFromZero，与伤害四舍五入一致）
        var rammerDamage = 0;
        if (kind == RamCollisionKind.BowToBow)
        {
            rammerDamage = (int)Math.Round(targetDamage / 2.0, MidpointRounding.AwayFromZero);
            rammer.HitPoints -= rammerDamage;
        }

        var events = new List<BattleEvent>
        {
            new RamHitEvent(target.Id, targetDamage, target.HitPoints, rammerDamage, rammer.HitPoints, kind, pushed, blocked, intoReef, reefDamage)
        };
        if (target.HitPoints <= 0) events.Add(new ShipSunkEvent(target.Id));
        if (rammer.HitPoints <= 0) events.Add(new ShipSunkEvent(rammer.Id));
        // Task 11：敌方撞击伤害（含船头对船头反伤）打断双方损管（设计 12.3，裁定 8）
        if (StatusRules.InterruptRepairs(target)) events.Add(new RepairsInterruptedEvent(target.Id));
        if (StatusRules.InterruptRepairs(rammer)) events.Add(new RepairsInterruptedEvent(rammer.Id));
        // Task 12 修复：撞击推动成功后，被推舰新占格可能压上/靠近水雷 → 统一刷新探测 + 正常触发（设计 13.1）。
        // 事件并入撞击命令结果（与 MoveOutcome.MineEvents 同语义）；不阻塞推动本身。
        if (pushed)
            events.AddRange(MineRules.RefreshMines(battle));
        return events.ToArray();
    }

    // 撞角系数：按 WeaponCounts["ram"] 等级（0=未装，1/2/3=等级）读 ram.MultiplierByLevel；配置缺失回退默认。
    public static double RamCoefficient(BattleState battle, ShipState ship)
    {
        var level = ship.WeaponCounts.GetValueOrDefault("ram", 0);
        var weapon = battle.Config.Weapons.FirstOrDefault(w => w.Id == "ram");
        if (weapon is null || weapon.MultiplierByLevel.Length == 0)
            return DefaultRamCoefficients[Math.Clamp(level, 0, DefaultRamCoefficients.Length - 1)];
        var idx = Math.Clamp(level, 0, weapon.MultiplierByLevel.Length - 1);
        return weapon.MultiplierByLevel[idx];
    }

    // 推动合法性与通过性复用 MovementRules.FootprintValid（界内/残骸/地形/其它舰船，按被推目标通过性）
    private static bool PushFootprintValid(BattleState battle, ShipState target, CardinalDirection pushDir)
    {
        var destination = target.OccupiedCells().Select(c => c + pushDir.Vector()).ToList();
        return MovementRules.FootprintValid(battle, destination, target);
    }
}
