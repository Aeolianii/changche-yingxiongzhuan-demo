#nullable enable
namespace NavalCombat.Core;

// U-2a（CHG-20260812-map-schemes-phase1）新地形共享判定（纯 C#，无 Godot 依赖）：
// 集中"陆地形 / 浅水挡深水限定舰 / 挡视线平射"三类判定，避免各规则类各自 switch 漏判。
// 语义约定：
//   - 陆地（Beach/Forest/Grass/Port/Town/Mountain）对舰船一律不可通行；
//   - 浅水（Shallow/Reef/River 陆河）对深水限定舰（Passability.DeepWaterOnly）不可通行，
//     通过性 ≥2 可通行（陆河按浅滩类似：可走、不损血、自沉成火力点）；
//   - 陆地挡视线与火炮平射（同山地），水面（含陆河）不挡。
public static class TerrainRules
{
    // 陆地形：对舰船一律不可通行（含山地）。
    public static bool IsLand(TerrainType t) => t is TerrainType.Beach
        or TerrainType.Forest or TerrainType.Grass or TerrainType.Port or TerrainType.Town or TerrainType.Mountain;

    // 浅水：深水限定舰不可进（浅滩/礁石/陆河——陆河按浅滩类似，通过性≥2 可走）。
    public static bool IsShallowWater(TerrainType t) => t is TerrainType.Shallow or TerrainType.Reef or TerrainType.River;

    // 该格是否阻挡某舰移动（地形维度）：陆地恒挡；深水限定舰不可进浅水。
    public static bool BlocksShip(TerrainType t, Passability passability)
        => IsLand(t) || (passability == Passability.DeepWaterOnly && IsShallowWater(t));

    // 挡视线/火炮平射：陆地形（同山地）挡；水面（深水/浅滩/礁石/陆河）不挡。
    public static bool BlocksLineOfSight(TerrainType t) => IsLand(t);
}
