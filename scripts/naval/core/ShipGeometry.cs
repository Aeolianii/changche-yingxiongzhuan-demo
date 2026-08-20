#nullable enable
using System.Collections.Generic;

namespace NavalCombat.Core;

// 矩形船体几何统一入口（CHG 海怪 Boss 战）：Footprint/TurnCost/枢轴。
// Width=1 时退化为旧线性行为（索引0=船头、向后延伸），与既有船舰完全一致。
public static class ShipGeometry
{
    // 船体占用格（含船头）：索引 0 = 船头（Bow）。u 沿船头反方向（0..Length-1），
    // v 沿右侧（Turn(Right)）（0..Width-1）。列表序 v 外层 → 索引 0 恒为 (u0,v0)=Bow。
    public static List<GridPos> Footprint(ShipDefinition def, GridPos bow, CardinalDirection facing)
    {
        var cells = new List<GridPos>(def.Length * def.Width);
        var right = facing.Turn(TurnDirection.Right);
        for (var v = 0; v < def.Width; v++)
            for (var u = 0; u < def.Length; u++)
                cells.Add(bow + right.Vector() * v - facing.Vector() * u);
        return cells;
    }

    // 转向成本 = (Length-1) + (Width-1)；Width=1 时 = Length-1（与旧行为一致）。
    public static int TurnCost(ShipDefinition def) => (def.Length - 1) + (def.Width - 1);

    // 转轴（重心格）：u 取中央（偶数长取靠船头一格），v 取中央（偶数宽取近船头侧一格）。
    public static GridPos TurnPivot(ShipDefinition def, GridPos bow, CardinalDirection facing)
    {
        var pivotU = (def.Length - 1) / 2;
        var pivotV = def.Width % 2 == 1 ? (def.Width - 1) / 2 : def.Width / 2 - 1;
        return bow + facing.Turn(TurnDirection.Right).Vector() * pivotV - facing.Vector() * pivotU;
    }

    // 转弯后新船头：枢轴不动，新船头 = 枢轴 − 新右侧×pivotV + 新朝向×pivotU。
    public static GridPos NewBowAfterTurn(ShipDefinition def, GridPos pivot, CardinalDirection newFacing)
    {
        var pivotU = (def.Length - 1) / 2;
        var pivotV = def.Width % 2 == 1 ? (def.Width - 1) / 2 : def.Width / 2 - 1;
        return pivot - newFacing.Turn(TurnDirection.Right).Vector() * pivotV + newFacing.Vector() * pivotU;
    }
}
