#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

public enum FishMode { Hunt, Chase, Corner }

// 海怪02（巨型飞鱼）规则：直线冲撞 + 飞越 + 按存活数切换模式（猎杀/追击/困兽）。
public static class FishSchoolRules
{
    public const double BaseDamagePerMass = 20.0; // 质量5 → 基准100
    public const double HuntCoeff = 0.8;          // 3条：猎杀
    public const double ChaseCoeff = 0.9;         // 2条：追击
    public const double CornerCoeff = 1.2;        // 1条：困兽（狂暴）
    public const int ChargeRange = 8;             // 冲撞 8 格
    public const int LeapRange = 2;               // 飞越 2 格
    public const int HuntCycle = 3;               // 猎杀每 3 回合三连
    public const int PushDistance = 1;            // 冲撞推 1 格
    public static readonly double[] HuntChainMult = { 0.5, 1.0, 1.5 }; // 三连首低后高

    public static bool IsFish(ShipState s) => s.HitPoints > 0 && s.Definition.IsFish;

    public static int AliveFishCount(BattleState battle) => battle.Ships.Values.Count(IsFish);

    public static FishMode ModeOf(int alive) => alive switch
    {
        3 => FishMode.Hunt,
        2 => FishMode.Chase,
        _ => FishMode.Corner,
    };

    // 冲撞上限：猎杀每 3 回合三连、其余回合单冲；追击每回合双连；困兽每回合单冲。
    public static int ChargeLimit(BattleState battle, FishMode mode)
    {
        if (mode == FishMode.Hunt) return battle.FishHuntRound % HuntCycle == 0 ? 3 : 1;
        return mode == FishMode.Chase ? 2 : 1;
    }

    public static string? ValidateCharge(BattleState battle, FishChargeCommand cmd)
    {
        if (!battle.Ships.TryGetValue(cmd.ShipId, out var fish) || !IsFish(fish) || fish.SelfSunk)
            return "fish.unknown_or_inactive";
        // 冲撞链：同一鱼本回合可连续冲撞至模式上限。HasAttacked 仅标记"已行动"，不拦截链内后续冲撞。
        var mode = ModeOf(AliveFishCount(battle));
        if (fish.FishChargesUsed >= ChargeLimit(battle, mode)) return "fish.charge_limit";
        return null;
    }

    public static BattleEvent[] ResolveCharge(BattleState battle, FishChargeCommand cmd)
    {
        var err = ValidateCharge(battle, cmd);
        if (err is not null) return Array.Empty<BattleEvent>();
        var fish = battle.Ships[cmd.ShipId];
        var mode = ModeOf(AliveFishCount(battle));
        var coeff = mode switch { FishMode.Hunt => HuntCoeff, FishMode.Chase => ChaseCoeff, _ => CornerCoeff };
        // 猎杀模式：每 3 回合触发三连，链次由本回合已冲撞数决定。
        var chainMult = mode == FishMode.Hunt && battle.FishHuntRound % HuntCycle == 0
            ? HuntChainMult[Math.Min(fish.FishChargesUsed, HuntChainMult.Length - 1)]
            : 1.0;
        var baseDmg = fish.Definition.Mass * BaseDamagePerMass * coeff * chainMult;
        // 直线前冲：从鱼占格前沿向方向逐格扫描，撞到第一个敌舰停止；未撞到则移到合法最远格。
        var dir = cmd.Direction.Vector();
        var front = FishFront(fish, cmd.Direction);
        ShipState? target = null;
        GridPos hitCell = front;
        var reachable = 0; // 合法可达格数（界内/地形扫到的最远步数）
        for (var i = 1; i <= ChargeRange; i++)
        {
            var cell = front + dir * i;
            if (!battle.Map.InBounds(cell)) break;
            if (TerrainRules.BlocksShip(battle.Map.TerrainAt(cell), fish.Definition.Passability)) break;
            reachable = i;
            if (ShipAt(battle, cell) is { } s && s.Faction != fish.Faction && s.HitPoints > 0) { target = s; hitCell = cell; break; }
        }
        fish.FishChargesUsed += 1;
        fish.HasAttacked = true;
        fish.LastMoveDirection = cmd.Direction;
        var evs = new List<BattleEvent>();
        var pushed = false;
        if (target is not null)
        {
            var dmg = DamageRules.Calculate(new DamagePacket(baseDmg, target.ArmorLevel, IgnoresArmor: false)).FinalDamage;
            target.HitPoints -= dmg;
            // 推 1 格（目标格合法才推）：先计算 push 结果，再一次性构造 FishChargeEvent。
            // （简报原写法用 evs.RemoveAt(evs.Count-1) 重加 pushed 版本：目标沉没时 Count-1 指向 ShipSunkEvent，
            // 会误删沉没事件——改为先算 push 再构造，保持事件序 伤害→沉没 且不丢沉没事件。）
            var away = target.Bow + dir * PushDistance;
            if (!target.Definition.Immovable && MovementRules.FootprintValid(battle, ShipGeometry.Footprint(target.Definition, away, target.Facing), target))
            {
                target.Bow = away; pushed = true;
            }
            evs.Add(new FishChargeEvent(fish.Id, hitCell, target.Id, dmg, target.HitPoints, pushed));
            if (target.HitPoints <= 0) evs.Add(new ShipSunkEvent(target.Id));
            // 停在被撞舰前一格。倒退冲撞（Direction==Facing.Opposite()）时 front=cells[^1]≠bow
            // （船体向船头反方向延伸），直接 hitCell-dir 会使后格压目标；用当前前缘格做差值修正，
            // 正前/侧向冲撞结果与 hitCell-dir 完全一致。
            fish.Bow = fish.Bow + (hitCell - dir - FishFront(fish, cmd.Direction));
        }
        else
        {
            // 未撞到：移到合法最远格。与目标分支同理，倒退冲撞时 front=cells[^1]≠bow，
            // 直接 front+dir*reachable 会使后格越过合法边界（前缘格=最后合法格+1）；用前缘差值修正。
            fish.Bow = fish.Bow + (front + dir * reachable - FishFront(fish, cmd.Direction));
        }
        return evs.ToArray();
    }

    public static string? ValidateLeap(BattleState battle, FishLeapMoveCommand cmd)
    {
        if (!battle.Ships.TryGetValue(cmd.ShipId, out var fish) || !IsFish(fish) || fish.SelfSunk)
            return "fish.unknown_or_inactive";
        // 飞越仅困兽模式（存活 1 条）冲撞后可进行一次；其余模式禁飞越。
        var mode = ModeOf(AliveFishCount(battle));
        if (mode != FishMode.Corner) return "fish.leap_corner_only";
        if (fish.FishChargesUsed < 1) return "fish.leap_requires_charge";
        if (fish.FishLeapedThisTurn) return "fish.leap_already_used";
        var landing = fish.Bow + cmd.Direction.Vector() * LeapRange; // 跳 2 格；中间格可越过（地形/舰船不受阻挡）
        // 落点须整条足迹合法：2 格鱼体占 [landing, landing-facing]，FootprintValid 统一校验
        // 界内/残骸/地形/与他舰重叠（排除自身）；中间格虽可越过，但新后格不可压任何阻挡。
        if (!MovementRules.FootprintValid(battle, ShipGeometry.Footprint(fish.Definition, landing, fish.Facing), fish))
            return "fish.leap_blocked";
        return null;
    }

    public static BattleEvent[] ResolveLeap(BattleState battle, FishLeapMoveCommand cmd)
    {
        var err = ValidateLeap(battle, cmd);
        if (err is not null) return Array.Empty<BattleEvent>();
        var fish = battle.Ships[cmd.ShipId];
        fish.Bow = fish.Bow + cmd.Direction.Vector() * LeapRange; // GridPos 为 readonly record struct，须整体赋值
        fish.HasAttacked = true;
        fish.FishLeapedThisTurn = true;
        return new BattleEvent[] { new FishLeapEvent(fish.Id, fish.Bow) };
    }

    // 回合边界：猎杀循环推进 + 冲撞/飞越标记清零（EndTurn 玩家回合分支挂接）。
    public static void ProcessTurnStart(BattleState battle)
    {
        battle.FishHuntRound += 1;
        foreach (var s in battle.Ships.Values.Where(IsFish))
        {
            s.FishChargesUsed = 0;
            s.FishLeapedThisTurn = false;
        }
    }

    // —— 辅助 ——

    private static GridPos FishFront(ShipState fish, CardinalDirection dir)
    {
        var cells = fish.OccupiedCells();
        return dir == fish.Facing ? cells[0]
            : dir == fish.Facing.Opposite() ? cells[^1]
            : cells[0];
    }

    private static ShipState? ShipAt(BattleState battle, GridPos cell)
        => battle.Ships.Values.FirstOrDefault(s => s.HitPoints > 0 && s.OccupiedCells().Contains(cell));
}
