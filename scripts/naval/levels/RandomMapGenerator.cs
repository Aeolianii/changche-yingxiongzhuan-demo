#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// R-1 随机地图生成器（纯 C#，无 Godot 依赖）：以深水为主生成可玩的随机战斗地图。
// 按难度放置少量山地/岛屿簇（不可通行）、几处浅滩与几处礁石（可通行但减速/损血）；
// 左右各留一个布阵区（恒为深水 → 舰队恒可放置）；每张地图左右各生成一组相邻双格逃跑区。
//
// 可玩性保障（连通性）：地形放完后做 BFS 连通性检查（玩家区中心 → 敌区中心，可通行格=非山地）。
// 不连通则整图重生成重试（同一种子随机序列推进，可复现）；至多 MaxAttempts 次后兜底纯深水图
// （必然连通），保证生成的地图玩家区与敌区之间始终有可达路径，不会被岛屿切成死区。
//
// 种子化可复现：同 seed → 同 TerrainRows / 出口（LevelMapSpec.FromAscii 确定性解析）。
// 输出 LevelMapSpec 与现有关卡地图同构，可喂 NavalDeploymentController 构建 BattleMap（另提供 ToBattleMap）。
public sealed class RandomMapGenerator
{
    public const int MinWidth = 12;
    public const int MinHeight = 10;
    public const int MinDifficulty = 1;
    public const int MaxDifficulty = 3;

    // 连通性重试上限；概率极低（特征小、布阵区清空），最终兜底仍保证可玩。
    private const int MaxAttempts = 2000;

    // 生成随机地图：返回地图规格 + 双方布阵区。非法尺寸/难度抛 ArgumentOutOfRangeException。
    public RandomMapResult Generate(RandomMapOptions options)
    {
        if (options is null) throw new ArgumentNullException(nameof(options));
        ValidateOptions(options);
        var rng = new SeedRandomSource(options.Seed);
        var playerZone = ComputePlayerZone(options.Width, options.Height);
        var enemyZone = ComputeEnemyZone(options.Width, options.Height);
        for (var attempt = 0; attempt < MaxAttempts; attempt++)
        {
            var spec = BuildOnce(options, rng, playerZone, enemyZone);
            if (HasPath(spec, ZoneCenter(spec, playerZone), ZoneCenter(spec, enemyZone)))
                return new RandomMapResult(spec, playerZone, enemyZone);
        }
        // 兜底：纯深水 + 出口（必然连通）。深水图保底可玩；浅滩/礁石可通行不阻塞，故不加入。
        var fallback = LevelMapSpec.FromAscii(AllDeepRows(options));
        return new RandomMapResult(fallback, playerZone, enemyZone);
    }

    // 便捷助手：把地图规格转换为核心 BattleMap（与 NavalDeploymentController.BuildMapFromSpec 同款构建）。
    public static BattleMap ToBattleMap(LevelMapSpec spec)
    {
        var map = new BattleMap(spec.Width, spec.Height);
        for (var x = 0; x < spec.Width; x++)
            for (var y = 0; y < spec.Height; y++)
                map.SetTerrain(new GridPos(x, y), spec.TerrainAt(x, y));
        foreach (var exit in spec.ExitCells) map.ExitCells.Add(exit);
        ExitCellRules.EnsureSafeExits(map);
        return map;
    }

    // 布阵区中心格（取左上 + 半宽/半高；布阵区恒为深水 → 连通性 BFS 起点/终点恒可通行）。
    public static GridPos ZoneCenter(LevelMapSpec spec, GridRect zone)
        => new(zone.X + zone.Width / 2, zone.Y + zone.Height / 2);

    // 地形可通行（非陆地）。浅滩/礁石/陆河可通行（减速/损血，不阻塞）；一切陆地（海滩/林地/草地/港口/小镇/山地）不可通行。
    public static bool IsPassable(TerrainType t) => !TerrainRules.IsLand(t);

    // 按舰型通过性判定某格是否可通行（与 ValidatePlacement 同口径：陆地恒不可通行；DeepWaterOnly 不可进浅滩/礁石/陆河）。
    public static bool IsPassableFor(ShipDefinition def, TerrainType t) => t switch
    {
        TerrainType.DeepWater => true,
        _ when TerrainRules.IsLand(t) => false,
        _ => def.Passability != Passability.DeepWaterOnly,
    };

    // BFS 连通性检查：from 到 to 是否存在仅经可通行格的路径。任一起点不可通行即返回 false。
    public static bool HasPath(LevelMapSpec spec, GridPos from, GridPos to)
    {
        if (spec is null) throw new ArgumentNullException(nameof(spec));
        if (!spec.InBounds(from) || !spec.InBounds(to)) return false;
        if (!IsPassable(spec.TerrainAt(from)) || !IsPassable(spec.TerrainAt(to))) return false;
        var visited = new HashSet<GridPos> { from };
        var queue = new Queue<GridPos>();
        queue.Enqueue(from);
        while (queue.Count > 0)
        {
            var cur = queue.Dequeue();
            if (cur == to) return true;
            foreach (var dir in new[] { CardinalDirection.North, CardinalDirection.East, CardinalDirection.South, CardinalDirection.West })
            {
                var next = cur + dir.Vector();
                if (spec.InBounds(next) && IsPassable(spec.TerrainAt(next)) && visited.Add(next))
                    queue.Enqueue(next);
            }
        }
        return false;
    }

    // —— 内部实现 ——

    private static void ValidateOptions(RandomMapOptions o)
    {
        if (o.Width < MinWidth || o.Height < MinHeight)
            throw new ArgumentOutOfRangeException(nameof(o), $"地图尺寸至少 {MinWidth}×{MinHeight}（实际 {o.Width}×{o.Height}）");
        if (o.Difficulty < MinDifficulty || o.Difficulty > MaxDifficulty)
            throw new ArgumentOutOfRangeException(nameof(o), $"难度须在 {MinDifficulty}-{MaxDifficulty}（实际 {o.Difficulty}）");
    }

    // 玩家布阵区：左 1 列起、约 1/3 宽、顶/底留 1 行；恒为深水（供舰队放置）。
    private static GridRect ComputePlayerZone(int w, int h)
        => new(1, 1, Math.Max(2, (w - 2) / 3), Math.Max(2, h - 2));

    // 敌布阵区：与玩家区对称靠右；同样恒为深水。
    private static GridRect ComputeEnemyZone(int w, int h)
    {
        var pzWidth = Math.Max(2, (w - 2) / 3);
        return new GridRect(w - 1 - pzWidth, 1, pzWidth, Math.Max(2, h - 2));
    }

    // 单次布局：深水底 → 山地簇/浅滩/礁石（避开布阵区与出口列）→ 出口列 → ASCII 解析。
    private static LevelMapSpec BuildOnce(RandomMapOptions o, IRandomSource rng, GridRect playerZone, GridRect enemyZone)
    {
        var grid = new char[o.Width, o.Height];
        for (var y = 0; y < o.Height; y++)
            for (var x = 0; x < o.Width; x++)
                grid[x, y] = '.'; // 深水底

        var exitY = Math.Max(0, (o.Height - 2) / 2);
        bool IsReservedExit(int x, int y)
            => (x == 0 || x == o.Width - 1) && (y == exitY || y == exitY + 1);

        // 特征可放格：界内、深水、不在布阵区，也不占用两侧双格逃跑区。
        bool AllowFeature(int x, int y)
            => x >= 0 && x < o.Width && y >= 0 && y < o.Height
               && grid[x, y] == '.'
               && !playerZone.Contains(x, y) && !enemyZone.Contains(x, y)
               && !IsReservedExit(x, y);

        // 山地/岛屿簇：diff1 1-2 簇、diff2 2-3 簇、diff3 3-4 簇；每簇中心 + 0-2 随机邻居（1-3 格）。
        var clusterCount = o.Difficulty switch
        {
            1 => rng.NextInt(1, 3),
            2 => rng.NextInt(2, 4),
            _ => rng.NextInt(3, 5),
        };
        for (var c = 0; c < clusterCount; c++)
        {
            var center = FindFreeCell(o, rng, grid, AllowFeature);
            if (center is not { } cx) break;
            grid[cx.X, cx.Y] = '^';
            // 随机邻居（去重、可放才放）；邻居顺序随机 → 每次簇形不同。
            var neighbors = new[] { CardinalDirection.North, CardinalDirection.East, CardinalDirection.South, CardinalDirection.West }
                .OrderBy(_ => rng.NextDouble()).ToArray();
            var blob = rng.NextInt(0, 3); // 0-2 个邻居
            for (var i = 0; i <= blob && i < neighbors.Length; i++)
            {
                var n = cx + neighbors[i].Vector();
                if (AllowFeature(n.X, n.Y)) grid[n.X, n.Y] = '^';
            }
        }

        // 浅滩 2-4 格、礁石 1-3 格（可通行地形，不参与连通性阻断）。
        PlaceScattered(o, rng, grid, AllowFeature, '~', rng.NextInt(2, 5));
        PlaceScattered(o, rng, grid, AllowFeature, '#', rng.NextInt(1, 4));

        // 每张随机地图强制生成左右各一组双格出口；旧 IncludeExits 参数仅保留调用兼容性。
        for (var y = exitY; y <= exitY + 1; y++)
        {
            grid[0, y] = 'E';
            grid[o.Width - 1, y] = 'E';
        }

        var rows = new string[o.Height];
        for (var y = 0; y < o.Height; y++)
        {
            var line = new char[o.Width];
            for (var x = 0; x < o.Width; x++) line[x] = grid[x, y];
            rows[y] = new string(line);
        }
        return LevelMapSpec.FromAscii(rows);
    }

    // 在可放格内随机找一个空格（至多 128 次尝试；地图填满时返回 null）。
    private static GridPos? FindFreeCell(RandomMapOptions o, IRandomSource rng, char[,] grid, Func<int, int, bool> allow)
    {
        for (var attempt = 0; attempt < 128; attempt++)
        {
            var x = rng.NextInt(0, o.Width);
            var y = rng.NextInt(0, o.Height);
            if (allow(x, y)) return new GridPos(x, y);
        }
        return null;
    }

    // 散点放置 count 格同类型地形（各自独立随机尝试，不保证全数成功 → 数量在"合理范围"）。
    private static void PlaceScattered(RandomMapOptions o, IRandomSource rng, char[,] grid, Func<int, int, bool> allow, char terrainChar, int count)
    {
        for (var i = 0; i < count; i++)
        {
            if (FindFreeCell(o, rng, grid, allow) is { } p) grid[p.X, p.Y] = terrainChar;
        }
    }

    private static string[] AllDeepRows(RandomMapOptions o)
    {
        var rows = new string[o.Height];
        var exitY = Math.Max(0, (o.Height - 2) / 2);
        for (var y = 0; y < o.Height; y++)
            rows[y] = new string(Enumerable.Range(0, o.Width)
                .Select(x => (x == 0 || x == o.Width - 1) && (y == exitY || y == exitY + 1) ? 'E' : '.')
                .ToArray());
        return rows;
    }
}

// R-1 随机地图参数。Width/Height 尺寸（默认 24×18）；Difficulty 1-3（地形密度）；Seed 种子（可复现）；
// IncludeExits 为旧接口兼容字段；当前规则要求所有地图始终生成逃跑格，因此 false 也不会关闭出口。
public sealed record RandomMapOptions(
    int Width = 24,
    int Height = 18,
    int Difficulty = 2,
    int Seed = 1337,
    bool IncludeExits = true);

// R-1 随机地图结果：地图规格（可喂 LevelMapSpec/BattleMap）+ 双方布阵区（供随机敌舰/布阵使用）。
public sealed record RandomMapResult(LevelMapSpec Spec, GridRect PlayerZone, GridRect EnemyZone)
{
    // 连通性（玩家区 → 敌区 可达路径）；生成器保证恒为 true。
    public bool Connected
        => RandomMapGenerator.HasPath(Spec, RandomMapGenerator.ZoneCenter(Spec, PlayerZone), RandomMapGenerator.ZoneCenter(Spec, EnemyZone));
}
