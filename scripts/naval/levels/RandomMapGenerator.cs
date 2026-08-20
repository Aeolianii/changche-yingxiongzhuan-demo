#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// R-1 固定地图选择器（纯 C#，无 Godot 依赖）：维护五张经过构图验证的海战地貌模板。
// Seed 只负责选择峡湾、群岛、孤岛、半岛或泻湖；模板内部的主地貌印章、散点装饰与出口均固定。
// 左右各留一个布阵区（恒为深水 → 舰队恒可放置）；每张地图左右各生成一组安全逃跑区。
//
// 可玩性保障（连通性）：地形放完后做 BFS 连通性检查（玩家区中心 → 敌区中心，可通行格=非陆地）。
// 固定模板若因非标准尺寸无法放置或未通过连通性检查，则兜底纯深水图，保证旧尺寸接口仍可用。
//
// 种子化可复现：同 seed → 同模板 / TerrainRows / 出口（LevelMapSpec.FromAscii 确定性解析）。
// 输出 LevelMapSpec 与现有关卡地图同构，可喂 NavalDeploymentController 构建 BattleMap（另提供 ToBattleMap）。
public sealed class RandomMapGenerator
{
    public const int MinWidth = 12;
    public const int MinHeight = 10;
    public const int MinDifficulty = 1;
    public const int MaxDifficulty = 3;

    public const int FixedMapWidth = 24;
    public const int FixedMapHeight = 18;
    public const string FjordStampId = "fjord_v1";
    public const string ArchipelagoStampId = "archipelago_v1";
    public const string SolitaryIslandStampId = "solitary_island_v1";
    public const string PeninsulaStampId = "peninsula_v1";
    public const string LagoonStampId = "lagoon_v1";
    private const string TerrainStampAssetRoot = "res://assets/naval/battle/terrain_stamps/";

    private sealed record TerrainStampDefinition(
        string Id,
        string TexturePath,
        string[] Mask)
    {
        public int Width => Mask[0].Length;
        public int Height => Mask.Length;
    }

    private sealed record TerrainDecoration(GridPos Position, char Terrain);

    private sealed record FixedMapTemplate(
        string Id,
        string DisplayName,
        TerrainStampDefinition MainStamp,
        GridPos MainOrigin,
        TerrainDecoration[] Decorations);

    private static readonly TerrainStampDefinition FjordStamp = new(
        FjordStampId,
        TerrainStampAssetRoot + "fjord_v1.png",
        new[]
        {
            "^^....^^",
            "^^^..^^^",
            "^^...^^^",
            "^^^...^^",
            "^^....^^",
            "^^^...^^",
            "^^....^^",
            "^^...^^^",
            "^^....^^",
            "^^^...^^",
            "^^....^^",
            "^^...^^^",
            "^^^...^^",
            "^^....^^",
        });

    private static readonly TerrainStampDefinition ArchipelagoStamp = new(
        ArchipelagoStampId,
        TerrainStampAssetRoot + "archipelago_v1.png",
        new[]
        {
            "FFF...^^",
            "FFFF..^^",
            "FFF.....",
            "...^^GGG",
            "...^.GGG",
            "........",
            ".^^...GG",
            ".^^..GGG",
            ".....GGG",
            "........",
        });

    private static readonly TerrainStampDefinition SolitaryIslandStamp = new(
        SolitaryIslandStampId,
        TerrainStampAssetRoot + "solitary_island_v1.png",
        new[]
        {
            "..BBBB..",
            ".BFFFFB.",
            "BFF^^FFB",
            "BFF^^FFB",
            "BFFFFFFB",
            "BFGGGGFB",
            ".BGGGGB.",
            "..BBBB..",
        });

    private static readonly TerrainStampDefinition PeninsulaStamp = new(
        PeninsulaStampId,
        TerrainStampAssetRoot + "peninsula_v1.png",
        new[]
        {
            "....BBBB",
            "....BBBB",
            ".....BBB",
            ".....BBB",
            "......BB",
            "......BB",
            ".....BBB",
            ".....BBB",
            "....BBBB",
            "...BBBBB",
            ".BBBBBBB",
            "BBBBBBBB",
            "BBBBBBBB",
        });

    private static readonly TerrainStampDefinition LagoonStamp = new(
        LagoonStampId,
        TerrainStampAssetRoot + "lagoon_v1.png",
        new[]
        {
            "..BBBB..",
            ".BB..BB.",
            "BB....BB",
            "BB....BB",
            "........",
            "........",
            "BB....BB",
            "BB....BB",
            ".BB..BB.",
            "..BBBB..",
        });

    private static readonly FixedMapTemplate[] FixedMapTemplates =
    {
        new(
            "fjord",
            "峡湾",
            FjordStamp,
            new GridPos(8, 2),
            Array.Empty<TerrainDecoration>()),
        new(
            "archipelago",
            "群岛",
            ArchipelagoStamp,
            new GridPos(8, 4),
            Array.Empty<TerrainDecoration>()),
        new(
            "solitary_island",
            "孤岛",
            SolitaryIslandStamp,
            new GridPos(8, 5),
            Array.Empty<TerrainDecoration>()),
        new(
            "peninsula",
            "半岛",
            PeninsulaStamp,
            new GridPos(8, 0),
            Array.Empty<TerrainDecoration>()),
        new(
            "lagoon",
            "泻湖",
            LagoonStamp,
            new GridPos(8, 4),
            Array.Empty<TerrainDecoration>()),
    };

    public static IReadOnlyList<string> TerrainStampIds { get; } =
        new[]
        {
            FjordStampId,
            ArchipelagoStampId,
            SolitaryIslandStampId,
            PeninsulaStampId,
            LagoonStampId,
        };

    public static IReadOnlyList<string> FixedMapIds { get; } = FixedMapTemplates.Select(template => template.Id).ToArray();
    public static IReadOnlyList<string> MainTerrainStampIds { get; } = FixedMapTemplates.Select(template => template.MainStamp.Id).ToArray();

    // 从五张固定地图中选择一张：返回地图规格 + 双方布阵区。非法尺寸/难度抛 ArgumentOutOfRangeException。
    public RandomMapResult Generate(RandomMapOptions options)
    {
        if (options is null) throw new ArgumentNullException(nameof(options));
        ValidateOptions(options);
        var playerZone = ComputePlayerZone(options.Width, options.Height);
        var enemyZone = ComputeEnemyZone(options.Width, options.Height);
        var template = FixedMapTemplates[PositiveModulo(options.Seed, FixedMapTemplates.Length)];
        var spec = BuildFixedMap(options, playerZone, enemyZone, template);
        if (spec.TerrainStamps.Count == 1
            && HasPath(spec, ZoneCenter(spec, playerZone), ZoneCenter(spec, enemyZone)))
            return new RandomMapResult(spec, playerZone, enemyZone);

        // 兜底：纯深水 + 出口（必然连通）。
        var fallback = LevelMapSpec.FromAscii(AllDeepRows(options));
        return new RandomMapResult(fallback, playerZone, enemyZone);
    }

    public static string FixedMapId(LevelMapSpec spec)
    {
        var mainStampId = spec.TerrainStamps.FirstOrDefault()?.Id;
        return FixedMapTemplates.FirstOrDefault(template => template.MainStamp.Id == mainStampId)?.Id ?? "open_sea";
    }

    public static string FixedMapDisplayName(LevelMapSpec spec)
    {
        var mainStampId = spec.TerrainStamps.FirstOrDefault()?.Id;
        return FixedMapTemplates.FirstOrDefault(template => template.MainStamp.Id == mainStampId)?.DisplayName ?? "开阔海域";
    }

    // 便捷助手：把地图规格转换为核心 BattleMap（与 NavalDeploymentController.BuildMapFromSpec 同款构建）。
    public static BattleMap ToBattleMap(LevelMapSpec spec)
    {
        var map = new BattleMap(spec.Width, spec.Height);
        for (var x = 0; x < spec.Width; x++)
            for (var y = 0; y < spec.Height; y++)
                map.SetTerrain(new GridPos(x, y), spec.TerrainAt(x, y));
        foreach (var exit in spec.ExitCells) map.ExitCells.Add(exit);
        map.TerrainStamps.AddRange(spec.TerrainStamps);
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

    private static int PositiveModulo(int value, int modulus)
    {
        var remainder = value % modulus;
        return remainder < 0 ? remainder + modulus : remainder;
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

    // 固定模板布局：深水底 → 一枚大型主地貌印章 → 固定散点装饰 → 安全出口 → ASCII 解析。
    private static LevelMapSpec BuildFixedMap(
        RandomMapOptions o,
        GridRect playerZone,
        GridRect enemyZone,
        FixedMapTemplate template)
    {
        var grid = new char[o.Width, o.Height];
        for (var y = 0; y < o.Height; y++)
            for (var x = 0; x < o.Width; x++)
                grid[x, y] = '.'; // 深水底

        var exitCount = ExitCellRules.RecommendedCount(o.Width, o.Height);
        var leftExitCount = exitCount / 2;
        var rightExitCount = exitCount - leftExitCount;
        var leftExitY = Math.Max(0, (o.Height - leftExitCount) / 2);
        var rightExitY = Math.Max(0, (o.Height - rightExitCount) / 2);
        bool IsReservedExit(int x, int y)
            => x == 0 && y >= leftExitY && y < leftExitY + leftExitCount
               || x == o.Width - 1 && y >= rightExitY && y < rightExitY + rightExitCount;

        var terrainStamps = new List<TerrainVisualStamp>();
        var mapOffset = new GridPos((o.Width - FixedMapWidth) / 2, (o.Height - FixedMapHeight) / 2);
        PlaceFixedTerrainStamp(
            o,
            grid,
            playerZone,
            enemyZone,
            IsReservedExit,
            terrainStamps,
            template.MainStamp,
            template.MainOrigin + mapOffset);
        foreach (var decoration in template.Decorations)
        {
            var cell = decoration.Position + mapOffset;
            if (cell.X < 0 || cell.X >= o.Width || cell.Y < 0 || cell.Y >= o.Height
                || grid[cell.X, cell.Y] != '.'
                || playerZone.Contains(cell) || enemyZone.Contains(cell)
                || IsReservedExit(cell.X, cell.Y)
                || terrainStamps.Any(stamp => stamp.Contains(cell)))
                continue;
            grid[cell.X, cell.Y] = decoration.Terrain;
        }

        // 每张固定地图仍按尺寸生成安全出口，并在左右边缘平衡分布。
        for (var y = leftExitY; y < leftExitY + leftExitCount; y++) grid[0, y] = 'E';
        for (var y = rightExitY; y < rightExitY + rightExitCount; y++) grid[o.Width - 1, y] = 'E';

        var rows = new string[o.Height];
        for (var y = 0; y < o.Height; y++)
        {
            var line = new char[o.Width];
            for (var x = 0; x < o.Width; x++) line[x] = grid[x, y];
            rows[y] = new string(line);
        }
        return LevelMapSpec.FromAscii(rows).WithTerrainStamps(terrainStamps);
    }

    private static bool PlaceFixedTerrainStamp(
        RandomMapOptions options,
        char[,] grid,
        GridRect playerZone,
        GridRect enemyZone,
        Func<int, int, bool> isReservedExit,
        List<TerrainVisualStamp> terrainStamps,
        TerrainStampDefinition definition,
        GridPos origin)
    {
        if (origin.X < 0 || origin.Y < 0
            || origin.X + definition.Width > options.Width
            || origin.Y + definition.Height > options.Height
            || terrainStamps.Any(stamp => RectanglesOverlap(origin, definition.Width, definition.Height, stamp)))
            return false;

        for (var y = 0; y < definition.Height; y++)
        {
            for (var x = 0; x < definition.Width; x++)
            {
                var mapX = origin.X + x;
                var mapY = origin.Y + y;
                if (grid[mapX, mapY] != '.'
                    || playerZone.Contains(mapX, mapY)
                    || enemyZone.Contains(mapX, mapY)
                    || isReservedExit(mapX, mapY))
                    return false;
            }
        }

        for (var y = 0; y < definition.Height; y++)
            for (var x = 0; x < definition.Width; x++)
                if (definition.Mask[y][x] != '.')
                    grid[origin.X + x, origin.Y + y] = definition.Mask[y][x];

        terrainStamps.Add(new TerrainVisualStamp(
            definition.Id,
            definition.TexturePath,
            origin,
            definition.Width,
            definition.Height,
            QuarterTurns: 0));
        return true;
    }

    private static bool RectanglesOverlap(
        GridPos origin,
        int width,
        int height,
        TerrainVisualStamp existing)
        => origin.X < existing.Origin.X + existing.Width
           && origin.X + width > existing.Origin.X
           && origin.Y < existing.Origin.Y + existing.Height
           && origin.Y + height > existing.Origin.Y;

    private static string[] AllDeepRows(RandomMapOptions o)
    {
        var rows = new string[o.Height];
        var exitCount = ExitCellRules.RecommendedCount(o.Width, o.Height);
        var leftExitCount = exitCount / 2;
        var rightExitCount = exitCount - leftExitCount;
        var leftExitY = Math.Max(0, (o.Height - leftExitCount) / 2);
        var rightExitY = Math.Max(0, (o.Height - rightExitCount) / 2);
        for (var y = 0; y < o.Height; y++)
            rows[y] = new string(Enumerable.Range(0, o.Width)
                .Select(x => x == 0 && y >= leftExitY && y < leftExitY + leftExitCount
                             || x == o.Width - 1 && y >= rightExitY && y < rightExitY + rightExitCount
                    ? 'E' : '.')
                .ToArray());
        return rows;
    }
}

// R-1 固定地图选择参数。Width/Height 默认 24×18；Difficulty 1-3 保留给遭遇强度但不改变地图；
// Seed 只选择五张模板之一（可复现）；
// IncludeExits 为旧接口兼容字段；当前规则要求所有地图始终生成逃跑格，因此 false 也不会关闭出口。
public sealed record RandomMapOptions(
    int Width = 24,
    int Height = 18,
    int Difficulty = 2,
    int Seed = 1337,
    bool IncludeExits = true);

// R-1 固定地图选择结果：地图规格（可喂 LevelMapSpec/BattleMap）+ 双方布阵区（供随机敌舰/布阵使用）。
public sealed record RandomMapResult(LevelMapSpec Spec, GridRect PlayerZone, GridRect EnemyZone)
{
    // 连通性（玩家区 → 敌区 可达路径）；生成器保证恒为 true。
    public bool Connected
        => RandomMapGenerator.HasPath(Spec, RandomMapGenerator.ZoneCenter(Spec, PlayerZone), RandomMapGenerator.ZoneCenter(Spec, EnemyZone));
}
