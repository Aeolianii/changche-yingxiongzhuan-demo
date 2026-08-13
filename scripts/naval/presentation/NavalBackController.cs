#nullable enable
using Godot;

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
            var brush = GD.Load<Texture2D>(ReturnBrushPath);
            StyleBrushButton(btn, brush);
            btn.FocusMode = Control.FocusModeEnum.None;
            btn.Pressed += () => GetTree().ChangeSceneToFile("res://scenes/naval/LevelSelect.tscn");
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
