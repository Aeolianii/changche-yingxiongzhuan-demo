#nullable enable
using System.Collections.Generic;
using System.Linq;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// L-3 目标追踪器（纯 C#，随玩家命令事件累积 目标判定所需计数）：
//   EnemySunkByWeapon : 各武器（arrow_rain/bombardment/cannon）击沉的敌舰数——攻击命令的事件流中
//                       含敌方 ShipSunkEvent 即计入（沉舰在事件播放时已在 Ships 或 RemovedShips，均可查阵营）。
//   SkillsUsed        : 已使用过的技能 id（连锁弹/火油/损管/布雷；命令类型即可确定，不依赖事件）。
//   PlayerCaptures    : 玩家俘获敌舰数（ShipCapturedEvent，Captor 为玩家）。
// 由战斗控制器在每次玩家命令成功执行后调用 RecordCommand(battle, command, events)；
// 敌方 AI 命令不喂入（敌方施放技能/击沉我方舰不影响目标计数）。
public sealed class LevelObjectiveTracker
{
    public Dictionary<string, int> EnemySunkByWeapon { get; } = new();
    public HashSet<string> SkillsUsed { get; } = new();
    public int PlayerCaptures { get; private set; }

    public void RecordCommand(BattleState battle, BattleCommand command, IReadOnlyList<BattleEvent> events)
    {
        var weapon = WeaponOf(command);
        if (weapon is not null)
            foreach (var e in events)
                if (e is ShipSunkEvent sunk && FactionOf(battle, sunk.ShipId) == FactionId.Enemy)
                    EnemySunkByWeapon[weapon] = EnemySunkByWeapon.GetValueOrDefault(weapon) + 1;
        switch (command)
        {
            case ChainShotCommand: SkillsUsed.Add("chain_shot"); break;
            case FireOilCommand: SkillsUsed.Add("fire_oil"); break;
            case DamageControlCommand: SkillsUsed.Add("damage_control"); break;
            case PlaceMineCommand: SkillsUsed.Add("mine"); break;
        }
        foreach (var e in events)
            if (e is ShipCapturedEvent cap && FactionOf(battle, cap.CaptorId) == FactionId.Player)
                PlayerCaptures++;
    }

    private static string? WeaponOf(BattleCommand command) => command switch
    {
        ArrowRainCommand => "arrow_rain",
        BombardmentCommand => "bombardment",
        CannonCommand => "cannon",
        _ => null,
    };

    // 舰船阵营：存活舰查 battle.Ships；已离场（沉没/逃脱/被俘/交付）舰查 RemovedShips。
    private static FactionId? FactionOf(BattleState battle, string shipId)
    {
        if (battle.Ships.TryGetValue(shipId, out var ship)) return ship.Faction;
        if (battle.RemovedShips.TryGetValue(shipId, out var rec)) return rec.Faction;
        return null;
    }
}
