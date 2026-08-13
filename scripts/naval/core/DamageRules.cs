using System;

namespace NavalCombat.Core;

public sealed record DamagePacket(double BaseDamage, int ArmorLevel, bool IgnoresArmor);
public sealed record DamageResult(int FinalDamage);

public static class DamageRules
{
    public const double ArmorReductionPerLevel = 0.10;
    public const double ArmorMaxReduction = 0.80;

    // 负载 = 基础负载 + 护甲每级 +3 + 撞角每件 +3 + 砲击每件 +3 + 火炮每门 +4（技能本身不增负载）
    public static int TotalLoad(int baseLoad, int armorLevel, int rams, int bombardments, int cannons)
        => baseLoad + armorLevel * 3 + rams * 3 + bombardments * 3 + cannons * 4;

    // 可减免伤害按 护甲每级 -10%、上限 80%；最终伤害 .5 四舍五入（AwayFromZero），成功攻击至少 1 点
    public static DamageResult Calculate(DamagePacket packet)
    {
        var reduction = packet.IgnoresArmor
            ? 0.0
            : Math.Min(packet.ArmorLevel * ArmorReductionPerLevel, ArmorMaxReduction);
        var final = Math.Round(packet.BaseDamage * (1.0 - reduction), MidpointRounding.AwayFromZero);
        return new DamageResult(Math.Max(1, (int)final));
    }
}
