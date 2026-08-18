#nullable enable
using System.Collections.Generic;
using NavalCombat.Core;

namespace NavalCombat.Levels;

// L-1 关卡单舰规格：ShipTypeId 对应 data/naval/ships.json 的舰型 id（如 "flagship"/"frigate"），
// 布阵位置 Bow（船头格）/朝向 Facing / 装备装载 Equipment（可选）/ 是否布阵自沉 SelfSunk（可选，布阵自沉教学用）。
// L-3 按此规格构建 BattleState.ShipState（参照 NavalDeploymentController.AddFleetShips 的装载方式）。
public sealed record LevelShipSpec(
    string ShipTypeId,
    GridPos Bow,
    CardinalDirection Facing,
    LevelEquipmentSpec? Equipment = null,
    bool SelfSunk = false);

// L-1 舰船装备规格：映射 ShipState 三处装载——
//   Weapons   : 武器类型ID → 件数   → ShipState.WeaponCounts（NavalDeploymentController 默认旗舰火炮/护卫砲击同款）
//   Skills    : 技能类型ID → 槽位数 → ShipState.SkillLoadout（战斗开始由 SkillSeeding.Seed 播种 SkillUsesLeft）
//   ArmorLevel: 护甲等级；null = 用舰型 BaseArmor（与 Demo 初始 ArmorLevel=def.BaseArmor 同语义）
public sealed record LevelEquipmentSpec(
    IReadOnlyDictionary<string, int>? Weapons = null,
    IReadOnlyDictionary<string, int>? Skills = null,
    int? ArmorLevel = null);
