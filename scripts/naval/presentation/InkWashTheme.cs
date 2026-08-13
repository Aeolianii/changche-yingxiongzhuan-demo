#nullable enable
using Godot;

namespace NanjiangNaval;

// UX-4 水墨风主题（spec 第 6 节：暖调黄绿褐色板，米白纸底 + 墨青描边 + 赭石/枯黄点缀）。
// 所有样式由代码构建（Godot 4 StyleBoxFlat），应用到按钮/面板/文字节点，
// 使底部行动面板与棋盘/舰船（伪 3D 水墨）视觉统一。系统中文/书法感字体（楷体优先），不引入外部字体包。
public static class InkWashTheme
{
    public static readonly Color Paper = new("e8dcc0");       // 米白纸底
    public static readonly Color PaperLight = new("f2e8d0");  // 按钮纸底（略亮）
    public static readonly Color PaperDark = new("d6c8a6");   // 压按纸底
    public static readonly Color PaperFaded = new("ddd6c4");  // 禁用纸底（墨色变淡）
    public static readonly Color Ink = new("3a4a3a");         // 墨青（描边 / 激活填充）
    public static readonly Color InkDeep = new("22302a");     // 深墨（激活 / 压按描边）
    public static readonly Color InkFaded = new("9aa08f");    // 淡墨（禁用文字 / 边框）
    public static readonly Color Ochre = new("8a5a2b");       // 赭石点缀
    public static readonly Color Khaki = new("b8a06a");       // 枯黄点缀
    public static readonly Color TextInk = new("2c352c");     // 正文墨色
    public static readonly Color BrownText = new("3a2f1c");   // 消息正文（暖褐）

    private static SystemFont? _font;

    // 系统中文/书法感字体：楷体优先（KaiTi/楷体/STKaiti），回退宋体/黑体；找不到则回退系统默认字体。
    public static SystemFont Font()
    {
        if (_font is null)
        {
            _font = new SystemFont
            {
                FontNames = new[] { "KaiTi", "楷体", "STKaiti", "SimSun", "宋体", "Microsoft YaHei", "微软雅黑" },
            };
        }
        return _font;
    }

    // 面板纸卡片：米白纸底 + 墨青描边 + 圆角 + 阴影（纸质卡片感）。
    public static StyleBoxFlat PanelCard()
    {
        return new StyleBoxFlat
        {
            BgColor = new Color(Paper, 0.97f),
            BorderColor = Ink,
            BorderWidthLeft = 2,
            BorderWidthTop = 2,
            BorderWidthRight = 2,
            BorderWidthBottom = 2,
            CornerRadiusTopLeft = 8,
            CornerRadiusTopRight = 8,
            CornerRadiusBottomLeft = 8,
            CornerRadiusBottomRight = 8,
            ShadowColor = new Color(0.05f, 0.08f, 0.06f, 0.35f),
            ShadowSize = 10,
            ShadowOffset = new Vector2(0, 4),
        };
    }

    // 情境式 HUD 顶部信息带：保留纸色与墨线，但取消厚重卡片轮廓和大阴影。
    public static StyleBoxFlat HudRibbon()
    {
        return new StyleBoxFlat
        {
            BgColor = new Color(Paper, 0.90f),
            BorderColor = new Color(Ink, 0.78f),
            BorderWidthTop = 1,
            BorderWidthBottom = 2,
            ContentMarginLeft = 12,
            ContentMarginRight = 12,
            ContentMarginTop = 6,
            ContentMarginBottom = 6,
            ShadowColor = new Color(0.05f, 0.08f, 0.06f, 0.18f),
            ShadowSize = 4,
            ShadowOffset = new Vector2(0, 2),
        };
    }

    // 开放式舰桥指令台：半透明墨青底、赭金上沿，不再形成厚重的米纸卡片。
    public static StyleBoxFlat CommandDock()
    {
        return new StyleBoxFlat
        {
            BgColor = new Color(0.055f, 0.14f, 0.15f, 0.84f),
            BorderColor = new Color(Khaki, 0.82f),
            BorderWidthTop = 2,
            BorderWidthBottom = 1,
            ContentMarginLeft = 12,
            ContentMarginRight = 12,
            ContentMarginTop = 6,
            ContentMarginBottom = 6,
            ShadowColor = new Color(0.02f, 0.05f, 0.05f, 0.30f),
            ShadowSize = 5,
            ShadowOffset = new Vector2(0, 2),
        };
    }

    // 移动簇恢复独立卡片，用赭石侧边与主命令卡区分。
    public static StyleBoxFlat ContextPanel()
    {
        return new StyleBoxFlat
        {
            BgColor = new Color(Paper, 0.95f),
            BorderColor = Ochre,
            BorderWidthLeft = 4,
            BorderWidthTop = 1,
            BorderWidthRight = 1,
            BorderWidthBottom = 1,
            CornerRadiusTopLeft = 6,
            CornerRadiusTopRight = 6,
            CornerRadiusBottomLeft = 6,
            CornerRadiusBottomRight = 6,
            ContentMarginLeft = 10,
            ContentMarginRight = 10,
            ContentMarginTop = 7,
            ContentMarginBottom = 7,
            ShadowColor = new Color(0.05f, 0.08f, 0.06f, 0.24f),
            ShadowSize = 6,
            ShadowOffset = new Vector2(0, 3),
        };
    }

    private static StyleBoxFlat ButtonCard(Color bg, Color border)
    {
        return new StyleBoxFlat
        {
            BgColor = bg,
            BorderColor = border,
            BorderWidthLeft = 2,
            BorderWidthTop = 2,
            BorderWidthRight = 2,
            BorderWidthBottom = 2,
            CornerRadiusTopLeft = 4,
            CornerRadiusTopRight = 4,
            CornerRadiusBottomLeft = 4,
            CornerRadiusBottomRight = 4,
            ContentMarginLeft = 10,
            ContentMarginRight = 10,
            ContentMarginTop = 4,
            ContentMarginBottom = 4,
            ShadowColor = new Color(0.05f, 0.08f, 0.06f, 0.18f),
            ShadowSize = 4,
            ShadowOffset = new Vector2(0, 2),
        };
    }

    // 按钮五态（纸质卡片 + 墨线描边）。
    public static StyleBoxFlat ButtonNormal() => ButtonCard(PaperLight, Ink);
    public static StyleBoxFlat ButtonHover() => ButtonCard(new Color("f7eeda"), Ochre);
    public static StyleBoxFlat ButtonPressed() => ButtonCard(PaperDark, InkDeep);
    public static StyleBoxFlat ButtonDisabled() => ButtonCard(PaperFaded, InkFaded);
    // 键盘焦点：赭石细描边（透明底，叠加在 normal 之上）。
    public static StyleBoxFlat ButtonFocus()
    {
        return new StyleBoxFlat
        {
            BgColor = Colors.Transparent,
            BorderColor = Ochre,
            BorderWidthLeft = 2,
            BorderWidthTop = 2,
            BorderWidthRight = 2,
            BorderWidthBottom = 2,
            CornerRadiusTopLeft = 5,
            CornerRadiusTopRight = 5,
            CornerRadiusBottomLeft = 5,
            CornerRadiusBottomRight = 5,
        };
    }

    // 激活/选中行为（墨色填充 + 深墨描边）：表示当前选中的武器/行为。
    public static StyleBoxFlat ButtonActive() => ButtonCard(Ink, InkDeep);
    public static StyleBoxFlat ButtonActiveHover() => ButtonCard(Ink.Lightened(0.10f), Ochre);
    public static StyleBoxFlat ButtonActivePressed() => ButtonCard(InkDeep, InkDeep);

    // 按钮五态 + 字体（NavalHud 行动面板与布阵装备面板共用，避免双份样式代码）。
    public static void StyleButton(Button b)
    {
        b.AddThemeStyleboxOverride("normal", ButtonNormal());
        b.AddThemeStyleboxOverride("hover", ButtonHover());
        b.AddThemeStyleboxOverride("pressed", ButtonPressed());
        b.AddThemeStyleboxOverride("disabled", ButtonDisabled());
        b.AddThemeStyleboxOverride("focus", ButtonFocus());
        b.AddThemeFontOverride("font", Font());
        b.AddThemeFontSizeOverride("font_size", 16);
        b.AddThemeColorOverride("font_color", TextInk);
        b.AddThemeColorOverride("font_hover_color", InkDeep);
        b.AddThemeColorOverride("font_pressed_color", Paper);
        b.AddThemeColorOverride("font_disabled_color", InkFaded);
        b.AddThemeColorOverride("font_focus_color", TextInk);
    }

    // 战斗 HUD 专用紧凑按钮；不影响布阵和结算等需要更大触控面积的界面。
    public static void StyleHudButton(Button b)
    {
        StyleButton(b);
        b.AddThemeFontSizeOverride("font_size", 14);
    }

    // U-1：非交互面板不挡地图点击——递归把纯背景/装饰子树置 mouse_filter=Ignore（点击穿透到棋盘），
    // 只保留按钮本身与带 tooltip 的悬浮热区（PointingHand）接收点击。用于面板底板/状态卡/提示条。
    public static void MakeClickTransparent(Control root)
    {
        root.MouseFilter = Control.MouseFilterEnum.Ignore;
        foreach (var child in root.GetChildren())
        {
            if (child is not Control c) continue;
            if (c is Button) continue; // 按钮仍需接收点击
            if (c.MouseDefaultCursorShape == Control.CursorShape.PointingHand) continue; // tooltip 热区保留
            MakeClickTransparent(c);
        }
    }
}
