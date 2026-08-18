#nullable enable
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

// Task 11 结转（T13 播种）：战斗初始化时按技能配置播种 SkillUsesLeft（每槽位 × 每场次数）。
// F-5：布阵阶段 BuildFleet 按 DemoSkillLayout 预置每舰 SkillLoadout（技能id → 槽位数），
// 玩家可在布阵装备面板增删；Seed 只读配置 + 初始化，不改任何结算逻辑；规则测试自建战斗自行播种或留空，不受影响。
public static class SkillSeeding
{
    // 演示默认技能位布局（舰型 → 技能id列表，每项占用 1 个技能位）。技能 id 必须存在于 skills.json，否则该位忽略。
    // merchant 双雷位供三雷连锁演示；flagship 全技能；frigate {连锁弹,损管} 无火油（既有 scene_smoke 断言）。
    public static readonly IReadOnlyDictionary<string, string[]> DemoSkillLayout = new Dictionary<string, string[]>
    {
        { "flagship", new[] { "chain_shot", "fire_oil", "damage_control", "mine" } },
        { "frigate", new[] { "chain_shot", "damage_control" } },
        { "merchant", new[] { "mine", "mine" } },
        { "transport", new[] { "damage_control" } },
    };

    // 播种：SkillUsesLeft[skill] = SkillLoadout 中该技能槽位数 × skills.json 的 UsesPerSlot。
    // 幂等：先清空再按当前配置重播（战斗初始化/重进调用安全；SkillLoadout 为空 = 无技能）。
    public static void Seed(BattleState battle)
    {
        foreach (var ship in battle.Ships.Values)
        {
            ship.SkillUsesLeft.Clear();
            foreach (var (skillId, count) in ship.SkillLoadout)
            {
                if (count <= 0) continue;
                var def = battle.Config.Skills.FirstOrDefault(s => s.Id == skillId);
                if (def is null) continue;
                ship.SkillUsesLeft[skillId] = ship.SkillUsesLeft.GetValueOrDefault(skillId) + def.UsesPerSlot * count;
            }
        }
    }
}
