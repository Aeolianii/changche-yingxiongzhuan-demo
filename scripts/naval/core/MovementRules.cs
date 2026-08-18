#nullable enable
using System;
using System.Collections.Generic;
using System.Linq;

namespace NavalCombat.Core;

// Task 12：MineEvents 承载成功平移后触雷/探测产生的额外事件（设计 13.1），由 ActionResolver.Move 并入事件流。
public sealed record MoveOutcome(bool Success, string? Reason = null, int ReefDamage = 0, BattleEvent[]? MineEvents = null);

public static class MovementRules
{
    // 转向成本 = 舰船占格长度减 1（设计 5.2）。规则与表现层（HUD）共用同一查询，避免双源。
    public static int TurnCost(ShipState ship) => ship.Length - 1;

    public static MoveOutcome TryTranslate(BattleState battle, ShipState ship, CardinalDirection dir)
    {
        if (ship.SelfSunk) return new(false, "action.self_sunk_immobile");
        if (ship.HasAttacked) return new(false, "action.attack_ended_movement");
        // F-1：风向修正按本回合首次移动前起点（TurnStartBow）与当前位置净位移主轴（顺风 +1 / 逆风 -1 / 侧风 0）。
        // 起点未记录（无风或未拍快照）时退化为原点=当前位置，修正 0，行为与无风一致（既有冒烟不回归）。
        var origin = ship.TurnStartBow ?? ship.Bow;
        var windBonus = battle.Wind is { } wind ? WeatherRules.WindCorrection(origin, ship.Bow, wind) : 0;
        if (ship.RemainingMovement + windBonus < 1) return new(false, "movement.no_points");
        var offset = dir.Vector();
        var destination = ship.OccupiedCells().Select(c => c + offset).ToList();
        if (!FootprintValid(battle, destination, ship))
            return new(false, "movement.blocked");
        // 礁石进入伤害（通过性2）。取整统一 .5 向上（设计 8，Task 18 B5）。
        // 修复（评审 Important）：多格舰跨多个礁格时取各格伤害最大值而非逐格覆盖赋值的"最后值"——
        // 当前各格乘数相同（均为 15%）结果不变，但未来若各格伤害乘数不同则不应静默取最后一个。
        var reefDamage = 0;
        foreach (var cell in destination)
            if (battle.Map.TerrainAt(cell) == TerrainType.Reef && ship.Definition.Passability == Passability.ReefDamaging)
                reefDamage = Math.Max(reefDamage, (int)Math.Round(ship.MaxHp * 0.15, MidpointRounding.AwayFromZero));
        // OccupiedCells 索引0=船头，故目标船头是 destination[0]
        ship.Bow = destination[0];
        ship.RemainingMovement -= 1;
        ship.SpentMovement += 1;
        if (reefDamage > 0) ship.HitPoints -= reefDamage;
        ship.LastMoveDirection = dir; // Task 9：记录最后一段平移方向（撞击资格，设计 10）
        // Task 12：成功平移后挂水雷探测 + 正常触发（设计 13.1）。友军不触发；触发不阻塞移动，未沉仍可继续。
        var mineEvents = MineRules.AfterShipMoved(battle, ship);
        return new(true, ReefDamage: reefDamage, MineEvents: mineEvents);
    }

    public static MoveOutcome TryTurn(BattleState battle, ShipState ship, TurnDirection turn)
    {
        if (ship.SelfSunk) return new(false, "action.self_sunk_immobile");
        if (ship.HasAttacked) return new(false, "action.attack_ended_movement");
        var cost = TurnCost(ship);
        if (ship.RemainingMovement < cost) return new(false, "movement.not_enough_points");
        var oldFacing = ship.Facing;
        var oldBow = ship.Bow;
        var newFacing = oldFacing.Turn(turn);
        // 转轴索引：奇数长=中央格；偶数长=两个中央格中靠近船头的一格
        var pivotIndex = ship.Length % 2 == 1 ? (ship.Length - 1) / 2 : ship.Length / 2 - 1;
        var oldCells = ship.OccupiedCells();
        var pivot = oldCells[pivotIndex];
        // 转轴在世界坐标不动，新船头 = 转轴 + 新朝向 × 转轴索引
        // （简报原文为 `-`，经推导应为 `+`：newCells[pivotIndex] = newBow - newFacing*pivotIndex ≡ pivot）
        var newBow = pivot + newFacing.Vector() * pivotIndex;
        ship.Bow = newBow;
        ship.Facing = newFacing;
        if (!FootprintValid(battle, ship.OccupiedCells(), ship))
        {
            ship.Bow = oldBow; // 回滚
            ship.Facing = oldFacing;
            return new(false, "movement.turn_blocked");
        }
        ship.RemainingMovement -= cost;
        ship.SpentMovement += cost;
        ship.LastMoveDirection = null; // Task 9：原地转向后不能启用撞击（设计 10）
        // Task 18 B6 裁定：转向使新占格进入礁石同样触发通过性2 的 15% 最大生命伤害（设计 5.3
        // 「礁石可通行，但损失最大生命15%」按占格语义统一，与平移/撞击推动入礁同口径）。
        // 取整统一 .5 向上；事件语义与平移入礁一致（不额外发事件，伤害随本次命令静默结算）。
        var reefDamage = 0;
        foreach (var cell in ship.OccupiedCells())
            if (battle.Map.TerrainAt(cell) == TerrainType.Reef && ship.Definition.Passability == Passability.ReefDamaging)
            {
                reefDamage = (int)Math.Round(ship.MaxHp * 0.15, MidpointRounding.AwayFromZero);
                break;
            }
        if (reefDamage > 0) ship.HitPoints -= reefDamage;
        // Task 12 修复：转向成功后新占格同样可能压上/靠近水雷 → 统一刷新探测 + 正常触发（设计 13.1）。
        // 水雷不阻塞转向本身；事件由 ActionResolver.Turn 并入事件流（与 TryTranslate 的 MineEvents 同语义）。
        var mineEvents = MineRules.RefreshMines(battle);
        return new(true, ReefDamage: reefDamage, MineEvents: mineEvents);
    }

    public static bool FootprintValid(BattleState battle, List<GridPos> cells, ShipState mover)
    {
        foreach (var c in cells)
        {
            if (!battle.Map.InBounds(c)) return false;
            if (battle.Map.IsWreck(c)) return false;
            var t = battle.Map.TerrainAt(c);
            // U-2a：陆地恒不可通行；深水限定舰不可进浅水（浅滩/礁石/陆河），经 TerrainRules 统一判定。
            if (TerrainRules.BlocksShip(t, mover.Definition.Passability)) return false;
        }
        // 不可穿过其他舰船
        foreach (var other in battle.Ships.Values)
        {
            if (other.Id == mover.Id || other.HitPoints <= 0) continue;
            if (other.OccupiedCells().Any(cells.Contains)) return false;
        }
        return true;
    }
}
