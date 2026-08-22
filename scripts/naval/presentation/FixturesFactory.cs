#nullable enable
using NavalCombat.Core;
using System.Linq;

namespace NanjiangNaval;

// 演示用种子战斗工厂：无 data 配置，手工 ShipDefinition 造几艘舰并放玩家/敌方阵营。
// Task 6 起改由 NavalConfigLoader 从 data/naval 加载真实配置。
public static class FixturesFactory
{
    public static BattleState CreateDemoBattle()
    {
        // UX-1：48×36，稀疏地形 + 双方各 4 舰，镜像 NavalDeploymentController 默认阵型（保持一致可复现）。
        var map = new BattleMap(48, 36);
        for (var x = 0; x < 48; x++)
            for (var y = 0; y < 36; y++)
                map.SetTerrain(new GridPos(x, y), TerrainType.DeepWater);
        map.SetTerrain(new GridPos(3, 8), TerrainType.Mountain);
        map.SetTerrain(new GridPos(5, 30), TerrainType.Mountain);
        map.SetTerrain(new GridPos(23, 3), TerrainType.Mountain);
        map.SetTerrain(new GridPos(42, 30), TerrainType.Mountain);
        map.SetTerrain(new GridPos(44, 6), TerrainType.Mountain);
        map.SetTerrain(new GridPos(8, 20), TerrainType.Shallow);
        map.SetTerrain(new GridPos(21, 33), TerrainType.Shallow);
        map.SetTerrain(new GridPos(26, 4), TerrainType.Shallow);
        map.SetTerrain(new GridPos(45, 24), TerrainType.Shallow);
        map.SetTerrain(new GridPos(11, 16), TerrainType.Reef);
        map.SetTerrain(new GridPos(23, 30), TerrainType.Reef);
        map.SetTerrain(new GridPos(40, 18), TerrainType.Reef);
        var battle = new BattleState { Map = map, Config = NavalRulesConfig.Default(), Random = new SeedRandomSource(1) };

        AddShip(battle, "p1", Flagship(), FactionId.Player, new GridPos(21, 6), CardinalDirection.East);
        AddShip(battle, "p2", Frigate(), FactionId.Player, new GridPos(21, 13), CardinalDirection.East);
        AddShip(battle, "p3", Transport(), FactionId.Player, new GridPos(22, 26), CardinalDirection.East);
        AddShip(battle, "p4", Merchant(), FactionId.Player, new GridPos(22, 27), CardinalDirection.East);
        AddShip(battle, "e1", Flagship(), FactionId.Enemy, new GridPos(26, 6), CardinalDirection.West);
        AddShip(battle, "e2", Frigate(), FactionId.Enemy, new GridPos(26, 13), CardinalDirection.West);
        AddShip(battle, "e3", Frigate(), FactionId.Enemy, new GridPos(30, 22), CardinalDirection.West);
        AddShip(battle, "e4", Transport(), FactionId.Enemy, new GridPos(26, 26), CardinalDirection.West);
        ExitCellRules.EnsureSafeExits(map, battle.Ships.Values.SelectMany(s => s.OccupiedCells()));
        return battle;
    }

    private static void AddShip(BattleState battle, string id, ShipDefinition def, FactionId faction, GridPos bow, CardinalDirection facing)
    {
        var ship = new ShipState
        {
            Id = id,
            Definition = def,
            Faction = faction,
            Bow = bow,
            Facing = facing,
            HitPoints = def.MaxHp,
            ArmorLevel = def.BaseArmor,
        };
        ship.RemainingMovement = WeatherRules.CurrentMovementPoints(battle, ship);
        ship.TurnStartBow = bow; // F-1：风向修正起点快照（与首回合移动点一致）
        battle.Ships[id] = ship;
    }

    public static ShipDefinition Flagship() => new(
        Id: "flagship", DisplayName: "旗舰", Cost: new ShipCost(0, 2, 1, 100), MaxHp: 100,
        BaseArmor: 1, SpeedCap: SpeedTier.V3, LoadCapacity: 5, Length: 3, Passability: Passability.DeepWaterOnly,
        WeaponSlots: 7, SkillSlots: 4, ArmorSlots: 5, BoardingDamage: 350, ArrowRainDamage: 200);

    public static ShipDefinition Frigate() => new(
        Id: "frigate", DisplayName: "护卫舰", Cost: new ShipCost(1, 3, 3, 350), MaxHp: 200,
        BaseArmor: 2, SpeedCap: SpeedTier.V4, LoadCapacity: 15, Length: 2, Passability: Passability.ReefDamaging,
        WeaponSlots: 3, SkillSlots: 2, ArmorSlots: 3, BoardingDamage: 200, ArrowRainDamage: 100);

    public static ShipDefinition Transport() => new(
        Id: "transport", DisplayName: "运输船", Cost: new ShipCost(3, 4, 3, 500), MaxHp: 350,
        BaseArmor: 2, SpeedCap: SpeedTier.V4, LoadCapacity: 20, Length: 1, Passability: Passability.ReefDamaging,
        WeaponSlots: 1, SkillSlots: 1, ArmorSlots: 1, BoardingDamage: 120, ArrowRainDamage: 50);

    public static ShipDefinition Merchant() => new(
        Id: "merchant", DisplayName: "商船", Cost: new ShipCost(5, 8, 5, 2000), MaxHp: 1000,
        BaseArmor: 3, SpeedCap: SpeedTier.V4, LoadCapacity: 35, Length: 2, Passability: Passability.FreeAll,
        WeaponSlots: 2, SkillSlots: 2, ArmorSlots: 2, BoardingDamage: 100, ArrowRainDamage: 70);
}
