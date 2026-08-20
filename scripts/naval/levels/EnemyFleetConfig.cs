#nullable enable
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// U-2a/U-2b 差异化敌人配置（纯数据层，无 Godot 依赖）：
// 每套配置 = 策略标注 + 舰队构成（模板列表，按舰型槽位装载武器/技能/护甲）+ 奖励占位。
// 策略（Aggressive 进攻型 / Defensive 防守型 / Retreating 逃跑型）本阶段仅作枚举标注，
// 规则层 NavalAi 默认行为不变（阶段三再按策略差异化 AI）。
// U-2b 新增：7 套配置（3 套新） + EncounterDefinition「地图方案 × 敌人配置」配对（见本文件尾部）。
public enum EnemyStrategy { Aggressive, Defensive, Retreating }

// 奖励占位：金/铁/木/麻 + 讨伐专属宝物（可选）。
public sealed record EnemyRewards(int Gold, int Iron, int Wood, int Hemp, IReadOnlyList<TreasureId>? Treasures = null);

// 舰队模板：舰型 + 数量 + 装备（按该舰型槽位装载；null=无装备）。
public sealed record EnemyShipTemplate(string ShipTypeId, int Count, LevelEquipmentSpec? Equipment = null);

public sealed record EnemyFleetConfig(
    string Id,
    string DisplayName,
    string Description,
    EnemyStrategy Strategy,
    IReadOnlyList<EnemyShipTemplate> Fleet,
    EnemyRewards Rewards)
{
    // 确定性逐舰放置：按模板顺序，每舰在敌布阵区行优先扫描首个合法位（船头朝向枚举 West/North/East/South）。
    // 合法 = 占格界内/区内/地形按舰型通过性可通行（TerrainRules.BlocksShip）+ 与已放舰不重叠。
    // 舰型不存在于 rules 时抛 InvalidDataException（配置错误，尽早暴露）。
    public static IReadOnlyList<LevelShipSpec> PlaceInEnemyZone(
        EnemyFleetConfig config, NavalRulesConfig rules, LevelMapSpec map, GridRect enemyZone)
    {
        if (config is null) throw new ArgumentNullException(nameof(config));
        if (rules is null) throw new ArgumentNullException(nameof(rules));
        if (map is null) throw new ArgumentNullException(nameof(map));
        if (enemyZone.Width <= 0 || enemyZone.Height <= 0)
            throw new ArgumentOutOfRangeException(nameof(enemyZone), $"敌布阵区无效 {enemyZone}");

        var result = new List<LevelShipSpec>();
        var occupied = new HashSet<GridPos>();
        var facings = new[]
        {
            CardinalDirection.West, CardinalDirection.North,
            CardinalDirection.East, CardinalDirection.South,
        };
        foreach (var template in config.Fleet)
        {
            var def = rules.Ships.FirstOrDefault(s => s.Id == template.ShipTypeId)
                ?? throw new InvalidDataException($"ships.json 缺少舰型 {template.ShipTypeId}（配置 {config.Id}）");
            for (var n = 0; n < template.Count; n++)
            {
                var placed = false;
                foreach (var facing in facings)
                    for (var y = enemyZone.Y; y < enemyZone.Bottom && !placed; y++)
                        for (var x = enemyZone.X; x < enemyZone.Right && !placed; x++)
                        {
                            var bow = new GridPos(x, y);
                            if (!LegalPlacement(map, def, bow, facing, enemyZone, occupied)) continue;
                            occupied.UnionWith(Footprint(def, bow, facing));
                            result.Add(new LevelShipSpec(def.Id, bow, facing, template.Equipment));
                            placed = true;
                        }
                if (!placed)
                    throw new InvalidDataException($"敌舰队 {config.Id} 数量超出布阵区 {enemyZone} 容量");
            }
        }
        return result;
    }

    // 自校验：返回 null=合法，否则中文原因。
    // 校验项：舰队非空、各模板数量 ≥1、舰型存在、装备不超武器位/技能位/护甲上限、奖励非负。
    public string? Validate(NavalRulesConfig rules)
    {
        if (rules is null) throw new ArgumentNullException(nameof(rules));
        if (Fleet is not { Count: > 0 }) return $"配置 {Id} 舰队为空";
        if (Rewards is null || Rewards.Gold < 0 || Rewards.Iron < 0 || Rewards.Wood < 0 || Rewards.Hemp < 0)
            return $"配置 {Id} 奖励占位非负";
        foreach (var template in Fleet)
        {
            if (template.Count < 1) return $"配置 {Id} 模板 {template.ShipTypeId} 数量须 ≥1（实际 {template.Count}）";
            var def = rules.Ships.FirstOrDefault(s => s.Id == template.ShipTypeId);
            if (def is null) return $"ships.json 缺少舰型 {template.ShipTypeId}（配置 {Id}）";
            var equip = template.Equipment;
            if (equip is null) continue;
            if (equip.Weapons is { Count: > 0 })
            {
                if (equip.Weapons.Values.Sum() > def.WeaponSlots)
                    return $"配置 {Id} {def.Id} 武器位 {equip.Weapons.Values.Sum()} 超上限 {def.WeaponSlots}";
                foreach (var (wid, count) in equip.Weapons)
                {
                    var wDef = rules.Weapons.FirstOrDefault(w => w.Id == wid);
                    if (wDef is null) return $"配置 {Id} {def.Id} 装备未知武器 {wid}";
                    if (wDef.MaxCount is { } mc && count > mc) return $"配置 {Id} {def.Id} {wid} 超上限 {mc}";
                }
            }
            if (equip.Skills is { Count: > 0 } skills && skills.Values.Sum() > def.SkillSlots)
                return $"配置 {Id} {def.Id} 技能位 {skills.Values.Sum()} 超上限 {def.SkillSlots}";
            if (equip.ArmorLevel is { } armor && (armor < 0 || armor > def.BaseArmor + def.ArmorSlots))
                return $"配置 {Id} {def.Id} 护甲 {armor} 越界（0-{def.BaseArmor + def.ArmorSlots}）";
        }
        return null;
    }

    // —— 内部实现 ——

    private static bool LegalPlacement(
        LevelMapSpec map, ShipDefinition def, GridPos bow, CardinalDirection facing, GridRect enemyZone, HashSet<GridPos> occupied)
    {
        foreach (var c in Footprint(def, bow, facing))
        {
            if (!map.InBounds(c)) return false;
            if (!enemyZone.Contains(c)) return false;
            if (TerrainRules.BlocksShip(map.TerrainAt(c), def.Passability)) return false;
            if (occupied.Contains(c)) return false;
        }
        return true;
    }

    // 舰船占格：委托 ShipGeometry（Width>1 矩形占格；Width=1 与旧线性一致，索引0=船头）。
    private static IEnumerable<GridPos> Footprint(ShipDefinition def, GridPos bow, CardinalDirection facing)
        => ShipGeometry.Footprint(def, bow, facing);
}

// U-2a/U-2b 敌人配置注册表：7 套差异化配置（策略/构成/装备/奖励各不相同），纯数据交付（不接入流程）。
// 配置规则（策略↔舰队↔装备↔奖励映射）见 docs/design/map-design-rules.md。
public static class EnemyFleetConfigRegistry
{
    public static IReadOnlyList<EnemyFleetConfig> All { get; } = BuildAll();

    public static EnemyFleetConfig? GetById(string id) => All.FirstOrDefault(c => c.Id == id);

    private static IReadOnlyList<EnemyFleetConfig> BuildAll() => new[]
    {
        // 海盗小船队：逃跑型——船多血脆、装备稀疏，撞见商队撒腿就跑（奖励薄）。
        new EnemyFleetConfig(
            Id: "pirate_flotilla",
            DisplayName: "海盗小船队",
            Description: "一群亡命海盗凑起来的杂牌小船，装备稀疏、一遇强敌便四散逃窜。",
            Strategy: EnemyStrategy.Retreating,
            Fleet: new[]
            {
                new EnemyShipTemplate("transport", 2),
                new EnemyShipTemplate("merchant", 2),
                new EnemyShipTemplate("frigate", 1, new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["cannon"] = 1 })),
            },
            Rewards: new EnemyRewards(Gold: 200, Iron: 20, Wood: 30, Hemp: 15)),

        // 破袭舰队：进攻型——护卫为主、带劫掠商船，火炮砲击齐备，主动贴近抢攻（奖励较厚）。
        new EnemyFleetConfig(
            Id: "raider_squadron",
            DisplayName: "破袭舰队",
            Description: "专职袭扰商路的快舰编队，火力铺满、主动贴近抢攻，抢了就跑。",
            Strategy: EnemyStrategy.Aggressive,
            Fleet: new[]
            {
                new EnemyShipTemplate("frigate", 2, new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["cannon"] = 1 })),
                new EnemyShipTemplate("merchant", 1, new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["bombardment"] = 1 })),
                new EnemyShipTemplate("merchant", 1),
            },
            Rewards: new EnemyRewards(Gold: 350, Iron: 40, Wood: 25, Hemp: 20)),

        // 正规水师：防守型——旗舰坐镇、护卫成阵，火炮+连锁弹、砲击+损管齐备，依托阵型稳守（奖励丰厚）。
        new EnemyFleetConfig(
            Id: "regular_navy",
            DisplayName: "正规水师",
            Description: "朝廷正规水师，旗舰坐镇、护卫列阵，火力与损管齐备，依托阵型稳扎稳打。",
            Strategy: EnemyStrategy.Defensive,
            Fleet: new[]
            {
                new EnemyShipTemplate("flagship", 1, new LevelEquipmentSpec(
                    Weapons: new Dictionary<string, int> { ["cannon"] = 1 },
                    Skills: new Dictionary<string, int> { ["chain_shot"] = 1 })),
                new EnemyShipTemplate("frigate", 2, new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["bombardment"] = 1 })),
                new EnemyShipTemplate("frigate", 1, new LevelEquipmentSpec(Skills: new Dictionary<string, int> { ["damage_control"] = 1 })),
            },
            Rewards: new EnemyRewards(Gold: 600, Iron: 80, Wood: 60, Hemp: 40)),

        // 护航编队：防守型——商船为主、护卫护航，中规中矩守商路（奖励中上）。
        new EnemyFleetConfig(
            Id: "convoy_escort",
            DisplayName: "护航编队",
            Description: "护卫押着满载商船编队航行，火力适中，重点是保住货船。",
            Strategy: EnemyStrategy.Defensive,
            Fleet: new[]
            {
                new EnemyShipTemplate("merchant", 1, new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["bombardment"] = 1 })),
                new EnemyShipTemplate("merchant", 1),
                new EnemyShipTemplate("frigate", 2, new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["cannon"] = 1 })),
            },
            Rewards: new EnemyRewards(Gold: 450, Iron: 30, Wood: 50, Hemp: 25)),

        // 商路巡逻：防守型——护卫护航商船、火力适中，守住商路即赢（金略低、木多）。
        new EnemyFleetConfig(
            Id: "trade_route_patrol",
            DisplayName: "商路巡逻",
            Description: "水师例行巡逻商路，护卫押运、守住航道即可；火力适中，重在护航不恋战。",
            Strategy: EnemyStrategy.Defensive,
            Fleet: new[]
            {
                new EnemyShipTemplate("frigate", 2, new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["cannon"] = 1 })),
                new EnemyShipTemplate("merchant", 1, new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["bombardment"] = 1 })),
                new EnemyShipTemplate("merchant", 1),
            },
            Rewards: new EnemyRewards(Gold: 400, Iron: 25, Wood: 45, Hemp: 30)),

        // 快舟骚扰：逃跑型——清一色快舟（运输/商船空船），一遇强敌四散，奖励最薄（纯骚扰）。
        new EnemyFleetConfig(
            Id: "skiff_harassment",
            DisplayName: "快舟骚扰",
            Description: "一群空载快舟昼夜骚扰航道，不接硬仗、打了就跑；击沉也没多少战利品。",
            Strategy: EnemyStrategy.Retreating,
            Fleet: new[]
            {
                new EnemyShipTemplate("transport", 3),
                new EnemyShipTemplate("merchant", 1),
            },
            Rewards: new EnemyRewards(Gold: 150, Iron: 10, Wood: 20, Hemp: 12)),

        // 水师精锐：进攻型——旗舰坐镇、护卫/商船齐全，火炮+火油、砲击+水雷齐备，主动压上（奖励最丰厚）。
        new EnemyFleetConfig(
            Id: "elite_fleet",
            DisplayName: "水师精锐",
            Description: "朝廷水师精锐倾巢而出，旗舰指挥、火力与投送齐备，主动抢攻压上，战利品最丰厚。",
            Strategy: EnemyStrategy.Aggressive,
            Fleet: new[]
            {
                new EnemyShipTemplate("flagship", 1, new LevelEquipmentSpec(
                    Weapons: new Dictionary<string, int> { ["cannon"] = 1 },
                    Skills: new Dictionary<string, int> { ["fire_oil"] = 1 })),
                new EnemyShipTemplate("frigate", 2, new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["bombardment"] = 1 })),
                new EnemyShipTemplate("frigate", 1, new LevelEquipmentSpec(Skills: new Dictionary<string, int> { ["mine"] = 1 })),
                new EnemyShipTemplate("merchant", 1, new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["bombardment"] = 1 })),
            },
            Rewards: new EnemyRewards(Gold: 900, Iron: 120, Wood: 90, Hemp: 60)),

        // CHG（海怪 Boss 战）：讨伐三阶段敌人。海怪/城寨/炮台经 ships.json 数据驱动。
        new EnemyFleetConfig(
            Id: "sea_monster_hunt",
            DisplayName: "海怪01 · 触手",
            Description: "深海触手怪（一阶段多目标触手，二阶段水面/水下移动）。",
            Strategy: EnemyStrategy.Aggressive,
            Fleet: new[] { new EnemyShipTemplate("sea_monster", 1) },
            Rewards: new EnemyRewards(Gold: 2000, Iron: 0, Wood: 0, Hemp: 0,
                Treasures: new[] { TreasureId.SeaMonsterHorn })),
        new EnemyFleetConfig(
            Id: "sea_fish_hunt",
            DisplayName: "海怪02 · 飞鱼",
            Description: "巨型飞鱼群（猎杀/追击/困兽三模式冲撞飞越）。",
            Strategy: EnemyStrategy.Aggressive,
            Fleet: new[] { new EnemyShipTemplate("sea_fish", 3) },
            Rewards: new EnemyRewards(Gold: 1600, Iron: 0, Wood: 0, Hemp: 0,
                Treasures: new[] { TreasureId.SunPiercingSpear })),
        // 大本营：城寨坐镇、炮台环伺、护卫护航（难度 3 进攻型）。
        new EnemyFleetConfig(
            Id: "wokou_stronghold",
            DisplayName: "倭寇大本营",
            Description: "城寨 2000 血，火炮×2 + 砲击×2 火力全开；四炮台掩护，护卫护航。",
            Strategy: EnemyStrategy.Aggressive,
            Fleet: new[]
            {
                new EnemyShipTemplate("wokou_citadel", 1, new LevelEquipmentSpec(Weapons: new Dictionary<string, int>
                    { ["cannon"] = 2, ["bombardment"] = 2 })),
                new EnemyShipTemplate("fort_turret", 4, new LevelEquipmentSpec(Weapons: new Dictionary<string, int>
                    { ["cannon"] = 1 })),
                new EnemyShipTemplate("frigate", 2, new LevelEquipmentSpec(Weapons: new Dictionary<string, int>
                    { ["cannon"] = 1 })),
            },
            Rewards: new EnemyRewards(Gold: 4000, Iron: 8, Wood: 12, Hemp: 8,
                Treasures: new[] { TreasureId.WokouBanner })),
    };
}

// U-2b（CHG-20260812-map-schemes-phase2）遭遇定义：一次遭遇 = 选定一张地图方案 + 一套敌人配置。
// 纯数据配对（Id 引用），供阶段三随机流程组装实际遭遇；不承担 AI/流程语义。
public sealed record EncounterDefinition(
    string Id,
    string DisplayName,
    string Description,
    string MapSchemeId,
    string EnemyConfigId)
{
    // 解析出实际的地图方案与敌人配置；引用的 Id 不存在时抛 InvalidDataException（尽早暴露配置错误）。
    public (MapScheme Map, EnemyFleetConfig Enemy) Resolve()
    {
        var map = MapSchemeRegistry.GetById(MapSchemeId)
            ?? throw new InvalidDataException($"EncounterDefinition {Id} 引用未知地图方案 {MapSchemeId}");
        var enemy = EnemyFleetConfigRegistry.GetById(EnemyConfigId)
            ?? throw new InvalidDataException($"EncounterDefinition {Id} 引用未知敌人配置 {EnemyConfigId}");
        return (map, enemy);
    }

    // 自校验：返回 null=合法，否则中文原因（引用的地图/敌人配置必须存在）。
    public string? Validate()
    {
        if (MapSchemeRegistry.GetById(MapSchemeId) is null) return $"遭遇 {Id} 引用未知地图方案 {MapSchemeId}";
        if (EnemyFleetConfigRegistry.GetById(EnemyConfigId) is null) return $"遭遇 {Id} 引用未知敌人配置 {EnemyConfigId}";
        return null;
    }
}

// U-2b 遭遇注册表：每个基址族至少一个代表性配对，策略搭配多样化（进攻/防守/逃跑齐全）。
public static class EncounterDefinitionRegistry
{
    public static IReadOnlyList<EncounterDefinition> All { get; } = BuildAll();

    public static EncounterDefinition? GetById(string id) => All.FirstOrDefault(d => d.Id == id);

    private static IReadOnlyList<EncounterDefinition> BuildAll() => new[]
    {
        new EncounterDefinition(
            Id: "open_skirmish", DisplayName: "开阔近海遭遇", Description: "大小岛海域遭遇海盗小船队（逃跑型，练手）。",
            MapSchemeId: "single_island_big_small", EnemyConfigId: "pirate_flotilla"),
        new EncounterDefinition(
            Id: "twin_routes", DisplayName: "双岛航线", Description: "双岛海域遭遇破袭舰队（进攻型）。",
            MapSchemeId: "single_island_twin", EnemyConfigId: "raider_squadron"),
        new EncounterDefinition(
            Id: "reef_patrol", DisplayName: "礁盘巡防", Description: "群岛·礁盘海域遭遇商路巡逻（防守型）。",
            MapSchemeId: "archipelago_reef_plate", EnemyConfigId: "trade_route_patrol"),
        new EncounterDefinition(
            Id: "fjord_blockade", DisplayName: "峡湾封锁", Description: "峡湾·双航道海域遭遇正规水师（防守型）。",
            MapSchemeId: "fjord_dual_channel", EnemyConfigId: "regular_navy"),
        new EncounterDefinition(
            Id: "lagoon_raid", DisplayName: "泻湖破袭", Description: "泻湖·岛链海域遭遇水师精锐（进攻型）。",
            MapSchemeId: "lagoon_island_chain", EnemyConfigId: "elite_fleet"),

        // CHG（海怪 Boss 战）：讨伐章三阶段固定遭遇（各自专属地图，CHG-20260819-hunt-maps 重画）。
        // hunt_stage1 海怪01→稀疏群岛；hunt_stage2 海怪02→泻湖；hunt_stage3 大本营→营寨（城寨竖放最右+炮台岸防）。
        new EncounterDefinition(
            Id: "hunt_stage1", DisplayName: "讨伐·海怪01", Description: "讨伐章第一战：深海触手怪。稀疏群岛外围。",
            MapSchemeId: "hunt_archipelago", EnemyConfigId: "sea_monster_hunt"),
        new EncounterDefinition(
            Id: "hunt_stage2", DisplayName: "讨伐·海怪02", Description: "讨伐章第二战：巨型飞鱼群。泻湖内湖。",
            MapSchemeId: "hunt_lagoon", EnemyConfigId: "sea_fish_hunt"),
        new EncounterDefinition(
            Id: "hunt_stage3", DisplayName: "讨伐·大本营", Description: "讨伐章终战：倭寇大本营城寨。营寨右缘。",
            MapSchemeId: "hunt_stronghold", EnemyConfigId: "wokou_stronghold"),
    };
}
