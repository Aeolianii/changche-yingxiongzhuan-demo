namespace NavalCombat.Core;

public readonly record struct ShipCost(int Iron, int Wood, int Hemp, int Gold);

public enum Passability
{
    DeepWaterOnly = 1, // 深水可通行，浅滩/礁石不可
    ReefDamaging = 2,  // 浅滩可通行，礁石可通行但损最大生命15%
    FreeAll = 3        // 深水/浅滩/礁石全可自由通行
}

public sealed record ShipDefinition(
    string Id,
    string DisplayName,
    ShipCost Cost,
    int MaxHp,
    int BaseArmor,
    SpeedTier SpeedCap,
    int LoadCapacity,
    int Length,
    Passability Passability,
    int WeaponSlots,
    int SkillSlots,
    int ArmorSlots,
    int BoardingDamage,
    int ArrowRainDamage);
