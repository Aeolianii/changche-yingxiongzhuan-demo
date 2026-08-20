#nullable enable
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

// 海怪01 AI：决策节奏见 Task 5 裁定。纯规则层，不依赖 Godot；随机只来自 battle.Random（3:1 水下掷骰）。
public static class SeaMonsterAi
{
    public static BattleCommand ChooseNext(BattleState battle, FactionId faction)
    {
        var monster = battle.Ships.Values
            .Where(s => s.Faction == faction && s.HitPoints > 0 && s.Definition.IsSeaMonster)
            .OrderBy(s => s.Id).FirstOrDefault();
        if (monster is null) return new EndFactionTurnCommand();
        var phase = SeaMonsterRules.PhaseOf(monster);

        // ① 有上回合遗留的已预告移动 → 执行（占动作）。本回合刚声明的预告（MonsterDeclaredPreview）不执行，下回合才动。
        if (monster.PendingMonsterMovePreview is { } pv && !monster.MonsterDeclaredPreview)
            return new MonsterMoveCommand(monster.Id, pv.Path[^1]);

        // ② 未攻击 → 触手。
        if (!monster.HasAttacked)
        {
            var tentacle = ChooseTentacle(battle, monster, phase);
            if (tentacle is not null) return tentacle;
        }

        // ③ 冷却 0 且无未决预告 → 预告下回合移动（免费动作；本回合预告后即结束回合，下回合执行）。
        if (monster.MonsterNoMoveRoundsLeft == 0 && monster.PendingMonsterMovePreview is null)
            return DeclareNextMove(battle, monster, phase);

        // ④ 结束回合。
        return new EndFactionTurnCommand();
    }

    private static BattleCommand? ChooseTentacle(BattleState battle, ShipState monster, int phase)
    {
        // 一阶段：优先 MultiThree（覆盖≥2 目标），否则 SingleFive。
        foreach (var kind in phase == 1
                     ? new[] { TentacleKind.MultiThree, TentacleKind.SingleFive }
                     : new[] { TentacleKind.SingleFive })
        {
            var target = BestLineTarget(battle, monster, kind);
            if (target is not null) return new TentacleStrikeCommand(monster.Id, target.Value, kind);
        }
        return null;
    }

    // 选触手线：按海怪四方向偏移扫描线首（距海怪 1），找首个合法且覆盖目标的线。
    private static GridPos? BestLineTarget(BattleState battle, ShipState monster, TentacleKind kind)
    {
        foreach (var d in new[] { CardinalDirection.North, CardinalDirection.East, CardinalDirection.South, CardinalDirection.West })
            foreach (var near in monster.OccupiedCells())
            {
                var target = near + d.Vector();
                var cmd = new TentacleStrikeCommand(monster.Id, target, kind);
                if (SeaMonsterRules.ValidateTentacleStrike(battle, cmd) is null)
                    return target;
            }
        return null;
    }

    // 预告：一阶段水下 8 格；二阶段 3:1 掷骰（Random.NextInt(0,4)==0 → 水下），水下后冷却由规则设 2。
    private static MonsterDeclareMoveCommand DeclareNextMove(BattleState battle, ShipState monster, int phase)
    {
        if (phase == 2 && battle.Random.NextInt(0, 4) == 0)
        {
            var dest = PickWaterDestination(battle, monster, SeaMonsterRules.Phase2SubmergedRange, deepOnly: true);
            if (dest is not null) return new MonsterDeclareMoveCommand(monster.Id, LinePath(monster.Bow, dest.Value), SurfaceMove: false);
        }
        var range = phase == 1 ? SeaMonsterRules.Phase1MoveRange : SeaMonsterRules.Phase2SurfaceRange;
        var goal = PickWaterDestination(battle, monster, range, deepOnly: phase == 1);
        var path = goal is { } g
            ? LinePath(monster.Bow, g)
            : new[] { monster.Bow };
        return new MonsterDeclareMoveCommand(monster.Id, path, SurfaceMove: phase == 2);
    }

    // 水目标：距海怪 ≤ range 的合法水格中离最近玩家舰最近者（确定性排序）。
    private static GridPos? PickWaterDestination(BattleState battle, ShipState monster, int range, bool deepOnly)
    {
        var playerCells = battle.Ships.Values
            .Where(s => s.Faction != monster.Faction && s.HitPoints > 0)
            .SelectMany(s => s.OccupiedCells()).ToList();
        GridPos? best = null;
        var bestScore = int.MaxValue;
        for (var x = 0; x < battle.Map.Width; x++)
            for (var y = 0; y < battle.Map.Height; y++)
            {
                var cell = new GridPos(x, y);
                if (cell.SquaredDistance(monster.Bow) > range * range) continue;
                var t = battle.Map.TerrainAt(cell);
                if (TerrainRules.BlocksShip(t, deepOnly ? Passability.DeepWaterOnly : Passability.ReefDamaging)) continue;
                // Task 11 冒烟发现：仅校验终点格不够——直线路径可能穿越陆地/浅滩（海盗据点图），
                // 预告会被 ValidateDeclareMove 拒绝 → AI 反复返回同一非法预告 → 死循环打满步数。
                // 只接受「直线路径全部为合法水域」的目标，否则放弃该候选（无合法目标时 AI 预告原地移动）。
                if (!PathCellsAreWater(battle, LinePath(monster.Bow, cell), deepOnly)) continue;
                var score = playerCells.Count == 0 ? 0 : playerCells.Min(c => c.SquaredDistance(cell));
                // 偏好空格：任何被活舰占用的格加极大惩罚，仅在无空格可选时落到占格。
                if (battle.Ships.Values.Any(s => s.HitPoints > 0 && s.OccupiedCells().Contains(cell))) score += 1_000_000;
                if (score < bestScore) { bestScore = score; best = cell; }
            }
        return best;
    }

    // 直线路径各格是否为合法水域（与 SeaMonsterRules.ValidWaterCells 同口径：水下=深水、水面=可礁行）。
    private static bool PathCellsAreWater(BattleState battle, IReadOnlyList<GridPos> path, bool deepOnly)
    {
        foreach (var cell in path)
        {
            if (!battle.Map.InBounds(cell)) return false;
            if (TerrainRules.BlocksShip(battle.Map.TerrainAt(cell), deepOnly ? Passability.DeepWaterOnly : Passability.ReefDamaging))
                return false;
        }
        return true;
    }

    // 直线路径（含起终点；终点为 dest）。
    private static GridPos[] LinePath(GridPos from, GridPos to)
    {
        var dx = to.X - from.X; var dy = to.Y - from.Y;
        var steps = System.Math.Max(System.Math.Abs(dx), System.Math.Abs(dy));
        var path = new List<GridPos>();
        for (var i = 1; i <= steps; i++)
            path.Add(new GridPos(from.X + dx * i / steps, from.Y + dy * i / steps));
        if (path.Count == 0 || path[^1] != to) path.Add(to);
        return path.ToArray();
    }
}
