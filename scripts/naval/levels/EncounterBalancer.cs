#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// CHG（海怪 Boss 战收尾）：难度计算——敌我强度配平，使玩家在匹配难度下较容易获胜。
// 友好系数（敌方目标强度 = 玩家 × 系数，恒 <1）：简单 0.5 / 普通 0.65 / 困难 0.8；教学关/讨伐/自由按普通 0.65。
// 战斗中敌方总强度超目标 → 等比降敌舰 HitPoints（不动位置/朝向/装备）；不超则原样。
public static class EncounterBalancer
{
    public const double FriendlyRatio = 0.65; // 默认友好系数（无难度/教学关/讨伐）

    public static double FriendlyCoefficient(int difficulty) => difficulty switch
    {
        RandomEnemyFleetGenerator.MinDifficulty => 0.5, // 简单
        2 => FriendlyRatio,                              // 普通
        _ => 0.8,                                        // 困难
    };

    // 敌我强度比（敌/玩家）：>1 敌方更强；≤FriendlyRatio 玩家明显占优。
    public static double Ratio(int playerStrength, int enemyStrength)
        => playerStrength <= 0 ? 1.0 : (double)enemyStrength / playerStrength;

    // 舰队强度（ShipState 版，配平时玩家为实际布阵舰队）。
    public static int PlayerStrength(IEnumerable<ShipState> playerShips)
        => playerShips.Where(s => s.HitPoints > 0).Sum(s => RandomEnemyFleetGenerator.ShipStrength(s.Definition));
    public static int EnemyStrength(IEnumerable<ShipState> enemyShips)
        => enemyShips.Where(s => s.HitPoints > 0).Sum(s => RandomEnemyFleetGenerator.ShipStrength(s.Definition));

    // 有效难度：固定关/讨伐（CreateFromDefinition 恒置 Difficulty 1）无视其难度、统一按普通（2，友好系数 0.65）；
    // 随机遭遇透传所选难度；无遭遇（教学关/自由）按普通（2）。
    public static int EffectiveDifficulty(RandomEncounter? encounter)
        => encounter is not null && encounter.IsFixed ? 2 : (encounter?.Difficulty ?? 2);

    // 配平系数：敌方超目标返回 <1 的削血系数，否则 1.0。
    public static double BalanceFactor(int playerStrength, int enemyStrength, int difficulty)
    {
        var target = playerStrength * FriendlyCoefficient(difficulty);
        if (target <= 0 || enemyStrength <= target) return 1.0;
        return target / enemyStrength;
    }

    // 对战斗应用配平：玩家实际舰队 vs 敌舰队，超友好目标则等比降敌舰 HitPoints（最少 1）。
    // 在战斗开始前（ConfirmDeployment → StartBattle 之间）调用。
    public static void BalanceEnemyFleet(BattleState battle, int difficulty)
    {
        var player = battle.Ships.Values.Where(s => s.Faction == FactionId.Player).ToList();
        var enemy = battle.Ships.Values.Where(s => s.Faction == FactionId.Enemy).ToList();
        var factor = BalanceFactor(PlayerStrength(player), EnemyStrength(enemy), difficulty);
        if (factor >= 1.0) return;
        foreach (var s in enemy)
            if (s.HitPoints > 0)
                s.HitPoints = Math.Max(1, (int)Math.Round(s.HitPoints * factor, MidpointRounding.AwayFromZero));
    }
}
