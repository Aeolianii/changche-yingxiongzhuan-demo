#nullable enable
using Godot;

namespace NavalCombat.Levels;

// CHG-20260817-pirate-random-battle：海盗战接入随机战斗 + 战斗结果返回。
// sea_overworld（GDScript）不能直接调用 C# 静态类，沿用项目 meta 互操作模式：
//   1) sea_overworld 把海盗战请求写入场景根 meta（RequestMetaKey），切换 NavalDemo；
//   2) NavalDeploymentController._Ready 消费 meta 后 Begin 随机遭遇，并在此登记海盗会话；
//   3) 结算面板据此判定海盗战并显示「返回海上大地图」；
//   4) ReturnToSea 把战斗结果补写回返回 meta（ReturnMetaKey）后切回海上大地图。
public static class PirateBattleSession
{
    // 场景根 meta 键（与 sea_overworld.gd 常量同值，字符串保持一致）。
    public const string RequestMetaKey = "sea_pirate_battle_request";
    public const string ReturnMetaKey = "sea_pirate_battle_return_context";

    // 本场海盗战身份：海盗节点名（"PirateShip%d"）与所选难度。null 表示非海盗战。
    public static string? PirateId { get; private set; }
    public static int Difficulty { get; private set; }
    // 发起方（sea_overworld）写入请求 meta 的原始上下文（玩家位置/农历日等），
    // 由 Deployment._Ready 消费时暂存，ReturnToSea 构造返回 meta 时以其为基础补结算结果。
    public static Godot.Collections.Dictionary? ReturnContextCarrier { get; private set; }
    public static bool Active => PirateId is not null;

    public static void Begin(string pirateId, int difficulty, Godot.Collections.Dictionary? returnContext = null)
    {
        PirateId = pirateId;
        Difficulty = difficulty;
        ReturnContextCarrier = returnContext;
    }

    public static void Clear()
    {
        PirateId = null;
        ReturnContextCarrier = null;
    }
}
