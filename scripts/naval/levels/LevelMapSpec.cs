#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// L-1 关卡地图规格（数据层，纯 C# 无 Godot 依赖）：
// 宽/高 + ASCII 地形网格（string[]，每行定宽）→ 解析为 TerrainType[,] + 出口格集合。
// 符号约定：`.`=深水、`~`=浅滩、`#`=礁石、`^`=山地、`E`=出口格（地形=深水 + 记入 ExitCells）；
//          U-2a 新增：`B`=海滩、`F`=林地、`G`=草地、`P`=港口、`T`=小镇、`R`=陆上河流（陆地/浅水类，见 TerrainRules）。
// 坐标约定：ASCII 第 0 行 = 地图 Y=0（顶行），向下递增，与 Demo GridPos.Y 向下约定一致。
public sealed class LevelMapSpec
{
    public int Width { get; }
    public int Height { get; }
    public IReadOnlyList<string> TerrainRows { get; }
    public IReadOnlyList<GridPos> ExitCells { get; }

    private readonly TerrainType[,] _terrain;

    private LevelMapSpec(int width, int height, IReadOnlyList<string> rows, TerrainType[,] terrain, IReadOnlyList<GridPos> exits)
    {
        Width = width;
        Height = height;
        TerrainRows = rows;
        _terrain = terrain;
        ExitCells = exits;
    }

    // 从 ASCII 地形网格解析：校验非空、每行定宽、仅含合法符号；解析失败抛 ArgumentException（附行列定位）。
    public static LevelMapSpec FromAscii(string[] rows)
    {
        if (rows is null || rows.Length == 0)
            throw new ArgumentException("地形网格不能为空");
        var width = rows[0].Length;
        if (width == 0)
            throw new ArgumentException("地形网格首行为空，须为定宽非空行");
        for (var y = 0; y < rows.Length; y++)
        {
            if (rows[y].Length != width)
                throw new ArgumentException($"地形网格第 {y} 行宽度 {rows[y].Length} 与首行 {width} 不一致");
        }
        var terrain = new TerrainType[width, rows.Length];
        var exits = new List<GridPos>();
        for (var y = 0; y < rows.Length; y++)
        {
            for (var x = 0; x < width; x++)
            {
                var c = rows[y][x];
                terrain[x, y] = c switch
                {
                    '.' => TerrainType.DeepWater,
                    '~' => TerrainType.Shallow,
                    '#' => TerrainType.Reef,
                    '^' => TerrainType.Mountain,
                    'B' => TerrainType.Beach,   // U-2a 海滩
                    'F' => TerrainType.Forest,  // U-2a 林地
                    'G' => TerrainType.Grass,   // U-2a 草地
                    'P' => TerrainType.Port,    // U-2a 港口
                    'T' => TerrainType.Town,    // U-2a 小镇
                    'R' => TerrainType.River,   // U-2a 陆上河流（浅水类）
                    'E' => TerrainType.DeepWater, // 出口格：地形为深水 + 记入 ExitCells
                    _ => throw new ArgumentException($"地形网格 ({x},{y}) 非法符号 '{c}'（允许 . ~ # ^ B F G P T R E）"),
                };
                if (c == 'E') exits.Add(new GridPos(x, y));
            }
        }
        return new LevelMapSpec(width, rows.Length, rows, terrain, exits);
    }

    public bool InBounds(int x, int y) => x >= 0 && x < Width && y >= 0 && y < Height;
    public bool InBounds(GridPos p) => InBounds(p.X, p.Y);

    // 越界访问抛 ArgumentOutOfRangeException（测试覆盖越界行为）。
    public TerrainType TerrainAt(int x, int y)
    {
        if (!InBounds(x, y))
            throw new ArgumentOutOfRangeException(nameof(y), $"地形格 ({x},{y}) 越界（宽 {Width} 高 {Height}）");
        return _terrain[x, y];
    }

    public TerrainType TerrainAt(GridPos p) => TerrainAt(p.X, p.Y);

    public bool IsExit(int x, int y) => ExitCells.Any(p => p.X == x && p.Y == y);
    public bool IsExit(GridPos p) => ExitCells.Any(q => q == p);
}
