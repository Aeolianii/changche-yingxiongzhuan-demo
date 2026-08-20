#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// U-2a（CHG-20260812-map-schemes-phase1）地图方案（纯数据层，无 Godot 依赖）：
// 固定地图（LevelMapSpec，含新地形）+ 玩家/敌布阵区（GridRect）+ 展示文本。
// 符号表：`.`深水 `~`浅滩 `#`礁石 `^`山地 `B`海滩 `F`林地 `G`草地 `P`港口 `T`小镇 `R`陆河 `E`出口。
// 玩家区在左、敌区在右、保连通（玩家区中心 → 敌区中心 BFS 可达）。阶段一仅作数据与规则测试交付，不接入流程。
public sealed record MapScheme(
    string Id,
    string DisplayName,
    string Description,
    LevelMapSpec Map,
    GridRect PlayerZone,
    GridRect EnemyZone,
    string VariantGroup)
{
    // 自校验：返回 null=合法，否则中文原因。
    // 校验项：布阵区界内 + 恒深水（舰队恒可放置）+ 不重叠（玩家区在左）+ 连通（玩家区中心→敌区中心可达）。
    public string? Validate()
    {
        if (Map is null) return "地图规格为空";
        if (PlayerZone.Width <= 0 || PlayerZone.Height <= 0) return $"玩家区无效 {PlayerZone}";
        if (EnemyZone.Width <= 0 || EnemyZone.Height <= 0) return $"敌区无效 {EnemyZone}";
        foreach (var (name, zone) in new[] { ("玩家区", PlayerZone), ("敌区", EnemyZone) })
        {
            if (zone.X < 0 || zone.Y < 0 || zone.Right > Map.Width || zone.Bottom > Map.Height)
                return $"{name} {zone} 越界（地图 {Map.Width}×{Map.Height}）";
            for (var y = zone.Y; y < zone.Bottom; y++)
                for (var x = zone.X; x < zone.Right; x++)
                    if (Map.TerrainAt(x, y) != TerrainType.DeepWater)
                        return $"{name} 格 ({x},{y}) 应为深水，实际 {Map.TerrainAt(x, y)}";
        }
        if (PlayerZone.Right > EnemyZone.X)
            return $"玩家区 {PlayerZone} 与敌区 {EnemyZone} 重叠（玩家应在左）";
        var from = RandomMapGenerator.ZoneCenter(Map, PlayerZone);
        var to = RandomMapGenerator.ZoneCenter(Map, EnemyZone);
        if (!RandomMapGenerator.HasPath(Map, from, to))
            return $"地图不连通：{from} → {to} 无可达路径";
        return null;
    }
}

// U-2a/U-2b 地图方案注册表：4 张基址 + 5 张变体（VariantGroup 归族），共 9 张固定地图，提供 ASCII 说明文本。
// 变体规则见 docs/design/map-design-rules.md（地图设计/随机生成/敌人配置三章）。
public static class MapSchemeRegistry
{
    public static IReadOnlyList<MapScheme> All { get; } = BuildAll();

    public static MapScheme? GetById(string id) => All.FirstOrDefault(s => s.Id == id);

    public static string AsciiArt(MapScheme scheme) => string.Join('\n', scheme.Map.TerrainRows);

    // —— 4 张地图方案 ——

    private static IReadOnlyList<MapScheme> BuildAll() => new[]
    {
        // 单海岛：中央大岛（林地+山地+小镇+港口+海滩），四周深水；东南角礁石伏击点。开敞近海交锋。
        new MapScheme(
            Id: "single_island",
            DisplayName: "单海岛",
            Description: "中央一座大岛（林地/山地/小镇/港口/海滩），四周深水开阔，东南角暗礁。适合正面交锋的遭遇战。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "........................",
                "........~~..............",
                "........GGGGGGGG........",
                "........BGFFGGGB........",
                "........BFF^FGGB........",
                "........BFF^FGGB........",
                "........BGGTTGGB........",
                "........BGGTTGGB........",
                "........BGFFGGBB........",
                "........BGGGGGBB........",
                "........BGGGGBBB........",
                "........BPGGGBBB........",
                "........BPGGGBBB........",
                "........BBBBBBBB........",
                "..............##........",
                "........................",
            }),
            PlayerZone: new GridRect(1, 1, 7, 14),
            EnemyZone: new GridRect(16, 1, 7, 14),
            VariantGroup: "single_island"),

        // 群岛：四个中小岛屿散布，岛间水道窄（2 格），浅滩环绕、航道暗礁埋伏；短兵相接、航线多变。
        new MapScheme(
            Id: "archipelago",
            DisplayName: "群岛",
            Description: "中小岛屿散布、岛间水道狭窄，浅滩环绕与航道暗礁埋伏；航线多变、适合近战与伏击。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "..........................",
                "..........~~..............",
                ".........BBBB.BBB.........",
                ".........BGFB.BGB.........",
                ".........BGFB.BGB.........",
                ".........BBBB.BBB.........",
                "..........~~..~~..........",
                ".............BBB..........",
                ".............BFB..........",
                "............##.~~.........",
                "..........BBBBBBB.........",
                "..........BGTTBGB.........",
                "..........BGTTBGB.........",
                "..........BGFFBGB.........",
                "..........BGGGGBB.........",
                "..........BGGGBBB.........",
                "..........BBBBBBB.........",
                "..........................",
            }),
            PlayerZone: new GridRect(1, 1, 8, 16),
            EnemyZone: new GridRect(17, 1, 8, 16),
            VariantGroup: "archipelago"),

        // 峡湾：上下两侧高岸（山地/林地/草地+海滩岸缘）夹狭长水道，山嘴收窄成咽喉，入海口浅滩+礁石；一条主航道。
        new MapScheme(
            Id: "fjord",
            DisplayName: "峡湾",
            Description: "高岸夹峙的狭长水道，中央山嘴把航道收窄成咽喉，入海口浅滩与暗礁；只有一条主航道，考验抢点与穿插。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "GGG^^^^^^GGGGGG^^^^^^GGGGGGG",
                "GGG^^^^^^FFFFFF^^^^^^GGGGGGG",
                "GGGGGGGGGFFFFFFGGGGGGGGGGGGG",
                "GGGGGGGGGFFFFFFGGGGGGGGGGGGG",
                "GGGGGGGGGFFFFFFGGGGGGGGGGGGG",
                "GGGGGGGGGFFFF^^FFGGGGGGGGGGG",
                "BBBBBBBBBBBBBBBBBBBBBBBBBBBB",
                ".............^^.....##......",
                ".............^^.............",
                ".............^^.......~~....",
                "......................~~....",
                "............................",
                "BBBBBBBBBBBBBBBBBBBBBBBBBBBB",
                "GGGGGGGGGFFFFFFGGGGGGGGGGGGG",
                "GGGGGGGGGFFFFFF^^^^^^GGGGGGG",
                "GGGGGGGGGFFFFFF^^^^^^GGGGGGG",
                "GGGGGGGGGFFFFFF^^^^^^GGGGGGG",
                "GGGGGGGGGFFFFFFGGGGGGGGGGGGG",
            }),
            PlayerZone: new GridRect(1, 7, 4, 5),
            EnemyZone: new GridRect(24, 7, 4, 5),
            VariantGroup: "fjord"),

        // 泻湖：环形陆地（草地/林地/陆河注入）围出内湖，西侧湖口狭窄，湖内浅滩/礁石、中央深水航道。
        new MapScheme(
            Id: "lagoon",
            DisplayName: "泻湖",
            Description: "环形陆地围出的内湖，陆河自北岸注入，西侧湖口狭窄；湖内浅滩与暗礁交错、中央一线深水航道。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "....GGGGGGGGGGGGGGGGGGGG^^^^",
                "....GGGGGGGGGGGGGGGGGGGG^^^^",
                "....GGGGGGGGGGFFFGGGGGGG^^^^",
                "....GGGGGGGGGGRRRGGGGGGG^^^^",
                "....GGGGGGGGGGRRRGGGGGGG^^^^",
                ".......~~~~~~~~~~~~~~~~~^^^^",
                "........###.............^^^^",
                "........................^^^^",
                ".............~~~........^^^^",
                "........................^^^^",
                "...........##...........^^^^",
                "...............~~.......^^^^",
                ".......~~~~~~~~~~~~~~~~~^^^^",
                "....GGGGGGGGGGGGGGGGGGGG^^^^",
                "....GGGGGGGGGGFFFGGGGGGG^^^^",
                "....GGGGGGGGGGFFFGGGGGGG^^^^",
                "....GGGGGGGGGGGGGGGGGGGG^^^^",
                "....GGGGGGGGGGGGGGGGGGGG^^^^",
            }),
            PlayerZone: new GridRect(1, 1, 3, 16),
            EnemyZone: new GridRect(18, 6, 6, 6),
            VariantGroup: "lagoon"),

        // 单海岛·大小岛：中央大岛 + 东南近岸一座小岛，伏击礁石仍在；南侧多一处绕行/登陆点。
        new MapScheme(
            Id: "single_island_big_small",
            DisplayName: "大小岛",
            Description: "中央大岛旁东南近岸添一座小岛，航道多一处绕行点；其余与基址一致，适合正面交锋。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "........................",
                "........~~..............",
                "........GGGGGGGG........",
                "........BGFFGGGB........",
                "........BFF^FGGB........",
                "........BFF^FGGB........",
                "........BGGTTGGB........",
                "........BGGTTGGB........",
                "........BGFFGGBB........",
                "........BGGGGGBB........",
                "........BGGGGBBB........",
                "........BPGGGBBB........",
                "........BPGGGBBB........",
                "........BBBBBBBB........",
                "..............##........",
                ".................BB.....",
            }),
            PlayerZone: new GridRect(1, 1, 7, 14),
            EnemyZone: new GridRect(16, 1, 7, 14),
            VariantGroup: "single_island"),

        // 单海岛·双岛：大岛（林地/山体）+ 东侧第二座小岛把航道切成南北两线，右缘全程出口。
        new MapScheme(
            Id: "single_island_twin",
            DisplayName: "双岛",
            Description: "一座大岛与东侧第二座小岛把开阔海面切成南北两线航道，右缘留出口，伏击与绕行并重。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                ".......................E",
                "........~~.............E",
                "........GGGG...........E",
                "........BGFG...........E",
                "........BGFG...........E",
                "........BGGG...........E",
                "........BGGG...........E",
                "........BGGG...........E",
                "........BGGG...........E",
                "........BBBB..GG.......E",
                "..............BG.......E",
                "..............BG.......E",
                "..............BG.......E",
                "..............BB.......E",
                "..............BB.......E",
                ".......................E",
            }),
            PlayerZone: new GridRect(1, 1, 7, 14),
            EnemyZone: new GridRect(16, 1, 7, 14),
            VariantGroup: "single_island"),

        // 群岛·礁盘：移除中央大岛，改作大片暗礁（#）+ 浅滩（~）交错礁盘带，逼出多条窄航道。
        new MapScheme(
            Id: "archipelago_reef_plate",
            DisplayName: "礁盘",
            Description: "群岛基址中央改作暗礁与浅滩交错的礁盘带，航道被切成多条窄口，穿礁抢航是焦点。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "..........................",
                "..........~~..............",
                ".........BBBB.............",
                ".........BGFB.............",
                ".........BGFB.............",
                ".........BBBB.............",
                "...........~~.............",
                "..........####............",
                ".........######...........",
                ".........########.........",
                "..........#######.........",
                "...........####...........",
                ".............##...........",
                "..........BBBB............",
                "..........BGBB............",
                "..........BBBB............",
                "..........................",
                "..........................",
            }),
            PlayerZone: new GridRect(1, 1, 8, 16),
            EnemyZone: new GridRect(17, 1, 8, 16),
            VariantGroup: "archipelago"),

        // 峡湾·双航道：南浅滩航道 + 北深水航道并行，中央双山嘴分隔，入海口双侧浅滩。
        new MapScheme(
            Id: "fjord_dual_channel",
            DisplayName: "双航道",
            Description: "峡湾基址开出一条南浅滩航道与一条北深水航道，中央双山嘴分隔；浅水船与深水舰各有其道。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "GGG^^^^^^GGGGGG^^^^^^GGGGGGG",
                "GGG^^^^^^FFFFFF^^^^^^GGGGGGG",
                "GGGGGGGGGFFFFFFGGGGGGGGGGGGG",
                "GGGGGGGGGFFFFFFGGGGGGGGGGGGG",
                "GGGGGGGGGGGGGGGGGGGGGGGGGGGG",
                "GGGGGGGGGFFFF^^FFGGGGGGGGGGG",
                "BBBBBBBBBBBBBBBBBBBBBBBBBBBB",
                ".......~~~..................",
                ".......~~~..................",
                ".............^^^^...........",
                ".............^^^^...........",
                "............................",
                ".......~~~...........~~.....",
                ".......~~~...........~~.....",
                "BBBBBBBBBBBBBBBBBBBBBBBBBBBB",
                "GGGGGGGGGFFFFFF^^^^^^GGGGGGG",
                "GGGGGGGGGFFFFFF^^^^^^GGGGGGG",
                "GGGGGGGGGFFFFFF^^^^^^GGGGGGG",
            }),
            PlayerZone: new GridRect(1, 7, 4, 5),
            EnemyZone: new GridRect(24, 7, 4, 5),
            VariantGroup: "fjord"),

        // 泻湖·岛链：湖中央一道岛链（大小岛斜列、中央深水豁口），北/南浅滩带夹持。
        new MapScheme(
            Id: "lagoon_island_chain",
            DisplayName: "岛链",
            Description: "泻湖基址湖心添一道斜列岛链，把内湖隔出深浅水区，南北浅滩带夹持，穿豁口抢航是焦点。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "....GGGGGGGGGGGGGGGGGGGG^^^^",
                "....GGGGGGGGGGFFFGGGGGGG^^^^",
                "....GGGGGGGGGGFFFGGGGGGG^^^^",
                "....GGGGGGGGGGRRRGGGGGGG^^^^",
                "....GGGGGGGGGGRRRGGGGGGG^^^^",
                ".......~~~~~~~~~~~~~~~~~^^^^",
                ".........###.BB.........^^^^",
                ".............BB.........^^^^",
                ".............BB~~.......^^^^",
                "........................^^^^",
                "...........##..BB.......^^^^",
                "..............BB........^^^^",
                ".......~~~~~~~~~~~~~~~~~^^^^",
                "....GGGGGGGGGGGGGGGGGGGG^^^^",
                "....GGGGGGGGGGFFFGGGGGGG^^^^",
                "....GGGGGGGGGGFFFGGGGGGG^^^^",
                "....GGGGGGGGGGGGGGGGGGGG^^^^",
                "....GGGGGGGGGGGGGGGGGGGG^^^^",
            }),
            PlayerZone: new GridRect(1, 1, 3, 16),
            EnemyZone: new GridRect(18, 6, 6, 6),
            VariantGroup: "lagoon"),

        // CHG（海怪 Boss 战）：海盗据点——倭寇大本营。左港区（玩家布阵）→ 中央港口/小镇/海滩岛 → 右敌港区；
        // 岛礁与浅滩散布；右下留出口列。讨伐章三阶段共用本图（区恒深水、玩家区在左、连通）。
        // VariantGroup 用既有分组名（single_island），满足 U-2b「变体归组」校验。
        new MapScheme(
            Id: "pirate_stronghold",
            DisplayName: "海盗据点",
            Description: "盘踞岛礁的倭寇大本营，港口泊着城寨，炮台环伺；海怪潜行在外围深水。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "........................",
                "..........~~............",
                "...~~..........##.......",
                "......GFFTTTGGG.........",
                "......BGPPPPPGG.........",
                "......BGPPPPPGG.........",
                "......BGTTTTTGG.........",
                "......BGGGGGGG~~........",
                "......BBBBBBBB..........",
                ".......~~~..............",
                "........##..............",
                "............###.........",
                ".......................E",
                ".......................E",
                "........................",
                "........................",
            }),
            PlayerZone: new GridRect(X: 1, Y: 3, Width: 5, Height: 8),
            EnemyZone: new GridRect(X: 17, Y: 2, Width: 6, Height: 10),
            VariantGroup: "single_island"),

        // CHG-20260819（F-2 讨伐战地图）：海怪01——稀疏分散群岛。
        // 三个 4×4 小岛（西北/中部/西南）稀疏散布、水道开阔；东北礁群 + 零星浅滩/礁石点缀；
        // 底部两行深水主航道贯通（海怪01 Passability=DeepWaterOnly 全程深水可达）。
        // 玩家区在左、敌区贴右缘（2 列窄区，海怪 2×2 朝西可摆）；右下出口列。
        new MapScheme(
            Id: "hunt_archipelago",
            DisplayName: "讨伐·海怪01群岛",
            Description: "稀疏分散群岛：小岛稀疏散布、水道开阔，暗礁与浅滩点缀；深水主航道贯通，海怪潜行在外围。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                ".......................E",
                ".......................E",
                ".......BBBB......###~..E",
                ".......BGFB......###...E",
                ".......BGFB......###...E",
                "......~BBBB......###~..E",
                "......~~...~~...#......E",
                ".......................E",
                ".............BBBB......E",
                ".............BGFB......E",
                ".............BG##......E",
                "...........~~BBBB......E",
                "......BBBB.............E",
                "......BGFB.......~~~...E",
                "......BGFB.............E",
                "......BBBB.............E",
                ".......................E",
                ".......................E",
            }),
            PlayerZone: new GridRect(1, 2, 5, 14),
            EnemyZone: new GridRect(21, 2, 2, 14),
            VariantGroup: "archipelago"),

        // CHG-20260819（F-2 讨伐战地图）：海怪02——泻湖。
        // 环形陆地（北/南岸草地 + 陆河注入 + 小镇/港口，东北/东南山地）围出内湖；
        // 西侧湖口窄（col6 宽 1 列），湖内浅滩/礁石点缀；敌区贴右缘山地内侧湖缘，飞鱼群出生湖内。
        new MapScheme(
            Id: "hunt_lagoon",
            DisplayName: "讨伐·海怪02泻湖",
            Description: "环形陆地围出的泻湖：陆河自北岸注入、湖口狭窄；湖内浅滩与暗礁点缀，飞鱼群藏身湖内东缘。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "GGGGGGGGGGRRGGGGGGGG^^^E",
                "GGGGGGGGGGRRGGGGGGGG^^^E",
                "G.....GGGGRRGGGGGGGG^^^E",
                "G.....GGGGRRGGGGGGGG^^^E",
                "G.....G...RR........^^^E",
                "G......................E",
                "G........~~..##........E",
                "G......................E",
                "G................~~....E",
                "G......................E",
                "G......................E",
                "G...........##.........E",
                "G.....G..~~............E",
                "G.....G................E",
                "G.....GGGGGGGGGGGGGG^^^E",
                "G.....GGGTTTTTTGGGGG^^^E",
                "GGGGGGGGGTTTTTTGGPPPP^^E",
                "GGGGGGGGGGGGGGGGGPPPP^^E",
            }),
            PlayerZone: new GridRect(1, 2, 5, 14),
            EnemyZone: new GridRect(21, 5, 2, 8),
            VariantGroup: "lagoon"),

        // CHG-20260819（F-2 讨伐战地图）：大本营——倭寇营寨。
        // 左港区（玩家布阵）→ 中央营地岛（山地寨墙 + 营帐小镇 + 栅栏林地，东前暗礁防线）→ 右岸防带（敌区贴右缘 2 列窄区）。
        // 城寨为 2×4 矩形、横放（East/West 占 4 列）必然越出 2 列窄区 → 只能竖放贴右缘最右；炮台 ×4 与守军护卫沿其前排布
        // （PlaceInEnemyZone 行优先自动放置，Deterministic）。敌出生在城寨附近；右下出口列。
        new MapScheme(
            Id: "hunt_stronghold",
            DisplayName: "讨伐·倭寇大本营",
            Description: "倭寇营寨：城寨竖镇右缘、炮台沿岸防位列阵，守军停泊护航；中央营地岛与暗礁防线层层设防。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                ".......................E",
                ".......................E",
                "G......................E",
                "G......................E",
                "G........^GGGGGGG^.....E",
                "G........GTTT^TTTG.....E",
                "G........GTFFFFFTG.....E",
                "G........GTFFFFFTG##...E",
                "G......~.GTFFFFFTG##...E",
                "G......~.GTFFFFFTG##...E",
                "G........GTFFFFFTG.....E",
                "G........GTTT^TTTG.....E",
                "G........^GGGGGGG^.....E",
                "G......~~~.............E",
                "G......................E",
                "G......................E",
                ".......................E",
                ".......................E",
            }),
            PlayerZone: new GridRect(1, 2, 5, 14),
            EnemyZone: new GridRect(21, 2, 2, 13),
            VariantGroup: "single_island"),
    };
}
