#nullable enable
using NavalCombat.Core;

namespace NavalCombat.Levels;

// R-1 纯 C# 整数矩形（避免在数据层引入 Godot Rect2I）：表示布阵区/出口区等网格矩形。
// X/Y 为左上角、Width/Height 为宽高；Contains 采用半开区间（含左/上、不含右/下），与 Rect2I 语义一致。
public readonly record struct GridRect(int X, int Y, int Width, int Height)
{
    public int Right => X + Width;
    public int Bottom => Y + Height;

    public bool Contains(int x, int y) => x >= X && x < Right && y >= Y && y < Bottom;
    public bool Contains(GridPos p) => Contains(p.X, p.Y);
    public override string ToString() => $"GridRect({X},{Y},{Width},{Height})";
}
