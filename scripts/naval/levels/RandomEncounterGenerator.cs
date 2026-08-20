#nullable enable
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// U-2c（CHG-20260812-random-encounter-flow）随机遭遇战生成器（纯 C#，无 Godot 依赖）：
// 「随机遭遇战」= 伪随机拼装的一场合法可玩战斗，供关卡选择「随机遭遇战」入口直接开始。
//
// 地图三来源混合（掷 0-99）：
//   <40  固定方案  → MapSchemeRegistry.All（9 张含变体）任选，用其 Map/PlayerZone/EnemyZone；
//   <75  伪随机变体 → PseudoRandomVariant(baseScheme, seed, budget)：从基址两布阵区之间的深水格
//                     按地形预算撒新地形（浅滩/礁石/陆河可通行为主 80%，海滩/林地/草地/港口/小镇/山地陆地 20%），
//                     用 R-1 HasPath 连通性校验，重试 40 次失败则回退基址（布阵区/出口列绝不动）；
//   75+  R-1 随机地图 → RandomMapGenerator.Generate（难度/随机种子/含出口），用其 Spec/区。
//
// 敌人两来源（掷 0-99）：
//   <50  固定配置   → 按难度池选 EnemyFleetConfig + PlaceInEnemyZone 确定性放置；奖励 = 配置 Rewards；
//   50+  R-1 随机舰队 → RandomEnemyFleetGenerator.Generate（数量 2+难度+随机0-1、玩家强度匹配）；奖励 = 难度奖励表。
//
// 玩家舰队：默认 4 舰（flagship/frigate/transport/merchant）沿玩家区纵轴摆放在深水格（供布阵，
// 旗舰 1 火炮、护卫 1 砲击、其余空装），保证玩家恒可布阵且不越区。
//
// 种子化可复现：同 (Difficulty, Seed) → 完全同一场遭遇（地图/双方舰队/奖励/展示文本）。
// UI「重掷」= 同难度 Seed+101 重新生成；「再来一局」= 保留同一场重新布阵。
public sealed record RandomEncounterOptions(
    int Difficulty = 2,
    int Seed = 20260812,
    bool IncludeExits = true);

// 随机遭遇结果：地图 + 双方布阵区 + 双方舰队 + 奖励 + 展示文本 + 来源标注。Validate 自校验合法。
public sealed record RandomEncounter(
    string Id,
    int Difficulty,
    int Seed,
    string DisplayName,
    string Description,
    string MapSourceLabel,
    string EnemyLabel,
    LevelMapSpec Map,
    GridRect PlayerZone,
    GridRect EnemyZone,
    IReadOnlyList<LevelShipSpec> PlayerFleet,
    IReadOnlyList<LevelShipSpec> EnemyFleet,
    EnemyRewards Rewards,
    bool IsFixed = false) // V-4：固定测试关卡标记（隐藏「重掷换一场」）
{
    // 自校验：返回 null=合法，否则中文原因。
    // 校验项：布阵区界内 + 恒深水 + 玩家区在左 + 地图连通（区中心 BFS）+ 敌/玩家舰队占格合法
    //         （区内含船、无重叠、地形按舰型通过性可通行）+ 奖励非负。
    public string? Validate(NavalRulesConfig rules)
    {
        if (rules is null) throw new ArgumentNullException(nameof(rules));
        if (Map is null) return "遭遇地图为空";
        if (PlayerZone.Width <= 0 || PlayerZone.Height <= 0) return $"玩家区无效 {PlayerZone}";
        if (EnemyZone.Width <= 0 || EnemyZone.Height <= 0) return $"敌区无效 {EnemyZone}";
        if (PlayerZone.Right > EnemyZone.X) return $"玩家区 {PlayerZone} 与敌区 {EnemyZone} 重叠（玩家应在左）";
        foreach (var (name, zone) in new[] { ("玩家区", PlayerZone), ("敌区", EnemyZone) })
        {
            if (zone.X < 0 || zone.Y < 0 || zone.Right > Map.Width || zone.Bottom > Map.Height)
                return $"{name} {zone} 越界（地图 {Map.Width}×{Map.Height}）";
            for (var y = zone.Y; y < zone.Bottom; y++)
                for (var x = zone.X; x < zone.Right; x++)
                    if (Map.TerrainAt(x, y) != TerrainType.DeepWater)
                        return $"{name} 格 ({x},{y}) 应为深水，实际 {Map.TerrainAt(x, y)}";
        }
        var from = RandomMapGenerator.ZoneCenter(Map, PlayerZone);
        var to = RandomMapGenerator.ZoneCenter(Map, EnemyZone);
        if (!RandomMapGenerator.HasPath(Map, from, to)) return $"地图不连通：{from} → {to} 无可达路径";
        if (PlayerFleet is not { Count: > 0 }) return "玩家舰队为空";
        if (EnemyFleet is not { Count: > 0 }) return "敌舰队为空";
        if (FleetInZone(rules, PlayerFleet, PlayerZone) is { } perr) return perr;
        if (RandomEnemyFleetGenerator.Validate(EnemyFleet, rules, Map, EnemyZone) is { } eerr) return eerr;
        if (Rewards is null || Rewards.Gold < 0 || Rewards.Iron < 0 || Rewards.Wood < 0 || Rewards.Hemp < 0)
            return "奖励非负";
        return null;
    }

    // 玩家舰队占格校验（与 RandomEnemyFleetGenerator.Validate 同口径，但区为玩家区）。
    private string? FleetInZone(NavalRulesConfig rules, IReadOnlyList<LevelShipSpec> fleet, GridRect zone)
    {
        var occupied = new HashSet<GridPos>();
        foreach (var spec in fleet)
        {
            var def = rules.Ships.FirstOrDefault(s => s.Id == spec.ShipTypeId);
            if (def is null) return $"ships.json 缺少舰型 {spec.ShipTypeId}";
            foreach (var c in ShipGeometry.Footprint(def, spec.Bow, spec.Facing))
            {
                if (!Map.InBounds(c)) return $"玩家舰 {spec.ShipTypeId}@{spec.Bow} 占格 {c} 越界";
                if (!zone.Contains(c)) return $"玩家舰 {spec.ShipTypeId}@{spec.Bow} 占格 {c} 在玩家布阵区外";
                if (TerrainRules.BlocksShip(Map.TerrainAt(c), def.Passability))
                    return $"玩家舰 {spec.ShipTypeId}@{spec.Bow} 占格 {c} 不可通行（{Map.TerrainAt(c)}）";
                if (!occupied.Add(c)) return $"玩家舰 {spec.ShipTypeId}@{spec.Bow} 与其它舰占格 {c} 重叠";
            }
        }
        return null;
    }
}

// 跨场景会话：LevelSelect 生成后 Begin，NavalDemo 各控制器读取 Active/Pending。
// 随机遭遇不作为 LevelRegistry 关卡（LevelSession.EnterLevel("random") 仅置标记），
// 结算走自由模式 HUD 追加奖励行；返回主菜单时 LevelSelectController._Ready 调 Clear()。
public static class RandomEncounterSession
{
    public static RandomEncounter? Pending { get; private set; }
    public static bool Active => Pending is not null;
    public static void Begin(RandomEncounter encounter) => Pending = encounter ?? throw new ArgumentNullException(nameof(encounter));
    public static void Clear() => Pending = null;
}

public static class RandomEncounterGenerator
{
    public const int MinDifficulty = 1;
    public const int MaxDifficulty = 3;

    // V-4（测试关卡）：由 EncounterDefinition 固定配对组装一场可进入遭遇。地图/布阵区/敌方舰队/奖励
    // 全部来自配对（确定性、无随机种子）；玩家舰队同随机遭遇默认 4 舰。固定遭遇不提供重掷（IsFixed）。
    // 与随机遭遇同走 RandomEncounterSession 路径（关卡选择「测试关卡」章进入，复用布阵→战斗→结算）。
    public static RandomEncounter CreateFromDefinition(NavalRulesConfig config, EncounterDefinition definition)
    {
        if (config is null) throw new ArgumentNullException(nameof(config));
        if (definition is null) throw new ArgumentNullException(nameof(definition));
        var (scheme, enemy) = definition.Resolve();
        var enemyFleet = EnemyFleetConfig.PlaceInEnemyZone(enemy, config, scheme.Map, scheme.EnemyZone);
        var playerFleet = PlacePlayerFleet(config, scheme.PlayerZone);
        var encounter = new RandomEncounter(
            Id: definition.Id,
            Difficulty: 1,
            Seed: 0,
            DisplayName: definition.DisplayName,
            Description: definition.Description,
            MapSourceLabel: scheme.DisplayName,
            EnemyLabel: enemy.DisplayName,
            Map: scheme.Map,
            PlayerZone: scheme.PlayerZone,
            EnemyZone: scheme.EnemyZone,
            PlayerFleet: playerFleet,
            EnemyFleet: enemyFleet,
            Rewards: enemy.Rewards,
            IsFixed: true);
        var err = encounter.Validate(config);
        if (err is not null) throw new InvalidDataException($"测试关卡 {definition.Id} 组装非法：{err}");
        return encounter;
    }

    // 伪随机变体连通性重试上限；概率极低，最终回退基址仍保证可玩。
    private const int VariantAttempts = 40;

    // 玩家默认舰队（旗舰/护卫/运输/商船 4 舰；与自由模式 PlayerRoster 一致）。
    private static readonly string[] PlayerRoster = { "flagship", "frigate", "transport", "merchant" };

    // 难度 → 固定敌人配置池（按强度/复杂度递进）。
    private static readonly IReadOnlyDictionary<int, string[]> ConfigsByDifficulty =
        new Dictionary<int, string[]>
        {
            { 1, new[] { "skiff_harassment", "pirate_flotilla" } },
            { 2, new[] { "pirate_flotilla", "raider_squadron", "convoy_escort", "trade_route_patrol" } },
            { 3, new[] { "regular_navy", "elite_fleet", "raider_squadron" } },
        };

    // R-1 随机敌舰队奖励表（金/铁/木/麻）。
    private static readonly IReadOnlyDictionary<int, EnemyRewards> RewardsByDifficulty =
        new Dictionary<int, EnemyRewards>
        {
            { 1, new EnemyRewards(180, 15, 25, 12) },
            { 2, new EnemyRewards(420, 45, 40, 25) },
            { 3, new EnemyRewards(720, 95, 75, 50) },
        };

    // 伪随机变体撒入的可通行地形（浅滩/礁石/陆河为主）与陆地地形（海滩/林地/草地/港口/小镇/山地）。
    private static readonly char[] WaterChars = { '~', '~', '~', '~', '#', 'R' }; // 浅滩为主 + 礁石/陆河
    private static readonly char[] LandChars = { '^', 'B', 'F', 'G', 'P', 'T' };

    public static string DifficultyLabel(int difficulty) => difficulty switch
    {
        1 => "简单",
        2 => "普通",
        _ => "困难",
    };

    // 生成一场随机遭遇：全链路 SeedRandomSource(options.Seed) 种子化，同种子可复现。
    public static RandomEncounter Generate(NavalRulesConfig config, RandomEncounterOptions options)
    {
        if (config is null) throw new ArgumentNullException(nameof(config));
        if (options is null) throw new ArgumentNullException(nameof(options));
        ValidateOptions(options);
        var rng = new SeedRandomSource(options.Seed);

        // —— 地图三来源 ——
        var mapRoll = rng.NextInt(0, 100);
        LevelMapSpec map;
        GridRect playerZone;
        GridRect enemyZone;
        string mapLabel;
        if (mapRoll < 40)
        {
            var scheme = PickScheme(rng);
            map = scheme.Map; playerZone = scheme.PlayerZone; enemyZone = scheme.EnemyZone;
            mapLabel = scheme.DisplayName;
        }
        else if (mapRoll < 75)
        {
            var baseScheme = PickScheme(rng);
            var budget = 3 + options.Difficulty + rng.NextInt(0, 3);
            var variant = PseudoRandomVariant(baseScheme, NextSubSeed(rng), budget);
            map = variant ?? baseScheme.Map;
            playerZone = baseScheme.PlayerZone; enemyZone = baseScheme.EnemyZone;
            mapLabel = variant is null ? baseScheme.DisplayName : $"{baseScheme.DisplayName}·变体";
        }
        else
        {
            var rr = new RandomMapGenerator().Generate(new RandomMapOptions(
                Difficulty: options.Difficulty, Seed: NextSubSeed(rng), IncludeExits: options.IncludeExits));
            map = rr.Spec; playerZone = rr.PlayerZone; enemyZone = rr.EnemyZone;
            mapLabel = "随机海域";
        }

        // —— 玩家舰队（默认 4 舰，玩家区深水内，供布阵） ——
        var playerFleet = PlacePlayerFleet(config, playerZone);

        // —— 敌人两来源 ——
        var enemyRoll = rng.NextInt(0, 100);
        IReadOnlyList<LevelShipSpec> enemyFleet;
        EnemyRewards rewards;
        string enemyLabel;
        if (enemyRoll < 50)
        {
            var cfg = PickConfigByDifficulty(rng, options.Difficulty);
            enemyFleet = EnemyFleetConfig.PlaceInEnemyZone(cfg, config, map, enemyZone);
            rewards = cfg.Rewards;
            enemyLabel = cfg.DisplayName;
        }
        else
        {
            var count = 2 + options.Difficulty + rng.NextInt(0, 2);
            enemyFleet = RandomEnemyFleetGenerator.Generate(config,
                new RandomEnemyFleetOptions(options.Difficulty, count, NextSubSeed(rng), playerFleet),
                map, enemyZone);
            rewards = RewardsByDifficulty[options.Difficulty];
            enemyLabel = $"随机舰队·{DifficultyLabel(options.Difficulty)}";
        }

        var difficultyLabel = DifficultyLabel(options.Difficulty);
        var encounter = new RandomEncounter(
            Id: $"random-{options.Difficulty}-{options.Seed}",
            Difficulty: options.Difficulty,
            Seed: options.Seed,
            DisplayName: $"随机遭遇战 · {difficultyLabel}",
            Description: $"伪随机生成的一场遭遇战（难度 {difficultyLabel}）· 目标：歼灭全部敌舰",
            MapSourceLabel: mapLabel,
            EnemyLabel: enemyLabel,
            Map: map,
            PlayerZone: playerZone,
            EnemyZone: enemyZone,
            PlayerFleet: playerFleet,
            EnemyFleet: enemyFleet,
            Rewards: rewards);
        var err = encounter.Validate(config);
        if (err is not null) throw new InvalidDataException($"随机遭遇生成非法：{err}");
        return encounter;
    }

    // 伪随机变体：从基址两布阵区之间的深水格撒入预算块新地形（可通行为主 + 少量陆地），
    // 保持玩家区/敌区/出口列不动；连通（HasPath）则采用，重试 VariantAttempts 次失败返回 null（调用方回退基址）。
    public static LevelMapSpec? PseudoRandomVariant(MapScheme baseScheme, int seed, int terrainBudget)
    {
        if (baseScheme is null) throw new ArgumentNullException(nameof(baseScheme));
        var playerZone = baseScheme.PlayerZone;
        var enemyZone = baseScheme.EnemyZone;
        var w = baseScheme.Map.Width;
        var h = baseScheme.Map.Height;

        // 候选格 = 玩家区右界与敌区左界之间的深水格（只动中央交战区，不动布阵区/出口列）。
        var candidates = new List<GridPos>();
        for (var y = 0; y < h; y++)
            for (var x = playerZone.Right; x < enemyZone.X; x++)
                if (baseScheme.Map.TerrainAt(x, y) == TerrainType.DeepWater)
                    candidates.Add(new GridPos(x, y));
        if (candidates.Count == 0) return null; // 无深水可撒（不应发生，调用方回退基址）

        var budget = Math.Min(Math.Max(1, terrainBudget), candidates.Count);
        for (var attempt = 0; attempt < VariantAttempts; attempt++)
        {
            var rng = new SeedRandomSource(seed + attempt * 100003);
            var rows = baseScheme.Map.TerrainRows.Select(r => r.ToCharArray()).ToArray();
            var shuffled = candidates.OrderBy(_ => rng.NextDouble()).ToList();
            // 撒地形：以可通行地形为主（80%），陆地（不可通行）为辅；陆地若切断通路由 HasPath 重试兜底。
            for (var i = 0; i < budget; i++)
            {
                var c = shuffled[i];
                var isLand = rng.NextInt(0, 5) == 0;
                rows[c.Y][c.X] = isLand
                    ? LandChars[rng.NextInt(0, LandChars.Length)]
                    : WaterChars[rng.NextInt(0, WaterChars.Length)];
            }
            var spec = LevelMapSpec.FromAscii(rows.Select(r => new string(r)).ToArray());
            if (RandomMapGenerator.HasPath(spec,
                RandomMapGenerator.ZoneCenter(spec, playerZone),
                RandomMapGenerator.ZoneCenter(spec, enemyZone)))
                return spec;
        }
        return null; // 重试仍不连通 → 调用方回退基址（保证可玩）
    }

    // —— 内部实现 ——

    private static void ValidateOptions(RandomEncounterOptions o)
    {
        if (o.Difficulty < MinDifficulty || o.Difficulty > MaxDifficulty)
            throw new ArgumentOutOfRangeException(nameof(o), $"难度须在 {MinDifficulty}-{MaxDifficulty}（实际 {o.Difficulty}）");
    }

    private static MapScheme PickScheme(IRandomSource rng)
    {
        var all = MapSchemeRegistry.All;
        return all[rng.NextInt(0, all.Count)];
    }

    private static EnemyFleetConfig PickConfigByDifficulty(IRandomSource rng, int difficulty)
    {
        var pool = ConfigsByDifficulty[difficulty];
        var id = pool[rng.NextInt(0, pool.Length)];
        return EnemyFleetConfigRegistry.GetById(id)!
            ?? throw new InvalidDataException($"敌人配置 {id} 未注册（难度池 {difficulty}）");
    }

    // 子种子：取 0..int.MaxValue-1（SeedRandomSource 的 maxExclusive 语义，避免负种子歧义）。
    private static int NextSubSeed(IRandomSource rng) => rng.NextInt(0, int.MaxValue);

    // 玩家默认舰队：旗舰/护卫/运输/商船沿玩家区纵轴按舰长摆放在深水格（船头朝东、舰体在区内）。
    private static IReadOnlyList<LevelShipSpec> PlacePlayerFleet(NavalRulesConfig config, GridRect zone)
    {
        var result = new List<LevelShipSpec>(PlayerRoster.Length);
        var usedRows = new HashSet<int>();
        var rowStep = Math.Max(1, zone.Height / (PlayerRoster.Length + 1));
        var row = zone.Y + rowStep;
        foreach (var id in PlayerRoster)
        {
            if (row >= zone.Bottom) break;
            while (usedRows.Contains(row)) row++;
            if (row >= zone.Bottom) break;
            var def = config.Ships.FirstOrDefault(s => s.Id == id);
            if (def is null) continue; // ships.json 缺舰型 → 跳过（校验层/部署层会再暴露）
            usedRows.Add(row);
            var bow = new GridPos(Math.Min(zone.Right - 1, zone.X + def.Length - 1), row);
            result.Add(new LevelShipSpec(id, bow, CardinalDirection.East, DefaultEquipmentFor(id)));
            row += rowStep;
        }
        return result;
    }

    // 玩家舰默认装备：旗舰 1 火炮、护卫 1 砲击；运输/商船空装（与自由模式 DefaultWeaponEquip 同款）。
    private static LevelEquipmentSpec? DefaultEquipmentFor(string id) => id switch
    {
        "flagship" => new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["cannon"] = 1 }),
        "frigate" => new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["bombardment"] = 1 }),
        _ => null,
    };
}
