#nullable enable
using System.Linq;

namespace NavalCombat.Core;

// 敌人回合命令路由（CHG 海怪 Boss 战）：按在场敌舰类型分派。
// 优先级：海怪01（SeaMonster）→ 海怪02（FishSchool）→ 普通舰队（NavalAi）。
public static class AiRouter
{
    public static BattleCommand ChooseNext(BattleState battle, FactionId faction)
    {
        if (battle.Ships.Values.Any(s => s.Faction == faction && s.HitPoints > 0 && s.Definition.IsSeaMonster))
            return SeaMonsterAi.ChooseNext(battle, faction);
        // Task 7：海怪02（鱼群）→ FishSchoolAi。
        if (battle.Ships.Values.Any(s => s.Faction == faction && s.HitPoints > 0 && s.Definition.IsFish))
            return FishSchoolAi.ChooseNext(battle, faction);
        return NavalAi.ChooseNext(battle, faction);
    }
}
