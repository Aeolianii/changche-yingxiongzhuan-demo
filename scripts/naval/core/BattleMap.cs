#nullable enable
using System.Collections.Generic;

namespace NavalCombat.Core;

// U-2a：新增陆地（海滩/林地/草地/港口/小镇）与陆上河流。陆地恒不可通行；陆河按浅滩类似（通过性≥2 可走）。
public enum TerrainType { DeepWater, Shallow, Reef, Mountain, Beach, Forest, Grass, Port, Town, River }

public sealed class BattleMap
{
    private readonly TerrainType[,] _terrain;
    public int Width { get; }
    public int Height { get; }
    public HashSet<GridPos> Wrecks { get; } = new();
    public HashSet<GridPos> ExitCells { get; } = new();
    // Task 12：水雷（设计 13）。同一格至多一颗雷，以 GridPos 为唯一身份（连锁爆炸按格去重）。
    public Dictionary<GridPos, Mine> Mines { get; } = new();

    public BattleMap(int width, int height)
    {
        Width = width;
        Height = height;
        _terrain = new TerrainType[width, height];
    }
    public bool InBounds(GridPos p) => p.X >= 0 && p.X < Width && p.Y >= 0 && p.Y < Height;
    public TerrainType TerrainAt(GridPos p) => _terrain[p.X, p.Y];
    public void SetTerrain(GridPos p, TerrainType t) => _terrain[p.X, p.Y] = t;
    public bool IsWreck(GridPos p) => Wrecks.Contains(p);
    public Mine? MineAt(GridPos p) => Mines.TryGetValue(p, out var m) ? m : null;
    public Mine PlaceMine(Mine m) { Mines[m.Cell] = m; return m; }
    public bool RemoveMine(Mine m) => Mines.Remove(m.Cell);
}
