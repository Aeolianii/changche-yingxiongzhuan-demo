#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

// 逃跑格统一规则：按地图规模生成 4-6 格，且只允许落在无残骸、无水雷、无初始舰体的深水格上。
// 优先平衡分布于左右边缘（符合双方航向），不足时再从上下边缘及图内安全深水补齐。
public static class ExitCellRules
{
    public static int RecommendedCount(int width, int height)
    {
        var area = Math.Max(1, width) * Math.Max(1, height);
        return area <= 200 ? 4 : area <= 800 ? 5 : 6;
    }

    public static void EnsureSafeExits(BattleMap map, IEnumerable<GridPos>? occupiedCells = null)
    {
        if (map is null) throw new ArgumentNullException(nameof(map));
        var occupied = occupiedCells?.ToHashSet() ?? new HashSet<GridPos>();
        var targetCount = RecommendedCount(map.Width, map.Height);
        var selected = map.ExitCells
            .Where(cell => IsSafe(map, cell, occupied))
            .OrderBy(cell => DistanceToMapCenter(map, cell))
            .Take(targetCount)
            .ToHashSet();
        map.ExitCells.Clear();

        var leftQuota = targetCount / 2;
        var rightQuota = targetCount - leftQuota;
        FillVerticalEdge(map, selected, occupied, x: 0, leftQuota, targetCount);
        FillVerticalEdge(map, selected, occupied, x: map.Width - 1, rightQuota, targetCount);

        // 某侧被连续陆地封死时，从其余三边按靠近地图中线顺序补齐。
        var boundary = Enumerable.Range(0, map.Width).Select(x => new GridPos(x, 0))
            .Concat(Enumerable.Range(0, map.Width).Select(x => new GridPos(x, map.Height - 1)))
            .Concat(Enumerable.Range(0, map.Height).Select(y => new GridPos(0, y)))
            .Concat(Enumerable.Range(0, map.Height).Select(y => new GridPos(map.Width - 1, y)))
            .Distinct()
            .OrderBy(cell => DistanceToMapCenter(map, cell));
        FillFromCandidates(map, selected, occupied, boundary, targetCount);

        // 极端封闭地图兜底：边界无深水时仍从图内安全深水补足，不把逃跑格放到障碍物上。
        var allSafe = Enumerable.Range(0, map.Height)
            .SelectMany(y => Enumerable.Range(0, map.Width).Select(x => new GridPos(x, y)))
            .OrderBy(cell => DistanceToMapCenter(map, cell));
        FillFromCandidates(map, selected, occupied, allSafe, targetCount);

        foreach (var cell in selected) map.ExitCells.Add(cell);
    }

    public static bool IsSafeExit(BattleMap map, GridPos cell)
        => map.InBounds(cell) && IsSafe(map, cell, new HashSet<GridPos>()) && map.ExitCells.Contains(cell);

    private static void FillVerticalEdge(
        BattleMap map,
        HashSet<GridPos> selected,
        HashSet<GridPos> occupied,
        int x,
        int quota,
        int targetCount)
    {
        var onEdge = selected.Count(cell => cell.X == x);
        if (onEdge >= quota) return;
        var candidates = Enumerable.Range(0, map.Height)
            .Select(y => new GridPos(x, y))
            .OrderBy(cell => Math.Abs(cell.Y - (map.Height - 1) * 0.5f));
        foreach (var cell in candidates)
        {
            if (selected.Count >= targetCount || onEdge >= quota) break;
            if (!IsSafe(map, cell, occupied) || !selected.Add(cell)) continue;
            onEdge++;
        }
    }

    private static void FillFromCandidates(
        BattleMap map,
        HashSet<GridPos> selected,
        HashSet<GridPos> occupied,
        IEnumerable<GridPos> candidates,
        int targetCount)
    {
        foreach (var cell in candidates)
        {
            if (selected.Count >= targetCount) return;
            if (IsSafe(map, cell, occupied)) selected.Add(cell);
        }
    }

    private static float DistanceToMapCenter(BattleMap map, GridPos cell)
        => Math.Abs(cell.X - (map.Width - 1) * 0.5f) + Math.Abs(cell.Y - (map.Height - 1) * 0.5f);

    private static bool IsSafe(BattleMap map, GridPos cell, HashSet<GridPos> occupied)
        => map.TerrainAt(cell) == TerrainType.DeepWater
           && !occupied.Contains(cell)
           && !map.Wrecks.Contains(cell)
           && !map.Mines.ContainsKey(cell);
}
