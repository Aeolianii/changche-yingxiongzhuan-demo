#nullable enable
using System.Collections.Generic;
using System.IO;
using System.Linq;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// CHG（海怪 Boss 战）：讨伐遭遇组装。三阶段固定遭遇（海怪01→海怪02→大本营），镜像随机遭遇的
// RandomEncounterGenerator.CreateFromDefinition 路径（同会话进入：布阵→战斗→结算）。
public static class HuntEncounterGenerator
{
    public static IReadOnlyList<EncounterDefinition> Stages { get; } = EncounterDefinitionRegistry.All
        .Where(d => d.Id.StartsWith("hunt_stage"))
        .OrderBy(d => d.Id)
        .ToList();

    public static RandomEncounter CreateStage(NavalRulesConfig config, string stageId)
    {
        var def = EncounterDefinitionRegistry.GetById(stageId)
            ?? throw new InvalidDataException($"讨伐遭遇未注册：{stageId}");
        return RandomEncounterGenerator.CreateFromDefinition(config, def);
    }
}
