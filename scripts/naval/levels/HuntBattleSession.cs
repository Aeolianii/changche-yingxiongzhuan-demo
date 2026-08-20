#nullable enable
using Godot;

namespace NavalCombat.Levels;

// CHG-20260819（S-2 海面接入）：讨伐战（海怪/倭寇营寨）接入随机战斗 + 战斗结果返回。
// 与海盗战同构：sea_overworld（GDScript）把讨伐请求写入场景根 meta（RequestMetaKey），切换 NavalDemo；
// NavalDeploymentController._Ready 消费 meta 后经 HuntEncounterGenerator.CreateStage 组装对应 hunt_stage
// 固定遭遇并 Begin 随机遭遇，同时在此登记讨伐会话；
// 结算面板据此判定讨伐战并显示「返回海上大地图」；ReturnToSea 把战斗结果补写回返回 meta 后切回海上大地图。
public static class HuntBattleSession
{
    // 场景根 meta 键（与 sea_overworld.gd 常量同值，字符串保持一致）。
    public const string RequestMetaKey = "sea_hunt_battle_request";
    public const string ReturnMetaKey = "sea_hunt_battle_return_context";

    // 本场讨伐阶段 id（"hunt_stage1/2/3"）。null 表示非讨伐战。
    public static string? StageId { get; private set; }
    // 发起方（sea_overworld）写入请求 meta 的原始上下文（玩家位置/农历日等），
    // 由 Deployment._Ready 消费时暂存，ReturnToSea 构造返回 meta 时以其为基础补结算结果。
    public static Godot.Collections.Dictionary? ReturnContextCarrier { get; private set; }
    public static bool Active => StageId is not null;

    public static void Begin(string stageId, Godot.Collections.Dictionary? returnContext = null)
    {
        StageId = stageId;
        ReturnContextCarrier = returnContext;
    }

    public static void Clear()
    {
        StageId = null;
        ReturnContextCarrier = null;
    }
}
