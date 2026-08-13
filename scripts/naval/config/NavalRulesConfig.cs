using System.Collections.Generic;

namespace NavalCombat.Core;

// 配置容器：由 NavalConfigLoader 从 data/naval/*.json 反序列化产出的完整平衡配置。
public sealed record NavalRulesConfig
{
    public List<ShipDefinition> Ships { get; init; } = new();
    public List<WeaponDefinition> Weapons { get; init; } = new();
    public List<SkillDefinition> Skills { get; init; } = new();
    public List<WeatherDefinition> Weather { get; init; } = new();

    public static NavalRulesConfig Default() => new();
}

// 武器定义：撞角/砲击/火炮等级伤害与负载（spec 4.2）
public sealed record WeaponDefinition(
    string Id,
    string DisplayName,
    int LoadCost,
    int? MaxCount,                    // null = 不限件数（受武位约束）
    int[] DamageByLevel,              // 等级 → 单件/单门伤害
    double[] MultiplierByLevel);      // 撞角：等级(0=未装) → 系数；非撞角武器为空

// 技能定义：次数与参数（spec 4.3）
public sealed record SkillDefinition(
    string Id,
    string DisplayName,
    int UsesPerSlot,
    int MinRange,
    int MaxRange,
    int? SlowLevels = null,           // 连锁弹：减速级数
    int? SlowRounds = null,           // 连锁弹：减速持续回合
    int? BurnRounds = null,           // 火油：燃烧持续回合
    int? InstantHealPercent = null,   // 损管：瞬时回复最大生命比例
    int? RegenRounds = null,          // 损管：后续恢复回合数
    int? RegenPercent = null);        // 损管：每回合恢复最大生命比例

// 天气定义：速度/视野修正与台风伤害比例（spec 4.4）
public sealed record WeatherDefinition(
    string Id,
    string DisplayName,
    bool AllowsWind,
    int SpeedModifier,                // 雨天 -1、台风 -2
    int VisionModifier,               // 阴/雨 -1、台风 -3
    double TyphoonDamagePercent);     // 台风回合末当前生命比例（0.05）
