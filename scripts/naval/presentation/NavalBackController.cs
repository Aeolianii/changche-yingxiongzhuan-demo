#nullable enable
using Godot;
using NavalCombat.Levels; // CHG-20260817：海盗战会话/随机遭遇会话清理

namespace NanjiangNaval;

// L-2 返回关卡选择（主菜单）：NavalDemo 右上角「返回关卡选择」按钮 → 切回 LevelSelect.tscn。
// CanvasLayer 顶层按钮，布阵/战斗阶段均可用（不随 Node2D 隐藏）。L-3 可在战斗中加确认/改行为。
public partial class NavalBackController : CanvasLayer
{
    private const string ReturnBrushPath = "res://assets/naval/ui/level_select_return_brush.png";

    public override void _Ready()
    {
        if (GetNodeOrNull<Button>("BackButton") is { } btn)
        {
            // CHG-20260818：竹简关卡选择菜单只属于「水师操演」入口；大地图（海盗战/讨伐战）触发的战斗
            // 直接进布阵→战斗，不暴露竹简菜单——故海盗战/讨伐战激活时隐藏「返回关卡选择」按钮，
            // 退出统一走结算面板的「返回海上大地图」。
            // CHG-20260819（S-2 海面接入）：讨伐战（海怪/营寨）同海盗战处理。
            if (PirateBattleSession.Active || HuntBattleSession.Active)
            {
                btn.Visible = false;
                return;
            }
            var brush = GD.Load<Texture2D>(ReturnBrushPath);
            StyleBrushButton(btn, brush);
            btn.FocusMode = Control.FocusModeEnum.None;
            // CHG-20260817：返回关卡选择时中止海盗战——清掉未消费的请求 meta 与进行中的随机遭遇，
            // 避免返回后下一次进入 NavalDemo 时残留海盗战会话/遭遇状态。
            // CHG-20260819（S-2 海面接入）：讨伐战请求 meta/会话一并清理。
            btn.Pressed += () =>
            {
                var root = GetTree().Root;
                if (root.HasMeta(PirateBattleSession.RequestMetaKey))
                    root.RemoveMeta(PirateBattleSession.RequestMetaKey);
                if (root.HasMeta(HuntBattleSession.RequestMetaKey))
                    root.RemoveMeta(HuntBattleSession.RequestMetaKey);
                PirateBattleSession.Clear();
                HuntBattleSession.Clear();
                RandomEncounterSession.Clear();
                GetTree().ChangeSceneToFile("res://scenes/naval/LevelSelect.tscn");
            };
        }
    }

    private static void StyleBrushButton(Button button, Texture2D brush)
    {
        button.TextureFilter = CanvasItem.TextureFilterEnum.Nearest;
        button.MouseDefaultCursorShape = Control.CursorShape.PointingHand;
        button.AddThemeStyleboxOverride("normal", BrushStyle(brush, Colors.White));
        button.AddThemeStyleboxOverride("hover", BrushStyle(brush, new Color(1.0f, 0.94f, 0.78f, 1.0f)));
        button.AddThemeStyleboxOverride("pressed", BrushStyle(brush, new Color(0.72f, 0.76f, 0.72f, 1.0f)));
        button.AddThemeStyleboxOverride("focus", BrushStyle(brush, Colors.White));
        button.AddThemeFontOverride("font", InkWashTheme.Font());
        button.AddThemeFontSizeOverride("font_size", 18);
        button.AddThemeColorOverride("font_color", InkWashTheme.PaperLight);
        button.AddThemeColorOverride("font_hover_color", new Color("f0cf79"));
        button.AddThemeColorOverride("font_pressed_color", Colors.White);
        button.AddThemeColorOverride("font_outline_color", InkWashTheme.InkDeep);
        button.AddThemeConstantOverride("outline_size", 4);
    }

    private static StyleBoxTexture BrushStyle(Texture2D brush, Color tint)
    {
        var style = new StyleBoxTexture
        {
            Texture = brush,
            ModulateColor = tint,
        };
        style.Set("content_margin_left", 24.0f);
        style.Set("content_margin_right", 24.0f);
        style.Set("content_margin_top", 10.0f);
        style.Set("content_margin_bottom", 10.0f);
        return style;
    }
}
