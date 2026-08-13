#nullable enable
using System.Collections.Generic;
using System.Linq;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// L-1 关卡静态注册表：全部 8 关（3 章，线性序 1-1..3-2）+ 自由模式（沙盒，不进解锁序列）。
// 8 关具体内容 L-4 逐个完善；本任务 1-1/1-2 为样例定义，其余 6 关为占位定义（保证编译与注册表/解锁可测）。
public static class LevelRegistry
{
    // 线性解锁序：1-1,1-2,1-3,2-1,2-2,2-3,3-1,3-2（每关前一关完成后解锁；跨章连续）。
    public static IReadOnlyList<LevelDefinition> AllLevels { get; } = BuildAllLevels();
    public static LevelDefinition FreeMode { get; } = BuildFreeMode();
    public static IReadOnlyList<string> AllLevelIds { get; } = AllLevels.Select(l => l.Id).ToList();

    // 按 id 查找 8 关或自由模式；未命中返回 null。
    public static LevelDefinition? GetById(string id)
        => AllLevels.FirstOrDefault(l => l.Id == id)
           ?? (FreeMode.Id == id ? FreeMode : null);

    // 按章节取关卡；Free 章返回自由模式（单元素）。
    public static IReadOnlyList<LevelDefinition> ByChapter(LevelChapter chapter)
        => chapter == LevelChapter.Free
            ? new[] { FreeMode }
            : AllLevels.Where(l => l.Chapter == chapter).ToList();

    // —— 8 关定义（1-1/1-2 样例，其余占位）——

    private static IReadOnlyList<LevelDefinition> BuildAllLevels() => new[]
    {
        // 1-1 样例：基础操控——移动与转向（深水开放图，旗舰直抵目标格）
        new LevelDefinition(
            Id: "1-1",
            Chapter: LevelChapter.Chapter1,
            Title: "起航·移动与转向",
            Description: "学习旗舰的基础移动与转向，把船开到目标格。",
            ObjectiveText: "把旗舰开到目标格 (8,4)。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "............",
                "............",
                "............",
                "............",
                "...........E",
                "..^........~",
                "............",
                "............",
                "............",
            }),
            Weather: Weather.Clear,
            Wind: null,
            // L-3 修正：旗舰长 3 朝东占格 (2,4),(1,4),(0,4)（原 (1,4) 会延伸出图 OOB）→ 合法布阵/自动开始。
            PlayerFleet: new[]
            {
                new LevelShipSpec("flagship", new GridPos(2, 4), CardinalDirection.East),
            },
            EnemyFleet: new LevelShipSpec[0],
            EnemyAiEnabled: true,
            Objective: new LevelObjective(LevelObjectiveType.ReachCell, TargetCell: new GridPos(8, 4)),
            Hints: new[]
            {
                "点击己方舰选中；鼠标右键可随时退选",
                "点击目标格移动（该格为船头）；也可用方向键 ↑↓←→ 逐格移动",
                "可点「左转 / 右转」旋转朝向，也可按 [ 和 ] 键转向后再移动",
                "抵达 (8,4) 目标格即通关",
            }),

        // 1-2 样例：基础操控——布阵与装备（教学战斗，击沉全部敌舰）
        new LevelDefinition(
            Id: "1-2",
            Chapter: LevelChapter.Chapter1,
            Title: "备战·布阵与装备",
            Description: "布好阵型、装载武器，打赢第一场教学战斗。",
            ObjectiveText: "布阵并装备火炮/砲击，击沉全部敌舰。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "................",
                "................",
                "................",
                "........~.......",
                "........~.......",
                "........~....#..",
                "........~.......",
                "................",
                "................",
                "................",
            }),
            Weather: Weather.Cloudy,
            Wind: null,
            // L-3 修正：旗舰长 3 朝东占格 (2,2),(1,2),(0,2)（原 (1,2) 会延伸出图 OOB）→ 布阵校验通过。
            PlayerFleet: new[]
            {
                new LevelShipSpec("flagship", new GridPos(2, 2), CardinalDirection.East,
                    new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["cannon"] = 1 })),
                new LevelShipSpec("frigate", new GridPos(1, 6), CardinalDirection.East,
                    new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["bombardment"] = 1 })),
            },
            EnemyFleet: new[]
            {
                new LevelShipSpec("frigate", new GridPos(14, 2), CardinalDirection.West),
                new LevelShipSpec("transport", new GridPos(14, 6), CardinalDirection.West),
            },
            EnemyAiEnabled: true,
            Objective: new LevelObjective(LevelObjectiveType.SinkAllEnemies),
            Hints: new[]
            {
                "点选己方舰布阵，可旋转朝向",
                "打开「装备配置」，为旗舰装载 1 门火炮、护卫舰装载砲击",
                "确认布阵后开始战斗",
                "击沉全部敌舰即通关",
            }),

        // 1-3 巡航·综合操控：第一章综合练习——双舰协同，箭雨近程 + 砲击中程，全部内容 L-4 完善。
        new LevelDefinition(
            Id: "1-3",
            Chapter: LevelChapter.Chapter1,
            Title: "巡航·综合操控",
            Description: "第一章综合练习：旗舰与护卫舰协同，运用移动与两类远程武器击沉全部敌舰。",
            ObjectiveText: "击沉全部敌舰。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                ".............",
                ".............",
                "...^^........",
                "...^^........",
                ".............",
                ".............",
                ".............",
                ".............",
                ".............",
            }),
            Weather: Weather.Clear,
            Wind: null,
            PlayerFleet: new[]
            {
                new LevelShipSpec("flagship", new GridPos(2, 4), CardinalDirection.East),
                new LevelShipSpec("frigate", new GridPos(2, 7), CardinalDirection.East,
                    new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["bombardment"] = 1 })),
            },
            EnemyFleet: new[]
            {
                new LevelShipSpec("frigate", new GridPos(10, 4), CardinalDirection.West),
                new LevelShipSpec("frigate", new GridPos(11, 7), CardinalDirection.West),
            },
            EnemyAiEnabled: false,
            Objective: new LevelObjective(LevelObjectiveType.SinkAllEnemies),
            Hints: new[]
            {
                "点击己方舰选中",
                "移动旗舰靠近敌舰后用箭雨击沉（射程≤2，无需武器）",
                "移动护卫舰进入砲击射程（3-5，可越山）后击沉",
                "击沉全部敌舰即通关",
            }),

        // 2-1 炮火·远程攻击：三种远程武器教学——箭雨近程逼近、砲击中程越山、火炮侧舷平射。
        new LevelDefinition(
            Id: "2-1",
            Chapter: LevelChapter.Chapter2,
            Title: "炮火·远程攻击",
            Description: "三种远程武器：箭雨（近程）、砲击（中程、可越山）、火炮（侧舷平射），各击沉一艘敌舰。",
            ObjectiveText: "用远程武器击沉全部敌舰。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "................",
                "................",
                "................",
                "................",
                "................",
                "................",
                "................",
                "................",
                "....^...........",
                "................",
                "................",
            }),
            Weather: Weather.Clear,
            Wind: null,
            PlayerFleet: new[]
            {
                new LevelShipSpec("flagship", new GridPos(2, 2), CardinalDirection.East),
                new LevelShipSpec("frigate", new GridPos(2, 5), CardinalDirection.North,
                    new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["cannon"] = 1 })),
                new LevelShipSpec("frigate", new GridPos(2, 8), CardinalDirection.East,
                    new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["bombardment"] = 1 })),
            },
            EnemyFleet: new[]
            {
                new LevelShipSpec("frigate", new GridPos(9, 2), CardinalDirection.West),
                new LevelShipSpec("frigate", new GridPos(6, 5), CardinalDirection.West),
                new LevelShipSpec("frigate", new GridPos(8, 8), CardinalDirection.West),
            },
            EnemyAiEnabled: false,
            Objective: new LevelObjective(LevelObjectiveType.SinkAllEnemies),
            Hints: new[]
            {
                "点击己方舰选中",
                "箭雨射程近（≤2）：移动旗舰靠近后用箭雨击沉",
                "砲击射程3-5、可越山：移动护卫舰进入射程后击沉",
                "火炮侧舷平射：垂直朝向的护卫舰沿本行用火炮击沉敌舰",
                "用远程武器击沉全部敌舰即通关",
            }),

        // 2-2 近战·撞击与接舷：撞击重创/推动 + 接舷合围俘获，清除全部敌舰。
        new LevelDefinition(
            Id: "2-2",
            Chapter: LevelChapter.Chapter2,
            Title: "近战·撞击与接舷",
            Description: "近战战术：撞角撞击重创并推开，接舷合围提升俘获进度、交换俘获，清除全部敌舰。",
            ObjectiveText: "撞击/接舷俘获，清除全部敌舰。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "..............",
                "..............",
                "..............",
                "..............",
                "..............",
                "..............",
                "..............",
                "..............",
                "..............",
            }),
            Weather: Weather.Clear,
            Wind: null,
            PlayerFleet: new[]
            {
                new LevelShipSpec("frigate", new GridPos(2, 3), CardinalDirection.East,
                    new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["ram"] = 1 })),
                new LevelShipSpec("transport", new GridPos(4, 5), CardinalDirection.East),
                new LevelShipSpec("frigate", new GridPos(4, 8), CardinalDirection.East),
            },
            EnemyFleet: new[]
            {
                new LevelShipSpec("frigate", new GridPos(9, 3), CardinalDirection.West),
                new LevelShipSpec("transport", new GridPos(7, 5), CardinalDirection.West),
            },
            EnemyAiEnabled: false,
            Objective: new LevelObjective(LevelObjectiveType.SinkAllEnemies),
            Hints: new[]
            {
                "点击己方舰选中撞击舰",
                "移动撞击舰贴近敌舰船头后点「撞击」",
                "撞击重创敌舰（可能推开），补箭雨或再撞击击沉它",
                "移动运输船贴住敌船侧面接舷，再派护卫舰合围",
                "接舷进度到100%后点「交换」俘获敌舰，清除全部敌舰即通关",
            }),

        // 2-3 奇谋·技能运用：旗舰四技能各用一次（连锁弹/火油/水雷/损管），无战斗负担。
        new LevelDefinition(
            Id: "2-3",
            Chapter: LevelChapter.Chapter2,
            Title: "奇谋·技能运用",
            Description: "旗舰四大技能：连锁弹减速、火油点燃、水雷封路、损管修复，各使用一次。",
            ObjectiveText: "四种技能各使用一次。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "............",
                "............",
                "............",
                "............",
                "............",
                "............",
                "............",
                "............",
                "............",
            }),
            Weather: Weather.Clear,
            Wind: null,
            PlayerFleet: new[]
            {
                new LevelShipSpec("flagship", new GridPos(2, 4), CardinalDirection.East,
                    new LevelEquipmentSpec(Skills: new Dictionary<string, int>
                    {
                        ["chain_shot"] = 1,
                        ["fire_oil"] = 1,
                        ["damage_control"] = 1,
                        ["mine"] = 1,
                    })),
            },
            EnemyFleet: new[]
            {
                new LevelShipSpec("frigate", new GridPos(6, 4), CardinalDirection.West),
            },
            EnemyAiEnabled: false,
            Objective: new LevelObjective(LevelObjectiveType.UseAllSkills),
            Hints: new[]
            {
                "点击己方舰选中旗舰",
                "点选旗舰后用连锁弹攻击敌舰（射程3-5，减速）",
                "再点选旗舰：用火油点燃敌舰（射程3-4）、放水雷（射程1）",
                "再点选旗舰用损管修复；四技能各用一次即通关",
            }),

        // 3-1 天威·天气与地形：雨天（视野缩短）+ 山地墙（砲击越山/遮挡视野）+ 浅滩（深水旗舰不可进）。
        // L-4 盲射几何校验（Bresenham 手推，雨天视野预算 8）：
        //   山地 (6,5),(7,5),(8,5),(6,6),(7,6) 使护卫舰在 (5,7) 看山后敌舰 (9,4)：射线 (6,6)[3]→(7,6)[3]→(8,5)[3]→(9,4)[1]
        //   累计 9 > 8 → 真隐藏（盲射）；再靠近到 (6,7)：射线 (7,6)[3]→(8,5)[3]→(9,4)[1] 累计 7 ≤ 8 → 进入视野 → 教学"移动靠近"。
        //   旗舰也是观察者：旗舰 (2,6) 看 (9,4) 累计 9 > 8 同样隐藏 → 敌舰对所有己方舰隐藏，盲射教学才成立。
        //   顺行敌舰 (9,7) 从 (5,7) 直线累计 4 ≤ 8 可见（护卫舰直击目标）。
        // 两艘护卫舰 2×砲击单发 320 伤均一击沉；旗舰 (2,6) 东行被浅滩 (3,6) 挡（深水旗舰不可进浅滩演示）。
        new LevelDefinition(
            Id: "3-1",
            Chapter: LevelChapter.Chapter3,
            Title: "天威·天气与地形",
            Description: "雨天、山地与浅滩：视野缩短，山地遮挡视线但砲击可越山，深水旗舰不能进浅滩。",
            ObjectiveText: "在雨天中击沉全部敌舰。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "..............",
                "..............",
                "..............",
                "..............",
                "..............",
                "......^^^.....",   // 山地 (6,5),(7,5),(8,5)
                "...~~.^^......",   // 浅滩 (3,6),(4,6)：挡旗舰东行（旗舰深水舰）；山地 (6,6),(7,6)
                "..............",
                "..............",
            }),
            Weather: Weather.Rainy,
            Wind: null,
            PlayerFleet: new[]
            {
                new LevelShipSpec("flagship", new GridPos(2, 6), CardinalDirection.East),
                new LevelShipSpec("frigate", new GridPos(2, 7), CardinalDirection.East,
                    new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["bombardment"] = 2 })),
            },
            EnemyFleet: new[]
            {
                new LevelShipSpec("frigate", new GridPos(9, 7), CardinalDirection.West), // 顺行可见：护卫舰直击
                new LevelShipSpec("frigate", new GridPos(9, 4), CardinalDirection.West), // 山后隐藏：盲射/靠近进视野
            },
            EnemyAiEnabled: false,
            Objective: new LevelObjective(LevelObjectiveType.SinkAllEnemies),
            Hints: new[]
            {
                "点击己方舰选中（雨天视野缩短）",
                "移动护卫舰靠近山体，砲击可越山击中山后敌舰（深水旗舰不可进浅滩）",
                "山后敌舰被雨雾遮挡：再移动靠近，进入视野后用砲击击沉",
                "击沉全部敌舰即通关",
            }),

        // 3-2 终局·逃跑自沉与投降维修：旗舰撤退抵出口逃离通关；护卫舰浅滩自沉固守掩护；战后自动维修。
        // 投降机制在本关以规则说明提及（避免与逃离目标冲突），规则层用例单独覆盖。
        new LevelDefinition(
            Id: "3-2",
            Chapter: LevelChapter.Chapter3,
            Title: "终局·逃跑自沉与投降维修",
            Description: "终局综合：逃跑、自沉固守、投降与维修规则集于一身。",
            ObjectiveText: "任一舰船抵达出口格逃离战场。",
            Map: LevelMapSpec.FromAscii(new[]
            {
                "...............E",
                "...............E",
                "........##.....E",
                "...............E",
                "...............E",
                "...............E",
                "...............E",
                "......~~.......E",
                "...............E",
                "...............E",
            }),
            Weather: Weather.Clear,
            Wind: null,
            PlayerFleet: new[]
            {
                // 旗舰长 3 朝东：船头 (2,4) 船尾 (0,4) 全在图内（(1,4) 会延伸出图 OOB）
                new LevelShipSpec("flagship", new GridPos(2, 4), CardinalDirection.East),
                new LevelShipSpec("frigate", new GridPos(1, 7), CardinalDirection.East,
                    new LevelEquipmentSpec(Weapons: new Dictionary<string, int> { ["bombardment"] = 1 })),
            },
            EnemyFleet: new[]
            {
                new LevelShipSpec("flagship", new GridPos(9, 4), CardinalDirection.West),
                new LevelShipSpec("frigate", new GridPos(9, 7), CardinalDirection.West),
            },
            EnemyAiEnabled: false,
            Objective: new LevelObjective(LevelObjectiveType.Escape),
            Hints: new[]
            {
                "点击己方舰选中",
                "选中护卫舰开上浅滩后点「自沉」固守成炮台，掩护撤退",
                "移动旗舰向东避开敌舰，抵达右侧出口格（E）即逃离通关",
                "战斗结束幸存舰自动维修",
            }),
    };

    // —— 自由模式（沙盒）：不进解锁序列（LevelProgress.IsUnlocked 对非序列 id 恒返回 true）——

    private static LevelDefinition BuildFreeMode()
        => new(
            Id: "free",
            Chapter: LevelChapter.Free,
            Title: "自由模式",
            Description: "自由沙盒：自定义舰队、阵型与装备，任意练习全部机制。",
            ObjectiveText: "自由演练，无固定目标。",
            Map: FreeMap,
            Weather: Weather.Clear,
            Wind: null,
            PlayerFleet: new LevelShipSpec[0],
            EnemyFleet: new LevelShipSpec[0],
            EnemyAiEnabled: true,
            Objective: new LevelObjective(LevelObjectiveType.WinBattle),
            Hints: new[]
            {
                "自由模式无固定目标，可随意演练",
                "布阵阶段可装载任意武器/技能/护甲",
            });

    private static readonly LevelMapSpec FreeMap = LevelMapSpec.FromAscii(
        Enumerable.Repeat("................", 10).ToArray());
}
