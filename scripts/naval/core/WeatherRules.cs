#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

public enum Weather { Clear, Cloudy, Rainy, Typhoon }

public static class WeatherRules
{
    // F-1：战斗开始时掷定整场天气与风向（设计 6"天气在战斗开始时确定并保持不变；风向在有风天气确定并保持不变"）。
    // 权重：晴 40% / 阴 30% / 雨 20% / 台风 10%（晴/阴常见、雨较少、台风稀有）。
    // 用 battle.Random（种子化、可复现）：首个 NextInt(0,100) 掷天气；有风天气再掷 NextInt(0,4) 四向风；晴天无风。
    public static void RollStartWeather(BattleState battle)
    {
        var roll = battle.Random.NextInt(0, 100);
        battle.Weather = roll switch
        {
            < 40 => Weather.Clear,
            < 70 => Weather.Cloudy,
            < 90 => Weather.Rainy,
            _ => Weather.Typhoon,
        };
        battle.Wind = AllowsWind(battle) ? (CardinalDirection)battle.Random.NextInt(0, 4) : null;
    }

    // 当前天气是否允许风（weather.json AllowsWind；配置缺失回退：晴天无风、其余有风）
    private static bool AllowsWind(BattleState battle)
        => WeatherDefinitionOf(battle)?.AllowsWind ?? (battle.Weather != Weather.Clear);

    // 当前移动点 = 有效速度档对应的移动点（含负载/天气/连锁弹降级，最低 V1）
    public static int CurrentMovementPoints(BattleState battle, ShipState ship)
    {
        var tier = EffectiveSpeedTier(battle, ship);
        return SpeedTable.MovePoints(tier);
    }

    public static SpeedTier EffectiveSpeedTier(BattleState battle, ShipState ship)
    {
        var tier = ship.Definition.SpeedCap;
        var loadRatio = (double)CurrentLoad(ship) / ship.Definition.LoadCapacity;
        if (loadRatio >= 1.0) tier = Down(tier);
        if (loadRatio >= 0.70) tier = Down(tier);
        if (loadRatio >= 0.40) tier = Down(tier);
        // 天气减速读 battle.Config.Weather（weather.json SpeedModifier），消除硬编码双源（T8 遗留消歧）
        var speedModifier = WeatherSpeedModifier(battle);
        if (speedModifier < 0) tier = Down(tier, -speedModifier);
        // 连锁弹减速：每层减速独立计时（Task 10），每层降一级，最低 V1
        foreach (var _ in ship.SpeedPenalties) tier = Down(tier);
        if (tier == SpeedTier.V0) tier = SpeedTier.V1; // 天气/负载/连锁弹叠加后最低 V1
        return tier;
    }

    // 天气速度修正（雨天 -1、台风 -2）：优先读配置（weather.json），配置缺失时按设计 6 回退硬编码默认
    private static int WeatherSpeedModifier(BattleState battle)
        => WeatherDefinitionOf(battle)?.SpeedModifier
           ?? (battle.Weather == Weather.Rainy ? -1 : battle.Weather == Weather.Typhoon ? -2 : 0);

    // 当前天气对应的 WeatherDefinition（weather.json id 与 Weather 枚举名忽略大小写匹配）；无则 null
    private static WeatherDefinition? WeatherDefinitionOf(BattleState battle)
        => battle.Config.Weather.FirstOrDefault(w =>
            string.Equals(w.Id, battle.Weather.ToString(), StringComparison.OrdinalIgnoreCase));

    // 负载 = 护甲 + 撞角 + 砲击 + 火炮（基础 0；技能不增负载）
    // 撞角按"件数"计负载（设计 3.3"每件+3"且"只能装载一个"）：WeaponCounts["ram"] 是等级（0/1/2/3），
    // 等级 1/2/3 仍是一件 → 一律 +3；等级只影响系数（RamRules.RamCoefficient），不影响负载。
    public static int CurrentLoad(ShipState ship) => DamageRules.TotalLoad(
        baseLoad: 0,
        armorLevel: ship.ArmorLevel,
        rams: ship.WeaponCounts.GetValueOrDefault("ram", 0) > 0 ? 1 : 0,
        bombardments: ship.WeaponCounts.GetValueOrDefault("bombardment", 0),
        cannons: ship.WeaponCounts.GetValueOrDefault("cannon", 0));

    // 风向修正按本回合首次移动前起点与最终位置总位移主轴计算；两轴相等视为侧风。
    // 风向按"来向"命名（North 风自北向南吹）：顺风=位移方向与风吹向一致 → +1；逆风 → -1；侧风 0。
    // 注：简报 Step 3 实现风向符号与此相反，与用例断言冲突；以用例为契约，符号见 CHG-20260807-config-damage-weather 偏差 2。
    public static int WindCorrection(GridPos from, GridPos to, CardinalDirection wind)
    {
        var dx = Math.Abs(to.X - from.X);
        var dy = Math.Abs(to.Y - from.Y);
        if (dx == dy) return 0; // 侧风
        var dominant = dx > dy
            ? (from.X < to.X ? CardinalDirection.East : CardinalDirection.West)
            : (from.Y < to.Y ? CardinalDirection.South : CardinalDirection.North);
        return dominant == wind.Opposite() ? 1 : (dominant == wind ? -1 : 0);
    }

    // 台风完整回合末：每舰当前生命比例伤害（向上取整 ≥1），但不把舰船降至 1 点以下。
    // 伤害比例读 battle.Config.Weather（weather.json TyphoonDamagePercent），配置缺失时回退设计 6 的 5%。
    public static void TyphoonRoundEnd(BattleState battle)
    {
        if (battle.Weather != Weather.Typhoon) return;
        var percent = WeatherDefinitionOf(battle)?.TyphoonDamagePercent ?? 0.05;
        foreach (var ship in battle.Ships.Values)
        {
            if (ship.HitPoints <= 0) continue;
            var dmg = (int)Math.Ceiling(ship.HitPoints * percent);
            ship.HitPoints = Math.Max(1, ship.HitPoints - dmg);
        }
    }

    private static SpeedTier Down(SpeedTier tier, int steps = 1)
    {
        var v = (int)tier - steps;
        return (SpeedTier)Math.Max((int)SpeedTier.V0, v);
    }
}
