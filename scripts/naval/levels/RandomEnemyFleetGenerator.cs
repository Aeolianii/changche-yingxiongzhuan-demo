#nullable enable
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// R-1 随机敌舰队配置生成器（纯 C#，无 Godot 依赖）：按难度(1-3)/数量/种子在敌方布阵区内生成合法敌舰队。
//
// 难度映射：
//   diff1 以运输/商船为主（运输 40 / 商船 30 / 护卫 20 / 旗舰 10），装备稀疏（武器概率 35%、无护甲加成、技能≈无）。
//   diff2 混合、护卫增多（运输 25 / 商船 20 / 护卫 40 / 旗舰 15），装备中等（武器概率 60%、护甲 20% +1、技能 30% 1 位）。
//   diff3 以护卫/旗舰为主（运输 10 / 商船 5 / 护卫 50 / 旗舰 35），装备精良（武器概率 90%、护甲 40% +1..2、技能 60% 1-2 位）。
//   可选玩家舰队强度匹配：PlayerFleet 给定 → 装备慷慨度按 玩家强度×难度系数 / 己方基础强度 缩放（钳制 0.5-2.0）。
//
// 合法保证（与 ValidatePlacement 同口径）：
//   占格不重叠、在地图内、在敌方布阵区内、地形按舰型通过性可通行（DeepWaterOnly 不可进浅滩/礁石）；
//   装备不超武器位/技能位/撞角上限(MaxCount)；载重为软约束（超载仅降速，与游戏口径一致，不判非法）。
//   随机放置失败回退逐行首次适配（敌方区深水 → 恒可放置）；数量超出布阵区容量抛 InvalidDataException。
// 种子化可复现：同 seed（同地图/区）→ 同舰队序列与朝向。
public static class RandomEnemyFleetGenerator
{
    public const int MinDifficulty = 1;
    public const int MaxDifficulty = 3;

    // 随机放置尝试次数；之后回退逐行首次适配（确定性、恒成功）。
    private const int RandomPlacementAttempts = 512;

    // 难度 → 舰型池（舰型 id, 权重）。权重越大越常见。
    private static readonly IReadOnlyDictionary<int, (string Id, int Weight)[]> PoolByDifficulty =
        new Dictionary<int, (string, int)[]>
        {
            { 1, new[] { ("transport", 40), ("merchant", 30), ("frigate", 20), ("flagship", 10) } },
            { 2, new[] { ("transport", 25), ("merchant", 20), ("frigate", 40), ("flagship", 15) } },
            { 3, new[] { ("transport", 10), ("merchant", 5), ("frigate", 50), ("flagship", 35) } },
        };

    // 生成敌舰队。config 提供舰型/装备定义；map + enemyZone 提供放置区域。
    public static IReadOnlyList<LevelShipSpec> Generate(
        NavalRulesConfig config,
        RandomEnemyFleetOptions options,
        LevelMapSpec map,
        GridRect enemyZone)
    {
        ValidateInputs(config, options, map, enemyZone);
        var rng = new SeedRandomSource(options.Seed);
        var pool = PoolByDifficulty[options.Difficulty];

        // 装备慷慨度：玩家强度匹配（可选）。玩家越强 → 敌方装备越慷慨（钳制 0.5-2.0）。
        var generosity = ComputeGenerosity(config, options, pool);

        var fleet = new List<LevelShipSpec>(options.Count);
        var occupied = new HashSet<GridPos>();
        for (var i = 0; i < options.Count; i++)
        {
            var shipDef = PickShipType(config, rng, pool);
            var spec = PlaceOne(config, shipDef, options, map, enemyZone, rng, occupied, generosity);
            fleet.Add(spec);
        }
        return fleet;
    }

    // 自校验：返回 null=合法，否则返回中文原因。供测试与调用方验证生成结果。
    public static string? Validate(
        IReadOnlyList<LevelShipSpec> fleet,
        NavalRulesConfig config,
        LevelMapSpec map,
        GridRect enemyZone)
    {
        var occupied = new HashSet<GridPos>();
        foreach (var spec in fleet)
        {
            var def = config.Ships.FirstOrDefault(s => s.Id == spec.ShipTypeId);
            if (def is null) return $"ships.json 缺少舰型 {spec.ShipTypeId}";
            for (var i = 0; i < def.Length; i++)
            {
                var c = spec.Bow - spec.Facing.Vector() * i;
                if (!map.InBounds(c)) return $"{spec.ShipTypeId}@{spec.Bow}/{spec.Facing} 占格 {c} 越界";
                if (!enemyZone.Contains(c)) return $"{spec.ShipTypeId}@{spec.Bow} 占格 {c} 在敌布阵区外";
                var t = map.TerrainAt(c);
                // U-2a：陆地恒不可通行；深水限定舰不可进浅水（浅滩/礁石/陆河），经 TerrainRules 统一判定。
                if (TerrainRules.BlocksShip(t, def.Passability))
                    return $"{spec.ShipTypeId}@{spec.Bow} 占格 {c} 不可通行（{t}）";
                if (!occupied.Add(c)) return $"{spec.ShipTypeId}@{spec.Bow} 与其它舰占格 {c} 重叠";
            }
            var equipErr = ValidateEquipment(spec, def, config);
            if (equipErr is not null) return equipErr;
        }
        return null;
    }

    // 舰型强度（组合战斗力）：近战+远程+生命折算；旗舰 > 护卫 > 商船 > 运输（强度对比用）。
    public static int ShipStrength(ShipDefinition def)
        => def.ArrowRainDamage + def.BoardingDamage + def.MaxHp / 10;

    public static int FleetStrength(IReadOnlyList<LevelShipSpec> fleet, NavalRulesConfig config)
        => fleet.Sum(s => config.Ships.FirstOrDefault(d => d.Id == s.ShipTypeId) is { } d ? ShipStrength(d) : 0);

    // 单舰载重（护甲 + 武器；与 WeatherRules.CurrentLoad 同口径：护甲 + 撞角1件3 + 砲击3/件 + 火炮4/件）。
    public static int LoadOf(LevelShipSpec spec, NavalRulesConfig config)
    {
        var def = config.Ships.FirstOrDefault(s => s.Id == spec.ShipTypeId);
        if (def is null) return 0;
        var armor = spec.Equipment?.ArmorLevel ?? def.BaseArmor;
        var rams = spec.Equipment?.Weapons?.GetValueOrDefault("ram", 0) ?? 0;
        var bombardments = spec.Equipment?.Weapons?.GetValueOrDefault("bombardment", 0) ?? 0;
        var cannons = spec.Equipment?.Weapons?.GetValueOrDefault("cannon", 0) ?? 0;
        return DamageRules.TotalLoad(0, armor, rams > 0 ? 1 : 0, bombardments, cannons);
    }

    public static int TotalLoad(IReadOnlyList<LevelShipSpec> fleet, NavalRulesConfig config)
        => fleet.Sum(s => LoadOf(s, config));

    // —— 内部实现 ——

    private static void ValidateInputs(NavalRulesConfig config, RandomEnemyFleetOptions options, LevelMapSpec map, GridRect enemyZone)
    {
        if (config is null) throw new ArgumentNullException(nameof(config));
        if (config.Ships.Count == 0) throw new InvalidDataException("ships.json 为空，无法生成敌舰队");
        if (options is null) throw new ArgumentNullException(nameof(options));
        if (options.Difficulty < MinDifficulty || options.Difficulty > MaxDifficulty)
            throw new ArgumentOutOfRangeException(nameof(options), $"难度须在 {MinDifficulty}-{MaxDifficulty}（实际 {options.Difficulty}）");
        if (options.Count < 1)
            throw new ArgumentOutOfRangeException(nameof(options), $"数量须 ≥1（实际 {options.Count}）");
        if (map is null) throw new ArgumentNullException(nameof(map));
        if (enemyZone.Width <= 0 || enemyZone.Height <= 0)
            throw new ArgumentOutOfRangeException(nameof(enemyZone), $"敌布阵区无效 {enemyZone}");
    }

    // 玩家强度匹配 → 装备慷慨度。无玩家舰队时 =1（按难度固有强度）。
    private static double ComputeGenerosity(NavalRulesConfig config, RandomEnemyFleetOptions options, (string Id, int Weight)[] pool)
    {
        if (options.PlayerFleet is not { Count: > 0 } playerFleet) return 1.0;
        var playerStrength = FleetStrength(playerFleet, config);
        // 期望敌方强度 = 玩家强度 × 难度系数（diff1 弱 0.6 / diff2 相当 0.9 / diff3 略强 1.3）。
        var target = playerStrength * options.Difficulty switch { 1 => 0.6, 2 => 0.9, _ => 1.3 };
        // 基础强度 = 池加权平均单舰强度 × 数量（与真实抽舰口径一致，避免整池总和虚高使慷慨度恒触下限）。
        var baseStrength = WeightedAvgStrength(config, pool) * options.Count;
        if (baseStrength <= 0) return 1.0;
        return Math.Clamp(target / baseStrength, 0.5, 2.0);
    }

    // 池加权平均单舰强度：Σ(权重 × 舰型强度) / Σ权重。
    private static double WeightedAvgStrength(NavalRulesConfig config, (string Id, int Weight)[] pool)
    {
        var weightSum = 0; var strengthSum = 0;
        foreach (var (id, weight) in pool)
        {
            var def = config.Ships.FirstOrDefault(s => s.Id == id);
            if (def is null) continue;
            weightSum += weight;
            strengthSum += weight * ShipStrength(def);
        }
        return weightSum == 0 ? 0 : (double)strengthSum / weightSum;
    }

    // 加权随机选舰型（权重池）。
    private static ShipDefinition PickShipType(NavalRulesConfig config, IRandomSource rng, (string Id, int Weight)[] pool)
    {
        var total = pool.Sum(p => p.Weight);
        var roll = rng.NextInt(0, total);
        foreach (var (id, weight) in pool)
        {
            if (roll < weight)
                return config.Ships.First(s => s.Id == id);
            roll -= weight;
        }
        return config.Ships[0];
    }

    // 放置单舰：随机尝试（随机朝向+随机船头）失败后回退逐行首次适配。
    private static LevelShipSpec PlaceOne(
        NavalRulesConfig config,
        ShipDefinition def,
        RandomEnemyFleetOptions options,
        LevelMapSpec map,
        GridRect enemyZone,
        IRandomSource rng,
        HashSet<GridPos> occupied,
        double generosity)
    {
        var facings = new[] { CardinalDirection.North, CardinalDirection.East, CardinalDirection.South, CardinalDirection.West };
        for (var attempt = 0; attempt < RandomPlacementAttempts; attempt++)
        {
            var facing = facings[rng.NextInt(0, facings.Length)];
            var bow = new GridPos(
                enemyZone.X + rng.NextInt(0, enemyZone.Width),
                enemyZone.Y + rng.NextInt(0, enemyZone.Height));
            if (LegalPlacement(map, def, bow, facing, enemyZone, occupied))
            {
                AddFootprint(occupied, def, bow, facing);
                return BuildSpec(config, def, options.Difficulty, rng, generosity, bow, facing);
            }
        }
        // 回退：逐行扫描首次适配（船头放在该格，朝向枚举 West/East/North/South）。
        foreach (var facing in facings)
            for (var y = enemyZone.Y; y < enemyZone.Bottom; y++)
                for (var x = enemyZone.X; x < enemyZone.Right; x++)
                {
                    var bow = new GridPos(x, y);
                    if (LegalPlacement(map, def, bow, facing, enemyZone, occupied))
                    {
                        AddFootprint(occupied, def, bow, facing);
                        return BuildSpec(config, def, options.Difficulty, rng, generosity, bow, facing);
                    }
                }
        throw new InvalidDataException($"敌舰队数量 {options.Count} 超出敌方布阵区 {enemyZone} 容量");
    }

    private static bool LegalPlacement(
        LevelMapSpec map, ShipDefinition def, GridPos bow, CardinalDirection facing, GridRect enemyZone, HashSet<GridPos> occupied)
    {
        for (var i = 0; i < def.Length; i++)
        {
            var c = bow - facing.Vector() * i;
            if (!map.InBounds(c)) return false;
            if (!enemyZone.Contains(c)) return false;
            var t = map.TerrainAt(c);
            // U-2a：陆地恒不可通行；深水限定舰不可进浅水（浅滩/礁石/陆河），经 TerrainRules 统一判定。
            if (TerrainRules.BlocksShip(t, def.Passability)) return false;
            if (occupied.Contains(c)) return false;
        }
        return true;
    }

    // 构造 LevelShipSpec + 按难度/慷慨度随机装备（不超武器位/技能位/撞角上限/载重上限）。
    private static LevelShipSpec BuildSpec(
        NavalRulesConfig config, ShipDefinition def, int difficulty, IRandomSource rng, double generosity,
        GridPos bow, CardinalDirection facing)
    {
        var weapons = new Dictionary<string, int>();
        var weaponChance = difficulty switch { 1 => 0.35, 2 => 0.60, _ => 0.90 } * generosity;
        if (rng.NextDouble() < Math.Min(1.0, weaponChance))
        {
            var maxWeapons = difficulty switch { 1 => 1, 2 => 2, _ => 3 };
            maxWeapons = Math.Min(maxWeapons, def.WeaponSlots);
            for (var i = 0; i < maxWeapons; i++)
            {
                var wid = PickWeapon(rng, difficulty);
                var wDef = config.Weapons.FirstOrDefault(w => w.Id == wid);
                if (wDef is null) continue;
                if (wDef.MaxCount is { } mc && weapons.GetValueOrDefault(wid) >= mc) continue; // 撞角限 1 件
                weapons[wid] = weapons.GetValueOrDefault(wid) + 1;
            }
        }

        // 护甲：难度1 无加成；难度2 20% +1；难度3 40% +1..2（上限 BaseArmor+ArmorSlots）。
        int? armorLevel = null;
        var armorChance = difficulty switch { 1 => 0.0, 2 => 0.20, _ => 0.40 } * generosity;
        if (rng.NextDouble() < Math.Min(1.0, armorChance))
        {
            var bonus = difficulty switch { 1 => 0, 2 => 1, _ => 1 + rng.NextInt(0, 2) };
            armorLevel = Math.Min(def.BaseArmor + def.ArmorSlots, def.BaseArmor + bonus);
        }

        // 载重是软约束（超载仅降速，不非法——旗舰默认 1 火炮即超载 7>5，与游戏口径一致），故不裁剪；
        // 武器数只受武器位/撞角上限约束。LoadOf/TotalLoad 仅作强度对比度量。

        // 技能：难度1 约无；难度2 30% 1 位；难度3 60% 1-2 位（不超技能位）。
        var skills = new Dictionary<string, int>();
        var skillChance = difficulty switch { 1 => 0.05, 2 => 0.30, _ => 0.60 } * generosity;
        if (rng.NextDouble() < Math.Min(1.0, skillChance))
        {
            var maxSkills = difficulty switch { 1 => 0, 2 => 1, _ => 2 };
            maxSkills = Math.Min(maxSkills, def.SkillSlots);
            for (var i = 0; i < maxSkills; i++)
            {
                var sid = PickSkill(rng, difficulty);
                skills[sid] = skills.GetValueOrDefault(sid) + 1;
            }
        }

        return new LevelShipSpec(def.Id, bow, facing, ToEquipment(weapons, skills, armorLevel));
    }

    private static string PickWeapon(IRandomSource rng, int difficulty)
    {
        // diff1 偏砲击；diff2 混合；diff3 偏火炮/砲击。撞角留给低难度偶尔一装。
        return difficulty switch
        {
            1 => rng.NextInt(0, 4) == 0 ? "cannon" : "bombardment",
            2 => rng.NextInt(0, 3) switch { 0 => "cannon", 1 => "ram", _ => "bombardment" },
            _ => rng.NextInt(0, 3) switch { 0 => "bombardment", _ => "cannon" },
        };
    }

    private static string PickSkill(IRandomSource rng, int difficulty)
    {
        return difficulty switch
        {
            1 => "damage_control",
            2 => rng.NextInt(0, 2) == 0 ? "chain_shot" : "damage_control",
            _ => rng.NextInt(0, 4) switch { 0 => "mine", 1 => "fire_oil", 2 => "chain_shot", _ => "damage_control" },
        };
    }

    private static LevelEquipmentSpec? ToEquipment(Dictionary<string, int> weapons, Dictionary<string, int>? skills, int? armorLevel)
    {
        if (weapons.Count == 0 && (skills is null || skills.Count == 0) && armorLevel is null) return null;
        return new LevelEquipmentSpec(weapons, skills, armorLevel);
    }

    private static string? ValidateEquipment(LevelShipSpec spec, ShipDefinition def, NavalRulesConfig config)
    {
        if (spec.Equipment is null) return null;
        var weapons = spec.Equipment.Weapons;
        if (weapons is { Count: > 0 })
        {
            if (weapons.Values.Sum() > def.WeaponSlots) return $"{def.Id} 武器位 {weapons.Values.Sum()} 超上限 {def.WeaponSlots}";
            foreach (var (wid, count) in weapons)
            {
                var wDef = config.Weapons.FirstOrDefault(w => w.Id == wid);
                if (wDef is null) return $"{def.Id} 装备未知武器 {wid}";
                if (wDef.MaxCount is { } mc && count > mc) return $"{def.Id} {wid} 超上限 {mc}";
            }
        }
        if (spec.Equipment.Skills is { Count: > 0 } skills && skills.Values.Sum() > def.SkillSlots)
            return $"{def.Id} 技能位 {skills.Values.Sum()} 超上限 {def.SkillSlots}";
        if (spec.Equipment.ArmorLevel is { } armor)
        {
            if (armor < 0 || armor > def.BaseArmor + def.ArmorSlots)
                return $"{def.Id} 护甲 {armor} 越界（0-{def.BaseArmor + def.ArmorSlots}）";
        }
        // 载重是软约束（超载仅降速），不判非法；LoadOf 仅作强度对比度量。
        return null;
    }

    // 把已放置舰的占格（船头朝向后延伸 def.Length 格）并入 occupied，供后续舰重叠校验。
    private static void AddFootprint(HashSet<GridPos> occupied, ShipDefinition def, GridPos bow, CardinalDirection facing)
    {
        for (var i = 0; i < def.Length; i++)
            occupied.Add(bow - facing.Vector() * i);
    }
}

// R-1 随机敌舰队参数。Difficulty 1-3；Count 数量；Seed 种子（可复现）；
// PlayerFleet 可选玩家舰队（用于强度匹配：玩家越强敌方装备越慷慨）。
public sealed record RandomEnemyFleetOptions(
    int Difficulty,
    int Count,
    int Seed,
    IReadOnlyList<LevelShipSpec>? PlayerFleet = null);
