#nullable enable
using System.Linq;

namespace NavalCombat.Core;

// 海怪02 AI：节奏见 Task 7 裁定。朝最近玩家舰冲撞/飞越，确定性排序。
public static class FishSchoolAi
{
    public static BattleCommand ChooseNext(BattleState battle, FactionId faction)
    {
        var fish = battle.Ships.Values
            .Where(s => s.Faction == faction && s.HitPoints > 0 && s.Definition.IsFish)
            .OrderBy(s => s.Id).FirstOrDefault();
        if (fish is null) return new EndFactionTurnCommand();
        var mode = FishSchoolRules.ModeOf(FishSchoolRules.AliveFishCount(battle));

        // ① 冲撞（未达上限）。
        if (fish.FishChargesUsed < FishSchoolRules.ChargeLimit(battle, mode))
        {
            var dir = DirectionToPlayer(battle, fish);
            return new FishChargeCommand(fish.Id, dir);
        }

        // ② 困兽：冲撞后飞越一次。方向优先朝玩家，落点非法则回退其他方向；全非法则不飞（结束）。
        if (mode == FishMode.Corner && !fish.FishLeapedThisTurn)
        {
            var dir = PickLeapDirection(battle, fish);
            if (dir is not null)
                return new FishLeapMoveCommand(fish.Id, dir.Value);
        }

        // ③ 结束。
        return new EndFactionTurnCommand();
    }

    // 困兽飞越方向：先朝最近玩家舰，再按北/东/南/西回退，取首个落点合法（界内/水域/空格）的方向；全非法返回 null。
    private static CardinalDirection? PickLeapDirection(BattleState battle, ShipState fish)
    {
        var preferred = DirectionToPlayer(battle, fish);
        var dirs = new[] { preferred, CardinalDirection.North, CardinalDirection.East, CardinalDirection.South, CardinalDirection.West };
        foreach (var d in dirs)
            if (FishSchoolRules.ValidateLeap(battle, new FishLeapMoveCommand(fish.Id, d)) is null)
                return d;
        return null;
    }

    // 朝最近玩家舰占格的方向（确定性：最近格 → 轴占优）。
    private static CardinalDirection DirectionToPlayer(BattleState battle, ShipState fish)
    {
        var target = battle.Ships.Values
            .Where(s => s.Faction != fish.Faction && s.HitPoints > 0)
            .SelectMany(s => s.OccupiedCells())
            .OrderBy(c => c.SquaredDistance(fish.Bow))
            .FirstOrDefault();
        var dx = target.X - fish.Bow.X;
        var dy = target.Y - fish.Bow.Y;
        if (System.Math.Abs(dx) >= System.Math.Abs(dy))
            return dx >= 0 ? CardinalDirection.East : CardinalDirection.West;
        return dy >= 0 ? CardinalDirection.South : CardinalDirection.North;
    }
}
