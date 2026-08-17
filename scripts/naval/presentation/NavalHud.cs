#nullable enable
using Godot;
using NavalCombat.Core;
using NavalCombat.Integration;
using System;
using System.Collections.Generic;
using System.Linq;

namespace NanjiangNaval;

// 行动可用性标志（T13/UX-7）：全部由控制器从规则层只读查询/Validate 计算，UI 只做按钮 Disabled/Visible 映射，不重复实现规则。
// 普攻按攻击方式拆分（CanArrowRain/CanBombardment/CanCannon，对应箭雨/砲击/火炮按钮）；撞击/接舷属战术普攻。
// 每回合一次单位行为：执行任一普攻或技能后（HasAttacked）其余普攻/技能标志均为 false。
// F-7a：CanPairMove=选中舰是接舷组合防守方且预算未耗尽（方向簇切「组合移动」语义，最多 2 格、不能转向）。
// F-7b：CanSelfSink=战斗内浅滩自沉资格（通过性 1/2 + 船头在浅滩，未攻击/未自沉/非接舷）。
public readonly record struct ShipActionFlags(
    bool CanMove, bool CanTurn,
    bool CanArrowRain, bool CanBombardment, bool CanCannon,
    bool CanRam, bool CanBoard, bool CanExchange, bool CanDisengage,
    bool CanChainShot, bool CanFireOil, bool CanDamageControl, bool CanMine,
    bool CanPairMove, bool CanSelfSink);

// 底部军令牌指令台：攻击/转向分页，结束令始终跟在当前类别之后；按钮点击转发到控制器 OnAction。
// 节点引用懒加载（??=），避免控制器 _Ready 早于本节点 _Ready 时的空引用。
public partial class NavalHud : CanvasLayer
{
    private Panel? _actionPanel;
    private Panel? _shipStatusPanel;
    private TextureRect? _shipPortrait;
    private Label? _shipName, _shipHpText, _shipLoadText;
    private ProgressBar? _shipHpBar, _shipLoadBar;
    private TextureRect? _armorIcon, _speedIcon, _movementIcon;
    private Label? _armorValue, _speedValue, _movementValue;
    private string _shipStatusPanelText = "";
    private Label? _statusLabel;
    private Label? _messageLabel;
    private Panel? _turnBanner;
    private Label? _turnBannerLabel;
    private Tween? _turnBannerTween;
    private Button? _attackTab, _turnTab;
    private Control? _attackCommands, _turnCommands;
    private Button? _btnTurnLeft, _btnTurnRight;
    // UX-7：普攻区按攻击方式拆分（箭雨始终可用；砲击/火炮按装载武器隐藏/置灰）。
    private Button? _btnArrowRain, _btnBombardment, _btnCannon;
    private Button? _btnRam, _btnBoard, _btnExchange, _btnDisengage;
    private Button? _btnChainShot, _btnFireOil, _btnDamageControl, _btnMine;
    private Button? _btnEndTurn;
    private Button? _btnSelfSink; // F-7b/V-6：战斗内浅滩自沉按钮（V-6 起选中我方舰时始终显示，不满足资格置灰+原因）
    private Panel? _resultPanel;
    private Label? _resultLabel;
    private Button? _btnNewGame;
    private Button? _btnReroll; // U-2c：随机遭遇「重掷换一场」按钮（仅结算面板出现）
    // F-3：投降交涉面板（顶栏下方独立面板）——接受/拒绝敌方劝降 + 我方发起劝降。
    private Panel? _surrenderPanel;
    private Label? _surrenderCaption;
    private Button? _btnAcceptSurrender, _btnRejectSurrender, _btnOfferSurrender;
    // F-7c：交付舰选择面板（金币不足时接受劝降弹出）——动态 CheckBox 列表 + 确认/取消。
    private Panel? _deliveryPanel;
    private Label? _deliveryCaption;
    private VBoxContainer? _deliveryList;
    private Button? _btnConfirmDelivery, _btnCancelDelivery;
    private int _deliveryRequired; // 需交付数量（⌊符合条件现存舰数÷3⌋），供 headless 断言
    private readonly Dictionary<string, CheckBox> _deliveryCheckboxes = new(); // 舰 id → CheckBox（重开面板清空重建）
    // UX-5：左侧上下文状态栏，未选中=全局 / 选中=单位详情。
    private Label? _topLeftCaption, _topLeftContent;
    // UX-4：选武器/行为 = 切换而非叠加——当前武器/行为按钮高亮（墨色填充），其它恢复常态。
    private readonly Dictionary<string, Button> _actionButtons = new();
    private readonly Dictionary<Button, bool> _attackCommandAvailable = new();
    // R-3：攻击令牌按组分页——每组一个组头标签 + 该组令牌按钮（顺序同 GroupHeaders/ActionTokens）。
    private readonly List<(string Group, Label Label, List<Button> Buttons)> _attackGroups = new();
    private int _attackPage;
    private int _attackPageCount = 1;
    private string _currentAttackLabel = "武器"; // 当前攻击页组头文本（headless 断言用）
    private const float CommandTokenWidth = 79.0f;
    private const float CommandTokenGap = 30.0f;
    private const float CommandConnectorRight = 800.0f;
    private const float CommandConnectorOverhang = 60.0f;
    private const float GroupLabelWidth = 40.0f; // R-3：攻击页组头标签占宽（连接笔触补段）
    // R-3：令牌分组定义（数据驱动）——新增武器/技能只需加一条定义（并把令牌/组头放进场景对应组），
    // 即自动进对应组、按组参与分页/可用性/次数显示，无需改分页逻辑（扩展位）。
    private const string GroupWeapon = "weapon";
    private const string GroupSkill = "skill";
    private const string GroupBoarding = "boarding";
    private readonly record struct ActionTokenDef(string ActionId, string Group, bool IsSkill);
    private static readonly ActionTokenDef[] ActionTokens =
    {
        // 武器组：箭雨/撞角(撞击)/火炮/接舷/砲击（箭雨/撞角/接舷始终可用；火炮/砲击按装载显示/置灰）。
        new("arrow_rain", GroupWeapon, false),
        new("ram", GroupWeapon, false),
        new("cannon", GroupWeapon, false),
        new("board", GroupWeapon, false),
        new("bombardment", GroupWeapon, false),
        // 技能组：损管/火油/链弹/水雷（显示剩余次数）。
        new("damage_control", GroupSkill, true),
        new("fire_oil", GroupSkill, true),
        new("chain_shot", GroupSkill, true),
        new("mine", GroupSkill, true),
        // 接舷管理组：俘获交换/脱离（仅接舷状态出现）。
        new("board_exchange", GroupBoarding, false),
        new("disengage", GroupBoarding, false),
    };
    // 组头：组 → 标签文本 + 场景组头标签节点名（AttackCommands 内）。
    private static readonly (string Group, string Label, string NodeName)[] GroupHeaders =
    {
        (GroupWeapon, "武器", "WeaponLabel"),
        (GroupSkill, "技能", "SkillLabel"),
        (GroupBoarding, "接舷", "BoardingLabel"),
    };
    private Texture2D? _attackTokenTexture, _turnTokenTexture, _endTokenTexture, _categoryBrushTexture;
    private TextureRect? _commandConnector;
    private Panel ActionPanel => _actionPanel ??= GetNode<Panel>("ActionPanel");
    private Panel ShipStatusPanel => _shipStatusPanel ??= GetNode<Panel>("ShipStatusPanel");
    private TextureRect ShipPortrait => _shipPortrait ??= GetNode<TextureRect>("ShipStatusPanel/PortraitShip");
    private Label ShipName => _shipName ??= GetNode<Label>("ShipStatusPanel/ShipName");
    private ProgressBar ShipHpBar => _shipHpBar ??= GetNode<ProgressBar>("ShipStatusPanel/HpBar");
    private ProgressBar ShipLoadBar => _shipLoadBar ??= GetNode<ProgressBar>("ShipStatusPanel/LoadBar");
    private Label ShipHpText => _shipHpText ??= GetNode<Label>("ShipStatusPanel/HpText");
    private Label ShipLoadText => _shipLoadText ??= GetNode<Label>("ShipStatusPanel/LoadText");
    private TextureRect ArmorIcon => _armorIcon ??= GetNode<TextureRect>("ShipStatusPanel/Attributes/Armor/Icon");
    private TextureRect SpeedIcon => _speedIcon ??= GetNode<TextureRect>("ShipStatusPanel/Attributes/Speed/Icon");
    private TextureRect MovementIcon => _movementIcon ??= GetNode<TextureRect>("ShipStatusPanel/Attributes/Movement/Icon");
    private Label ArmorValue => _armorValue ??= GetNode<Label>("ShipStatusPanel/Attributes/Armor/Value");
    private Label SpeedValue => _speedValue ??= GetNode<Label>("ShipStatusPanel/Attributes/Speed/Value");
    private Label MovementValue => _movementValue ??= GetNode<Label>("ShipStatusPanel/Attributes/Movement/Value");
    private Panel ResultPanel => _resultPanel ??= GetNode<Panel>("ResultPanel");
    private Label ResultLabel => _resultLabel ??= GetNode<Label>("ResultPanel/ResultLabel");
    private Button NewGameButton => _btnNewGame ??= GetNode<Button>("ResultPanel/NewGameButton");
    private Button RerollButton => _btnReroll ??= GetNode<Button>("ResultPanel/RerollButton"); // U-2c：重掷换一场
    private Label StatusLabel => _statusLabel ??= GetNode<Label>("StatusLabel");
    private Label MessageLabel => _messageLabel ??= GetNode<Label>("MessageLabel");
    private Panel TurnBanner => _turnBanner ??= GetNode<Panel>("TurnBanner");
    private Label TurnBannerLabel => _turnBannerLabel ??= GetNode<Label>("TurnBanner/Label");
    private Button AttackTab => _attackTab ??= GetNode<Button>("ActionPanel/Box/CategoryTabs/AttackTab");
    private Button TurnTab => _turnTab ??= GetNode<Button>("ActionPanel/Box/CategoryTabs/TurnTab");
    private TextureRect CommandConnector => _commandConnector ??= GetNode<TextureRect>("ActionPanel/Box/CommandConnector");
    private Control AttackCommands => _attackCommands ??= GetNode<Control>("ActionPanel/Box/CommandStrip/AttackCommands");
    private Control TurnCommands => _turnCommands ??= GetNode<Control>("ActionPanel/Box/CommandStrip/TurnCommands");
    private Button TurnLeft => _btnTurnLeft ??= GetNode<Button>("ActionPanel/Box/CommandStrip/TurnCommands/TurnLeft");
    private Button TurnRight => _btnTurnRight ??= GetNode<Button>("ActionPanel/Box/CommandStrip/TurnCommands/TurnRight");
    // UX-7：普攻区攻击方式按钮（箭雨/砲击/火炮/撞击/接舷）。
    private Button ArrowRain => _btnArrowRain ??= GetNode<Button>("ActionPanel/Box/CommandStrip/AttackCommands/ArrowRain");
    private Button Bombardment => _btnBombardment ??= GetNode<Button>("ActionPanel/Box/CommandStrip/AttackCommands/Bombardment");
    private Button Cannon => _btnCannon ??= GetNode<Button>("ActionPanel/Box/CommandStrip/AttackCommands/Cannon");
    private Button Ram => _btnRam ??= GetNode<Button>("ActionPanel/Box/CommandStrip/AttackCommands/Ram");
    private Button Board => _btnBoard ??= GetNode<Button>("ActionPanel/Box/CommandStrip/AttackCommands/Board");
    private Button Exchange => _btnExchange ??= GetNode<Button>("ActionPanel/Box/CommandStrip/AttackCommands/Exchange");
    private Button Disengage => _btnDisengage ??= GetNode<Button>("ActionPanel/Box/CommandStrip/AttackCommands/Disengage");
    private Button ChainShot => _btnChainShot ??= GetNode<Button>("ActionPanel/Box/CommandStrip/AttackCommands/ChainShot");
    private Button FireOil => _btnFireOil ??= GetNode<Button>("ActionPanel/Box/CommandStrip/AttackCommands/FireOil");
    private Button DamageControl => _btnDamageControl ??= GetNode<Button>("ActionPanel/Box/CommandStrip/AttackCommands/DamageControl");
    private Button Mine => _btnMine ??= GetNode<Button>("ActionPanel/Box/CommandStrip/AttackCommands/Mine");
    // V-5：单结束令——去掉「结束本舰」，结束令 = 整体「结束回合」（EndCommands 常驻在攻击/转向类别之后）。
    private Button EndTurnButton => _btnEndTurn ??= GetNode<Button>("ActionPanel/Box/CommandStrip/EndCommands/EndTurn");
    private Button SelfSinkButton => _btnSelfSink ??= GetNode<Button>("ActionPanel/Box/CommandStrip/EndCommands/SelfSink"); // F-7b/V-6：浅滩自沉
    private Texture2D AttackTokenTexture => _attackTokenTexture ??= GD.Load<Texture2D>("res://assets/naval/ui/action_tokens/attack_command_token.png");
    private Texture2D TurnTokenTexture => _turnTokenTexture ??= GD.Load<Texture2D>("res://assets/naval/ui/action_tokens/turn_command_token.png");
    private Texture2D EndTokenTexture => _endTokenTexture ??= GD.Load<Texture2D>("res://assets/naval/ui/action_tokens/end_command_token.png");
    private Texture2D CategoryBrushTexture => _categoryBrushTexture ??= GD.Load<Texture2D>("res://assets/naval/ui/level_select_return_brush.png");
    // UX-5：左侧顶栏 Caption/Content（上下文状态栏）。
    private Label TopLeftCaption => _topLeftCaption ??= GetNode<Label>("TopBarLeft/Box/Caption");
    private Label TopLeftContent => _topLeftContent ??= GetNode<Label>("TopBarLeft/Box/Content");
    // F-3：投降交涉面板节点。
    private Panel SurrenderPanel => _surrenderPanel ??= GetNode<Panel>("SurrenderPanel");
    private Label SurrenderCaption => _surrenderCaption ??= GetNode<Label>("SurrenderPanel/Box/Caption");
    private Button AcceptSurrenderButton => _btnAcceptSurrender ??= GetNode<Button>("SurrenderPanel/Box/Buttons/AcceptSurrender");
    private Button RejectSurrenderButton => _btnRejectSurrender ??= GetNode<Button>("SurrenderPanel/Box/Buttons/RejectSurrender");
    private Button OfferSurrenderButton => _btnOfferSurrender ??= GetNode<Button>("SurrenderPanel/Box/Buttons/OfferSurrender");
    // F-7c：交付舰选择面板节点（金币不足接受劝降时弹出）。
    private Panel DeliveryPanel => _deliveryPanel ??= GetNode<Panel>("DeliveryPanel");
    private Label DeliveryCaption => _deliveryCaption ??= GetNode<Label>("DeliveryPanel/Box/Caption");
    private VBoxContainer DeliveryList => _deliveryList ??= GetNode<VBoxContainer>("DeliveryPanel/Box/List");
    private Button ConfirmDeliveryButton => _btnConfirmDelivery ??= GetNode<Button>("DeliveryPanel/Box/Buttons/ConfirmDelivery");
    private Button CancelDeliveryButton => _btnCancelDelivery ??= GetNode<Button>("DeliveryPanel/Box/Buttons/CancelDelivery");

    public override void _Ready()
    {
        var controller = GetNode<NavalBattleController>("../BattleController");
        AttackTab.Pressed += OnAttackTabPressed;
        TurnTab.Pressed += () => SetCommandCategory(false);
        TurnLeft.Pressed += () => controller.OnAction("turn_left");
        TurnRight.Pressed += () => controller.OnAction("turn_right");
        // UX-7：普攻区各攻击方式按钮 → 展开该方式可攻击范围。
        ArrowRain.Pressed += () => controller.OnAction("arrow_rain");
        Bombardment.Pressed += () => controller.OnAction("bombardment");
        Cannon.Pressed += () => controller.OnAction("cannon");
        Ram.Pressed += () => controller.OnAction("ram");
        Board.Pressed += () => controller.OnAction("board");
        Exchange.Pressed += () => controller.OnAction("board_exchange");
        Disengage.Pressed += () => controller.OnAction("disengage");
        ChainShot.Pressed += () => controller.OnAction("chain_shot");
        FireOil.Pressed += () => controller.OnAction("fire_oil");
        DamageControl.Pressed += () => controller.OnAction("damage_control");
        Mine.Pressed += () => controller.OnAction("mine");
        EndTurnButton.Pressed += () => controller.OnAction("end_turn"); // V-5：整体结束回合 = 主要结束方式
        NewGameButton.Pressed += () => controller.OnAction("new_game");
        RerollButton.Pressed += () => controller.OnAction("reroll_encounter"); // U-2c：随机遭遇重掷
        SelfSinkButton.Pressed += () => controller.OnAction("self_sink"); // F-7b：战斗内浅滩自沉
        // F-3：投降交涉面板三按钮 → 控制器分发（接受/拒绝敌方劝降、我方发起劝降）。
        AcceptSurrenderButton.Pressed += () => controller.OnAction("accept_surrender");
        RejectSurrenderButton.Pressed += () => controller.OnAction("reject_surrender");
        OfferSurrenderButton.Pressed += () => controller.OnAction("offer_surrender");
        // F-7c：交付面板确认/取消 → 控制器分发（确认 = 以勾选舰交付、取消 = 放弃并恢复接受/拒绝按钮）。
        ConfirmDeliveryButton.Pressed += () => controller.OnAction("confirm_delivery");
        CancelDeliveryButton.Pressed += () => controller.OnAction("cancel_delivery");
        // UX-4：激活行为映射（选武器/行为 = 切换高亮）。
        _actionButtons["arrow_rain"] = ArrowRain;
        _actionButtons["bombardment"] = Bombardment;
        _actionButtons["cannon"] = Cannon;
        _actionButtons["ram"] = Ram;
        _actionButtons["board"] = Board;
        _actionButtons["chain_shot"] = ChainShot;
        _actionButtons["fire_oil"] = FireOil;
        _actionButtons["mine"] = Mine;
        // R-3：按组装配令牌（组头标签 + 组内令牌按钮），顺序同 GroupHeaders/ActionTokens。
        foreach (var (group, _, nodeName) in GroupHeaders)
        {
            var label = GetNode<Label>($"ActionPanel/Box/CommandStrip/AttackCommands/{nodeName}");
            var buttons = new List<Button>();
            foreach (var def in ActionTokens)
                if (def.Group == group) buttons.Add(TokenButton(def.ActionId));
            _attackGroups.Add((group, label, buttons));
        }
        foreach (var (_, _, buttons) in _attackGroups)
            foreach (var button in buttons)
                _attackCommandAvailable[button] = button.Visible;
        ApplyInkWash();
        SetCommandCategory(true);
        // 情境式 HUD：未选中舰船时不显示底部命令台和舰船状态卡。
        ActionPanel.Visible = false;
        ShipStatusPanel.Visible = false;
        // U-1：非交互面板底板不挡地图点击——递归置 mouse_filter=Ignore（按钮/tooltip 热区保留）。
        InkWashTheme.MakeClickTransparent(ActionPanel);
        InkWashTheme.MakeClickTransparent(ShipStatusPanel);
    }

    // ---- 水墨纸卡片主题（UX-4）：面板/按钮/文字全部走 InkWashTheme 色板 + 系统楷体 ----

    private void ApplyInkWash()
    {
        ActionPanel.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        ShipStatusPanel.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        ResultPanel.AddThemeStyleboxOverride("panel", InkWashTheme.PanelCard());
        // F-3：投降交涉面板同纸卡片风格。
        SurrenderPanel.AddThemeStyleboxOverride("panel", InkWashTheme.PanelCard());
        StyleText(SurrenderCaption, 14, InkWashTheme.Ochre);
        // F-7c：交付舰选择面板同纸卡片风格。
        DeliveryPanel.AddThemeStyleboxOverride("panel", InkWashTheme.PanelCard());
        StyleText(DeliveryCaption, 14, InkWashTheme.Ochre);
        // 左上角固定全局摘要：透明面板上由场景中的像素水墨笔触打底。
        if (GetNodeOrNull<Panel>("TopBarLeft") is { } topLeftPanel)
            topLeftPanel.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        StyleText(StatusLabel, 26, InkWashTheme.TextInk);
        StyleText(MessageLabel, 20, InkWashTheme.BrownText);
        StyleFloatingText(StatusLabel, 6);
        StyleFloatingText(MessageLabel, 5);
        TurnBanner.AddThemeStyleboxOverride("panel", CategoryBrushStyle(Colors.White));
        StyleText(TurnBannerLabel, 28, InkWashTheme.PaperLight);
        TurnBannerLabel.AddThemeColorOverride("font_outline_color", InkWashTheme.InkDeep);
        TurnBannerLabel.AddThemeConstantOverride("outline_size", 5);
        InkWashTheme.MakeClickTransparent(TurnBanner);
        StyleText(ShipName, 23, InkWashTheme.PaperLight);
        StyleText(ShipHpText, 15, InkWashTheme.PaperLight);
        StyleText(ShipLoadText, 15, InkWashTheme.PaperLight);
        StyleText(ArmorValue, 17, InkWashTheme.PaperLight);
        StyleText(SpeedValue, 17, InkWashTheme.PaperLight);
        StyleText(MovementValue, 17, InkWashTheme.PaperLight);
        StyleFloatingText(ShipName, 4);
        StyleFloatingText(ShipHpText, 3);
        StyleFloatingText(ShipLoadText, 3);
        StyleText(ResultLabel, 20, InkWashTheme.TextInk);
        StyleText(TopLeftCaption, 20, Colors.White);
        StyleText(TopLeftContent, 18, Colors.White);
        StyleFloatingText(TopLeftCaption, 5);
        StyleFloatingText(TopLeftContent, 5);
        TopLeftCaption.AddThemeColorOverride("font_outline_color", Colors.Black);
        TopLeftContent.AddThemeColorOverride("font_outline_color", Colors.Black);
        // 页签继续使用小型纸按钮；行动本体使用三类生图军令牌，并由程序叠加可靠文字。
        StyleCommandCategoryTab(AttackTab, true);
        StyleCommandCategoryTab(TurnTab, false);
        foreach (var button in new[]
        {
            ArrowRain, Bombardment, Cannon, Ram, Board,
            ChainShot, FireOil, DamageControl, Mine, Exchange, Disengage,
        })
            StyleCommandTokenButton(button, AttackTokenTexture);
        // R-3：组头标签使用赭石色竖排；武器页按视觉反馈隐藏组头，只保留军令牌。
        foreach (var (_, label, _) in _attackGroups)
            StyleGroupHeader(label);
        foreach (var button in new[] { TurnLeft, TurnRight })
            StyleCommandTokenButton(button, TurnTokenTexture);
        foreach (var button in new[] { SelfSinkButton, EndTurnButton })
            StyleCommandTokenButton(button, EndTokenTexture);
        foreach (var node in SurrenderPanel.FindChildren("*", "Button", true, false))
            if (node is Button b) StylePanelButton(b);
        foreach (var node in DeliveryPanel.FindChildren("*", "Button", true, false))
            if (node is Button b) StylePanelButton(b);
        StylePanelButton(NewGameButton);
    }

    // UX-10：按钮统一样式 + 禁用焦点——按钮点击后不夺键盘焦点，方向键才能落到控制器 _UnhandledKeyInput
    //（Godot GUI 焦点导航会吞方向键；本 Demo 无 Tab 导航需求，FocusMode.None 安全）。
    private static void StylePanelButton(Button b)
    {
        InkWashTheme.StyleHudButton(b);
        b.FocusMode = Control.FocusModeEnum.None;
    }

    private static void StyleCommandTokenButton(Button button, Texture2D texture, bool active = false)
    {
        button.CustomMinimumSize = new Vector2(79.0f, 219.0f);
        button.FocusMode = Control.FocusModeEnum.None;
        button.TextureFilter = CanvasItem.TextureFilterEnum.Nearest;
        button.MouseDefaultCursorShape = Control.CursorShape.PointingHand;
        button.Alignment = HorizontalAlignment.Center;
        button.AddThemeStyleboxOverride("normal", CommandTokenStyle(texture, active ? new Color(1.12f, 1.04f, 0.78f, 1.0f) : Colors.White));
        button.AddThemeStyleboxOverride("hover", CommandTokenStyle(texture, new Color(1.16f, 1.08f, 0.82f, 1.0f)));
        button.AddThemeStyleboxOverride("pressed", CommandTokenStyle(texture, new Color(0.72f, 0.76f, 0.72f, 1.0f)));
        button.AddThemeStyleboxOverride("disabled", CommandTokenStyle(texture, new Color(0.42f, 0.45f, 0.44f, 0.82f)));
        button.AddThemeStyleboxOverride("focus", CommandTokenStyle(texture, Colors.White));
        button.AddThemeFontOverride("font", InkWashTheme.Font());
        button.AddThemeFontSizeOverride("font_size", 25);
        button.AddThemeColorOverride("font_color", active ? new Color("f5d77d") : InkWashTheme.PaperLight);
        button.AddThemeColorOverride("font_hover_color", new Color("ffe59a"));
        button.AddThemeColorOverride("font_pressed_color", Colors.White);
        button.AddThemeColorOverride("font_disabled_color", new Color("c0baa9"));
        button.AddThemeColorOverride("font_outline_color", InkWashTheme.InkDeep);
        button.AddThemeConstantOverride("outline_size", active ? 5 : 4);
    }

    private static StyleBoxTexture CommandTokenStyle(Texture2D texture, Color tint)
    {
        var style = new StyleBoxTexture
        {
            Texture = texture,
            ModulateColor = tint,
        };
        style.Set("content_margin_left", 4.0f);
        style.Set("content_margin_right", 4.0f);
        style.Set("content_margin_top", 45.0f);
        style.Set("content_margin_bottom", 24.0f);
        return style;
    }

    private void StyleCommandCategoryTab(Button button, bool active)
    {
        // 武器页签同时承担分页入口，留足横排「武器1/2」文本；转向页签保持紧凑。
        button.CustomMinimumSize = new Vector2(ReferenceEquals(button, AttackTab) ? 160.0f : 110.0f, 40.0f);
        button.FocusMode = Control.FocusModeEnum.None;
        button.TextureFilter = CanvasItem.TextureFilterEnum.Nearest;
        button.MouseDefaultCursorShape = Control.CursorShape.PointingHand;
        button.AddThemeStyleboxOverride("normal", CategoryBrushStyle(active ? new Color(0.94f, 0.78f, 0.46f, 1.0f) : Colors.White));
        button.AddThemeStyleboxOverride("hover", CategoryBrushStyle(new Color(1.0f, 0.9f, 0.62f, 1.0f)));
        button.AddThemeStyleboxOverride("pressed", CategoryBrushStyle(new Color(0.68f, 0.72f, 0.68f, 1.0f)));
        button.AddThemeStyleboxOverride("focus", CategoryBrushStyle(Colors.White));
        button.AddThemeFontOverride("font", InkWashTheme.Font());
        button.AddThemeFontSizeOverride("font_size", 20);
        button.AddThemeColorOverride("font_color", InkWashTheme.PaperLight);
        button.AddThemeColorOverride("font_hover_color", new Color("ffe59a"));
        button.AddThemeColorOverride("font_pressed_color", Colors.White);
        button.AddThemeColorOverride("font_outline_color", InkWashTheme.InkDeep);
        button.AddThemeConstantOverride("outline_size", 4);
    }

    private StyleBoxTexture CategoryBrushStyle(Color tint)
    {
        var style = new StyleBoxTexture
        {
            Texture = CategoryBrushTexture,
            ModulateColor = tint,
        };
        style.Set("content_margin_left", 14.0f);
        style.Set("content_margin_right", 14.0f);
        style.Set("content_margin_top", 7.0f);
        style.Set("content_margin_bottom", 7.0f);
        return style;
    }

    private void OnAttackTabPressed()
    {
        if (AttackCommands.Visible && _attackPageCount > 1)
        {
            _attackPage = (_attackPage + 1) % _attackPageCount;
            AttackTab.ButtonPressed = true;
            StyleCommandCategoryTab(AttackTab, true);
            ApplyAttackPage();
            return;
        }
        SetCommandCategory(true);
    }

    private void SetAttackCommandAvailable(Button button, bool available)
        => _attackCommandAvailable[button] = available;

    // R-3：动作 id → 令牌按钮（令牌定义表的布局载体；未知动作抛错以暴露定义/场景不一致）。
    private Button TokenButton(string actionId) => actionId switch
    {
        "arrow_rain" => ArrowRain,
        "ram" => Ram,
        "cannon" => Cannon,
        "board" => Board,
        "bombardment" => Bombardment,
        "damage_control" => DamageControl,
        "fire_oil" => FireOil,
        "chain_shot" => ChainShot,
        "mine" => Mine,
        "board_exchange" => Exchange,
        "disengage" => Disengage,
        _ => throw new ArgumentException($"未知令牌动作：{actionId}"),
    };

    // R-3：按组分页——每组一页（武器/技能/接舷），页内显示组头标签 + 该组可用令牌，不可用令牌隐藏。
    // 扩展位：组内令牌由 ActionTokens 定义，新增武器/技能自动进对应组参与分页（武器组至多 5 令牌仍满足每页上限）。
    private void ApplyAttackPage()
    {
        // 仅含可用令牌的组成页（接舷管理组仅在接舷状态成页；箭雨恒可用保证武器组恒成页）。
        var pages = _attackGroups
            .Where(group => group.Buttons.Any(button => _attackCommandAvailable.GetValueOrDefault(button)))
            .ToList();
        _attackPageCount = Math.Max(1, pages.Count);
        _attackPage = Math.Clamp(_attackPage, 0, _attackPageCount - 1);
        if (pages.Count == 0)
        {
            foreach (var (_, label, buttons) in _attackGroups)
            {
                label.Visible = false;
                foreach (var button in buttons) button.Visible = false;
            }
            UpdateCommandConnector(0);
            return;
        }
        var current = pages[_attackPage];
        foreach (var (group, label, buttons) in _attackGroups)
        {
            var isCurrent = ReferenceEquals(label, current.Label);
            label.Visible = isCurrent && group != GroupWeapon;
            foreach (var button in buttons)
                button.Visible = isCurrent && _attackCommandAvailable.GetValueOrDefault(button);
        }
        _currentAttackLabel = current.Label.Text.Replace("\n", string.Empty);
        AttackTab.Text = $"{_currentAttackLabel}{_attackPage + 1}/{_attackPageCount}";
        AttackTab.TooltipText = _attackPageCount > 1 ? "点击翻到下一页武器栏" : "当前只有一页武器栏";
        UpdateCommandConnector(VisibleAttackCommandCount(), hasGroupLabel: current.Group != GroupWeapon);
    }

    private void SetCommandCategory(bool showAttack)
    {
        AttackCommands.Visible = showAttack;
        TurnCommands.Visible = !showAttack;
        AttackTab.ButtonPressed = showAttack;
        TurnTab.ButtonPressed = !showAttack;
        StyleCommandCategoryTab(AttackTab, showAttack);
        StyleCommandCategoryTab(TurnTab, !showAttack);
        if (showAttack)
            ApplyAttackPage();
        else
            UpdateCommandConnector(2);
    }

    // R-3：组头标签样式——赭石色竖排文字（「武\n器」「技\n能」「接\n舷」），与令牌竖排风格一致、视觉区分。
    private static void StyleGroupHeader(Label label)
    {
        label.AddThemeFontOverride("font", InkWashTheme.Font());
        label.AddThemeFontSizeOverride("font_size", 18);
        label.AddThemeColorOverride("font_color", InkWashTheme.Ochre);
        label.AddThemeColorOverride("font_outline_color", InkWashTheme.InkDeep);
        label.AddThemeConstantOverride("outline_size", 3);
        label.AddThemeConstantOverride("shadow_offset_x", 1);
        label.AddThemeConstantOverride("shadow_offset_y", 2);
        label.AddThemeColorOverride("font_shadow_color", new Color(InkWashTheme.InkDeep, 0.30f));
        label.HorizontalAlignment = HorizontalAlignment.Center;
        label.VerticalAlignment = VerticalAlignment.Center;
    }

    private void UpdateCommandConnector(int categoryCommandCount, bool hasGroupLabel = false)
    {
        // 当前分类令 + 可选自沉令 + 固定结束令共用一条后层水墨笔触，随可见牌数收放。
        // R-3：攻击页组头标签向左扩展（令牌组右对齐，令牌本身不动），笔触补一段组头宽避免标签越出覆盖。
        var tokenCount = Math.Max(1, categoryCommandCount + (SelfSinkButton.Visible ? 1 : 0) + 1);
        var labelSpan = hasGroupLabel ? GroupLabelWidth + CommandTokenGap : 0;
        var tokenSpan = tokenCount * CommandTokenWidth + Math.Max(0, tokenCount - 1) * CommandTokenGap + labelSpan;
        CommandConnector.OffsetRight = CommandConnectorRight;
        CommandConnector.OffsetLeft = CommandConnectorRight - tokenSpan - CommandConnectorOverhang;
    }

    public void ShowCommandCategory(string category) => SetCommandCategory(category == "attack");
    public string CommandCategory() => AttackCommands.Visible ? "attack" : "turn";
    public int AttackPageCount() => _attackPageCount;
    public int AttackPageIndex() => _attackPage;
    public int VisibleAttackCommandCount() => _attackGroups.Sum(group => group.Buttons.Count(button => button.Visible));
    // R-3：令牌分组只读访问（headless 冒烟断言武器/技能组结构、分组标签、可用性/次数映射、动作 id 覆盖）。
    public int WeaponGroupTokenCount() => ActionTokens.Count(def => def.Group == GroupWeapon);
    public int SkillGroupTokenCount() => ActionTokens.Count(def => def.Group == GroupSkill);
    public int AttackGroupCount() => GroupHeaders.Length;
    public string AttackGroupHeader(int index) => GroupHeaders[index].Label;
    public string CurrentAttackGroupLabel() => _currentAttackLabel;
    public string[] AllAttackTokenActionIds() => ActionTokens.Select(def => def.ActionId).ToArray();
    public bool AttackTokenVisible(string actionId) => TokenButton(actionId).Visible;
    public bool AttackTokenDisabled(string actionId) => TokenButton(actionId).Disabled;
    public string AttackTokenText(string actionId) => TokenButton(actionId).Text;

    private static void StyleButton(Button b) => InkWashTheme.StyleButton(b); // F-5：委托主题公共样式（布阵装备面板共用）

    private static void StyleText(Label l, int size, Color color)
    {
        l.AddThemeFontOverride("font", InkWashTheme.Font());
        l.AddThemeFontSizeOverride("font_size", size);
        l.AddThemeColorOverride("font_color", color);
    }

    private static void StyleFloatingText(Label label, int outlineSize)
    {
        label.AddThemeColorOverride("font_outline_color", new Color(InkWashTheme.PaperLight, 0.86f));
        label.AddThemeConstantOverride("outline_size", outlineSize);
        label.AddThemeConstantOverride("shadow_offset_x", 1);
        label.AddThemeConstantOverride("shadow_offset_y", 2);
        label.AddThemeColorOverride("font_shadow_color", new Color(InkWashTheme.InkDeep, 0.34f));
    }

    // UX-4：激活行为高亮（切换而非叠加）——当前武器/行为按钮墨色填充，其余恢复纸卡片常态。
    public void SetActiveAction(string? actionId)
    {
        foreach (var (id, btn) in _actionButtons)
            StyleCommandTokenButton(btn, AttackTokenTexture, id == actionId);
    }

    // ---- 面板显隐 / 行动按钮可用态 ----

    public bool ActionPanelVisible() => ActionPanel.Visible;
    public bool ShipStatusPanelVisible() => ShipStatusPanel.Visible;
    public string ShipStatusPanelText() => _shipStatusPanelText;

    public void ShowTurnStatus(FactionId faction, int round)
        => StatusLabel.Text = $"第 {round} 回合 · {FactionName(faction)}";

    // T13/UX-7：全部按钮可用性由控制器经规则查询算好传入，UI 只映射 Disabled/Visible。
    // R-3：令牌按组分页——武器组（箭雨/撞角/火炮/接舷/砲击：箭雨/撞角/接舷始终可用，火炮/砲击按装载显示）、
    // 技能组（损管/火油/链弹/水雷：显示剩余次数 ship.SkillUsesLeft）、接舷管理组（俘获交换/脱离：仅接舷状态）。
    // 每回合一次单位行为：执行后（Can* 均 false）普攻/技能按钮全部禁用。
    public void ShowShipActions(ShipState ship, ShipActionFlags flags)
    {
        if (!ActionPanel.Visible) _attackPage = 0;
        ActionPanel.Visible = true;
        // 竖向军令牌使用固定高度；动态行动只改变牌数，不再改变面板高度。
        ActionPanel.OffsetTop = -291.0f;
        TurnLeft.Disabled = !flags.CanTurn;
        TurnRight.Disabled = !flags.CanTurn;
        // ---- R-3 武器组：箭雨/撞角/接舷始终可用；火炮/砲击按装载显示（未装隐藏）、按规则置灰 ----
        SetAttackCommandAvailable(ArrowRain, true);
        ArrowRain.Disabled = !flags.CanArrowRain;
        SetAttackCommandAvailable(Ram, true);
        Ram.Disabled = !flags.CanRam;
        SetAttackCommandAvailable(Cannon, ship.WeaponCounts.GetValueOrDefault("cannon", 0) > 0);
        Cannon.Disabled = !flags.CanCannon;
        SetAttackCommandAvailable(Board, true);
        Board.Disabled = !flags.CanBoard;
        SetAttackCommandAvailable(Bombardment, ship.WeaponCounts.GetValueOrDefault("bombardment", 0) > 0);
        Bombardment.Disabled = !flags.CanBombardment;
        // ---- R-3 技能组：显示剩余次数（规则层 SkillUsesLeft）；无次数/未播种 → 隐藏并禁用 ----
        var damageControlUses = ship.SkillUsesLeft.GetValueOrDefault("damage_control", 0);
        var fireOilUses = ship.SkillUsesLeft.GetValueOrDefault("fire_oil", 0);
        var chainShotUses = ship.SkillUsesLeft.GetValueOrDefault("chain_shot", 0);
        var mineUses = ship.SkillUsesLeft.GetValueOrDefault("mine", 0);
        SetAttackCommandAvailable(DamageControl, damageControlUses > 0);
        DamageControl.Text = $"损\n管\n×{damageControlUses}";
        DamageControl.Disabled = !flags.CanDamageControl;
        SetAttackCommandAvailable(FireOil, fireOilUses > 0);
        FireOil.Text = $"火\n油\n×{fireOilUses}";
        FireOil.Disabled = !flags.CanFireOil;
        SetAttackCommandAvailable(ChainShot, chainShotUses > 0);
        ChainShot.Text = $"连\n锁\n弹\n×{chainShotUses}";
        ChainShot.Disabled = !flags.CanChainShot;
        SetAttackCommandAvailable(Mine, mineUses > 0);
        Mine.Text = $"布\n雷\n×{mineUses}";
        Mine.Disabled = !flags.CanMine;
        // ---- R-3 接舷管理组：俘获交换/脱离（仅接舷状态出现）----
        SetAttackCommandAvailable(Exchange, ship.Boarding is not null);
        SetAttackCommandAvailable(Disengage, ship.Boarding is not null);
        Exchange.Disabled = !flags.CanExchange;
        Disengage.Disabled = !flags.CanDisengage;
        // V-6：战斗内自沉作为单位行为选项——选中我方舰时始终显示；不满足资格置灰并提示原因（规则层校验已存在）。
        // 可点时执行战斗自沉（扣 15% 最大生命）；不可点原因由 SelfSinkReason 给出（已自沉/接舷/已攻击/通过性/需浅滩）。
        SelfSinkButton.Visible = true;
        SelfSinkButton.Disabled = !flags.CanSelfSink;
        SelfSinkButton.TooltipText = SelfSinkReason(ship, flags.CanSelfSink);
        ApplyAttackPage();
    }

    public void HidePanel()
    {
        ActionPanel.Visible = false;
        ShipStatusPanel.Visible = false;
        _attackPage = 0;
        SetCommandCategory(true);
    }

    public void HideActionPanel()
    {
        ActionPanel.Visible = false;
        _attackPage = 0;
        SetCommandCategory(true);
    }

    // 新一局/新战斗清空选择上下文；面板只在选中舰船后出现。
    public void ResetContext()
    {
        HideTurnBanner();
        ActionPanel.Visible = false;
        ShipStatusPanel.Visible = false;
        _attackPage = 0;
    }

    public void ShowShipStatus(BattleState battle, ShipState ship)
    {
        ShipStatusPanel.Visible = true;
        var definition = ship.Definition;
        var currentLoad = CurrentLoad(battle, ship);
        ShipPortrait.Texture = NavalShipView.HudTextureFor(ship);
        ShipName.Text = definition.DisplayName;
        ShipHpBar.MaxValue = Math.Max(1, definition.MaxHp);
        ShipHpBar.Value = Math.Max(0, ship.HitPoints);
        ShipHpText.Text = $"生命值 {ship.HitPoints}/{definition.MaxHp}";
        ShipLoadBar.MaxValue = Math.Max(1, definition.LoadCapacity);
        ShipLoadBar.Value = Math.Max(0, currentLoad);
        ShipLoadText.Text = $"负载 {currentLoad}/{definition.LoadCapacity}";
        ArmorValue.Text = ship.ArmorLevel.ToString();
        SpeedValue.Text = SpeedName(definition.SpeedCap);
        MovementValue.Text = ship.RemainingMovement.ToString();
        ArmorIcon.TooltipText = $"护甲：{ship.ArmorLevel}（减免受到的伤害）";
        SpeedIcon.TooltipText = $"速度：{SpeedName(definition.SpeedCap)}（基础移动 {SpeedTable.MovePoints(definition.SpeedCap)} 点）";
        MovementIcon.TooltipText = $"剩余移动：{ship.RemainingMovement} 点";
        _shipStatusPanelText = ShipStatusText(battle, ship);
    }

    public void SetTurnEnabled(bool enabled)
    {
        TurnLeft.Disabled = !enabled;
        TurnRight.Disabled = !enabled;
    }

    // F-7b/V-6：浅滩自沉按钮当前是否可见（选中我方舰时始终显示；headless 断言"无选中/敌方选中不可见"）。
    // 用 IsVisibleInTree 而非 .Visible：ActionPanel 隐藏时按钮自身 Visible 仍为真（节点默认可见），
    // 未选中任何舰时须与面板一起视为不可见。
    public bool SelfSinkButtonVisible() => SelfSinkButton.IsVisibleInTree();
    // V-6：自沉按钮置灰/原因只读状态（headless 断言"不满足资格置灰 + 原因"）。
    public bool SelfSinkButtonDisabled() => SelfSinkButton.Disabled;
    public string SelfSinkButtonTooltip() => SelfSinkButton.TooltipText;

    // V-6：战斗内自沉按钮置灰原因（选中我方舰时：不满足资格给原因，可点时给操作提示）。
    // 与控制器 ComputeActionFlags.CanSelfSink 同口径（未攻击/未自沉/非接舷/通过性非 FreeAll/船头在浅滩或陆河）。
    private static string SelfSinkReason(ShipState ship, bool canSelfSink)
    {
        if (canSelfSink) return "点击执行浅滩自沉（扣 15% 最大生命，固守浅滩）";
        if (ship.SelfSunk) return "该舰已自沉";
        if (ship.Boarding is not null) return "接舷中，无法自沉";
        if (ship.HasAttacked) return "本回合已攻击，无法自沉";
        if (ship.Definition.Passability == Passability.FreeAll) return "该舰型无法浅滩自沉";
        return "需在浅滩才能自沉";
    }

    // ---- F-7c 交付舰选择面板（金币不足接受劝降时弹出）----

    // 打开交付面板：列出可交付舰（存活/非自沉/未逃），CheckBox 由玩家勾选指定数量后确认。
    // 数量不符被规则拒绝时面板保留，玩家可重选（需求：提示并让玩家重选）。
    public void ShowDeliveryPanel(List<(string Id, string Name)> eligible, int required)
    {
        _deliveryRequired = required;
        foreach (var child in DeliveryList.GetChildren()) child.QueueFree();
        _deliveryCheckboxes.Clear();
        DeliveryCaption.Text = $"交付舰船（需选 {required} 艘）";
        var controller = GetNode<NavalBattleController>("../BattleController");
        foreach (var (id, name) in eligible)
        {
            var box = new CheckBox { Text = $"{name}（{id}）" };
            var shipId = id;
            // 勾选/取消 → 控制器维护交付集合（确认时读取）。
            box.Toggled += on => controller.OnDeliveryShipToggled(shipId, on);
            DeliveryList.AddChild(box);
            _deliveryCheckboxes[id] = box;
        }
        DeliveryPanel.Visible = true;
    }

    public void HideDeliveryPanel()
    {
        DeliveryPanel.Visible = false;
        foreach (var child in DeliveryList.GetChildren()) child.QueueFree();
        _deliveryCheckboxes.Clear();
    }

    // 只读访问（headless 冒烟断言：面板弹出/关闭、列出的符合舰数量、需交付数量）。
    public bool DeliveryPanelVisible() => DeliveryPanel.Visible;
    public int DeliveryRowCount() => DeliveryList.GetChildCount();
    public int DeliveryRequired() => _deliveryRequired;

    // T16 结算面板：胜负/金币结余 + 各结局分类计数摘要 + 「再来一局」返回 Demo 入口。
    // U-2c：extraText 非空时追加一行（随机遭遇奖励行，由 BattleController.EncounterResultText 提供）。
    public void ShowResult(BattleResult result, string? extraText = null)
    {
        ActionPanel.Visible = false;
        ShipStatusPanel.Visible = false;
        ResultPanel.Visible = true;
        var outcome = result.Outcome switch
        {
            BattleOutcome.PlayerVictory => "我方胜利",
            BattleOutcome.EnemyVictory => "敌方胜利",
            _ => "平局",
        };
        var counts = string.Join(" · ", new[]
        {
            $"{Count(result, ShipLossKind.Survived)} 存活",
            $"{Count(result, ShipLossKind.Sunk)} 沉没",
            $"{Count(result, ShipLossKind.Escaped)} 逃脱",
            $"{Count(result, ShipLossKind.Captured)} 被俘",
            $"{Count(result, ShipLossKind.Surrendered)} 移交",
            $"{Count(result, ShipLossKind.Permanent)} 永久固定",
        });
        ResultLabel.Text = $"{outcome}   金币结余 {result.PlayerGoldRemaining}\n损失概览：{counts}"
            + (string.IsNullOrEmpty(extraText) ? "" : $"\n{extraText}");
    }

    public void HideResult() => ResultPanel.Visible = false;

    // U-2c：结算面板「重掷换一场」按钮显隐（非随机遭遇模式隐藏）。
    public void SetRerollVisible(bool visible) => RerollButton.Visible = visible;

    // 只读访问（headless 冒烟断言）：结算面板全文 / 重掷按钮可见。
    public string ResultText() => ResultLabel.Text;
    public bool RerollButtonVisible() => RerollButton.Visible;

    private static int Count(BattleResult result, ShipLossKind kind)
        => result.Ships.Count(r => r.Kind == kind);

    public void ShowPlayerTurnStart(int round)
    {
        HideTurnBanner();
        StatusLabel.Text = $"第 {round} 回合 · 我方回合开始";
        MessageLabel.Text = "敌方回合结束 · 现在轮到我方行动";
        TurnBannerLabel.Text = "我方回合开始";
        TurnBanner.Modulate = Colors.White;
        TurnBanner.Visible = true;

        _turnBannerTween = CreateTween();
        _turnBannerTween.TweenInterval(1.8);
        _turnBannerTween.TweenProperty(TurnBanner, "modulate:a", 0.0f, 0.35f);
        _turnBannerTween.TweenCallback(Callable.From(() =>
        {
            TurnBanner.Visible = false;
            TurnBanner.Modulate = Colors.White;
            _turnBannerTween = null;
        }));
    }

    private void HideTurnBanner()
    {
        _turnBannerTween?.Kill();
        _turnBannerTween = null;
        TurnBanner.Visible = false;
        TurnBanner.Modulate = Colors.White;
    }

    public void SetMessage(string text)
    {
        HideTurnBanner();
        MessageLabel.Text = text;
    }

    // 读取当前消息（headless 交互测试断言用）。
    public string MessageText() => MessageLabel.Text;

    // ---- F-3 投降交涉面板（接受/拒绝敌方劝降 + 我方发起劝降）----

    // 敌方劝降待决（PendingSurrenderFrom==Enemy）：显示 接受投降/拒绝投降 按钮（玩家响应）。
    public void ShowSurrenderButtons()
    {
        SurrenderCaption.Text = "敌方提议你方投降";
        AcceptSurrenderButton.Visible = true;
        RejectSurrenderButton.Visible = true;
        SetSurrenderPanelVisible(true);
    }

    public void HideSurrenderButtons()
    {
        AcceptSurrenderButton.Visible = false;
        RejectSurrenderButton.Visible = false;
        // 无任何按钮可见时隐藏整面板。
        SetSurrenderPanelVisible(OfferSurrenderButton.Visible);
    }

    // 我方劝降按钮：enabled=true 显示且启用；enabled=false 显示但禁用（本回合已发起，每回合一次门禁）；无优势时由控制器调 HideSurrenderOffer。
    public void ShowSurrenderOffer(bool enabled)
    {
        SurrenderCaption.Text = "劝降：要求敌方投降";
        OfferSurrenderButton.Visible = true;
        OfferSurrenderButton.Disabled = !enabled;
        SetSurrenderPanelVisible(true);
    }

    public void HideSurrenderOffer()
    {
        OfferSurrenderButton.Visible = false;
        SetSurrenderPanelVisible(AcceptSurrenderButton.Visible || RejectSurrenderButton.Visible);
    }

    public void HideSurrenderPanel() => SetSurrenderPanelVisible(false);

    private void SetSurrenderPanelVisible(bool visible)
    {
        SurrenderPanel.Visible = visible;
        GetNodeOrNull<NavalLevelPlayController>("../../LevelPlay")?.SetModalOverlayVisible(visible);
    }

    // 只读访问（headless 冒烟断言：接受/拒绝弹出、劝降可用、每回合一次门禁禁用态）。
    public bool SurrenderPanelVisible() => SurrenderPanel.Visible;
    public bool OfferSurrenderButtonEnabled() => OfferSurrenderButton.Visible && !OfferSurrenderButton.Disabled;
    public bool AcceptSurrenderButtonVisible() => AcceptSurrenderButton.Visible;
    public bool RejectSurrenderButtonVisible() => RejectSurrenderButton.Visible;

    // ---- 左上角全局摘要：选中舰船时也保持不变，舰船详情由左下角状态区承载 ----

    // 读当前顶栏完整文本（界面仅显示三行精简摘要，Tooltip 保留详细全局字段）。
    public string TopLeftBarText() => TopLeftContent.TooltipText;

    // 保留原入口签名供控制器调用，但不再根据 selected 切换为舰船详情。
    public void ShowContextStatus(BattleState battle, ShipState? selected, ShipActionFlags? flags, int readyShips)
    {
        TopLeftCaption.Text = GlobalHeaderText(battle);
        TopLeftContent.Text = GlobalSummaryText(battle, readyShips);
        TopLeftContent.TooltipText = GlobalStatusText(battle, readyShips);
    }

    private string GlobalHeaderText(BattleState battle)
    {
        var faction = battle.CurrentFaction == FactionId.Player ? "我方" : "敌方";
        var wind = battle.Wind is { } d ? $"风 {DirectionName(d)}" : "无风";
        return $"{faction} · {WeatherName(battle)} / {wind}";
    }

    private static string GlobalSummaryText(BattleState battle, int readyShips)
    {
        var playerAlive = battle.Ships.Values.Count(s => s.Faction == FactionId.Player && s.HitPoints > 0);
        var enemyAlive = battle.Ships.Values.Count(s => s.Faction == FactionId.Enemy && s.HitPoints > 0);
        return $"待命{readyShips}\n舰{playerAlive}：{enemyAlive}";
    }

    // 左栏全局：回合/阵营/天气风向/当前阵营待命舰数/双方存活舰数。
    private string GlobalStatusText(BattleState battle, int readyShips)
    {
        var faction = battle.CurrentFaction == FactionId.Player ? "我方" : "敌方";
        // F-1：状态栏明确呈现实际天气/风向——有风" · 风向X"，无风" · 无风"（晴天无风）
        var wind = battle.Wind is { } d ? $" · 风向{DirectionName(d)}" : " · 无风";
        var playerAlive = battle.Ships.Values.Count(s => s.Faction == FactionId.Player && s.HitPoints > 0);
        var enemyAlive = battle.Ships.Values.Count(s => s.Faction == FactionId.Enemy && s.HitPoints > 0);
        return $"第 {battle.Round} 回合 · {faction}\n"
             + $"天气：{WeatherName(battle)}{wind}\n"
             + $"待命：{readyShips}\n"
             + $"存活：我方 {playerAlive} · 敌方 {enemyAlive}";
    }

    // 舰船摘要：生命/负载用条显示，护甲/速度/剩余移动用图标显示；武器/技能/状态不在舰况卡展示。
    private string ShipStatusText(BattleState battle, ShipState ship)
    {
        var def = ship.Definition;
        var lines = new List<string> { $"{def.DisplayName}（{def.Id}）" };
        lines.Add($"生命：{ship.HitPoints}/{def.MaxHp}");
        lines.Add($"负载：{CurrentLoad(battle, ship)}/{def.LoadCapacity}");
        lines.Add($"护甲：{ship.ArmorLevel}");
        lines.Add($"速度：{SpeedName(def.SpeedCap)}（{SpeedTable.MovePoints(def.SpeedCap)} 点）");
        lines.Add($"移动：{ship.RemainingMovement}");
        return string.Join("\n", lines);
    }

    // F-5：负载与规则层同口径（护甲每级 +3 + 武器负载；WeatherRules.CurrentLoad 含护甲/撞角/砲击/火炮）。
    private static int CurrentLoad(BattleState battle, ShipState ship) => WeatherRules.CurrentLoad(ship);

    private static string WeatherName(BattleState battle)
    {
        var def = battle.Config.Weather.FirstOrDefault(w =>
            string.Equals(w.Id, battle.Weather.ToString(), StringComparison.OrdinalIgnoreCase));
        return def?.DisplayName ?? battle.Weather.ToString();
    }

    private static string DirectionName(CardinalDirection d) => d switch
    {
        CardinalDirection.North => "北",
        CardinalDirection.East => "东",
        CardinalDirection.South => "南",
        CardinalDirection.West => "西",
        _ => "?",
    };

    private static string SpeedName(SpeedTier t) => t switch
    {
        SpeedTier.V0 => "V0",
        SpeedTier.V1 => "V1",
        SpeedTier.V2 => "V2",
        SpeedTier.V3 => "V3",
        SpeedTier.V4 => "V4",
        _ => "?",
    };

    // 伤害数字：入参为画布/世界坐标，经当前画布变换（含相机平移/缩放）转屏幕坐标后飘起渐隐文字
    //（UX-1：相机存在时数字仍落在目标舰格；无相机时退化为原 viewport≈global 行为）。
    public void ShowDamageText(Vector2 worldPos, string text, Color color)
    {
        var screenPos = GetViewport().GetCanvasTransform() * worldPos;
        var label = new Label
        {
            Text = text,
            Position = screenPos + new Vector2(-18, -28),
            ZIndex = 50,
        };
        label.AddThemeColorOverride("font_color", color);
        label.AddThemeFontSizeOverride("font_size", 24);
        AddChild(label);
        var tween = CreateTween();
        tween.TweenProperty(label, "position:y", label.Position.Y - 42, 1.1f);
        tween.Parallel().TweenProperty(label, "modulate:a", 0.0f, 1.1f);
        tween.TweenCallback(Callable.From(() => label.QueueFree()));
    }

    private static string FactionName(FactionId faction)
        => faction == FactionId.Player ? "我方回合" : "敌方回合";
}
