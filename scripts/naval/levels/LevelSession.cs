#nullable enable
namespace NavalCombat.Levels;

// L-2 关卡会话（跨场景传递）：点关卡/自由模式进入游玩场景前写入 PendingLevelId，
// 游玩场景（L-2 为 NavalDemo 占位，L-3 改关卡场景）_Ready 时读取构建关卡战斗。
// 默认 "free"：直接以主场景启动（LevelSelect 未进入任何关）仍视为自由模式。
public static class LevelSession
{
    public static string PendingLevelId { get; private set; } = "free";

    public static void EnterLevel(string id) => PendingLevelId = id;
}
