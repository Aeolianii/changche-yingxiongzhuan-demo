#nullable enable
using Godot;
using NavalCombat.Core;
using NavalCombat.Levels;
using System;
using System.Collections.Generic;
using System.Linq;

namespace NanjiangNaval;

// 布阵控制器：双方一次性全部布阵（不交替）。舰队从 data/naval/ships.json 经 NavalConfigLoader 加载。
// 默认阵型：双方各 4 舰横向、平行（玩家朝东、敌方朝西），在 48×36 大图各区呈纵深布置（设计 14 + UX-1）。
// 交互：点己方舰选中 → 点区域空格放置（该格为船头）/ 旋转按钮改横纵朝向 → 点「设为指挥舰」指定 → 「开始战斗」校验后交 BattleController。
// 非法占格（越界/重叠/区域外/不可通行地形）一律拒绝，返回原因 key。
public partial class NavalDeploymentController : Node2D, IGridClickReceiver
{
    // 预设己方区域（含 x、不含上边界；48×36 UX-1）：玩家 x[1,23) y[2,34)；敌 x[26,47) y[2,34)；中央 x[23,26) 留空为战场纵深。
    // 玩家区放宽到 x=22 列：p3/p4 默认在 (22,26)/(22,27)，东进 3/4 格即可与 e4(26,26) 形成双方向接舷邻接（各在 4 MP 内）。
    public static readonly Rect2I PlayerZone = new(1, 2, 22, 32);
    public static readonly Rect2I EnemyZone = new(26, 2, 21, 32);

    private NavalRulesConfig? _config;
    private BattleState _battle = null!;
    private NavalGridView _grid = null!;
    private Node2D _shipsRoot = null!;
    private Label? _statusLabel;
    private Label? _messageLabel;
    // UX-8：布阵底部面板（CanvasLayer——父节点 Node2D 设 Visible 不隐藏子 CanvasLayer，须显式控制其显隐）
    private CanvasLayer? _deployHud;
    private Panel? _deployPanel;
    private string? _selectedShip;
    private string? _flagshipId;
    // L-3：关卡模式定义（LevelSession.PendingLevelId 解析；null=自由模式原流程）。关卡模式按 LevelDefinition
    // 构建地图/固定天气风向/双方舰队/自沉/敌方 AI 开关，全图可布阵；Hints 无布阵提示时自动开始战斗。
    private LevelDefinition? _level;
    // U-2c：随机遭遇战模式（LevelSelect 生成后经 RandomEncounterSession.Begin 传入）。
    // 非 null = 遭遇模式：按遭遇的地图/布阵区/双方舰队构建，结算走自由 HUD 追加奖励行（不登记关卡）。
    private RandomEncounter? _encounter;
    private NavalLevelPlayController? _levelPlay;
    // 关卡模式玩家布阵区域：玩家舰队初始位置的包围盒 + 余量（防止"随意放置"到敌方半场/敌舰旁）。null=未初始化。
    private Rect2I? _levelPlayerZone;
    private Rect2I _levelEnemyZone;
    // F-4：布阵浅滩自沉按钮（设计 15）——选中满足自沉条件的舰时显示。
    private Button? _selfSinkButton;
    // F-5：布阵前装备配置 UI（设计 14）——底部栏「装备配置」按钮切换 EquipmentPanel；面板内逐舰增删武器/技能/护甲。
    private Button? _equipToggleButton;
    private Control? _equipPanel;
    private string? _equipShipId;   // 面板当前编辑的玩家舰（默认第一艘旗舰）
    private Label? _equipSlotsLabel;
    private Label? _equipHintLabel;
    private Button? _equipCloseButton;
    private readonly Dictionary<string, Button> _equipShipButtons = new();            // 舰位 id → 选择按钮
    private readonly Dictionary<string, (Button Minus, Label Count, Button Plus)> _weaponControls = new();
    private readonly Dictionary<string, (Button Minus, Label Count, Button Plus)> _skillControls = new();
    private (Button Minus, Label Count, Button Plus) _armorControls;
    // V-7：舰队配置修改器（增减舰船 / 装备 / 预设保存加载 / 应用到本场布阵）——自由模式布阵前可用。
    private const int MaxFleetSize = 12; // 舰队舰船上限（防无限添加；布阵区可容纳更多）
    private Button? _fleetToggleButton;
    private Control? _fleetPanel;
    private string? _fleetShipId;   // 面板当前编辑的玩家舰
    private Label? _fleetPreviewLabel;
    private Label? _fleetSlotsLabel;
    private LineEdit? _fleetNameEdit;
    private Button? _fleetSaveButton;
    private readonly Dictionary<string, (Button Minus, Label Count, Button Plus)> _fleetWeaponControls = new();
    private readonly Dictionary<string, (Button Minus, Label Count, Button Plus)> _fleetSkillControls = new();
    private (Button Minus, Label Count, Button Plus) _fleetArmorControls;
    private VBoxContainer? _fleetShipList;
    private VBoxContainer? _fleetPresetList;
    private FleetPresetStore? _fleetStore;
    private readonly Dictionary<string, NavalShipView> _shipViews = new();
    // 默认阵型按 roster 下标对齐（敌方有重复舰型，不能用舰型 id 作键）
    private readonly List<(GridPos Bow, CardinalDirection Facing)> _playerDefault = new();
    private readonly List<(GridPos Bow, CardinalDirection Facing)> _enemyDefault = new();
    // F-1：战斗种子。默认首局 seed 7（既有冒烟走晴天/无风路径不回归）；「再来一局」轮换种子让每场天气/风向不同；
    // 测试钩子 RebuildBattleForTest 可指定种子复现特定天气（同种子 → 同天气/同风向，可复现）。
    private int _battleSeedOverride = -1;
    private int _newGameCounter = 0;
    private Texture2D? _orderButtonTexture;

    // 默认阵型顺序 = 并列时自动指挥舰的优先级（第一艘优先）
    private static readonly string[] PlayerRoster = { "flagship", "frigate", "transport", "merchant" };
    private static readonly string[] EnemyRoster = { "flagship", "frigate", "frigate", "transport" };
    // F-5：默认武器装载（布阵前预置，玩家可在装备面板调整）——旗舰火炮、护卫舰砲击，保持既有攻击交互冒烟默认不回归。
    private static readonly Dictionary<string, string[]> DefaultWeaponEquip = new()
    {
        { "flagship", new[] { "cannon" } },
        { "frigate", new[] { "bombardment" } },
    };

    public override void _Ready()
    {
        _config = LoadConfigOrShowError();
        if (_config is null) return;
        // L-3：关卡模式 = LevelSession.PendingLevelId 命中 LevelRegistry 关卡（"free"/未命中 → 自由模式原流程）。
        var def = LevelRegistry.GetById(LevelSession.PendingLevelId);
        _level = def is not null && def.Id != "free" ? def : null;
        // U-2c：随机遭遇战（LevelSelect 生成后 Begin）→ 遭遇模式（独立于关卡/自由，按遭遇规格构建战斗）。
        _encounter = RandomEncounterSession.Active ? RandomEncounterSession.Pending : null;
        _levelPlay = GetNodeOrNull<NavalLevelPlayController>("../LevelPlay");
        _battle = _encounter is not null ? BuildBattleForEncounter(_encounter)
            : _level is not null ? BuildBattleForLevel(_level)
            : BuildBattle();
        _grid = GetNode<NavalGridView>("DeployGrid");
        _grid.ClickReceiver = this;
        _grid.Attach(_battle);
        _shipsRoot = GetNode<Node2D>("DeployShips");
        _statusLabel = GetNode<Label>("DeployHud/StatusLabel");
        _messageLabel = GetNode<Label>("DeployHud/MessageLabel");
        _deployHud = GetNode<CanvasLayer>("DeployHud");
        // 布阵底部面板只在选中己方舰时出现；底板不挡地图点击。
        _deployPanel = GetNodeOrNull<Panel>("DeployHud/Panel");
        if (_deployPanel is not null)
        {
            InkWashTheme.MakeClickTransparent(_deployPanel);
            _deployPanel.Visible = false;
        }
        StyleDeploymentScroll();
        // UX-8：阶段互斥——布阵阶段只显示布阵面板，隐藏战斗 HUD（CanvasLayer 不随父节点 Visible 隐藏，须显式控制）
        if (GetNodeOrNull<CanvasLayer>("../Battle/Hud") is { } battleHud) battleHud.Visible = false;
        // F-6：布阵阶段同时隐藏天气覆盖层（CanvasLayer 不随父节点隐藏，战斗开始才由 StartBattle 显示）。
        if (GetNodeOrNull<CanvasLayer>("../Battle/WeatherFx") is { } weatherFx) weatherFx.Visible = false;
        GetNode<Button>("DeployHud/Panel/Box/Columns/ShipCommands/FirstRow/Rotate").Pressed += RotateFromButton;
        GetNode<Button>("DeployHud/Panel/Box/Columns/ShipCommands/FirstRow/SetFlagship").Pressed += FlagshipFromButton;
        GetNode<Button>("DeployHud/Panel/Box/Columns/ShipCommands/SecondRow/ResetDefault").Pressed += AutoDeployDefault;
        GetNode<Button>("DeployHud/Panel/Box/Columns/BattleCommand/ConfirmCenter/Confirm").Pressed += ConfirmFromButton;
        // F-4/V-6：浅滩自沉按钮——初始隐藏（无选中）；选中玩家舰时始终显示（V-6），
        // 不满足资格置灰并提示原因（需在浅滩 / 该舰型无法浅滩自沉 / 已自沉）。
        _selfSinkButton = GetNodeOrNull<Button>("DeployHud/Panel/Box/Columns/ShipCommands/SecondRow/SelfSink");
        if (_selfSinkButton is not null)
        {
            _selfSinkButton.Pressed += SelfSinkFromButton;
            _selfSinkButton.Visible = false;
        }
        // F-5：装备配置按钮（底部栏）——切换装备面板。
        _equipToggleButton = GetNodeOrNull<Button>("DeployHud/Panel/Box/Columns/FleetCommands/Equip");
        if (_equipToggleButton is not null) _equipToggleButton.Pressed += EquipToggleFromButton;
        // V-7：舰队配置按钮（底部栏）——切换舰队配置面板（自由模式增删舰/装备/预设保存加载）。
        _fleetToggleButton = GetNodeOrNull<Button>("DeployHud/Panel/Box/Columns/FleetCommands/FleetConfig");
        if (_fleetToggleButton is not null) _fleetToggleButton.Pressed += FleetToggleFromButton;
        if (_level is null) BuildDefaultLineups();
        BuildFleet(); // L-3：关卡模式经 BuildFleet 内分支按 LevelDefinition 装配（下方）；自由模式沿用默认阵型
        // GridView Attach 早于舰队装配；舰船齐备后把镜头移到已指定指挥舰，未指定时随机落在我方舰上。
        _grid.FocusCameraOnPlayerFleet();
        // 布阵区：关卡模式按玩家舰队初始位置计算；随机遭遇模式直接用遭遇的玩家/敌区。
        if (_level is not null) ComputeLevelPlayerZone();
        else if (_encounter is not null)
        {
            _levelPlayerZone = ToRect(_encounter.PlayerZone);
            _levelEnemyZone = ToRect(_encounter.EnemyZone);
        }
        _grid.ShowDeploymentZones(ZoneOverlays());
        RefreshDeploymentHighlights();
        BuildEquipmentPanel(); // F-5：构建装备面板内容（舰选择 + 逐武器/技能 [-]N[+] 行）；默认隐藏
        BuildFleetDesignerPanel(); // V-7：舰队配置面板（增减舰船/装备/预设保存加载）；默认隐藏
        ApplyDeployStatusText();
        // L-3：关卡无布阵提示（"布阵/装备/确认布阵/开始战斗"关键词）→ 自动开始战斗（1-1 样例直入战斗）。
        if (_level is not null && !HasDeploymentHint(_level))
        {
            var autoErr = ConfirmDeployment();
            if (autoErr.Length > 0) GD.PushWarning($"关卡 {_level.Id} 自动开始战斗失败：{autoErr}");
        }
    }

    // 横向布阵卷轴：古风卷轴负责整体轮廓，纸签按钮保持横排并拉开主次层级。
    private void StyleDeploymentScroll()
    {
        if (_deployPanel is null) return;
        _deployPanel.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
        _orderButtonTexture = GD.Load<Texture2D>("res://assets/naval/ui/level_select_return_brush.png");

        var columns = GetNode<HBoxContainer>("DeployHud/Panel/Box/Columns");
        foreach (var button in FindOrderButtons(columns))
        {
            StyleHorizontalOrderButton(button, _orderButtonTexture);
            button.FocusMode = Control.FocusModeEnum.None;
            button.MouseDefaultCursorShape = Control.CursorShape.PointingHand;
            button.Alignment = HorizontalAlignment.Center;
        }

        foreach (var titlePath in new[] { "ShipCommands/Title", "FleetCommands/Title", "BattleCommand/Title" })
        {
            var label = GetNode<Label>($"DeployHud/Panel/Box/Columns/{titlePath}");
            label.AddThemeFontOverride("font", InkWashTheme.Font());
            label.AddThemeFontSizeOverride("font_size", 24);
            label.AddThemeColorOverride("font_color", Colors.White);
            label.AddThemeColorOverride("font_outline_color", Colors.Black);
            label.AddThemeConstantOverride("outline_size", 8);
        }
    }

    private static IEnumerable<Button> FindOrderButtons(Node root)
    {
        foreach (var child in root.GetChildren())
        {
            if (child is Button button) yield return button;
            foreach (var nested in FindOrderButtons(child)) yield return nested;
        }
    }

    private static void StyleHorizontalOrderButton(Button button, Texture2D? texture)
    {
        button.AddThemeStyleboxOverride("normal", HorizontalOrderTextureStyle(texture, Colors.White));
        button.AddThemeStyleboxOverride("hover", HorizontalOrderTextureStyle(texture, new Color("fff1c2")));
        button.AddThemeStyleboxOverride("pressed", HorizontalOrderTextureStyle(texture, new Color("a9b0a8")));
        button.AddThemeStyleboxOverride("disabled", HorizontalOrderTextureStyle(texture, new Color(0.48f, 0.48f, 0.45f, 0.72f)));
        button.AddThemeStyleboxOverride("focus", new StyleBoxEmpty());
        button.AddThemeFontOverride("font", InkWashTheme.Font());
        button.AddThemeFontSizeOverride("font_size", 21);
        button.AddThemeColorOverride("font_color", InkWashTheme.PaperLight);
        button.AddThemeColorOverride("font_hover_color", new Color("f0cf79"));
        button.AddThemeColorOverride("font_pressed_color", Colors.White);
        button.AddThemeColorOverride("font_disabled_color", new Color("8f918b"));
        button.AddThemeColorOverride("font_outline_color", InkWashTheme.InkDeep);
        button.AddThemeConstantOverride("outline_size", 4);
    }

    private static StyleBoxTexture HorizontalOrderTextureStyle(Texture2D? texture, Color tint)
        => new()
        {
            Texture = texture,
            ModulateColor = tint,
        TextureMarginLeft = 72,
        TextureMarginTop = 26,
        TextureMarginRight = 72,
        TextureMarginBottom = 26,
        ContentMarginLeft = 24,
        ContentMarginRight = 24,
        ContentMarginTop = 10,
        ContentMarginBottom = 10,
            AxisStretchHorizontal = StyleBoxTexture.AxisStretchMode.Stretch,
            AxisStretchVertical = StyleBoxTexture.AxisStretchMode.Stretch,
        };

    // ---- 地图/配置/战斗装配 ----

    private static BattleMap BuildMap()
    {
        var map = new BattleMap(48, 36);
        for (var x = 0; x < 48; x++)
            for (var y = 0; y < 36; y++)
                map.SetTerrain(new GridPos(x, y), TerrainType.DeepWater);
        // 地形稀疏点缀（UX-1，避开全部默认舰格与冒烟路径）：
        // 山地（岛/障碍）：(3,8) 玩家区内供非法占格演示；(5,30)/(23,3)/(42,30)/(44,6) 岛屿障碍
        // 浅滩：(8,20)/(21,33)/(26,4)/(45,24)  礁石：(11,16)/(23,30)/(40,18)
        map.SetTerrain(new GridPos(3, 8), TerrainType.Mountain);
        map.SetTerrain(new GridPos(5, 30), TerrainType.Mountain);
        map.SetTerrain(new GridPos(23, 3), TerrainType.Mountain);
        map.SetTerrain(new GridPos(42, 30), TerrainType.Mountain);
        map.SetTerrain(new GridPos(44, 6), TerrainType.Mountain);
        map.SetTerrain(new GridPos(8, 20), TerrainType.Shallow);
        map.SetTerrain(new GridPos(21, 33), TerrainType.Shallow);
        map.SetTerrain(new GridPos(26, 4), TerrainType.Shallow);
        map.SetTerrain(new GridPos(45, 24), TerrainType.Shallow);
        map.SetTerrain(new GridPos(11, 16), TerrainType.Reef);
        map.SetTerrain(new GridPos(23, 30), TerrainType.Reef);
        map.SetTerrain(new GridPos(40, 18), TerrainType.Reef);
        // F-2：地图出口边界（设计 16.1）——左右最外列（x=0 与 x=47 整列）为出口格，任一方"开到边缘即逃"。
        // 布阵区域（玩家 x[1,23)、敌 x[26,47)）不含出口列 → 出口必须"开"到边缘才能触达，直观。
        for (var y = 0; y < 36; y++)
        {
            map.ExitCells.Add(new GridPos(0, y));
            map.ExitCells.Add(new GridPos(47, y));
        }
        return map;
    }

    private static NavalRulesConfig? LoadConfigOrShowError()
    {
        try
        {
            var dir = System.IO.Path.Combine(ProjectSettings.GlobalizePath("res://"), "data", "naval");
            return NavalConfigLoader.LoadFromDirectory(dir);
        }
        catch (Exception ex)
        {
            GD.PushError($"加载 data/naval 配置失败：{ex.Message}");
            return null;
        }
    }

    private BattleState BuildBattle()
    {
        // F-1：天气/风向在战斗开始时用种子化 Random 掷定（RollStartWeather 在 ConfirmDeployment 调用）。
        // 首局默认 seed 7 → 晴天无风（既有冒烟走晴天路径）；再来一局轮换种子（+101）让每场天气/风向不同；
        // 测试钩子 RebuildBattleForTest 指定种子 → 同种子两次构建天气/风向相同（可复现）。
        var seed = _battleSeedOverride >= 0 ? _battleSeedOverride : 7 + _newGameCounter++ * 101;
        return new() { Map = BuildMap(), Config = _config!, Random = new SeedRandomSource(seed) };
    }

    // L-3：关卡战斗构建——地图按 LevelDefinition.Map（ASCII 地形 + 出口格）、天气/风向固定（LevelDefinition 无随机，
    // 跳过 RollStartWeather）；种子化 Random 仅用于伤害/掷骰。自由模式沿用 BuildBattle。
    private BattleState BuildBattleForLevel(LevelDefinition def)
    {
        var seed = _battleSeedOverride >= 0 ? _battleSeedOverride : 7 + _newGameCounter++ * 101;
        return new()
        {
            Map = BuildMapFromSpec(def.Map),
            Config = _config!,
            Random = new SeedRandomSource(seed),
            Weather = def.Weather,
            Wind = def.Wind,
        };
    }

    // U-2c：随机遭遇战斗构建——地图按遭遇规格（ASCII 地形 + 出口格）；天气/风向在 ConfirmDeployment
    // 随机掷定（自由语义，种子化可复现）；种子化 Random 仅用于伤害/掷骰。遭遇地图即战斗地图。
    private BattleState BuildBattleForEncounter(RandomEncounter encounter)
    {
        var seed = _battleSeedOverride >= 0 ? _battleSeedOverride : 7 + _newGameCounter++ * 101;
        return new()
        {
            Map = BuildMapFromSpec(encounter.Map),
            Config = _config!,
            Random = new SeedRandomSource(seed),
        };
    }

    private static BattleMap BuildMapFromSpec(LevelMapSpec spec)
    {
        var map = new BattleMap(spec.Width, spec.Height);
        for (var x = 0; x < spec.Width; x++)
            for (var y = 0; y < spec.Height; y++)
                map.SetTerrain(new GridPos(x, y), spec.TerrainAt(x, y));
        foreach (var exit in spec.ExitCells) map.ExitCells.Add(exit);
        return map;
    }

    // L-3：关卡是否需人工布阵（Hints 含 布阵/装备/确认布阵/开始战斗 关键词）→ 否则自动开始战斗（1-1 直入战斗）。
    private static bool HasDeploymentHint(LevelDefinition def)
        => def.Hints.Any(h => h.Contains("布阵") || h.Contains("装备") || h.Contains("确认布阵") || h.Contains("开始战斗"));

    private void BuildDefaultLineups()
    {
        // UX-1 默认阵型（48×36，双方横向平行、玩家朝东/敌方朝西）：
        // 玩家 p1旗舰(21,6) p2护卫舰(21,13) p3运输船(21,26) p4商船(21,27)；
        // 敌方 e1旗舰(26,6) e2护卫舰(26,13) e3护卫舰(30,22) e4运输船(26,27)。
        // 要点：p2↔e2 最近格距 5（d²=25，砲击上限，选中即可直击）；p3/p4 与 e4 保持接舷/布雷冒烟路径可达。
        _playerDefault.Clear();
        _enemyDefault.Clear();
        // UX-1：p3/p4 靠前（22 列），e4 移至 (26,26)——保证 p3 东进 3 格、p4 东进 4 格即可对 e4 形成接舷邻接（各在 4 MP 内）。
        _playerDefault.Add((new GridPos(21, 6), CardinalDirection.East));
        _playerDefault.Add((new GridPos(21, 13), CardinalDirection.East));
        _playerDefault.Add((new GridPos(22, 26), CardinalDirection.East));
        _playerDefault.Add((new GridPos(22, 27), CardinalDirection.East));
        _enemyDefault.Add((new GridPos(26, 6), CardinalDirection.West));
        _enemyDefault.Add((new GridPos(26, 13), CardinalDirection.West));
        _enemyDefault.Add((new GridPos(30, 22), CardinalDirection.West));
        _enemyDefault.Add((new GridPos(26, 26), CardinalDirection.West));
    }

    private void BuildFleet()
    {
        // U-2c：随机遭遇按遭遇规格装配双方舰队；L-3 关卡模式按 LevelDefinition 装配；自由模式沿用默认阵型。
        if (_encounter is not null) AddFleetFromEncounter(_encounter);
        else if (_level is not null) AddFleetFromLevel(_level);
        else
        {
            // V-7：自由模式玩家舰队——活动预设命中且合法 → 用预设替换默认阵型舰队（敌方保持默认 4 舰）。
            if (FleetPresetSession.Active && FleetStore().Get(FleetPresetSession.ActiveName!) is { } activePreset
                && FleetPresetValidator.Validate(_config!, activePreset).Count == 0)
            {
                AddPresetFleet(activePreset, FactionId.Player);
            }
            else
            {
                AddFleetShips(PlayerRoster, _playerDefault, FactionId.Player);
            }
            AddFleetShips(EnemyRoster, _enemyDefault, FactionId.Enemy);
        }
        foreach (var ship in _battle.Ships.Values)
        {
            var view = new NavalShipView { Name = ship.Id };
            view.Setup(ship, _grid);
            _shipsRoot.AddChild(view);
            _shipViews[ship.Id] = view;
        }
    }

    // U-2c：遭遇双方舰队装配（同 L-3 的 LevelShipSpec → ShipState；玩家舰沿遭遇玩家区、敌舰沿遭遇敌区）。
    private void AddFleetFromEncounter(RandomEncounter encounter)
    {
        AddLevelFleet(encounter.PlayerFleet, FactionId.Player);
        AddLevelFleet(encounter.EnemyFleet, FactionId.Enemy);
    }

    // L-3：关卡双方舰队装配（LevelShipSpec → ShipState；id 沿用 ShipIdFor 同款 p1..e1..）。
    private void AddFleetFromLevel(LevelDefinition def)
    {
        AddLevelFleet(def.PlayerFleet, FactionId.Player);
        AddLevelFleet(def.EnemyFleet, FactionId.Enemy);
    }

    private void AddLevelFleet(IReadOnlyList<LevelShipSpec> specs, FactionId faction)
    {
        var index = 0;
        foreach (var spec in specs)
        {
            var shipDef = _config!.Ships.FirstOrDefault(s => s.Id == spec.ShipTypeId);
            if (shipDef is null) { GD.PushWarning($"ships.json 缺少舰型 {spec.ShipTypeId}"); continue; }
            var ship = new ShipState
            {
                Id = ShipIdFor(faction, index),
                Definition = shipDef,
                Faction = faction,
                Bow = spec.Bow,
                Facing = spec.Facing,
                HitPoints = shipDef.MaxHp,
                ArmorLevel = spec.Equipment?.ArmorLevel ?? shipDef.BaseArmor,
                SelfSunk = spec.SelfSunk,
            };
            // L-3：装备按 LevelShipSpec.Equipment（武器/技能/护甲；未给定 → 该舰不预装，与 Demo 默认装载解耦）。
            if (spec.Equipment?.Weapons is { } weapons)
                foreach (var (wid, count) in weapons)
                    ship.WeaponCounts[wid] = ship.WeaponCounts.GetValueOrDefault(wid) + count;
            if (spec.Equipment?.Skills is { } skills)
                foreach (var (sid, count) in skills)
                    ship.SkillLoadout[sid] = ship.SkillLoadout.GetValueOrDefault(sid) + count;
            _battle.Ships[ship.Id] = ship;
            index++;
        }
    }

    private void AddFleetShips(string[] roster, IReadOnlyList<(GridPos Bow, CardinalDirection Facing)> defaults, FactionId faction)
    {
        for (var i = 0; i < roster.Length; i++)
        {
            var def = _config!.Ships.FirstOrDefault(s => s.Id == roster[i]);
            if (def is null) { GD.PushWarning($"ships.json 缺少舰型 {roster[i]}"); continue; }
            var (bow, facing) = defaults[i];
            var id = ShipIdFor(faction, i);
            var ship = new ShipState
            {
                Id = id,
                Definition = def,
                Faction = faction,
                Bow = bow,
                Facing = facing,
                HitPoints = def.MaxHp,
                ArmorLevel = def.BaseArmor,
            };
            // F-5：默认武器装载（DefaultWeaponEquip：旗舰火炮、护卫砲击）——布阵前预置，玩家可在装备面板增删；
            // 与既有交互冒烟等价（interaction 144 伤害基于 1 门火炮、weather 负载 9 基于护甲 2×3 + 砲击 3）。
            if (DefaultWeaponEquip.TryGetValue(def.Id, out var weapons))
                foreach (var w in weapons)
                    ship.WeaponCounts[w] = ship.WeaponCounts.GetValueOrDefault(w) + 1;
            // F-5：默认技能装载（SkillSeeding.DemoSkillLayout 舰型布局）→ SkillLoadout（槽位数）；
            // SkillSeeding.Seed 在 ConfirmDeployment 按槽位 × skills.json 每场次数播种 SkillUsesLeft。
            if (SkillSeeding.DemoSkillLayout.TryGetValue(def.Id, out var skills))
                foreach (var s in skills)
                    ship.SkillLoadout[s] = ship.SkillLoadout.GetValueOrDefault(s) + 1;
            _battle.Ships[id] = ship;
        }
    }

    private static string ShipIdFor(FactionId faction, int index)
        => faction == FactionId.Player ? $"p{index + 1}" : $"e{index + 1}";

    // ---- 对外交互入口（GDScript 冒烟与场景按钮调用） ----

    // 放置己方舰船到 (bowX,bowY)，朝向 east/north/south/west（可带 right/left/up/down）。空字符串 = 成功。
    public string PlaceShip(string shipId, int bowX, int bowY, string facingName)
    {
        var ship = _battle.ShipOrNull(shipId);
        if (ship is null || ship.Faction != FactionId.Player) return "deploy.unknown_ship";
        if (ship.SelfSunk) return "deploy.self_sunk"; // F-4：自沉舰固守浅滩，禁移动
        if (!TryParseFacing(facingName, out var facing)) return "deploy.bad_facing";
        var bow = new GridPos(bowX, bowY);
        var err = ValidatePlacement(ship, bow, facing);
        if (err is not null) return err;
        ship.Bow = bow;
        ship.Facing = facing;
        SyncShipView(ship.Id);
        RefreshSelfSinkButton(); // 移动后地形变化可能改变自沉资格
        return "";
    }

    public string RotateSelected()
    {
        var ship = SelectedPlayerShip();
        if (ship is null) return "deploy.no_selection";
        if (ship.SelfSunk) return "deploy.self_sunk"; // F-4：自沉舰禁转向（锁朝向）
        var newFacing = ship.Facing.Turn(TurnDirection.Right);
        var err = ValidatePlacement(ship, ship.Bow, newFacing);
        if (err is not null) return err;
        ship.Facing = newFacing;
        SyncShipView(ship.Id);
        _levelPlay?.OnRotated(); // L-3：布阵转向提示推进
        return "";
    }

    // F-4：布阵阶段浅滩主动自沉（设计 15）——通过性 1/2 且船头位于浅滩的己方舰自沉：
    // 保留生命（布阵免费）/朝向/占格，永久失去移动与转向（本控制器锁位 + 规则层 MovementRules 拦）。
    // 自沉后仍可指定指挥舰、开始战斗（规则层校验放行）。空字符串 = 成功。
    public string SelfSinkSelected()
    {
        var ship = SelectedPlayerShip();
        if (ship is null) return "deploy.no_selection";
        if (!CanSelfSinkInDeploy(ship))
        {
            // 用规则层校验给精确原因（已自沉/通过性/地形等）；规则层放行但非浅滩（礁石/深水=即时沉没移除）→ 布阵按钮只做浅滩固守。
            var reason = BattleEndRules.ValidateSelfSink(_battle, new SelfSinkCommand(ship.Id, DeploymentPhase: true));
            return reason is null ? "deploy.not_on_shallow" : reason;
        }
        // 复用规则层结算：浅滩 + DeploymentPhase → SelfSunk=true、HP 不扣（与战斗自沉同源校验/事件）。
        var events = BattleEndRules.ResolveSelfSink(_battle, new SelfSinkCommand(ship.Id, DeploymentPhase: true));
        if (events.Length == 0) return "deploy.self_sink_failed";
        SyncShipView(ship.Id);
        RefreshSelfSinkButton(); // 自沉后不满足资格 → 按钮隐藏；保持选中（移动/旋转被拒原因直出 deploy.self_sunk）
        SetMessage($"{ship.Definition.DisplayName} 已自沉，将固守当前浅滩");
        return "";
    }

    public string SelectShipForDeploy(string shipId)
    {
        var ship = _battle.ShipOrNull(shipId);
        if (ship is null || ship.Faction != FactionId.Player) return "deploy.unknown_ship";
        if (_selectedShip is not null && _shipViews.TryGetValue(_selectedShip, out var old)) old.SetSelected(false);
        _selectedShip = shipId;
        if (_shipViews.TryGetValue(shipId, out var view)) view.SetSelected(true);
        // 与战斗阶段一致：选中舰船后将共享相机平滑居中到舰船几何中心。
        _grid.FocusCameraOnShip(ship);
        RefreshDeploymentHighlights();
        // F-4：自沉舰选中提示固守浅滩（移动/转向已锁），仍可指定指挥舰/开始战斗。
        SetMessage(ship.SelfSunk
            ? $"选中 {ship.Definition.DisplayName}（已自沉，固守当前浅滩）· 可点「设为指挥舰」或「开始战斗」"
            : $"选中 {ship.Definition.DisplayName} · 点击目标格移动（该格=船头），可点「旋转朝向」· 右键退选");
        RefreshSelfSinkButton();
        _levelPlay?.OnPlayerSelected(); // L-3：布阵选中提示推进
        if (_deployPanel is not null) _deployPanel.Visible = true;
        return "";
    }

    // 取消当前选中并隐藏布阵相关面板。未选中返回 "deploy.no_selection"。
    public string DeselectSelected()
    {
        if (_selectedShip is null) return "deploy.no_selection";
        if (_shipViews.TryGetValue(_selectedShip, out var old)) old.SetSelected(false);
        _selectedShip = null;
        RefreshDeploymentHighlights();
        SetMessage("已取消选择");
        if (_deployPanel is not null) _deployPanel.Visible = false;
        if (_equipPanel is not null) _equipPanel.Visible = false;
        if (_fleetPanel is not null) _fleetPanel.Visible = false;
        RefreshSelfSinkButton();
        return "";
    }

    // 右键在棋盘或 UI 任意位置退选，布阵台随选择一起隐藏。
    public override void _Input(InputEvent @event)
    {
        if (!Visible || @event is not InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Right }) return;
        if (OnRightClick()) GetViewport().SetInputAsHandled();
    }

    public bool OnRightClick()
    {
        if (_selectedShip is null) return false;
        DeselectSelected();
        return true;
    }

    // 当前选中的己方舰 id；未选中空串。
    public string SelectedShip() => _selectedShip ?? "";

    // 格中心世界坐标（供 headless 冒烟按"点目标格移动"点击路径驱动）。
    public Vector2 CellToWorld(int x, int y) => _grid.GridToWorldCenter(new GridPos(x, y));

    public string SetFlagship(string shipId)
    {
        var ship = _battle.ShipOrNull(shipId);
        if (ship is null || ship.Faction != FactionId.Player) return "deploy.unknown_ship";
        _flagshipId = shipId;
        SetMessage($"指挥舰：{ship.Definition.DisplayName}");
        return "";
    }

    // 当前玩家指挥舰（未指定时自动取占格最多舰，并列按默认阵型顺序第一艘）
    public string PlayerFlagship() => _flagshipId ?? AutoFlagship(PlayerRoster, FactionId.Player);

    // 恢复双方默认阵型（遭遇模式 → 恢复遭遇生成的初始位置）。
    public void AutoDeployDefault()
    {
        _flagshipId = null;
        if (_encounter is not null) ApplyEncounterLineup();
        else
        {
            ApplyDefaultLineup(PlayerRoster, _playerDefault, FactionId.Player);
            ApplyDefaultLineup(EnemyRoster, _enemyDefault, FactionId.Enemy);
        }
        foreach (var id in _shipViews.Keys) SyncShipView(id);
        SetMessage("已恢复默认阵型");
    }

    // 遭遇模式：把双方舰队恢复到遭遇生成的初始位置（id 顺序与遭遇规格列表一致 p1.. / e1..）。
    private void ApplyEncounterLineup()
    {
        ApplyEncounterSide(_encounter!.PlayerFleet, FactionId.Player);
        ApplyEncounterSide(_encounter.EnemyFleet, FactionId.Enemy);
    }

    private void ApplyEncounterSide(IReadOnlyList<LevelShipSpec> specs, FactionId faction)
    {
        for (var i = 0; i < specs.Count; i++)
        {
            var ship = _battle.ShipOrNull(ShipIdFor(faction, i));
            if (ship is null || ship.Faction != faction) continue;
            if (ship.SelfSunk) continue; // 自沉舰固守浅滩，恢复默认阵型不移动它
            ship.Bow = specs[i].Bow;
            ship.Facing = specs[i].Facing;
        }
    }

    // 校验全部占格、定指挥舰、初始化战斗状态，并把同一 BattleState 交给 Battle/BattleController 开始战斗。空字符串 = 成功。
    public string ConfirmDeployment()
    {
        foreach (var ship in _battle.Ships.Values)
        {
            var err = ValidatePlacement(ship, ship.Bow, ship.Facing);
            if (err is not null) return err;
        }
        // L-3：关卡模式固定天气/风向（LevelDefinition，跳过 RollStartWeather）；空舰队阵营不登记指挥舰。
        if (_battle.Ships.Values.Any(s => s.Faction == FactionId.Player))
            _battle.Flagships[FactionId.Player] = PlayerFlagship();
        if (_battle.Ships.Values.Any(s => s.Faction == FactionId.Enemy))
            _battle.Flagships[FactionId.Enemy] = AutoFlagship(EnemyRoster, FactionId.Enemy);
        if (_level is null)
        {
            // F-1：战斗开始时随机掷定整场天气与风向（设计 6；用 _battle.Random 种子化可复现）。
            // 在计算首回合移动点之前调用（雨天 -1 / 台风 -2 影响 CurrentMovementPoints）。
            WeatherRules.RollStartWeather(_battle);
        }
        _battle.Round = 1;
        _battle.CurrentFaction = FactionId.Player;
        foreach (var ship in _battle.Ships.Values)
        {
            ship.HasAttacked = false;
            ship.SpentMovement = 0;
            ship.RemainingMovement = WeatherRules.CurrentMovementPoints(_battle, ship);
            ship.TurnStartBow = ship.Bow; // F-1：首回合风向修正起点快照
        }
        // T11 结转（T13 B）：战斗初始化时按舰型技能槽位 × 每局次数播种 SkillUsesLeft（data/naval/skills.json）。
        SkillSeeding.Seed(_battle);
        var battleController = GetNodeOrNull<NavalBattleController>("../Battle/BattleController");
        if (battleController is not null)
        {
            if (_level is not null) battleController.SetEnemyAiEnabled(_level.EnemyAiEnabled); // L-3：敌方 AI 开关
            else if (_encounter is not null) battleController.SetEnemyAiEnabled(true); // U-2c：随机遭遇敌方为正常敌人，AI 开
            battleController.StartBattle(_battle);
            StartBattleTransition();
        }
        _levelPlay?.OnDeployConfirmed(); // L-3：布阵完成提示推进（1-2 手动确认后提示"击沉全部敌舰即通关"）
        return "";
    }

    public int PlayerShipCount() => _battle?.Ships.Values.Count(s => s.Faction == FactionId.Player) ?? 0;
    public int EnemyShipCount() => _battle?.Ships.Values.Count(s => s.Faction == FactionId.Enemy) ?? 0;
    // U-2c：随机遭遇只读状态（headless 冒烟断言遭遇模式激活/难度/种子/地图与敌方来源）。
    public bool RandomEncounterActive() => _encounter is not null;
    public int RandomEncounterDifficulty() => _encounter?.Difficulty ?? 0;
    public int RandomEncounterSeed() => _encounter?.Seed ?? 0;
    public string RandomEncounterMapLabel() => _encounter?.MapSourceLabel ?? "";
    public string RandomEncounterEnemyLabel() => _encounter?.EnemyLabel ?? "";
    public int RandomEncounterPlayerFleetCount() => _encounter?.PlayerFleet.Count ?? 0;
    // F-2：出口格只读（headless 冒烟断言"地图有出口边界"）。
    public int ExitCellCount() => _battle?.Map.ExitCells.Count ?? 0;
    public bool IsExitCell(int x, int y) => _battle?.Map.ExitCells.Contains(new GridPos(x, y)) ?? false;

    // 只读状态访问（供 headless 布阵冒烟断言闭环）：Bow/Facing；Facing 索引 0=N 1=E 2=S 3=W
    public int BowX(string shipId) => _battle.ShipOrNull(shipId)?.Bow.X ?? -1;
    public int BowY(string shipId) => _battle.ShipOrNull(shipId)?.Bow.Y ?? -1;
    public int FacingIndex(string shipId) => (int)(_battle.ShipOrNull(shipId)?.Facing ?? CardinalDirection.North);
    public bool DeployPanelVisible() => _deployPanel?.Visible ?? false;

    // F-4/V-6：只读状态（headless 冒烟断言自沉闭环）——按钮显隐/置灰/原因、SelfSunk 标记、生命。
    public bool SelfSinkButtonVisible() => _selfSinkButton?.Visible ?? false;
    public bool SelfSinkButtonDisabled() => _selfSinkButton?.Disabled ?? true;
    public string SelfSinkButtonTooltip() => _selfSinkButton?.TooltipText ?? "";
    public bool IsSelfSunk(string shipId) => _battle.ShipOrNull(shipId)?.SelfSunk ?? false;
    public int ShipHitPoints(string shipId) => _battle.ShipOrNull(shipId)?.HitPoints ?? -1;

    // F-5：装备只读状态（headless 冒烟断言装备配置闭环）——面板显隐/当前编辑舰/武器数/技能槽位数/护甲/负载/减伤/槽位。
    public bool EquipPanelVisible() => _equipPanel?.Visible ?? false;
    public string EquipShip() => _equipShipId ?? "";
    public int ShipWeaponCount(string shipId, string weaponId) => _battle.ShipOrNull(shipId)?.WeaponCounts.GetValueOrDefault(weaponId, 0) ?? -1;
    public int ShipSkillSlotCount(string shipId, string skillId) => _battle.ShipOrNull(shipId)?.SkillLoadout.GetValueOrDefault(skillId, 0) ?? -1;
    public int ShipArmorLevel(string shipId) => _battle.ShipOrNull(shipId)?.ArmorLevel ?? -1;
    public int ShipUsedWeaponSlots(string shipId) => _battle.ShipOrNull(shipId) is { } s ? UsedWeaponSlots(s) : -1;
    public int ShipUsedSkillSlots(string shipId) => _battle.ShipOrNull(shipId) is { } s ? UsedSkillSlots(s) : -1;
    public int ShipWeaponSlots(string shipId) => _battle.ShipOrNull(shipId)?.Definition.WeaponSlots ?? -1;
    public int ShipSkillSlots(string shipId) => _battle.ShipOrNull(shipId)?.Definition.SkillSlots ?? -1;
    public int ShipArmorSlots(string shipId) => _battle.ShipOrNull(shipId)?.Definition.ArmorSlots ?? -1;
    public int ShipLoad(string shipId) => _battle.ShipOrNull(shipId) is { } s ? WeatherRules.CurrentLoad(s) : -1;
    public int ShipLoadCapacity(string shipId) => _battle.ShipOrNull(shipId)?.Definition.LoadCapacity ?? -1;
    // 减伤百分比（0-80，与 DamageRules.ArmorReductionPerLevel/ArmorMaxReduction 同口径）。
    public int ArmorReductionPercent(string shipId)
        => _battle.ShipOrNull(shipId) is { } s
            ? (int)Math.Round(Math.Min(s.ArmorLevel * DamageRules.ArmorReductionPerLevel, DamageRules.ArmorMaxReduction) * 100.0)
            : -1;

    // UX-11：布阵船视图/阴影断言访问器（与战斗控制器同款语义）——船视图位置=状态期望中心；
    // 阴影由 NavalGridView 在世界空间按 ship 当前占格绘制，暴露其左上世界坐标，供 headless 断言"移动后阴影跟随船"。
    public float ShipViewPosX(string shipId) => _shipViews.TryGetValue(shipId, out var v) ? v.Position.X : -1f;
    public float ShipViewPosY(string shipId) => _shipViews.TryGetValue(shipId, out var v) ? v.Position.Y : -1f;
    public float ShipStateCenterX(string shipId)
        => _battle?.ShipOrNull(shipId) is { } s ? _grid.ShipCenterToWorld(s.Bow, s.Length, s.Facing).X : -1f;
    public float ShipStateCenterY(string shipId)
        => _battle?.ShipOrNull(shipId) is { } s ? _grid.ShipCenterToWorld(s.Bow, s.Length, s.Facing).Y : -1f;
    public Vector2 ShipShadowTopLeft(string shipId) => _grid.ShipShadowRect(shipId).Position;
    public int DeploymentCellCount() => _grid.DeploymentCellCount();
    public bool DeploymentCellHighlighted(int x, int y)
        => _grid.DeploymentCellContains(new GridPos(x, y));

    // 布阵点击：点己方舰选中；点己方区域空格把选中舰船头放到该格。
    public void OnGridClicked(Vector2 worldPos)
    {
        if (_battle is null) return;
        var cell = _grid.WorldToGrid(worldPos);
        if (!_battle.Map.InBounds(cell)) return;
        foreach (var ship in _battle.Ships.Values)
        {
            if (ship.Faction != FactionId.Player || ship.HitPoints <= 0) continue;
            if (ship.OccupiedCells().Contains(cell))
            {
                SelectShipForDeploy(ship.Id);
                return;
            }
        }
        var selected = SelectedPlayerShip();
        if (selected is null) return;
        if (selected.SelfSunk) { SetMessage("自沉舰已固守当前浅滩，无法移动"); return; } // F-4：自沉锁位
        var err = ValidatePlacement(selected, cell, selected.Facing);
        if (err is not null) { SetMessage("无法放置：" + DescribePlacementError(err)); return; }
        selected.Bow = cell;
        SyncShipView(selected.Id);
        RefreshSelfSinkButton(); // 移动后地形变化可能改变自沉资格
        SetMessage($"{selected.Definition.DisplayName} 已放置到 ({cell.X},{cell.Y})");
    }

    // ---- 按钮包装 ----

    private void RotateFromButton()
    {
        var err = RotateSelected();
        SetMessage(err.Length == 0 ? "已旋转朝向" : "无法旋转：" + DescribePlacementError(err));
    }

    private void SelfSinkFromButton()
    {
        var err = SelfSinkSelected();
        if (err.Length > 0) SetMessage("无法自沉：" + DescribePlacementError(err));
    }

    private void FlagshipFromButton()
    {
        var ship = SelectedPlayerShip();
        if (ship is null) { SetMessage("请先选中一艘己方舰船"); return; }
        var err = SetFlagship(ship.Id);
        SetMessage(err.Length == 0 ? $"指挥舰设为 {ship.Definition.DisplayName}" : DescribePlacementError(err));
    }

    private void ConfirmFromButton()
    {
        var err = ConfirmDeployment();
        if (err.Length > 0) SetMessage("无法开始：" + DescribePlacementError(err));
    }

    // ---- 布阵校验（占格/朝向/区域/地形/重叠；不改变状态） ----

    private string? ValidatePlacement(ShipState ship, GridPos bow, CardinalDirection facing)
    {
        var cells = FootprintCells(bow, facing, ship.Length);
        // 关卡/遭遇模式：玩家舰限制在玩家布阵区内，敌舰沿用其阵营区域；自由模式沿用 Demo 阵营区域。
        // 防止"随意放置"到敌方半场。
        var zone = ship.Faction == FactionId.Player
            ? (HasRestrictedZones() ? _levelPlayerZone ?? new Rect2I(0, 0, _battle.Map.Width, _battle.Map.Height) : PlayerZone)
            : (HasRestrictedZones() ? _levelEnemyZone : EnemyZone);
        foreach (var c in cells)
        {
            if (!_battle.Map.InBounds(c)) return "deploy.out_of_bounds";
            if (!ZoneContains(zone, c)) return "deploy.outside_zone";
            var t = _battle.Map.TerrainAt(c);
            // U-2a：陆地恒不可通行；深水限定舰不可进浅水（浅滩/礁石/陆河），经 TerrainRules 统一判定。
            if (TerrainRules.BlocksShip(t, ship.Definition.Passability)) return "deploy.impassable";
            if (_battle.Map.IsWreck(c)) return "deploy.impassable";
        }
        foreach (var other in _battle.Ships.Values)
        {
            if (other.Id == ship.Id || other.HitPoints <= 0) continue;
            if (other.OccupiedCells().Any(cells.Contains)) return "deploy.overlap";
        }
        // 布阵禁止与敌舰相邻（Chebyshev 距离 ≤1，含正侧/斜对角）：防止直接放到对方船只隔壁。
        if (ship.Faction == FactionId.Player)
        {
            foreach (var enemy in _battle.Ships.Values)
            {
                if (enemy.Faction == FactionId.Player || enemy.HitPoints <= 0) continue;
                foreach (var c in cells)
                    foreach (var ec in enemy.OccupiedCells())
                        if (Math.Abs(c.X - ec.X) <= 1 && Math.Abs(c.Y - ec.Y) <= 1)
                            return "deploy.too_close_enemy";
            }
        }
        return null;
    }

    // 关卡模式玩家布阵区域：玩家舰队初始位置的包围盒 + 余量（margin=4），自适应任何关卡布局。
    // 防止玩家把舰摆到敌方半场或敌舰旁（配合 ValidatePlacement 的 too_close_enemy 检查）。
    private void ComputeLevelPlayerZone()
    {
        var minX = int.MaxValue; var minY = int.MaxValue; var maxX = int.MinValue; var maxY = int.MinValue;
        var found = false;
        foreach (var ship in _battle.Ships.Values)
        {
            if (ship.Faction != FactionId.Player || ship.HitPoints <= 0) continue;
            found = true;
            foreach (var c in ship.OccupiedCells())
            {
                minX = Math.Min(minX, c.X); minY = Math.Min(minY, c.Y);
                maxX = Math.Max(maxX, c.X); maxY = Math.Max(maxY, c.Y);
            }
        }
        if (!found) { _levelPlayerZone = new Rect2I(0, 0, _battle.Map.Width, _battle.Map.Height); return; }
        const int margin = 4;
        var zx = Math.Max(0, minX - margin);
        var zy = Math.Max(0, minY - margin);
        var zw = Math.Min(_battle.Map.Width, maxX + margin + 1) - zx;
        var zh = Math.Min(_battle.Map.Height, maxY + margin + 1) - zy;
        _levelPlayerZone = new Rect2I(zx, zy, Math.Max(1, zw), Math.Max(1, zh));
        // 敌方半场：供敌舰/校验用的敌方区域（关卡模式右半区，沿用玩家-敌方左右布局约定）。
        var enemyMinX = int.MaxValue; var enemyMaxX = int.MinValue;
        foreach (var ship in _battle.Ships.Values)
        {
            if (ship.Faction != FactionId.Enemy || ship.HitPoints <= 0) continue;
            foreach (var c in ship.OccupiedCells())
            { enemyMinX = Math.Min(enemyMinX, c.X); enemyMaxX = Math.Max(enemyMaxX, c.X); }
        }
        _levelEnemyZone = enemyMinX == int.MaxValue
            ? new Rect2I(_battle.Map.Width / 2, 0, _battle.Map.Width / 2, _battle.Map.Height)
            : new Rect2I(Math.Max(0, enemyMinX - margin), 0,
                Math.Min(_battle.Map.Width, enemyMaxX + margin + 1) - Math.Max(0, enemyMinX - margin), _battle.Map.Height);
    }

    private static List<GridPos> FootprintCells(GridPos bow, CardinalDirection facing, int length)
    {
        var cells = new List<GridPos>(length);
        for (var i = 0; i < length; i++)
            cells.Add(bow - facing.Vector() * i);
        return cells;
    }

    // 是否有受限布阵区（关卡/随机遭遇模式限定区；自由模式用全屏阵营区）。
    private bool HasRestrictedZones() => _level is not null || _encounter is not null;

    // GridRect（纯数据层布阵区）→ Rect2I（表现层区域；Rect2I(x,y,width,height)）。
    private static Rect2I ToRect(GridRect zone) => new(zone.X, zone.Y, zone.Width, zone.Height);

    private static bool ZoneContains(Rect2I zone, GridPos p)
        => p.X >= zone.Position.X && p.X < zone.End.X && p.Y >= zone.Position.Y && p.Y < zone.End.Y;

    private static bool TryParseFacing(string name, out CardinalDirection facing)
    {
        facing = name.Trim().ToLowerInvariant() switch
        {
            "north" or "up" => CardinalDirection.North,
            "south" or "down" => CardinalDirection.South,
            "east" or "right" => CardinalDirection.East,
            "west" or "left" => CardinalDirection.West,
            _ => CardinalDirection.North,
        };
        return name.Trim().ToLowerInvariant() is "north" or "up" or "south" or "down" or "east" or "right" or "west" or "left";
    }

    // ---- 辅助 ----

    // 自动指挥舰：占格最多舰（并列按 roster 顺序第一艘）。roster 是舰型 id，映射到该阵营实际舰船。
    private string AutoFlagship(IReadOnlyList<string> roster, FactionId faction)
    {
        var ships = roster
            .Select(defId => _battle.Ships.Values.FirstOrDefault(s => s.Faction == faction && s.Definition.Id == defId))
            .Where(s => s is not null)
            .ToList();
        string? best = null;
        var bestCells = -1;
        foreach (var s in ships)
        {
            if (s!.Length > bestCells) { bestCells = s.Length; best = s.Id; }
        }
        return best ?? _battle.Ships.Values.First(s => s.Faction == faction).Id;
    }

    private void ApplyDefaultLineup(string[] roster, IReadOnlyList<(GridPos Bow, CardinalDirection Facing)> defaults, FactionId faction)
    {
        for (var i = 0; i < roster.Length; i++)
        {
            var ship = _battle.ShipOrNull(ShipIdFor(faction, i));
            if (ship is null || ship.Faction != faction) continue;
            if (ship.SelfSunk) continue; // F-4：自沉舰固守浅滩，恢复默认阵型不移动它
            var (bow, facing) = defaults[i];
            ship.Bow = bow;
            ship.Facing = facing;
        }
    }

    private ShipState? SelectedPlayerShip()
    {
        if (_selectedShip is null) return null;
        var ship = _battle.ShipOrNull(_selectedShip);
        if (ship is null || ship.Faction != FactionId.Player) return null;
        return ship;
    }

    // F-4：布阵浅滩自沉资格（设计 15）——通过性 1 或 2（FreeAll=3 排除，规则层口径）+ 船头位于浅滩。
    // 通过性1（深水限定）舰无法放置浅滩（布阵校验 deploy.impassable），实际可触发的是通过性2 舰；
    // 与规则层 ValidateSelfSink 同口径但限定浅滩（礁石/深水自沉会在战斗中即时沉没移除，非"固守"语义）。
    private bool CanSelfSinkInDeploy(ShipState ship)
        => ship.HitPoints > 0
           && !ship.SelfSunk
           && ship.Definition.Passability != Passability.FreeAll
           && _battle.Map.TerrainAt(ship.Bow) == TerrainType.Shallow;

    // V-6：选中变化/放置/自沉/重置后刷新「浅滩自沉」按钮——选中玩家舰时始终显示；
    // 不满足资格置灰并给原因（需在浅滩 / 该舰型无法浅滩自沉 / 已自沉）。可点时正常自沉（布阵免费）。
    private void RefreshSelfSinkButton()
    {
        if (_selfSinkButton is null) return;
        var ship = SelectedPlayerShip();
        _selfSinkButton.Visible = ship is not null;
        if (ship is null) return;
        var eligible = CanSelfSinkInDeploy(ship);
        _selfSinkButton.Disabled = !eligible;
        _selfSinkButton.TooltipText = eligible
            ? "点击执行浅滩自沉（布阵免费，固守当前浅滩）"
            : SelfSinkDeployReason(ship);
    }

    // V-6：布阵自沉按钮置灰原因（与 CanSelfSinkInDeploy 同口径：存活 + 未自沉 + 通过性非 FreeAll + 船头浅滩）。
    private string SelfSinkDeployReason(ShipState ship)
    {
        if (ship.SelfSunk) return "该舰已自沉";
        if (ship.Definition.Passability == Passability.FreeAll) return "该舰型无法浅滩自沉";
        if (_battle.Map.TerrainAt(ship.Bow) != TerrainType.Shallow) return "需在浅滩才能自沉";
        return "无法浅滩自沉"; // 不应到达（其余情形 CanSelfSinkInDeploy 已覆盖）
    }

    private void SyncShipView(string id)
    {
        if (_shipViews.TryGetValue(id, out var view)) view.SyncToShip(_grid);
        // UX-11：船底阴影由 NavalGridView 在世界空间按 ship 当前占格绘制（非独立节点），
        // 布阵移动/转向/重置后必须重绘网格，阴影才跟随船（战斗侧每次移动都重绘网格，布阵侧此前漏了 → 阴影留原位）。
        _grid.QueueRedraw();
        RefreshDeploymentHighlights();
    }

    private void SetMessage(string text)
    {
        if (_messageLabel is not null) _messageLabel.Text = text;
    }

    // 布阵阶段状态栏/消息文案（按模式分支：随机遭遇 → 难度/地图/敌方来源/奖励；关卡 → 标题/目标/提示；自由 → 通用指引）。
    private void ApplyDeployStatusText()
    {
        if (_encounter is not null)
        {
            var e = _encounter;
            if (_statusLabel is not null)
                _statusLabel.Text = $"{e.DisplayName} · 地图 {e.MapSourceLabel} · 敌方 {e.EnemyLabel}";
            SetMessage($"{e.Description}｜战利品 金{e.Rewards.Gold} · 铁{e.Rewards.Iron} · 木{e.Rewards.Wood} · 麻{e.Rewards.Hemp}");
            return;
        }
        if (_level is not null)
        {
            if (_statusLabel is not null) _statusLabel.Text = $"关卡模式：{_level.Title}（目标：{_level.ObjectiveText}）";
            SetMessage(_level.Hints.Count > 0 ? $"提示：{_level.Hints[0]}" : _level.ObjectiveText);
            return;
        }
        if (_statusLabel is not null) _statusLabel.Text = "布阵阶段：摆好我方舰船、指定指挥舰后点「开始战斗」";
        SetMessage("点击己方舰船选中；点击目标格移动（该格为船头）；再点选中舰取消选择；可旋转朝向");
    }

    private static string DescribePlacementError(string key) => key switch
    {
        "deploy.out_of_bounds" => "越界",
        "deploy.outside_zone" => "超出己方布阵区域",
        "deploy.overlap" => "与其他舰船重叠",
        "deploy.too_close_enemy" => "不能与敌舰相邻放置",
        "deploy.impassable" => "地形不可通行",
        "deploy.unknown_ship" => "无法操作该舰",
        "deploy.no_selection" => "请先选中己方舰船",
        "deploy.bad_facing" => "朝向参数无效",
        // F-4：浅滩自沉（设计 15）——锁位与资格原因。
        "deploy.self_sunk" => "自沉舰已固守浅滩，不能移动/转向",
        "deploy.not_on_shallow" => "需位于浅滩格才能自沉",
        "deploy.self_sink_failed" => "自沉失败",
        "self_sink.already_sunk" => "该舰已自沉",
        "self_sink.captured" => "被俘舰不能自沉",
        "self_sink.boarding" => "接舷中不能自沉",
        "self_sink.passability" => "该舰型不能自沉（需通过性 1/2）",
        "self_sink.wrong_terrain" => "需在浅滩自沉",
        // F-5：装备配置（设计 14）——装载增量/槽位/上限原因。
        "equip.bad_delta" => "增量参数无效",
        "equip.unknown_weapon" => "未知武器",
        "equip.unknown_skill" => "未知技能",
        "equip.weapon_max" => "撞角限装 1 件",
        "equip.slots_full" => "槽位已满",
        "equip.armor_max" => "已达护甲上限",
        "equip.none_equipped" => "未装载该项",
        // V-7：舰队配置修改器（预设保存/加载/增减舰）原因。
        "fleet.level_locked" => "关卡/遭遇模式使用固定舰队，不可修改",
        "fleet.unknown_ship" => "舰型不存在",
        "fleet.unknown_weapon" => "未知武器",
        "fleet.unknown_skill" => "未知技能",
        "fleet.weapon_over_slots" => "武器超出该舰武器位",
        "fleet.weapon_over_max" => "武器超单件上限（撞角限 1 件）",
        "fleet.skill_over_slots" => "技能超出该舰技能位",
        "fleet.armor_over_cap" => "护甲超出该舰上限",
        "fleet.empty_name" => "预设名不能为空",
        "fleet.empty_fleet" => "舰队为空，无法保存",
        "fleet.too_many" => $"舰队已达上限 {MaxFleetSize} 艘",
        "fleet.no_room" => "布阵区已无空位",
        "fleet.last_ship" => "至少保留一艘舰船",
        "fleet.unknown_preset" => "预设不存在",
        "" => "",
        _ => key,
    };

    // ---- F-5 装备配置（布阵前，设计 14） ----

    // 构建装备面板（在 .tscn EquipmentPanel/Box 容器内）：舰选择按钮接线 + 逐武器/技能生成 [-]N[+] 行。
    // 结构一次构建（配置不变），之后装备/选舰变化只走 RefreshEquipmentPanel 刷新计数与禁用态。
    private void BuildEquipmentPanel()
    {
        _equipPanel = GetNodeOrNull<Control>("DeployHud/EquipmentPanel");
        if (_equipPanel is null) return;
        if (_equipPanel is Panel panel) panel.AddThemeStyleboxOverride("panel", InkWashTheme.PanelCard());
        var box = _equipPanel.GetNodeOrNull<Container>("Box");
        if (box is null) return;
        if (box.GetNodeOrNull<Label>("Caption") is { } cap) StyleEquipText(cap, 18, InkWashTheme.InkDeep);
        _equipSlotsLabel = box.GetNodeOrNull<Label>("SlotsLabel");
        if (_equipSlotsLabel is not null) StyleEquipText(_equipSlotsLabel, 14, InkWashTheme.TextInk);
        _equipHintLabel = box.GetNodeOrNull<Label>("HintLabel");
        if (_equipHintLabel is not null) StyleEquipText(_equipHintLabel, 13, InkWashTheme.BrownText);
        // 行标题（武器/技能/护甲）统一赭石强调。
        foreach (var row in new[] { "WeaponRow", "SkillRow", "ArmorRow" })
            if (box.GetNodeOrNull<Label>($"{row}/Caption") is { } rc) StyleEquipText(rc, 15, InkWashTheme.Ochre);
        // V-7：舰选择行按当前玩家舰队动态重建（替代固定 Ship1..Ship4；预设增减舰后自动同步）。
        // 既有冒烟依赖 WeaponRow/cannon/Plus 路径（不改），舰选择改走节点内动态按钮（Ship_<id>）。
        RebuildEquipShipRow();
        // 武器行：按 weapons.json 顺序逐个生成 [-]N[+]
        if (box.GetNodeOrNull<HBoxContainer>("WeaponRow") is { } weaponRow)
        {
            foreach (var w in _config!.Weapons)
            {
                BuildEquipGroup(weaponRow, w.DisplayName, w.Id, out var minus, out var count, out var plus);
                _weaponControls[w.Id] = (minus, count, plus);
                var wid = w.Id;
                minus.Pressed += () => EquipWeaponFromButton(wid, -1);
                plus.Pressed += () => EquipWeaponFromButton(wid, +1);
            }
        }
        // 技能行：按 skills.json 顺序逐个生成 [-]N[+]
        if (box.GetNodeOrNull<HBoxContainer>("SkillRow") is { } skillRow)
        {
            foreach (var s in _config!.Skills)
            {
                BuildEquipGroup(skillRow, s.DisplayName, s.Id, out var minus, out var count, out var plus);
                _skillControls[s.Id] = (minus, count, plus);
                var sid = s.Id;
                minus.Pressed += () => EquipSkillFromButton(sid, -1);
                plus.Pressed += () => EquipSkillFromButton(sid, +1);
            }
        }
        // 护甲行
        if (box.GetNodeOrNull<HBoxContainer>("ArmorRow") is { } armorRow)
        {
            BuildEquipGroup(armorRow, "护甲", "armor", out var aMinus, out var aCount, out var aPlus);
            _armorControls = (aMinus, aCount, aPlus);
            aMinus.Pressed += () => EquipArmorFromButton(-1);
            aPlus.Pressed += () => EquipArmorFromButton(+1);
        }
        _equipCloseButton = box.GetNodeOrNull<Button>("CloseRow/Close");
        if (_equipCloseButton is not null)
        {
            InkWashTheme.StyleButton(_equipCloseButton);
            _equipCloseButton.FocusMode = Control.FocusModeEnum.None;
            _equipCloseButton.Pressed += () => _equipPanel!.Visible = false;
        }
        RefreshEquipmentPanel();
    }

    // 生成一组「名称 − 数量 +」控件（node 名=id，供 headless 定位按钮路径）。
    private static HBoxContainer BuildEquipGroup(HBoxContainer row, string displayName, string id, out Button minus, out Label count, out Button plus)
    {
        var group = new HBoxContainer { Name = id, CustomMinimumSize = new Vector2(0, 34) };
        group.AddThemeConstantOverride("separation", 6);
        var name = new Label { Name = "Name", Text = displayName, VerticalAlignment = VerticalAlignment.Center, CustomMinimumSize = new Vector2(56, 0) };
        name.AddThemeFontOverride("font", InkWashTheme.Font());
        name.AddThemeFontSizeOverride("font_size", 15);
        name.AddThemeColorOverride("font_color", InkWashTheme.TextInk);
        minus = MakeEquipButton("−", 32, "Minus");
        count = new Label { Name = "Count", Text = "×0", VerticalAlignment = VerticalAlignment.Center, CustomMinimumSize = new Vector2(36, 0) };
        count.AddThemeFontOverride("font", InkWashTheme.Font());
        count.AddThemeFontSizeOverride("font_size", 15);
        count.AddThemeColorOverride("font_color", InkWashTheme.InkDeep);
        plus = MakeEquipButton("+", 32, "Plus");
        group.AddChild(name);
        group.AddChild(minus);
        group.AddChild(count);
        group.AddChild(plus);
        row.AddChild(group);
        return group;
    }

    private static Button MakeEquipButton(string text, int width, string name)
    {
        var b = new Button { Name = name, Text = text, CustomMinimumSize = new Vector2(width, 30) };
        InkWashTheme.StyleButton(b);
        b.FocusMode = Control.FocusModeEnum.None;
        return b;
    }

    private static void StyleEquipText(Label l, int size, Color color)
    {
        l.AddThemeFontOverride("font", InkWashTheme.Font());
        l.AddThemeFontSizeOverride("font_size", size);
        l.AddThemeColorOverride("font_color", color);
    }

    // 切换装备面板：默认编辑第一艘（旗舰）；关闭时提示。
    private void EquipToggleFromButton()
    {
        if (_equipPanel is null) return;
        _equipPanel.Visible = !_equipPanel.Visible;
        if (_equipPanel.Visible)
        {
            _equipShipId ??= ShipIdFor(FactionId.Player, 0);
            SelectEquipShip(_equipShipId!);
            _levelPlay?.OnEquipOpened(); // L-3：打开装备面板提示推进
        }
        else
        {
            SetMessage("已关闭装备配置");
        }
    }

    // 面板选中要编辑的舰：只读查询 + 刷新全面板计数/禁用态。
    private void SelectEquipShip(string shipId)
    {
        var ship = _battle.ShipOrNull(shipId);
        if (ship is null || ship.Faction != FactionId.Player) return;
        _equipShipId = shipId;
        RefreshEquipmentPanel();
        SetMessage($"装备配置：{ship.Definition.DisplayName}（{ship.Id}）——武器/技能/护甲在布阵前完成");
    }

    // 刷新装备面板全部计数/上限/按钮可用态（选中舰变化或装备变化后调用）。
    private void RefreshEquipmentPanel()
    {
        if (_equipPanel is null || !_equipPanel.Visible) return;
        if (_equipShipId is not { } id) return;
        var ship = _battle.ShipOrNull(id);
        if (ship is null || ship.Faction != FactionId.Player) return;
        var usedW = UsedWeaponSlots(ship);
        var maxW = ship.Definition.WeaponSlots;
        var usedS = UsedSkillSlots(ship);
        var maxS = ship.Definition.SkillSlots;
        var armorCap = ship.Definition.BaseArmor + ship.Definition.ArmorSlots;
        foreach (var (sid, btn) in _equipShipButtons)
        {
            if (sid == ship.Id) ActivateEquipShip(btn); else DeactivateEquipShip(btn);
        }
        if (_equipSlotsLabel is not null)
            _equipSlotsLabel.Text = $"{ship.Definition.DisplayName}（{ship.Id}）  武器位 {usedW}/{maxW} · 技能位 {usedS}/{maxS} · 护甲位 {ship.ArmorLevel}/{armorCap} · 负载 {WeatherRules.CurrentLoad(ship)}/{ship.Definition.LoadCapacity}";
        foreach (var (wid, ctl) in _weaponControls)
        {
            var count = ship.WeaponCounts.GetValueOrDefault(wid, 0);
            var atMax = _config!.Weapons.FirstOrDefault(w => w.Id == wid) is { MaxCount: { } mc } && count >= mc; // 撞角限 1 件
            ctl.Count.Text = $"×{count}";
            ctl.Minus.Disabled = count <= 0;
            ctl.Plus.Disabled = usedW >= maxW || atMax;
        }
        foreach (var (sid, ctl) in _skillControls)
        {
            var count = ship.SkillLoadout.GetValueOrDefault(sid, 0);
            ctl.Count.Text = $"×{count}";
            ctl.Minus.Disabled = count <= 0;
            ctl.Plus.Disabled = usedS >= maxS;
        }
        var armor = ship.ArmorLevel;
        _armorControls.Count.Text = $"×{armor}";
        _armorControls.Minus.Disabled = armor <= 0;
        _armorControls.Plus.Disabled = armor >= armorCap;
        if (_equipHintLabel is not null)
            _equipHintLabel.Text = "护甲每级 +3 负载 · −10% 减伤（上限80%）｜撞角限1件｜技能按槽位×每场次数";
    }

    // 装载/卸载武器：delta=+1 装 / -1 卸。总武器数受 WeaponSlots 限制；撞角（weapons.json MaxCount=1）限 1 件。
    // 返回原因 key；空字符串 = 成功。写 ShipState.WeaponCounts（ConfirmDeployment 时随战斗生效）。
    public string EquipWeapon(string shipId, string weaponId, int delta)
    {
        var ship = PlayerShipForEquip(shipId);
        if (ship is null) return "deploy.unknown_ship";
        if (delta is not 1 and not -1) return "equip.bad_delta";
        if (_config!.Weapons.FirstOrDefault(w => w.Id == weaponId) is not { } def) return "equip.unknown_weapon";
        var current = ship.WeaponCounts.GetValueOrDefault(weaponId, 0);
        if (delta > 0)
        {
            if (def.MaxCount is { } max && current >= max) return "equip.weapon_max";
            if (UsedWeaponSlots(ship) >= ship.Definition.WeaponSlots) return "equip.slots_full";
            ship.WeaponCounts[weaponId] = current + 1;
        }
        else
        {
            if (current <= 0) return "equip.none_equipped";
            if (current == 1) ship.WeaponCounts.Remove(weaponId); else ship.WeaponCounts[weaponId] = current - 1;
        }
        OnEquipmentChanged(ship, $"{ship.Definition.DisplayName} 武器 {def.DisplayName}×{ship.WeaponCounts.GetValueOrDefault(weaponId, 0)}");
        return "";
    }

    // 装载/卸载技能：delta=+1 装 / -1 卸。总技能位受 SkillSlots 限制；写 ShipState.SkillLoadout（槽位数），
    // 战斗开始时 SkillSeeding.Seed 按槽位 × skills.json 每场次数播种 SkillUsesLeft。
    public string EquipSkill(string shipId, string skillId, int delta)
    {
        var ship = PlayerShipForEquip(shipId);
        if (ship is null) return "deploy.unknown_ship";
        if (delta is not 1 and not -1) return "equip.bad_delta";
        if (_config!.Skills.FirstOrDefault(s => s.Id == skillId) is not { } def) return "equip.unknown_skill";
        var current = ship.SkillLoadout.GetValueOrDefault(skillId, 0);
        if (delta > 0)
        {
            if (UsedSkillSlots(ship) >= ship.Definition.SkillSlots) return "equip.slots_full";
            ship.SkillLoadout[skillId] = current + 1;
        }
        else
        {
            if (current <= 0) return "equip.none_equipped";
            if (current == 1) ship.SkillLoadout.Remove(skillId); else ship.SkillLoadout[skillId] = current - 1;
        }
        OnEquipmentChanged(ship, $"{ship.Definition.DisplayName} 技能 {def.DisplayName}×{ship.SkillLoadout.GetValueOrDefault(skillId, 0)}");
        return "";
    }

    // 护甲：delta=+1 加一级 / -1 卸一级。范围 [0, BaseArmor+ArmorSlots]（初始 = BaseArmor）；每级 +3 负载、-10% 减伤（上限 80%）。
    public string EquipArmor(string shipId, int delta)
    {
        var ship = PlayerShipForEquip(shipId);
        if (ship is null) return "deploy.unknown_ship";
        if (delta is not 1 and not -1) return "equip.bad_delta";
        var cap = ship.Definition.BaseArmor + ship.Definition.ArmorSlots;
        if (delta > 0)
        {
            if (ship.ArmorLevel >= cap) return "equip.armor_max";
            ship.ArmorLevel += 1;
        }
        else
        {
            if (ship.ArmorLevel <= 0) return "equip.none_equipped";
            ship.ArmorLevel -= 1;
        }
        OnEquipmentChanged(ship, $"{ship.Definition.DisplayName} 护甲 {ship.ArmorLevel} 级 · 减伤 {ArmorReductionPercent(ship.Id)}% · 负载 {WeatherRules.CurrentLoad(ship)}");
        return "";
    }

    // 面板按钮包装：把错误原因转中文提示。
    private void EquipWeaponFromButton(string weaponId, int delta)
    {
        var err = EquipWeapon(_equipShipId ?? "", weaponId, delta);
        if (err.Length > 0) SetMessage("无法装载武器：" + DescribePlacementError(err));
    }

    private void EquipSkillFromButton(string skillId, int delta)
    {
        var err = EquipSkill(_equipShipId ?? "", skillId, delta);
        if (err.Length > 0) SetMessage("无法装载技能：" + DescribePlacementError(err));
    }

    private void EquipArmorFromButton(int delta)
    {
        var err = EquipArmor(_equipShipId ?? "", delta);
        if (err.Length > 0) SetMessage("无法调整护甲：" + DescribePlacementError(err));
    }

    // 装备变化：刷新面板（计数/禁用态）+ 底部消息。
    private void OnEquipmentChanged(ShipState ship, string message)
    {
        RefreshEquipmentPanel();
        SetMessage(message);
    }

    private ShipState? PlayerShipForEquip(string shipId)
    {
        var ship = _battle.ShipOrNull(shipId);
        if (ship is null || ship.Faction != FactionId.Player) return null;
        return ship;
    }

    private static int UsedWeaponSlots(ShipState ship) => ship.WeaponCounts.Values.Sum();
    private static int UsedSkillSlots(ShipState ship) => ship.SkillLoadout.Values.Sum();

    private static void ActivateEquipShip(Button b)
    {
        b.AddThemeStyleboxOverride("normal", InkWashTheme.ButtonActive());
        b.AddThemeStyleboxOverride("hover", InkWashTheme.ButtonActiveHover());
        b.AddThemeStyleboxOverride("pressed", InkWashTheme.ButtonActivePressed());
        b.AddThemeColorOverride("font_color", InkWashTheme.Paper);
    }

    private static void DeactivateEquipShip(Button b)
    {
        b.AddThemeStyleboxOverride("normal", InkWashTheme.ButtonNormal());
        b.AddThemeStyleboxOverride("hover", InkWashTheme.ButtonHover());
        b.AddThemeStyleboxOverride("pressed", InkWashTheme.ButtonPressed());
        b.AddThemeColorOverride("font_color", InkWashTheme.TextInk);
    }

    private void StartBattleTransition()
    {
        Visible = false;
        ProcessMode = ProcessModeEnum.Disabled;
        // UX-8：布阵底部面板随进入战斗隐藏（CanvasLayer 不随父节点隐藏，须显式隐藏），保证任一时刻只一个底部面板
        if (_deployHud is not null) _deployHud.Visible = false;
        var battle = GetNodeOrNull<Node2D>("../Battle");
        if (battle is not null)
        {
            battle.Visible = true;
            battle.ProcessMode = ProcessModeEnum.Inherit;
        }
    }

    // T16 返回 Demo 入口（再来一局）：重建全新战斗状态与舰队视图，重新进入布阵阶段。
    // 由 BattleController.NewGame 在战斗结束结算后调用。
    public void ResetForNewGame()
    {
        // L-3：关卡模式统一重载本关（LevelSession.PendingLevelId 仍为本关 id → 重建同一关卡战斗）。
        if (_level is not null) { GetTree().ReloadCurrentScene(); return; }
        _flagshipId = null;
        _selectedShip = null;
        CloseEquipmentPanel(); // F-5：新一局装备随 BuildFleet 重置为默认，关闭装备面板
        RebuildFleetForDeploy();
        Visible = true;
        ProcessMode = ProcessModeEnum.Inherit;
        // UX-8：返回布阵阶段重新显示布阵面板、隐藏战斗 HUD（顶栏/行动面板不残留）
        if (_deployHud is not null) _deployHud.Visible = true;
        if (_deployPanel is not null) _deployPanel.Visible = false;
        if (GetNodeOrNull<CanvasLayer>("../Battle/Hud") is { } battleHud) battleHud.Visible = false;
        // F-6：布阵阶段同时隐藏天气覆盖层（CanvasLayer 不随父节点隐藏，战斗开始才由 StartBattle 显示）。
        if (GetNodeOrNull<CanvasLayer>("../Battle/WeatherFx") is { } weatherFx) weatherFx.Visible = false;
        var battle = GetNodeOrNull<Node2D>("../Battle");
        if (battle is not null)
        {
            battle.Visible = false;
            battle.ProcessMode = ProcessModeEnum.Disabled;
        }
        ApplyDeployStatusText();
        RefreshSelfSinkButton();
    }

    // 重建战斗 + 舰队视图（ResetForNewGame 与测试钩子共用）：清视图节点 → 按当前种子新建战斗 → 重新挂网格/区带/默认阵型/舰队。
    private void RebuildFleetForDeploy()
    {
        foreach (var child in _shipsRoot.GetChildren()) { _shipsRoot.RemoveChild(child); child.QueueFree(); }
        _shipViews.Clear();
        _battle = _encounter is not null ? BuildBattleForEncounter(_encounter) : BuildBattle();
        _grid.Attach(_battle);
        BuildDefaultLineups();
        BuildFleet();
        _grid.FocusCameraOnPlayerFleet();
        if (_level is not null) ComputeLevelPlayerZone();
        else if (_encounter is not null)
        {
            _levelPlayerZone = ToRect(_encounter.PlayerZone);
            _levelEnemyZone = ToRect(_encounter.EnemyZone);
        }
        _grid.ShowDeploymentZones(ZoneOverlays());
        RefreshDeploymentHighlights();
        RebuildEquipShipRow();  // V-7：舰队构成变化 → 重建装备面板舰选择行
        _fleetShipId = null;    // V-7：重建后不残留舰队配置面板编辑舰
        if (_fleetPanel is not null) _fleetPanel.Visible = false;
        RefreshFleetPanel();    // V-7：刷新舰队配置面板（舰列表/预览/预设列表）
    }

    // F-1：headless 冒烟测试钩子——指定种子重建战斗（天气/风向在 ConfirmDeployment 掷定走种子化 RNG）。
    // 同种子两次构建 → 天气/风向相同（可复现）；测试用 RebuildBattleForTest(9)=阴天、RebuildBattleForTest(0)=雨天 等。
    public void RebuildBattleForTest(int seed)
    {
        _battleSeedOverride = seed;
        _flagshipId = null;
        _selectedShip = null;
        if (_deployPanel is not null) _deployPanel.Visible = false;
        CloseEquipmentPanel(); // F-5：重建战斗时装备随 BuildFleet 重置为默认，关闭装备面板
        RebuildFleetForDeploy();
        RefreshSelfSinkButton();
    }

    // F-5：关闭装备面板并清当前编辑舰（新一局/重建/进入战斗后不残留编辑态）。
    private void CloseEquipmentPanel()
    {
        _equipShipId = null;
        if (_equipPanel is not null) _equipPanel.Visible = false;
    }

    // V-7：重建装备面板舰选择行（清空后按当前玩家舰列表逐个生成按钮）。舰队构成变化后调用。
    private void RebuildEquipShipRow()
    {
        if (_equipPanel is not { } panel) return;
        var row = panel.GetNodeOrNull<HBoxContainer>("Box/ShipRow");
        if (row is null) return;
        foreach (var child in row.GetChildren()) { row.RemoveChild(child); child.QueueFree(); }
        _equipShipButtons.Clear();
        foreach (var ship in _battle.Ships.Values)
        {
            if (ship.Faction != FactionId.Player || ship.HitPoints <= 0) continue;
            var btn = new Button
            {
                Name = $"Ship_{ship.Id}",
                Text = ship.Definition.DisplayName,
                CustomMinimumSize = new Vector2(110, 38),
            };
            InkWashTheme.StyleButton(btn);
            btn.FocusMode = Control.FocusModeEnum.None;
            var captured = ship.Id;
            btn.Pressed += () => SelectEquipShip(captured);
            _equipShipButtons[ship.Id] = btn;
            row.AddChild(btn);
        }
    }

    // ---- V-7 舰队配置修改器（布阵前，自由模式） ----

    // 预设保存路径：user://fleet_presets.json（参照 LevelProgress；测试钩子可换临时路径防污染）。
    private static string FleetPresetPath() => ProjectSettings.GlobalizePath("user://fleet_presets.json");

    private FleetPresetStore FleetStore()
    {
        if (_fleetStore is null)
        {
            _fleetStore = new FleetPresetStore(FleetPresetPath());
            _fleetStore.Load();
        }
        return _fleetStore;
    }

    // 构建舰队配置面板（在 .tscn FleetPanel/Box 容器内）：添加舰按钮 + 逐武器/技能护甲行 + 保存/关闭接线。
    private void BuildFleetDesignerPanel()
    {
        _fleetPanel = GetNodeOrNull<Control>("DeployHud/FleetPanel");
        if (_fleetPanel is null) return;
        if (_fleetPanel is Panel panel) panel.AddThemeStyleboxOverride("panel", InkWashTheme.PanelCard());
        var box = _fleetPanel.GetNodeOrNull<Container>("Box");
        if (box is null) return;
        if (box.GetNodeOrNull<Label>("Caption") is { } cap) StyleEquipText(cap, 18, InkWashTheme.InkDeep);
        _fleetPreviewLabel = box.GetNodeOrNull<Label>("PreviewLabel");
        if (_fleetPreviewLabel is not null) StyleEquipText(_fleetPreviewLabel, 14, InkWashTheme.Ochre);
        _fleetSlotsLabel = box.GetNodeOrNull<Label>("SlotsLabel");
        if (_fleetSlotsLabel is not null) StyleEquipText(_fleetSlotsLabel, 13, InkWashTheme.TextInk);
        // 行标题（添加舰/武器/技能/护甲）统一赭石强调。
        foreach (var row in new[] { "ComposeRow", "FleetWeaponRow", "FleetSkillRow", "FleetArmorRow" })
            if (box.GetNodeOrNull<Label>($"{row}/Caption") is { } rc) StyleEquipText(rc, 14, InkWashTheme.Ochre);
        _fleetShipList = box.GetNodeOrNull<VBoxContainer>("ShipScroll/ShipList");
        _fleetPresetList = box.GetNodeOrNull<VBoxContainer>("PresetScroll/PresetList");
        // 添加舰船按钮（4 舰型）
        foreach (var (typeId, node) in new[]
                 {
                     ("flagship", "AddFlagship"), ("frigate", "AddFrigate"),
                     ("merchant", "AddMerchant"), ("transport", "AddTransport"),
                 })
        {
            if (box.GetNodeOrNull<Button>($"ComposeRow/{node}") is not { } b) continue;
            InkWashTheme.StyleButton(b);
            b.FocusMode = Control.FocusModeEnum.None;
            var captured = typeId;
            b.Pressed += () => AddFleetShipFromButton(captured);
        }
        // 武器/技能/护甲行（逐项 [-]N[+]），复用 BuildEquipGroup 生成。
        if (box.GetNodeOrNull<HBoxContainer>("FleetWeaponRow") is { } weaponRow)
        {
            foreach (var w in _config!.Weapons)
            {
                BuildEquipGroup(weaponRow, w.DisplayName, w.Id, out var minus, out var count, out var plus);
                _fleetWeaponControls[w.Id] = (minus, count, plus);
                var wid = w.Id;
                minus.Pressed += () => EquipFleetWeaponFromButton(wid, -1);
                plus.Pressed += () => EquipFleetWeaponFromButton(wid, +1);
            }
        }
        if (box.GetNodeOrNull<HBoxContainer>("FleetSkillRow") is { } skillRow)
        {
            foreach (var s in _config!.Skills)
            {
                BuildEquipGroup(skillRow, s.DisplayName, s.Id, out var minus, out var count, out var plus);
                _fleetSkillControls[s.Id] = (minus, count, plus);
                var sid = s.Id;
                minus.Pressed += () => EquipFleetSkillFromButton(sid, -1);
                plus.Pressed += () => EquipFleetSkillFromButton(sid, +1);
            }
        }
        if (box.GetNodeOrNull<HBoxContainer>("FleetArmorRow") is { } armorRow)
        {
            BuildEquipGroup(armorRow, "护甲", "armor", out var aMinus, out var aCount, out var aPlus);
            _fleetArmorControls = (aMinus, aCount, aPlus);
            aMinus.Pressed += () => EquipFleetArmorFromButton(-1);
            aPlus.Pressed += () => EquipFleetArmorFromButton(+1);
        }
        // 保存预设（命名）
        _fleetNameEdit = box.GetNodeOrNull<LineEdit>("SaveRow/NameEdit");
        if (_fleetNameEdit is not null)
        {
            _fleetNameEdit.AddThemeFontOverride("font", InkWashTheme.Font());
            _fleetNameEdit.AddThemeFontSizeOverride("font_size", 15);
        }
        _fleetSaveButton = box.GetNodeOrNull<Button>("SaveRow/SaveButton");
        if (_fleetSaveButton is not null)
        {
            InkWashTheme.StyleButton(_fleetSaveButton);
            _fleetSaveButton.FocusMode = Control.FocusModeEnum.None;
            _fleetSaveButton.Pressed += SaveFleetPresetFromButton;
        }
        if (box.GetNodeOrNull<Button>("CloseRow/Close") is { } close)
        {
            InkWashTheme.StyleButton(close);
            close.FocusMode = Control.FocusModeEnum.None;
            close.Pressed += () => _fleetPanel!.Visible = false;
        }
        RefreshFleetPanel();
    }

    // 切换舰队配置面板：默认编辑第一艘玩家舰；关闭时提示。
    private void FleetToggleFromButton()
    {
        if (_fleetPanel is null) return;
        _fleetPanel.Visible = !_fleetPanel.Visible;
        if (_fleetPanel.Visible)
        {
            SelectFleetShip(_fleetShipId ?? "");
            RefreshFleetPanel();
        }
        else
        {
            SetMessage("已关闭舰队配置");
        }
    }

    // 面板选中要编辑的舰：无则回落第一艘玩家舰；刷新全面板计数/禁用态。
    private void SelectFleetShip(string shipId)
    {
        var ship = _battle.ShipOrNull(shipId);
        if (ship is null || ship.Faction != FactionId.Player)
        {
            ship = _battle.Ships.Values.FirstOrDefault(s => s.Faction == FactionId.Player && s.HitPoints > 0);
            if (ship is null) { _fleetShipId = null; RefreshFleetPanel(); return; }
            shipId = ship.Id;
        }
        _fleetShipId = shipId;
        RefreshFleetPanel();
        SetMessage($"配置 {ship.Definition.DisplayName}（{ship.Id}）的装备——增删舰/保存预设可在舰队配置完成");
    }

    // 添加舰船（public，headless 冒烟/面板按钮共用）：校验关卡锁定/舰型存在/上限/布阵区空位，
    // 自动摆位（玩家区扫描），装配 F-5 默认武器/技能布局（与默认阵型同款），重建视图/面板。
    public string AddFleetShip(string typeId)
    {
        if (_level is not null || _encounter is not null) return "fleet.level_locked";
        var def = _config!.Ships.FirstOrDefault(s => s.Id == typeId);
        if (def is null) return "fleet.unknown_ship";
        if (_battle.Ships.Values.Count(s => s.Faction == FactionId.Player && s.HitPoints > 0) >= MaxFleetSize)
            return "fleet.too_many";
        var spot = FindSpot(PlacedPlayerShips(), def, PlayerZone);
        if (spot is null) return "fleet.no_room";
        var id = NextPlayerShipId();
        var ship = new ShipState
        {
            Id = id,
            Definition = def,
            Faction = FactionId.Player,
            Bow = spot.Value, // FindSpot 返回合法船头；自动摆位固定朝东
            Facing = CardinalDirection.East,
            HitPoints = def.MaxHp,
            ArmorLevel = def.BaseArmor,
        };
        // F-5：默认武器/技能布局（旗舰火炮、护卫砲击 + DemoSkillLayout 槽位）——与默认舰队装配一致。
        if (DefaultWeaponEquip.TryGetValue(def.Id, out var weapons))
            foreach (var w in weapons) ship.WeaponCounts[w] = ship.WeaponCounts.GetValueOrDefault(w) + 1;
        if (SkillSeeding.DemoSkillLayout.TryGetValue(def.Id, out var skills))
            foreach (var s in skills) ship.SkillLoadout[s] = ship.SkillLoadout.GetValueOrDefault(s) + 1;
        _battle.Ships[id] = ship;
        var view = new NavalShipView { Name = id };
        view.Setup(ship, _grid);
        _shipsRoot.AddChild(view);
        _shipViews[id] = view;
        RebuildEquipShipRow();
        RefreshEquipmentPanel();
        SelectFleetShip(id);
        SetMessage($"已添加 {def.DisplayName}（{id}）");
        return "";
    }

    private void AddFleetShipFromButton(string typeId)
    {
        var err = AddFleetShip(typeId);
        if (err.Length > 0) SetMessage("无法添加：" + DescribePlacementError(err));
    }

    // 移除舰船（public）：关卡/遭遇锁定、至少保留 1 艘；清理视图/选中态/面板编辑态，重建装备行与面板。
    public string RemoveFleetShip(string shipId)
    {
        if (_level is not null || _encounter is not null) return "fleet.level_locked";
        var ship = _battle.ShipOrNull(shipId);
        if (ship is null || ship.Faction != FactionId.Player) return "deploy.unknown_ship";
        if (_battle.Ships.Values.Count(s => s.Faction == FactionId.Player && s.HitPoints > 0) <= 1)
            return "fleet.last_ship";
        _battle.Ships.Remove(shipId);
        if (_shipViews.Remove(shipId, out var view)) { _shipsRoot.RemoveChild(view); view.QueueFree(); }
        if (_selectedShip == shipId)
        {
            _selectedShip = null;
            if (_deployPanel is not null) _deployPanel.Visible = false;
        }
        if (_flagshipId == shipId) _flagshipId = null;
        if (_equipShipId == shipId) _equipShipId = null;
        if (_fleetShipId == shipId) _fleetShipId = null;
        RebuildEquipShipRow();
        RefreshEquipmentPanel();
        SelectFleetShip(_fleetShipId ?? "");
        SetMessage($"已移除 {ship.Definition.DisplayName}（{shipId}）");
        return "";
    }

    private void RemoveFleetShipFromButton(string shipId)
    {
        var err = RemoveFleetShip(shipId);
        if (err.Length > 0) SetMessage("无法删除：" + DescribePlacementError(err));
    }

    // 当前玩家已放舰（占格用于自动摆位避让）：(船头, 长度)。
    private IEnumerable<(GridPos Bow, int Length)> PlacedPlayerShips()
        => _battle.Ships.Values
            .Where(s => s.Faction == FactionId.Player && s.HitPoints > 0)
            .Select(s => (s.Bow, s.Length));

    // 玩家区自动摆位：从区右上往左下扫描合法船头（区内/地形可通行/非残骸/与已放舰不重叠）。朝向固定 East。
    // 校验口径与 ValidatePlacement 一致（不检查敌舰相邻，add 阶段敌舰尚未放置完成）。
    private GridPos? FindSpot(IEnumerable<(GridPos Bow, int Length)> placed, ShipDefinition def, Rect2I zone)
    {
        const CardinalDirection facing = CardinalDirection.East;
        for (var y = zone.Position.Y; y < zone.End.Y; y++)
        {
            for (var x = zone.End.X - 1; x >= zone.Position.X; x--)
            {
                var bow = new GridPos(x, y);
                var cells = FootprintCells(bow, facing, def.Length);
                var ok = true;
                foreach (var c in cells)
                {
                    if (!ZoneContains(zone, c)) { ok = false; break; }
                    if (TerrainRules.BlocksShip(_battle.Map.TerrainAt(c), def.Passability)) { ok = false; break; }
                    if (_battle.Map.IsWreck(c)) { ok = false; break; }
                }
                if (!ok) continue;
                foreach (var (pBow, pLen) in placed)
                {
                    var pCells = FootprintCells(pBow, facing, pLen);
                    if (cells.Any(pCells.Contains)) { ok = false; break; }
                }
                if (!ok) continue;
                return bow;
            }
        }
        return null;
    }

    // 下一个空闲玩家舰 id（p1.. 首空；增减后不重排，防与既有 id 冲突）。
    private string NextPlayerShipId()
    {
        for (var i = 0; ; i++)
        {
            var id = ShipIdFor(FactionId.Player, i);
            if (_battle.ShipOrNull(id) is null) return id;
        }
    }

    // 移除玩家全部舰船（加载预设前重置；不触碰敌方）。
    private void RemovePlayerFleet()
    {
        var playerIds = _battle.Ships.Values.Where(s => s.Faction == FactionId.Player).Select(s => s.Id).ToList();
        foreach (var id in playerIds)
        {
            _battle.Ships.Remove(id);
            if (_shipViews.Remove(id, out var view)) { _shipsRoot.RemoveChild(view); view.QueueFree(); }
        }
        _selectedShip = null;
        if (_deployPanel is not null) _deployPanel.Visible = false;
        _flagshipId = null;
        _equipShipId = null;
        _fleetShipId = null;
        if (_equipPanel is not null) _equipPanel.Visible = false;
        if (_fleetPanel is not null) _fleetPanel.Visible = false;
    }

    // 按预设装配一方舰队（自动摆位沿区扫描；舰型缺失跳过）。装备按预设（LevelShipSpec.Equipment），
    // 不套用 F-5 默认装载——预设完整捕获用户配置。
    private void AddPresetFleet(FleetPreset preset, FactionId faction)
    {
        var zone = faction == FactionId.Player ? PlayerZone : EnemyZone;
        var placed = new List<(GridPos Bow, int Length)>();
        var specs = new List<LevelShipSpec>();
        foreach (var ship in preset.Ships)
        {
            var def = _config!.Ships.FirstOrDefault(s => s.Id == ship.ShipTypeId);
            if (def is null) { GD.PushWarning($"ships.json 缺少舰型 {ship.ShipTypeId}"); continue; }
            var spot = FindSpot(placed, def, zone);
            if (spot is null) { GD.PushWarning($"布阵区已满，跳过 {def.DisplayName}"); continue; }
            placed.Add((spot.Value, def.Length)); // spot 即合法船头
            specs.Add(new LevelShipSpec(ship.ShipTypeId, spot.Value, CardinalDirection.East, ship.Equipment));
        }
        // 一次性装配 → AddLevelFleet 内部按序赋 p1..（分次调用会每次都从 index 0 覆盖）。
        AddLevelFleet(specs, faction);
    }

    // 应用预设（public）：校验合法 → 清玩家舰 → 按预设装配 → 重建视图/面板 → 置会话。
    // 会话置位后「再来一局」与 RebuildFleetForDeploy 沿用本预设替换默认舰队。
    public string ApplyFleetPreset(string name)
    {
        if (_level is not null || _encounter is not null) return "fleet.level_locked";
        var preset = FleetStore().Get(name);
        if (preset is null) return "fleet.unknown_preset";
        var errors = FleetPresetValidator.Validate(_config!, preset);
        if (errors.Count > 0) return errors[0];
        RemovePlayerFleet();
        AddPresetFleet(preset, FactionId.Player);
        foreach (var ship in _battle.Ships.Values)
        {
            if (ship.Faction != FactionId.Player || _shipViews.ContainsKey(ship.Id)) continue;
            var view = new NavalShipView { Name = ship.Id };
            view.Setup(ship, _grid);
            _shipsRoot.AddChild(view);
            _shipViews[ship.Id] = view;
        }
        FleetPresetSession.Begin(preset.Name);
        RebuildEquipShipRow();
        RefreshEquipmentPanel();
        RefreshFleetPanel();
        RefreshSelfSinkButton();
        SetMessage($"已应用舰队预设「{preset.Name}」：{preset.Ships.Count} 艘");
        return "";
    }

    private void LoadFleetPresetFromButton(string name)
    {
        var err = ApplyFleetPreset(name);
        if (err.Length > 0) SetMessage("无法加载预设：" + DescribePlacementError(err));
    }

    // 保存当前玩家舰队为预设（public）：名称非空、舰队非空、校验合法（装备不超槽位）→ 落盘。
    public string SaveCurrentFleetAs(string name)
    {
        if (_level is not null || _encounter is not null) return "fleet.level_locked";
        name = (name ?? "").Trim();
        if (name.Length == 0) return "fleet.empty_name";
        var ships = _battle.Ships.Values
            .Where(s => s.Faction == FactionId.Player && s.HitPoints > 0)
            .OrderBy(s => s.Id, StringComparer.Ordinal)
            .Select(FleetPresetShipFrom)
            .ToList();
        if (ships.Count == 0) return "fleet.empty_fleet";
        var preset = new FleetPreset(name, ships);
        var errors = FleetPresetValidator.Validate(_config!, preset);
        if (errors.Count > 0) return errors[0];
        FleetStore().Save(preset);
        RefreshFleetPanel();
        SetMessage($"舰队预设「{name}」已保存");
        return "";
    }

    // 单舰 → 预设舰（装备 = 当前武器/技能/护甲；护甲始终写入，0 时也可读）。
    private static FleetPresetShip FleetPresetShipFrom(ShipState s)
    {
        var equipment = new LevelEquipmentSpec(
            s.WeaponCounts.Count > 0 ? new Dictionary<string, int>(s.WeaponCounts) : null,
            s.SkillLoadout.Count > 0 ? new Dictionary<string, int>(s.SkillLoadout) : null,
            s.ArmorLevel);
        return new FleetPresetShip(s.Definition.Id, equipment);
    }

    private void SaveFleetPresetFromButton()
    {
        var err = SaveCurrentFleetAs(_fleetNameEdit?.Text ?? "");
        if (err.Length > 0) SetMessage("无法保存预设：" + DescribePlacementError(err));
    }

    // 删除预设（public）：存在才删除；刷新面板。
    public bool DeleteFleetPreset(string name)
    {
        var deleted = FleetStore().Delete(name);
        RefreshFleetPanel();
        if (deleted) SetMessage($"预设「{name}」已删除");
        return deleted;
    }

    private void DeleteFleetPresetFromButton(string name)
        => DeleteFleetPreset(name);

    // 刷新舰队配置面板：预览（数量/总强度/各舰型计数）+ 舰列表（选择/删除）+ 选中舰装备计数 + 预设列表（加载/删除）。
    private void RefreshFleetPanel()
    {
        if (_fleetPanel is null) return;
        if (_fleetPreviewLabel is not null)
        {
            var playerShips = _battle.Ships.Values.Where(s => s.Faction == FactionId.Player && s.HitPoints > 0).ToList();
            var strength = playerShips.Sum(s => RandomEnemyFleetGenerator.ShipStrength(s.Definition));
            var kinds = string.Join(" ", playerShips
                .GroupBy(s => s.Definition.Id)
                .OrderBy(g => g.Key, StringComparer.Ordinal)
                .Select(g => $"{g.First().Definition.DisplayName}×{g.Count()}"));
            _fleetPreviewLabel.Text = $"舰队 {playerShips.Count} 艘 · 总强度 {strength} · {kinds}";
        }
        if (_fleetShipList is not null)
        {
            foreach (var child in _fleetShipList.GetChildren()) { _fleetShipList.RemoveChild(child); child.QueueFree(); }
            foreach (var ship in _battle.Ships.Values)
            {
                if (ship.Faction != FactionId.Player || ship.HitPoints <= 0) continue;
                var row = new HBoxContainer { Name = $"Ship_{ship.Id}", CustomMinimumSize = new Vector2(0, 30) };
                row.AddThemeConstantOverride("separation", 6);
                var select = new Button
                {
                    Name = "Select",
                    Text = $"{ship.Definition.DisplayName} {ship.Id}",
                    SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
                    CustomMinimumSize = new Vector2(0, 30),
                };
                InkWashTheme.StyleButton(select);
                select.FocusMode = Control.FocusModeEnum.None;
                var captured = ship.Id;
                select.Pressed += () => SelectFleetShip(captured);
                var remove = MakeEquipButton("删除", 64, "Remove");
                remove.Pressed += () => RemoveFleetShipFromButton(captured);
                row.AddChild(select);
                row.AddChild(remove);
                _fleetShipList.AddChild(row);
            }
        }
        RefreshFleetEquipControls();
        if (_fleetPresetList is not null)
        {
            foreach (var child in _fleetPresetList.GetChildren()) { _fleetPresetList.RemoveChild(child); child.QueueFree(); }
            foreach (var preset in FleetStore().All.OrderBy(p => p.Name, StringComparer.Ordinal))
            {
                var row = new HBoxContainer { Name = $"Preset_{SafeNodeName(preset.Name)}", CustomMinimumSize = new Vector2(0, 30) };
                row.AddThemeConstantOverride("separation", 6);
                var label = new Label
                {
                    Name = "Name",
                    Text = $"{preset.Name}（{preset.Ships.Count}艘）",
                    SizeFlagsHorizontal = Control.SizeFlags.ExpandFill,
                    VerticalAlignment = VerticalAlignment.Center,
                };
                label.AddThemeFontOverride("font", InkWashTheme.Font());
                label.AddThemeFontSizeOverride("font_size", 14);
                label.AddThemeColorOverride("font_color", InkWashTheme.TextInk);
                var name_ = preset.Name;
                var load = MakeEquipButton("加载", 56, "Load");
                load.Pressed += () => LoadFleetPresetFromButton(name_);
                var del = MakeEquipButton("删除", 56, "Delete");
                del.Pressed += () => DeleteFleetPresetFromButton(name_);
                row.AddChild(label);
                row.AddChild(load);
                row.AddChild(del);
                _fleetPresetList.AddChild(row);
            }
        }
    }

    // 节点名安全化（预设名含 / : . 等 Godot 非法字符 → 下划线；空 → preset）。
    private static string SafeNodeName(string name)
    {
        var chars = name.Select(c => c is '/' or ':' or '@' or '.' or '"' or '\\' or '[' or ']' ? '_' : c).ToArray();
        var s = new string(chars).Trim();
        return s.Length == 0 ? "preset" : s;
    }

    // 刷新面板选中舰的装备计数/上限/按钮可用态（口径与 RefreshEquipmentPanel 一致）。
    private void RefreshFleetEquipControls()
    {
        if (_fleetSlotsLabel is not null)
        {
            var ship = _fleetShipId is { } id ? _battle.ShipOrNull(id) : null;
            if (ship is not null && ship.Faction == FactionId.Player)
            {
                var usedW = UsedWeaponSlots(ship);
                var maxW = ship.Definition.WeaponSlots;
                var usedS = UsedSkillSlots(ship);
                var maxS = ship.Definition.SkillSlots;
                var armorCap = ship.Definition.BaseArmor + ship.Definition.ArmorSlots;
                _fleetSlotsLabel.Text = $"{ship.Definition.DisplayName}（{ship.Id}） 武器位 {usedW}/{maxW} · 技能位 {usedS}/{maxS} · 护甲位 {ship.ArmorLevel}/{armorCap} · 负载 {WeatherRules.CurrentLoad(ship)}/{ship.Definition.LoadCapacity}";
            }
            else
            {
                _fleetSlotsLabel.Text = "请选择一艘舰配置装备";
            }
        }
        var selected = _fleetShipId is { } sel ? _battle.ShipOrNull(sel) : null;
        if (selected is { Faction: FactionId.Player } selShip)
        {
            var usedW = UsedWeaponSlots(selShip);
            var maxW = selShip.Definition.WeaponSlots;
            var usedS = UsedSkillSlots(selShip);
            var maxS = selShip.Definition.SkillSlots;
            var armorCap = selShip.Definition.BaseArmor + selShip.Definition.ArmorSlots;
            foreach (var (wid, ctl) in _fleetWeaponControls)
            {
                var count = selShip.WeaponCounts.GetValueOrDefault(wid, 0);
                var atMax = _config!.Weapons.FirstOrDefault(w => w.Id == wid) is { MaxCount: { } mc } && count >= mc;
                ctl.Count.Text = $"×{count}";
                ctl.Minus.Disabled = count <= 0;
                ctl.Plus.Disabled = usedW >= maxW || atMax;
            }
            foreach (var (sid, ctl) in _fleetSkillControls)
            {
                var count = selShip.SkillLoadout.GetValueOrDefault(sid, 0);
                ctl.Count.Text = $"×{count}";
                ctl.Minus.Disabled = count <= 0;
                ctl.Plus.Disabled = usedS >= maxS;
            }
            var armor = selShip.ArmorLevel;
            _fleetArmorControls.Count.Text = $"×{armor}";
            _fleetArmorControls.Minus.Disabled = armor <= 0;
            _fleetArmorControls.Plus.Disabled = armor >= armorCap;
        }
        else
        {
            foreach (var (_, ctl) in _fleetWeaponControls) { ctl.Count.Text = "×0"; ctl.Minus.Disabled = true; ctl.Plus.Disabled = true; }
            foreach (var (_, ctl) in _fleetSkillControls) { ctl.Count.Text = "×0"; ctl.Minus.Disabled = true; ctl.Plus.Disabled = true; }
            _fleetArmorControls.Count.Text = "×0";
            _fleetArmorControls.Minus.Disabled = true;
            _fleetArmorControls.Plus.Disabled = true;
        }
    }

    // 面板装备按钮 → 复用 F-5 EquipWeapon/EquipSkill/EquipArmor（校验/写状态同一套），再刷新面板。
    private void EquipFleetWeaponFromButton(string weaponId, int delta)
    {
        var err = EquipWeapon(_fleetShipId ?? "", weaponId, delta);
        if (err.Length > 0) SetMessage("无法装载武器：" + DescribePlacementError(err));
        RefreshFleetPanel();
    }

    private void EquipFleetSkillFromButton(string skillId, int delta)
    {
        var err = EquipSkill(_fleetShipId ?? "", skillId, delta);
        if (err.Length > 0) SetMessage("无法装载技能：" + DescribePlacementError(err));
        RefreshFleetPanel();
    }

    private void EquipFleetArmorFromButton(int delta)
    {
        var err = EquipArmor(_fleetShipId ?? "", delta);
        if (err.Length > 0) SetMessage("无法调整护甲：" + DescribePlacementError(err));
        RefreshFleetPanel();
    }

    // ---- V-7 只读访问器（headless 冒烟断言舰队配置闭环） ----

    public bool FleetPanelVisible() => _fleetPanel?.Visible ?? false;
    public string FleetDesignerShip() => _fleetShipId ?? "";
    public string PlayerShipType(string shipId) => _battle.ShipOrNull(shipId)?.Definition.Id ?? "";
    public string FleetPreviewText() => _fleetPreviewLabel?.Text ?? "";
    public int PlayerFleetCount() => _battle?.Ships.Values.Count(s => s.Faction == FactionId.Player && s.HitPoints > 0) ?? 0;
    public int StorePresetCount() => FleetStore().Count;
    public bool StoreHasPreset(string name) => FleetStore().Has(name);
    public string StorePresetNames() => string.Join(",", FleetStore().All.OrderBy(p => p.Name, StringComparer.Ordinal).Select(p => p.Name));

    // V-7 测试钩子：改用固定临时路径的预设库（冒烟跨场景共用同一文件，不污染 user:// 真实预设）。
    // UseFleetPresetsForTest = 指向临时库并载入（保留既有预设，跨场景持久）；ResetFleetPresetsForTest = 再清空全部（冒烟开头用）。
    public void UseFleetPresetsForTest()
    {
        _fleetStore = new FleetPresetStore(System.IO.Path.Combine(System.IO.Path.GetTempPath(), "naval_fleet_presets_smoke.json"));
        _fleetStore.Load();
    }

    public void ResetFleetPresetsForTest()
    {
        UseFleetPresetsForTest();
        foreach (var p in _fleetStore!.All.ToList()) _fleetStore.Delete(p.Name);
    }

    private List<(Rect2I Rect, Color Color)> ZoneOverlays()
        => _level is not null || _encounter is not null
            ? new()
            {
                (_levelEnemyZone, new Color(0.42f, 0.26f, 0.20f, 0.12f)),
            }
            : new()
            {
                (EnemyZone, new Color(0.42f, 0.26f, 0.20f, 0.12f)),
            };

    private void RefreshDeploymentHighlights()
    {
        if (_battle is null || _grid is null) return;
        var selected = SelectedPlayerShip();
        var candidates = selected is not null
            ? new[] { selected }
            : _battle.Ships.Values
                .Where(ship => ship.Faction == FactionId.Player && ship.HitPoints > 0 && !ship.SelfSunk)
                .ToArray();
        var validBows = new HashSet<GridPos>();
        foreach (var ship in candidates)
            for (var x = 0; x < _battle.Map.Width; x++)
                for (var y = 0; y < _battle.Map.Height; y++)
                {
                    var bow = new GridPos(x, y);
                    if (ValidatePlacement(ship, bow, ship.Facing) is null) validBows.Add(bow);
                }
        _grid.ShowDeploymentCells(validBows, new Color(0.18f, 0.48f, 0.82f, 0.38f));
    }
}
