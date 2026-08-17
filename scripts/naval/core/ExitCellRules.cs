#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

// 逃跑格统一规则：每侧最多放一组相邻两格，且只允许落在无残骸、无水雷的深水格上。
// 优先左右边缘（符合双方航向），左右不可用时再退到上下边缘；极端封闭地图则选任意安全深水格兜底。
public static class ExitCellRules
{
    public static void EnsureSafeExits(BattleMap map, IEnumerable<GridPos>? occupiedCells = null)
    {
        if (map is null) throw new ArgumentNullException(nameof(map));
        var occupied = occupiedCells?.ToHashSet() ?? new HashSet<GridPos>();
        var authored = map.ExitCells.Where(cell => IsSafe(map, cell, occupied)).ToList();
        map.ExitCells.Clear();

        // 关卡/随机地图显式标出的 E 是设计者意图，只剔除障碍或初始舰位冲突，不擅自挪位。
        if (authored.Count > 0)
        {
            foreach (var cell in authored) map.ExitCells.Add(cell);
            return;
        }

        var groups = new List<List<GridPos>>();
        AddBestPair(groups, EdgeRuns(map, left: true, occupied));
        AddBestPair(groups, EdgeRuns(map, left: false, occupied));

        if (groups.Count == 0)
        {
            AddBestPair(groups, HorizontalEdgeRuns(map, top: true, occupied));
            AddBestPair(groups, HorizontalEdgeRuns(map, top: false, occupied));
        }

        foreach (var group in groups)
            foreach (var cell in group)
                map.ExitCells.Add(cell);

        if (map.ExitCells.Count > 0) return;

        // 防御性兜底：即使四边全是陆地，也保证地图至少有一个不在障碍上的逃跑格。
        for (var y = 0; y < map.Height; y++)
            for (var x = 0; x < map.Width; x++)
            {
                var cell = new GridPos(x, y);
                if (!IsSafe(map, cell, occupied)) continue;
                map.ExitCells.Add(cell);
                return;
            }
    }

    public static bool IsSafeExit(BattleMap map, GridPos cell)
        => map.InBounds(cell) && IsSafe(map, cell, new HashSet<GridPos>()) && map.ExitCells.Contains(cell);

    private static IEnumerable<List<GridPos>> EdgeRuns(BattleMap map, bool left, HashSet<GridPos> occupied)
    {
        var x = left ? 0 : map.Width - 1;
        return ConsecutiveRuns(Enumerable.Range(0, map.Height).Select(y => new GridPos(x, y)), map, occupied);
    }

    private static IEnumerable<List<GridPos>> HorizontalEdgeRuns(BattleMap map, bool top, HashSet<GridPos> occupied)
    {
        var y = top ? 0 : map.Height - 1;
        return ConsecutiveRuns(Enumerable.Range(0, map.Width).Select(x => new GridPos(x, y)), map, occupied);
    }

    private static IEnumerable<List<GridPos>> ConsecutiveRuns(IEnumerable<GridPos> edge, BattleMap map, HashSet<GridPos> occupied)
    {
        var runs = new List<List<GridPos>>();
        var current = new List<GridPos>();
        foreach (var cell in edge)
        {
            if (IsSafe(map, cell, occupied))
            {
                current.Add(cell);
                continue;
            }
            if (current.Count > 0) runs.Add(current);
            current = new List<GridPos>();
        }
        if (current.Count > 0) runs.Add(current);
        return runs;
    }

    private static void AddBestPair(List<List<GridPos>> target, IEnumerable<List<GridPos>> runs)
    {
        var run = runs.Where(r => r.Count >= 2).OrderByDescending(r => r.Count).FirstOrDefault();
        if (run is null) return;
        var start = (run.Count - 2) / 2;
        target.Add(new List<GridPos> { run[start], run[start + 1] });
    }

    private static bool IsSafe(BattleMap map, GridPos cell, HashSet<GridPos> occupied)
        => map.TerrainAt(cell) == TerrainType.DeepWater
           && !occupied.Contains(cell)
           && !map.Wrecks.Contains(cell)
           && !map.Mines.ContainsKey(cell);
}
