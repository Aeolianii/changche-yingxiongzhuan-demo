using System;

namespace NavalCombat.Core;

public readonly record struct GridPos(int X, int Y)
{
    public int SquaredDistance(GridPos other)
    {
        var dx = X - other.X;
        var dy = Y - other.Y;
        return checked(dx * dx + dy * dy);
    }
    public static GridPos operator +(GridPos a, GridPos b) => new(a.X + b.X, a.Y + b.Y);
    public static GridPos operator -(GridPos a, GridPos b) => new(a.X - b.X, a.Y - b.Y);
    public static GridPos operator *(GridPos p, int k) => new(p.X * k, p.Y * k);
}

public enum CardinalDirection { North, East, South, West }

public enum TurnDirection { Left, Right }

public enum FactionId { Player, Enemy }

public enum SpeedTier { V0, V1, V2, V3, V4 }

public static class SpeedTable
{
    public static int MovePoints(SpeedTier tier) => tier switch
    {
        SpeedTier.V0 => 0,
        SpeedTier.V1 => 2,
        SpeedTier.V2 => 4,
        SpeedTier.V3 => 7,
        SpeedTier.V4 => 9,
        _ => throw new ArgumentOutOfRangeException(nameof(tier))
    };
}

public static class CardinalDirectionExtensions
{
    public static GridPos Vector(this CardinalDirection d) => d switch
    {
        CardinalDirection.North => new GridPos(0, -1),
        CardinalDirection.East => new GridPos(1, 0),
        CardinalDirection.South => new GridPos(0, 1),
        CardinalDirection.West => new GridPos(-1, 0),
        _ => throw new ArgumentOutOfRangeException(nameof(d))
    };
    public static CardinalDirection Opposite(this CardinalDirection d) => d switch
    {
        CardinalDirection.North => CardinalDirection.South,
        CardinalDirection.South => CardinalDirection.North,
        CardinalDirection.East => CardinalDirection.West,
        CardinalDirection.West => CardinalDirection.East,
        _ => throw new ArgumentOutOfRangeException(nameof(d))
    };
    public static CardinalDirection Turn(this CardinalDirection d, TurnDirection t) => t switch
    {
        TurnDirection.Left => d switch
        {
            CardinalDirection.North => CardinalDirection.West,
            CardinalDirection.West => CardinalDirection.South,
            CardinalDirection.South => CardinalDirection.East,
            CardinalDirection.East => CardinalDirection.North,
            _ => throw new ArgumentOutOfRangeException(nameof(d))
        },
        TurnDirection.Right => d switch
        {
            CardinalDirection.North => CardinalDirection.East,
            CardinalDirection.East => CardinalDirection.South,
            CardinalDirection.South => CardinalDirection.West,
            CardinalDirection.West => CardinalDirection.North,
            _ => throw new ArgumentOutOfRangeException(nameof(d))
        },
        _ => throw new ArgumentOutOfRangeException(nameof(t))
    };
}
