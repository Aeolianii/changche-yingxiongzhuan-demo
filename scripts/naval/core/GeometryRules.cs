using System;
using System.Collections.Generic;

namespace NavalCombat.Core;

public static class GeometryRules
{
    public static int NearestSquaredDistance(List<GridPos> a, List<GridPos> b)
    {
        var best = int.MaxValue;
        foreach (var ca in a)
            foreach (var cb in b)
                best = Math.Min(best, ca.SquaredDistance(cb));
        return best;
    }
    public static bool InCircularRange(ShipState source, ShipState target, int radius)
        => NearestSquaredDistance(source.OccupiedCells(), target.OccupiedCells()) <= radius * radius;

    // UX-1 扫描窗口：以舰船各占格为中心、按 radius 扩展、并按地图边界裁剪的行优先扫描范围 (MinX..MaxX, MinY..MaxY)。
    // 供 QueryAttackArcs/QueryChainShotCells/QueryFireOilCells/QueryMineCells 等"射程限定"查询代替全图 O(W×H) 扫描：
    // 距任一占格 > radius 的格不可能进入这些查询的射程窗口，必然被 Validate 拒绝，故结果集与全图扫描完全一致（纯性能优化）。
    public static (int MinX, int MaxX, int MinY, int MaxY) ScanWindow(ShipState ship, int radius, BattleMap map)
    {
        var minX = int.MaxValue; var maxX = int.MinValue;
        var minY = int.MaxValue; var maxY = int.MinValue;
        foreach (var c in ship.OccupiedCells())
        {
            if (c.X < minX) minX = c.X;
            if (c.X > maxX) maxX = c.X;
            if (c.Y < minY) minY = c.Y;
            if (c.Y > maxY) maxY = c.Y;
        }
        return (
            Math.Max(0, minX - radius), Math.Min(map.Width - 1, maxX + radius),
            Math.Max(0, minY - radius), Math.Min(map.Height - 1, maxY + radius));
    }
}
