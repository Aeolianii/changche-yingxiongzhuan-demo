#nullable enable
using System.Collections.Generic;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// L-1 章节：第1章基础操控 / 第2章作战进阶 / 第3章环境特殊 + 自由模式（沙盒，不进解锁序列）。
// V-4：追加「测试关卡」章——固定地图×敌人组合演练（EncounterDefinitionRegistry 配对），不进解锁序列。
public enum LevelChapter
{
    Chapter1,
    Chapter2,
    Chapter3,
    Free,
    Test,
}

// L-1 单关定义（不可变 record，纯数据层）：
//   Id             关卡 id，如 "1-1"/"free"
//   Chapter        章节（LevelChapter）
//   Title/Description/ObjectiveText  标题/描述/给玩家看的目标文本
//   Map            关卡地图（LevelMapSpec：宽高 + ASCII 地形网格）
//   Weather        固定该关天气（Core.Weather：Clear/Cloudy/Rainy/Typhoon）
//   Wind           固定风向（可选；无风关卡为 null）
//   PlayerFleet/EnemyFleet  双方舰队（List<LevelShipSpec>）
//   EnemyAiEnabled 敌舰是否由 NavalAi 驱动（false = 敌舰不动，教学关）
//   Objective      关卡目标（LevelObjective；判定 L-3 做）
//   Hints          分步教学提示（L-3 显示）
public sealed record LevelDefinition(
    string Id,
    LevelChapter Chapter,
    string Title,
    string Description,
    string ObjectiveText,
    LevelMapSpec Map,
    Weather Weather,
    CardinalDirection? Wind,
    IReadOnlyList<LevelShipSpec> PlayerFleet,
    IReadOnlyList<LevelShipSpec> EnemyFleet,
    bool EnemyAiEnabled,
    LevelObjective Objective,
    IReadOnlyList<string> Hints);
