namespace NavalCombat.Core;

public interface IRandomSource
{
    double NextDouble();
    int NextInt(int minInclusive, int maxExclusive);
}

public sealed class SeedRandomSource : IRandomSource
{
    private readonly System.Random _random;
    public SeedRandomSource(int seed) => _random = new System.Random(seed);
    public double NextDouble() => _random.NextDouble();
    public int NextInt(int minInclusive, int maxExclusive) => _random.Next(minInclusive, maxExclusive);
}

// 无种子随机源（Task 16 网关 BuildBattleState 的 RandomSeed 缺省路径）：每次开战结果不要求可复现。
public sealed class UnseededRandomSource : IRandomSource
{
    private readonly System.Random _random = new();
    public double NextDouble() => _random.NextDouble();
    public int NextInt(int minInclusive, int maxExclusive) => _random.Next(minInclusive, maxExclusive);
}
