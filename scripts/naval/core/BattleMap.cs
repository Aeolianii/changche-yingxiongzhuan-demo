#nullable enable
using System.Collections.Generic;

namespace NavalCombat.Core;

// U-2a：新增陆地（海滩/林地/草地/港口/小镇）与陆上河流。陆地恒不可通行；陆河按浅滩类似（通过性≥2 可走）。
public enum TerrainType { DeepWater, Shallow, Reef, Mountain, Beach, Forest, Grass, Port, Town, River }

// 多格地形印章的表现元数据。规则仍以 BattleMap 的逐格 TerrainType 为准；
// 纹理只负责把一组逻辑格绘制成连续地貌，不参与碰撞、寻路或部署判定。
public sealed record TerrainVisualStamp(
    string Id,
    string TexturePath,
    GridPos Origin,
    int Width,
    int Height,
    int QuarterTurns = 0)
{
    public bool Contains(GridPos cell)
        => cell.X >= Origin.X && cell.X < Origin.X + Width
           && cell.Y >= Origin.Y && cell.Y < Origin.Y + Height;
}

public sealed class BattleMap
{
    private readonly TerrainType[,] _terrain;
    public int Width { get; }
    public int Height { get; }
    public HashSet<GridPos> Wrecks { get; } = new();
    public HashSet<GridPos> ExitCells { get; } = new();
    public List<TerrainVisualStamp> TerrainStamps { get; } = new();
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
