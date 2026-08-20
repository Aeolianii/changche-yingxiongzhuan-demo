#nullable enable
using Godot;
using NavalCombat.Core;
using NavalCombat.Levels;
using System;
using System.Collections.Generic;
using System.Linq;

namespace NanjiangNaval;

// 布阵控制器：双方一次性全部布阵（不交替）。舰队从 data/naval/ships.json 经 NavalConfigLoader 加载。
// 默认阵型：双方各 4 舰横向、平行（玩家朝东、敌方朝西），在 48×36 大图缩小后的可配置区（12×10）呈纵深布置（CHG-20260819 F-3）。
// 交互：点己方舰选中 → 点区域空格放置（该格为船头）/ 旋转按钮改横纵朝向 → 点「设为指挥舰」指定 → 「开始战斗」校验后交 BattleController。
// 非法占格（越界/重叠/区域外/不可通行地形）一律拒绝，返回原因 key。
public partial class NavalDeploymentController : Node2D, IGridClickReceiver
{
    // CHG-20260819（F-3）：预设己方区域缩小为「正常战斗可配置范围」12 宽 × 10 高，竖直居中到地图中部
    // （y∈[12,22) 覆盖逃跑格 x=0 列 y16-18，冒烟逃跑仍可行）。与 ship_screen FORMATION_ZONE 同源，
    // 小地图预设阵型坐标可直接落入战斗布阵区。玩家 x[1,13) y[12,22)；敌 x[14,26) y[12,22)；中央 x=13 留 1 列交战纵深。
    public static readonly Rect2I PlayerZone = new(1, 12, 12, 10);
    public static readonly Rect2I EnemyZone = new(14, 12, 12, 10);

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
    // CHG-20260818：玩家舰队预设库（user://fleet_presets.json；复用 FleetPresetStore，含活动预设持久化）。
    // 旧海战 F-5 装备 / V-7 舰队配置 UI 已弃用，装备配置统一走整合版 ship_screen。
    private FleetPresetStore? _fleetStore;
    private readonly Dictionary<string, NavalShipView> _shipViews = new();
    // 默认阵型按 roster 下标对齐（敌方有重复舰型，不能用舰型 id 作键）。玩家侧 CHG-20260818 由经济舰队自动摆位。
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
        // CHG-20260817：海盗战请求 meta（sea_overworld 选择难度后写入）→ 先生成并 Begin 随机遭遇，再进遭遇模式。
        // CHG-20260819（S-2 海面接入）：讨伐战请求 meta（sea_overworld 海怪/营寨触发）→ 组装 hunt_stage 固定遭遇。
        if (TryConsumePirateBattleRequest(out var pirateId, out var pirateDifficulty))
            _encounter = BeginPirateEncounter(pirateId, pirateDifficulty);
        else if (TryConsumeHuntBattleRequest(out var huntStageId))
            _encounter = BeginHuntEncounter(huntStageId);
        else
            _encounter = RandomEncounterSession.Active ? RandomEncounterSession.Pending : null;
        _levelPlay = GetNodeOrNull<NavalLevelPlayController>("../LevelPlay");
        _battle = _encounter is not null ? BuildBattleForEncounter(_encounter)
            : _level is not null ? BuildBattleForLevel(_level)
            : BuildBattle();
        _grid = GetNode<NavalGridView>("DeployGrid");
        _grid.ClickReceiver = this;
        _grid.Attach(_battle);
        ShowLevelObjectiveHighlight();
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
        // CHG-20260818：旧海战 F-5 装备配置 / V-7 舰队配置按钮已弃用（场景节点移除），装备配置统一走 ship_screen。
        if (_level is null) BuildDefaultLineups();
        BuildFleet(); // L-3：关卡模式经 BuildFleet 内分支按 LevelDefinition 装配（下方）；自由模式沿用默认阵型
        ExitCellRules.EnsureSafeExits(_battle.Map, _battle.Ships.Values.SelectMany(s => s.OccupiedCells()));
        _grid.QueueRedraw();
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
        map.TerrainStamps.AddRange(spec.TerrainStamps);
        return map;
    }

    private void ShowLevelObjectiveHighlight()
    {
        if (_level?.Objective.TargetCell is { } target)
            _grid.ShowPersistentHighlights(new[] { (target, $"{target.X},{target.Y}") });
        else
            _grid.ClearPersistentHighlights();
    }

    // L-3：关卡是否需人工布阵（Hints 含 布阵/装备/确认布阵/开始战斗 关键词）→ 否则自动开始战斗（1-1 直入战斗）。
    private static bool HasDeploymentHint(LevelDefinition def)
        => def.Hints.Any(h => h.Contains("布阵") || h.Contains("装备") || h.Contains("确认布阵") || h.Contains("开始战斗"));

    private void BuildDefaultLineups()
    {
        // CHG-20260819（F-3）敌方默认阵型：随玩家区缩小右移贴齐敌区（14,12,12,10），贴近玩家区右缘便于交战：
        // e1旗舰(16,12) e2护卫舰(17,17) e3护卫舰(16,21) e4运输船(19,19)，全部朝西。
        // 玩家侧 CHG-20260818：自由模式玩家舰队 = 经济舰队，默认摆位由 BuildPlayerFleetFromEconomy 沿玩家区自动扫描（不再固定坐标）。
        _enemyDefault.Clear();
        _enemyDefault.Add((new GridPos(16, 12), CardinalDirection.West));
        _enemyDefault.Add((new GridPos(17, 17), CardinalDirection.West));
        _enemyDefault.Add((new GridPos(16, 21), CardinalDirection.West));
        _enemyDefault.Add((new GridPos(19, 19), CardinalDirection.West));
    }

    private void BuildFleet()
    {
        // CHG-20260818：玩家舰队一律来自经济舰队（economy_state 映射 + 活动预设增减，上限=拥有数量）——
        // 自由模式与随机遭遇（海盗战/遭遇战）都用玩家自己配置的舰队；仅关卡模式（教学）按 LevelDefinition 固定玩家/敌方舰队。
        if (_level is not null)
        {
            AddFleetFromLevel(_level);
        }
        else
        {
            BuildPlayerFleetFromEconomy();
            if (_encounter is not null)
                AddLevelFleet(_encounter.EnemyFleet, FactionId.Enemy); // U-2c：遭遇敌方舰队按遭遇规格
            else
                AddFleetShips(EnemyRoster, _enemyDefault, FactionId.Enemy); // 自由模式默认敌方 4 舰
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
        else if (_level is not null) { ApplySpecLineup(_level!.PlayerFleet, FactionId.Player); ApplySpecLineup(_level.EnemyFleet, FactionId.Enemy); }
        else
        {
            // CHG-20260818：玩家侧恢复为经济舰队的自动摆位（沿玩家区重新扫描），敌方恢复默认阵型。
            RestorePlayerEconomyLineup();
            ApplyDefaultLineup(EnemyRoster, _enemyDefault, FactionId.Enemy);
        }
        foreach (var id in _shipViews.Keys) SyncShipView(id);
        SetMessage("已恢复默认阵型");
    }

    // 遭遇模式：把双方舰队恢复到遭遇生成的初始位置（id 顺序与遭遇规格列表一致 p1.. / e1..）。
    private void ApplyEncounterLineup()
    {
        ApplySpecLineup(_encounter!.PlayerFleet, FactionId.Player);
        ApplySpecLineup(_encounter.EnemyFleet, FactionId.Enemy);
    }

    // 按规格列表恢复一方舰队的初始位置（遭遇与关卡共用；id 顺序与规格列表一致 p1.. / e1..）。
    private void ApplySpecLineup(IReadOnlyList<LevelShipSpec> specs, FactionId faction)
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
        ExitCellRules.EnsureSafeExits(_battle.Map, _battle.Ships.Values.SelectMany(s => s.OccupiedCells()));
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
        // CHG（海怪 Boss 战）：开战前敌我强度配平——按有效难度（固定/讨伐统一普通）降敌舰 HitPoints。
        var difficulty = EncounterBalancer.EffectiveDifficulty(_encounter);
        EncounterBalancer.BalanceEnemyFleet(_battle, difficulty);
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
    // CHG-20260817：海盗战请求 meta 消费——读取并移除场景根 meta，失败（缺海盗 id）返回 false。
    // 仅由 _Ready 调用；避免污染后续随机遭遇/关卡流程。
    private bool TryConsumePirateBattleRequest(out string pirateId, out int difficulty)
    {
        pirateId = "";
        difficulty = 2;
        var root = GetTree().Root;
        if (!root.HasMeta(PirateBattleSession.RequestMetaKey)) return false;
        var raw = root.GetMeta(PirateBattleSession.RequestMetaKey);
        root.RemoveMeta(PirateBattleSession.RequestMetaKey);
        if (raw.VariantType != Variant.Type.Dictionary) return false;
        var dict = raw.As<Godot.Collections.Dictionary>();
        var pid = dict.ContainsKey("pirate_id") ? dict["pirate_id"].AsString() : "";
        if (string.IsNullOrEmpty(pid)) return false;
        pirateId = pid;
        if (dict.ContainsKey("difficulty"))
            difficulty = Math.Clamp(dict["difficulty"].AsInt32(),
                RandomEncounterGenerator.MinDifficulty, RandomEncounterGenerator.MaxDifficulty);
        _pirateReturnCarrier = dict;
        return true;
    }

    // 海盗战：登记海盗会话（携带发起方上下文 → 结算返回时还原）→ 生成对应难度随机遭遇 → Begin。
    private Godot.Collections.Dictionary? _pirateReturnCarrier;
    private RandomEncounter? BeginPirateEncounter(string pirateId, int difficulty)
    {
        PirateBattleSession.Begin(pirateId, difficulty, _pirateReturnCarrier);
        var encounter = RandomEncounterGenerator.Generate(_config!,
            new RandomEncounterOptions(Difficulty: difficulty, Seed: PirateEncounterSeed()));
        RandomEncounterSession.Begin(encounter);
        return encounter;
    }

    // CHG-20260819（S-2 海面接入）：讨伐战请求 meta 消费——读取并移除场景根 meta，失败（缺阶段 id）返回 false。
    // 仅由 _Ready 调用；与海盗战消费同构，避免污染后续随机遭遇/关卡流程。
    private bool TryConsumeHuntBattleRequest(out string stageId)
    {
        stageId = "";
        var root = GetTree().Root;
        if (!root.HasMeta(HuntBattleSession.RequestMetaKey)) return false;
        var raw = root.GetMeta(HuntBattleSession.RequestMetaKey);
        root.RemoveMeta(HuntBattleSession.RequestMetaKey);
        if (raw.VariantType != Variant.Type.Dictionary) return false;
        var dict = raw.As<Godot.Collections.Dictionary>();
        var id = dict.ContainsKey("stage_id") ? dict["stage_id"].AsString() : "";
        if (string.IsNullOrEmpty(id)) return false;
        stageId = id;
        _huntReturnCarrier = dict;
        return true;
    }

    // 讨伐战：登记讨伐会话（携带发起方上下文 → 结算返回时还原）→ 组装 hunt_stage 固定遭遇 → Begin。
    private Godot.Collections.Dictionary? _huntReturnCarrier;
    private RandomEncounter? BeginHuntEncounter(string stageId)
    {
        HuntBattleSession.Begin(stageId, _huntReturnCarrier);
        var encounter = HuntEncounterGenerator.CreateStage(_config!, stageId);
        RandomEncounterSession.Begin(encounter);
        return encounter;
    }

    // 新种子：TickCount（毫秒），与 LevelSelectController.NewSeed 同源，避免连续进入同场。
    private int PirateEncounterSeed() => System.Environment.TickCount;
    // F-2：出口格只读（headless 冒烟断言"地图有出口边界"）。
    public int ExitCellCount() => _battle?.Map.ExitCells.Count ?? 0;
    public bool IsExitCell(int x, int y) => _battle?.Map.ExitCells.Contains(new GridPos(x, y)) ?? false;
    public bool RandomMapsAlwaysHaveSafeExits(int sampleCount = 24)
    {
        var generator = new RandomMapGenerator();
        for (var seed = 0; seed < Math.Max(1, sampleCount); seed++)
        {
            var options = new RandomMapOptions(24, 18, seed % 3 + 1, seed, IncludeExits: false);
            var spec = generator.Generate(options).Spec;
            if (spec.ExitCells.Count != ExitCellRules.RecommendedCount(spec.Width, spec.Height)) return false;
            if (spec.ExitCells.Any(cell => spec.TerrainAt(cell.X, cell.Y) != TerrainType.DeepWater)) return false;
            if (!spec.ExitCells.Any(cell => cell.X == 0)
                || !spec.ExitCells.Any(cell => cell.X == spec.Width - 1)) return false;
        }
        return true;
    }

    public bool FixedTerrainMapsAreCoherent(int sampleCount = 24)
    {
        var generator = new RandomMapGenerator();
        var expectedSizes = new Dictionary<string, (int Width, int Height)>(StringComparer.Ordinal)
        {
            [RandomMapGenerator.FjordStampId] = (8, 14),
            [RandomMapGenerator.ArchipelagoStampId] = (8, 12),
            [RandomMapGenerator.SolitaryIslandStampId] = (8, 8),
            [RandomMapGenerator.PeninsulaStampId] = (8, 13),
            [RandomMapGenerator.LagoonStampId] = (8, 12),
        };
        var expectedOrigins = new Dictionary<string, GridPos>(StringComparer.Ordinal)
        {
            [RandomMapGenerator.FjordStampId] = new GridPos(8, 2),
            [RandomMapGenerator.ArchipelagoStampId] = new GridPos(8, 3),
            [RandomMapGenerator.SolitaryIslandStampId] = new GridPos(8, 5),
            [RandomMapGenerator.PeninsulaStampId] = new GridPos(8, 0),
            [RandomMapGenerator.LagoonStampId] = new GridPos(8, 3),
        };
        var seenMapIds = new HashSet<string>(StringComparer.Ordinal);
        for (var seed = 0; seed < Math.Max(1, sampleCount); seed++)
        {
            var result = generator.Generate(new RandomMapOptions(24, 18, seed % 3 + 1, seed));
            var repeat = generator.Generate(new RandomMapOptions(24, 18, (seed + 1) % 3 + 1, seed));
            var sameTemplate = generator.Generate(new RandomMapOptions(24, 18, (seed + 2) % 3 + 1, seed + 5));
            if (result.Spec.TerrainStamps.Count != 1
                || repeat.Spec.TerrainStamps.Count != result.Spec.TerrainStamps.Count)
                return false;
            if (!result.Spec.TerrainRows.SequenceEqual(repeat.Spec.TerrainRows)
                || !result.Spec.TerrainStamps.SequenceEqual(repeat.Spec.TerrainStamps)
                || !result.Spec.TerrainRows.SequenceEqual(sameTemplate.Spec.TerrainRows)
                || !result.Spec.TerrainStamps.SequenceEqual(sameTemplate.Spec.TerrainStamps))
                return false;

            var mapId = RandomMapGenerator.FixedMapId(result.Spec);
            if (!RandomMapGenerator.FixedMapIds.Contains(mapId)
                || RandomMapGenerator.FixedMapDisplayName(result.Spec) == "开阔海域")
                return false;
            seenMapIds.Add(mapId);
            var mainStamp = result.Spec.TerrainStamps[0];
            if (!expectedOrigins.TryGetValue(mainStamp.Id, out var expectedOrigin)
                || mainStamp.Origin != expectedOrigin)
                return false;

            if (!expectedSizes.TryGetValue(mainStamp.Id, out var expectedSize)
                || mainStamp.Width != expectedSize.Width || mainStamp.Height != expectedSize.Height
                || mainStamp.QuarterTurns != 0
                || !ResourceLoader.Exists(mainStamp.TexturePath))
                return false;
            for (var y = mainStamp.Origin.Y; y < mainStamp.Origin.Y + mainStamp.Height; y++)
            {
                for (var x = mainStamp.Origin.X; x < mainStamp.Origin.X + mainStamp.Width; x++)
                {
                    var cell = new GridPos(x, y);
                    if (!result.Spec.InBounds(cell)
                        || result.PlayerZone.Contains(cell)
                        || result.EnemyZone.Contains(cell)
                        || result.Spec.IsExit(cell))
                        return false;
                }
            }

            if (mainStamp.Id == RandomMapGenerator.FjordStampId
                && (!HasDeepWaterPathInsideStamp(result.Spec, mainStamp, vertical: true)
                    || !EveryStampRowHasDeepWaterRun(result.Spec, mainStamp, minimumRun: 4)
                    || !CentralRowIsDeepWater(result, 1)
                    || !CentralRowIsDeepWater(result, 16)))
                return false;
            if (mainStamp.Id == RandomMapGenerator.ArchipelagoStampId
                && (CountLandComponents(result.Spec, mainStamp) < 5
                    || CountFullyDeepRows(result.Spec, mainStamp) < 4
                    || !HasDeepWaterPathInsideStamp(result.Spec, mainStamp, vertical: false)))
                return false;
            if (mainStamp.Id == RandomMapGenerator.SolitaryIslandStampId
                && (!TerrainRules.IsLand(result.Spec.TerrainAt(mainStamp.Origin.X + 3, mainStamp.Origin.Y + 3))
                    || !CentralRowIsDeepWater(result, 4)
                    || !CentralRowIsDeepWater(result, 13)))
                return false;
            if (mainStamp.Id == RandomMapGenerator.PeninsulaStampId
                && (!Enumerable.Range(mainStamp.Origin.X, mainStamp.Width)
                        .All(x => TerrainRules.IsLand(result.Spec.TerrainAt(x, mainStamp.Origin.Y)))
                    || result.Spec.TerrainAt(mainStamp.Origin.X + 1, mainStamp.Origin.Y + 5) != TerrainType.DeepWater
                    || !CentralRowIsDeepWater(result, 13)))
                return false;
            if (mainStamp.Id == RandomMapGenerator.LagoonStampId
                && (result.Spec.TerrainAt(mainStamp.Origin.X + 3, mainStamp.Origin.Y + 4) != TerrainType.DeepWater
                    || LongestFullyDeepRowRun(result.Spec, mainStamp) < 6
                    || !HasDeepWaterPathInsideStamp(result.Spec, mainStamp, vertical: false)))
                return false;
            if (RandomMapGenerator.ToBattleMap(result.Spec).TerrainStamps.Count != result.Spec.TerrainStamps.Count
                || !result.Connected)
                return false;
        }
        return RandomMapGenerator.FixedMapIds.All(seenMapIds.Contains);
    }

    private static bool CentralRowIsDeepWater(RandomMapResult result, int y)
        => Enumerable.Range(result.PlayerZone.Right, result.EnemyZone.X - result.PlayerZone.Right)
            .All(x => result.Spec.TerrainAt(x, y) == TerrainType.DeepWater);

    private static bool EveryStampRowHasDeepWaterRun(LevelMapSpec spec, TerrainVisualStamp stamp, int minimumRun)
    {
        for (var y = stamp.Origin.Y; y < stamp.Origin.Y + stamp.Height; y++)
        {
            var run = 0;
            var longest = 0;
            for (var x = stamp.Origin.X; x < stamp.Origin.X + stamp.Width; x++)
            {
                run = spec.TerrainAt(x, y) == TerrainType.DeepWater ? run + 1 : 0;
                longest = Math.Max(longest, run);
            }
            if (longest < minimumRun) return false;
        }
        return true;
    }

    private static int CountFullyDeepRows(LevelMapSpec spec, TerrainVisualStamp stamp)
        => Enumerable.Range(stamp.Origin.Y, stamp.Height)
            .Count(y => Enumerable.Range(stamp.Origin.X, stamp.Width)
                .All(x => spec.TerrainAt(x, y) == TerrainType.DeepWater));

    private static int LongestFullyDeepRowRun(LevelMapSpec spec, TerrainVisualStamp stamp)
    {
        var run = 0;
        var longest = 0;
        for (var y = stamp.Origin.Y; y < stamp.Origin.Y + stamp.Height; y++)
        {
            if (Enumerable.Range(stamp.Origin.X, stamp.Width)
                .All(x => spec.TerrainAt(x, y) == TerrainType.DeepWater))
            {
                run++;
                longest = Math.Max(longest, run);
            }
            else
            {
                run = 0;
            }
        }
        return longest;
    }

    private static bool HasDeepWaterPathInsideStamp(LevelMapSpec spec, TerrainVisualStamp stamp, bool vertical)
    {
        var starts = new Queue<GridPos>();
        var visited = new HashSet<GridPos>();
        var startCount = vertical ? stamp.Width : stamp.Height;
        for (var index = 0; index < startCount; index++)
        {
            var cell = vertical
                ? new GridPos(stamp.Origin.X + index, stamp.Origin.Y)
                : new GridPos(stamp.Origin.X, stamp.Origin.Y + index);
            if (spec.TerrainAt(cell) == TerrainType.DeepWater && visited.Add(cell)) starts.Enqueue(cell);
        }
        while (starts.Count > 0)
        {
            var cell = starts.Dequeue();
            if (vertical && cell.Y == stamp.Origin.Y + stamp.Height - 1
                || !vertical && cell.X == stamp.Origin.X + stamp.Width - 1)
                return true;
            foreach (var direction in new[] { CardinalDirection.North, CardinalDirection.East, CardinalDirection.South, CardinalDirection.West })
            {
                var next = cell + direction.Vector();
                if (!stamp.Contains(next) || spec.TerrainAt(next) != TerrainType.DeepWater || !visited.Add(next)) continue;
                starts.Enqueue(next);
            }
        }
        return false;
    }

    private static int CountLandComponents(LevelMapSpec spec, TerrainVisualStamp stamp)
    {
        var remaining = new HashSet<GridPos>();
        for (var y = stamp.Origin.Y; y < stamp.Origin.Y + stamp.Height; y++)
            for (var x = stamp.Origin.X; x < stamp.Origin.X + stamp.Width; x++)
                if (TerrainRules.IsLand(spec.TerrainAt(x, y))) remaining.Add(new GridPos(x, y));
        var count = 0;
        while (remaining.Count > 0)
        {
            count++;
            var queue = new Queue<GridPos>();
            var start = remaining.First();
            remaining.Remove(start);
            queue.Enqueue(start);
            while (queue.Count > 0)
            {
                var cell = queue.Dequeue();
                foreach (var direction in new[] { CardinalDirection.North, CardinalDirection.East, CardinalDirection.South, CardinalDirection.West })
                {
                    var next = cell + direction.Vector();
                    if (remaining.Remove(next)) queue.Enqueue(next);
                }
            }
        }
        return count;
    }

    public bool RandomTerrainStampsAreCoherent(int sampleCount = 24)
        => FixedTerrainMapsAreCoherent(sampleCount);

    public bool RandomEncountersUseFixedTerrainMaps(int sampleCount = 24)
    {
        if (_config is null) return false;
        var seenMapIds = new HashSet<string>(StringComparer.Ordinal);
        for (var seed = 0; seed < Math.Max(1, sampleCount); seed++)
        {
            var encounter = RandomEncounterGenerator.Generate(
                _config,
                new RandomEncounterOptions(seed % 3 + 1, seed));
            var mapId = RandomMapGenerator.FixedMapId(encounter.Map);
            if (!RandomMapGenerator.FixedMapIds.Contains(mapId)
                || encounter.MapSourceLabel != RandomMapGenerator.FixedMapDisplayName(encounter.Map)
                || encounter.Map.TerrainStamps.Count != 1)
                return false;
            seenMapIds.Add(mapId);
        }
        return RandomMapGenerator.FixedMapIds.All(seenMapIds.Contains);
    }

    // 聚焦首版印章的可视化测试钩子：清空舰船与布阵叠层，只保留随机海图和整张地貌素材。
    public bool ShowRandomTerrainStampPreviewForTest(int seed)
        => ShowRandomTerrainStampPreviewForTest(
            new RandomMapGenerator().Generate(new RandomMapOptions(24, 18, 2, seed)),
            seed,
            focusStampId: null);

    public bool ShowRandomTerrainStampKindPreviewForTest(string stampId)
    {
        if (!RandomMapGenerator.TerrainStampIds.Contains(stampId)) return false;
        var generator = new RandomMapGenerator();
        for (var seed = 0; seed < 512; seed++)
        {
            var result = generator.Generate(new RandomMapOptions(24, 18, seed % 3 + 1, seed));
            if (result.Spec.TerrainStamps.Any(stamp => stamp.Id == stampId))
                return ShowRandomTerrainStampPreviewForTest(result, seed, stampId);
        }
        return false;
    }

    public bool ShowFixedTerrainMapPreviewForTest(string mainStampId)
    {
        if (!RandomMapGenerator.MainTerrainStampIds.Contains(mainStampId)) return false;
        var generator = new RandomMapGenerator();
        for (var seed = 0; seed < RandomMapGenerator.FixedMapIds.Count; seed++)
        {
            var result = generator.Generate(new RandomMapOptions(24, 18, 2, seed));
            if (result.Spec.TerrainStamps.FirstOrDefault()?.Id == mainStampId)
                return ShowRandomTerrainStampPreviewForTest(result, seed, mainStampId, overview: true);
        }
        return false;
    }

    private bool ShowRandomTerrainStampPreviewForTest(
        RandomMapResult result,
        int seed,
        string? focusStampId,
        bool overview = false)
    {
        if (_config is null || result.Spec.TerrainStamps.Count == 0) return false;
        foreach (var child in _shipsRoot.GetChildren())
        {
            _shipsRoot.RemoveChild(child);
            child.QueueFree();
        }
        _shipViews.Clear();
        _battle = new BattleState
        {
            Map = RandomMapGenerator.ToBattleMap(result.Spec),
            Config = _config,
            Random = new SeedRandomSource(seed),
        };
        _grid.Attach(_battle);
        _grid.ShowDeploymentZones(Array.Empty<(Rect2I Rect, Color Color)>());
        _grid.ShowDeploymentCells(Array.Empty<GridPos>(), Colors.Transparent);
        _grid.ClearPersistentHighlights();
        _grid.ClearOverlay();
        if (overview) _grid.FocusCameraOnWholeMap();
        else if (focusStampId is null) _grid.FocusCameraOnFirstTerrainStamp();
        else _grid.FocusCameraOnTerrainStamp(focusStampId);
        if (_deployHud is not null) _deployHud.Visible = false;
        _grid.QueueRedraw();
        return true;
    }

    public bool OneSidedExitMapRebalancesAcrossBothEdges()
    {
        var map = new BattleMap(16, 10);
        for (var y = 0; y < map.Height; y++) map.ExitCells.Add(new GridPos(map.Width - 1, y));

        ExitCellRules.EnsureSafeExits(map);

        var target = ExitCellRules.RecommendedCount(map.Width, map.Height);
        var leftQuota = target / 2;
        var rightQuota = target - leftQuota;
        return map.ExitCells.Count == target
               && map.ExitCells.Count(cell => cell.X == 0) == leftQuota
               && map.ExitCells.Count(cell => cell.X == map.Width - 1) == rightQuota;
    }

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

    // CHG-20260818：玩家舰装备只读状态（headless 冒烟断言经济舰队装备映射闭环）——武器数/技能槽位数/护甲/槽位/负载/减伤。
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
    // 已用武器/技能槽位（装备映射测试断言闭环用）。
    private static int UsedWeaponSlots(ShipState ship) => ship.WeaponCounts.Values.Sum();
    private static int UsedSkillSlots(ShipState ship) => ship.SkillLoadout.Values.Sum();

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
        // CHG-20260818：舰队预设 / 经济舰队（ship_screen 预设校验 + 布阵装配）原因。
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
        "fleet.over_owned" => "出战数量超过该舰型拥有数",
        "fleet.unknown_preset" => "预设不存在",
        "" => "",
        _ => key,
    };


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
        ShowLevelObjectiveHighlight();
        BuildDefaultLineups();
        BuildFleet();
        ExitCellRules.EnsureSafeExits(_battle.Map, _battle.Ships.Values.SelectMany(s => s.OccupiedCells()));
        _grid.QueueRedraw();
        _grid.FocusCameraOnPlayerFleet();
        if (_level is not null) ComputeLevelPlayerZone();
        else if (_encounter is not null)
        {
            _levelPlayerZone = ToRect(_encounter.PlayerZone);
            _levelEnemyZone = ToRect(_encounter.EnemyZone);
        }
        _grid.ShowDeploymentZones(ZoneOverlays());
        RefreshDeploymentHighlights();
    }

    // F-1：headless 冒烟测试钩子——指定种子重建战斗（天气/风向在 ConfirmDeployment 掷定走种子化 RNG）。
    // 同种子两次构建 → 天气/风向相同（可复现）；测试用 RebuildBattleForTest(9)=阴天、RebuildBattleForTest(0)=雨天 等。
    public void RebuildBattleForTest(int seed)
    {
        _battleSeedOverride = seed;
        _flagshipId = null;
        _selectedShip = null;
        if (_deployPanel is not null) _deployPanel.Visible = false;
        RebuildFleetForDeploy();
        RefreshSelfSinkButton();
    }


    // ---- CHG-20260818：经济舰队装配（自由模式玩家舰队来源）+ 舰队预设库 ----

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

    // 自由模式玩家舰队 = 经济舰队：economy_state 每艘拥有舰 → 海战 ShipState（海战 ShipDefinition 数值 + economy 装备）。
    // 出战序列：活动预设（store.ActiveName 命中且通过拥有数量校验）→ 按预设列出场并套用预设装备（缺省回落该经济舰装备）；
    // 默认 = 全部拥有舰按 economy 顺序。每舰型出战数量 ≤ 拥有数量（预设超限回落默认）。
    // CHG-20260818：初始阵型——活动预设带阵型（Formation）时，玩家舰按阵型位置/朝向摆位（非法格回落 FindSpot 自动摆位朝东）；
    // 无阵型/回落时沿玩家区自动摆位（朝东）。
    private void BuildPlayerFleetFromEconomy()
    {
        var fleet = ReadEconomyFleet();
        if (fleet.Count == 0)
        {
            GD.PushWarning("economy_state 无可用玩家舰队，海战自由模式玩家舰队为空");
            return;
        }
        var ownedByType = fleet.GroupBy(s => s.TypeId).ToDictionary(g => g.Key, g => g.Count(), StringComparer.Ordinal);
        var activePreset = ActivePresetForLineup(fleet);
        var placed = new List<(GridPos Bow, int Length, CardinalDirection Facing)>();
        var index = 0;
        foreach (var (economyShip, preset) in SelectBattleLineup(fleet, ownedByType))
        {
            var navalType = EconomyFleetMapper.NavalTypeFor(economyShip.TypeId);
            var def = _config!.Ships.FirstOrDefault(s => s.Id == navalType);
            if (def is null) { GD.PushWarning($"ships.json 缺少映射舰型 {navalType}（economy {economyShip.TypeId}）"); continue; }
            var facing = CardinalDirection.East;
            var spot = FindSpot(placed, def, PlayerPlacementZone());
            if (activePreset is not null
                && TryApplyFormation(activePreset, index, def, placed, out var formationBow, out var formationFacing))
            {
                spot = formationBow;
                facing = formationFacing;
            }
            if (spot is null) { GD.PushWarning($"玩家布阵区已满，跳过 {def.DisplayName}"); continue; }
            placed.Add((spot.Value, def.Length, facing));
            var ns = new ShipState
            {
                Id = ShipIdFor(FactionId.Player, index++),
                Definition = def,
                Faction = FactionId.Player,
                Bow = spot.Value,
                Facing = facing,
                HitPoints = def.MaxHp,
                ArmorLevel = preset?.Equipment?.ArmorLevel ?? economyShip.ArmorLevel,
            };
            // 装备搬运：预设舰带装备 → 用预设装备；否则用该经济舰自身装备（ID 两套一致，数量原样）。
            foreach (var (wid, count) in preset?.Equipment?.Weapons ?? economyShip.Weapons)
                ns.WeaponCounts[wid] = ns.WeaponCounts.GetValueOrDefault(wid) + count;
            foreach (var (sid, count) in preset?.Equipment?.Skills ?? economyShip.Skills)
                ns.SkillLoadout[sid] = ns.SkillLoadout.GetValueOrDefault(sid) + count;
            _battle.Ships[ns.Id] = ns;
        }
    }

    // 恢复玩家侧默认阵型：活动预设带阵型 → 按阵型重放（槽位 = 布阵序号 p1→0）；无阵型 → 自动摆位（沿玩家区确定性扫描，朝东）；
    // 自沉舰固守浅滩不移动。预设阵型仅在此显式重置时重放，玩家布阵界面手动移动不受影响。
    private void RestorePlayerEconomyLineup()
    {
        var activePreset = ActivePresetForCurrentFleet();
        var placed = new List<(GridPos Bow, int Length, CardinalDirection Facing)>();
        foreach (var ship in _battle.Ships.Values
            .Where(s => s.Faction == FactionId.Player && s.HitPoints > 0)
            .OrderBy(s => s.Id, StringComparer.Ordinal))
        {
            if (ship.SelfSunk) continue;
            var facing = CardinalDirection.East;
            var spot = FindSpot(placed, ship.Definition, PlayerPlacementZone());
            var slot = SlotOfShip(ship.Id);
            if (activePreset is not null
                && TryApplyFormation(activePreset, slot, ship.Definition, placed, out var formationBow, out var formationFacing))
            {
                spot = formationBow;
                facing = formationFacing;
            }
            if (spot is null) continue;
            placed.Add((spot.Value, ship.Length, facing));
            ship.Bow = spot.Value;
            ship.Facing = facing;
        }
    }

    // 玩家布阵/自动摆位区域：遭遇（讨伐/海盗）模式 = 遭遇规格玩家区（通常狭小靠左）；自由模式 = 预设玩家区。
    // BuildPlayerFleetFromEconomy/RestorePlayerEconomyLineup 沿该区自动摆位，须与 ConfirmDeployment 的
    // ValidatePlacement 校验口径一致（否则经济舰队自动摆位会落在遭遇区外，开战校验报 deploy.outside_zone）。
    private Rect2I PlayerPlacementZone()
        => _encounter is not null ? ToRect(_encounter.PlayerZone) : PlayerZone;

    // 当前海战玩家舰队对应的活动预设（仅自由模式生效；关卡/遭遇模式返回 null）。用于布阵重置时重放阵型。
    private FleetPreset? ActivePresetForCurrentFleet()
    {
        if (_level is not null || _encounter is not null) return null;
        var active = FleetStore().ActiveName;
        if (string.IsNullOrWhiteSpace(active)) return null;
        var preset = FleetStore().Get(active);
        if (preset is null) return null;
        // 阵型槽位映射到当前玩家舰队 p1.. 顺序；若当前舰队规模超过预设出战数，超出的舰无阵型回落自动摆位。
        return preset;
    }

    // 活动预设（校验通过才有意义）：与 SelectBattleLineup 同口径（舰型可映射 + 每舰型数量 ≤ 拥有数）。
    private FleetPreset? ActivePresetForLineup(IReadOnlyList<EconomyShip> fleet)
    {
        var active = FleetStore().ActiveName;
        if (string.IsNullOrWhiteSpace(active)) return null;
        var preset = FleetStore().Get(active);
        if (preset is null) return null;
        var ownedByType = fleet.GroupBy(s => s.TypeId).ToDictionary(g => g.Key, g => g.Count(), StringComparer.Ordinal);
        if (EconomyFleetValidator.Validate(preset, ownedByType).Count > 0) return null;
        return preset;
    }

    // 布阵序号 → 阵型槽位（p1 → 0）。非 p 前缀返回 int.MaxValue（无阵型命中 → 回落自动摆位）。
    private static int SlotOfShip(string shipId)
        => shipId.Length >= 2 && shipId[0] == 'p' && int.TryParse(shipId.AsSpan(1), out var n) && n >= 1 ? n - 1 : int.MaxValue;

    // 尝试应用预设阵型到指定槽位：阵型存在 + 朝向合法 + 阵型格在玩家布阵区内/地形可通行/不重叠 → true。
    // false = 无阵型或非法，调用方回落 FindSpot 自动摆位。
    private bool TryApplyFormation(
        FleetPreset preset, int slot, ShipDefinition def,
        IReadOnlyList<(GridPos Bow, int Length, CardinalDirection Facing)> placed,
        out GridPos bow, out CardinalDirection facing)
    {
        bow = default;
        facing = CardinalDirection.East;
        var formation = preset.FormationFor(slot);
        if (formation is null) return false;
        if (!TryParseFacing(formation.Facing, out facing)) return false;
        bow = new GridPos(formation.X, formation.Y);
        return FormationBowValid(bow, facing, def, placed, PlayerPlacementZone());
    }

    // 阵型船头合法性（口径与 FindSpot/ValidatePlacement 一致：区内 + 地形可通行 + 非残骸 + 与已放舰不重叠）。
    private bool FormationBowValid(
        GridPos bow, CardinalDirection facing, ShipDefinition def,
        IReadOnlyList<(GridPos Bow, int Length, CardinalDirection Facing)> placed, Rect2I zone)
    {
        var cells = FootprintCells(bow, facing, def.Length);
        foreach (var c in cells)
        {
            if (!ZoneContains(zone, c)) return false;
            if (TerrainRules.BlocksShip(_battle.Map.TerrainAt(c), def.Passability)) return false;
            if (_battle.Map.IsWreck(c)) return false;
        }
        foreach (var (pBow, pLen, pFacing) in placed)
            if (cells.Any(FootprintCells(pBow, pFacing, pLen).Contains)) return false;
        return true;
    }

    // 出战序列（默认 = 全部拥有舰按 economy 顺序）：活动预设存在且通过拥有数量校验 → 按预设列出场
    // （每舰型从前 N 艘拥有舰按 economy 顺序取，超出拥有数部分跳过）；否则回落全部拥有舰。
    private IReadOnlyList<(EconomyShip Ship, FleetPresetShip? Preset)> SelectBattleLineup(
        IReadOnlyList<EconomyShip> fleet, IReadOnlyDictionary<string, int> ownedByType)
    {
        IReadOnlyList<(EconomyShip, FleetPresetShip?)> All()
            => fleet.Select(s => (s, (FleetPresetShip?)null)).ToList();
        var active = FleetStore().ActiveName;
        if (string.IsNullOrWhiteSpace(active)) return All();
        var preset = FleetStore().Get(active);
        if (preset is null || EconomyFleetValidator.Validate(preset, ownedByType).Count > 0) return All();
        var lineup = new List<(EconomyShip Ship, FleetPresetShip? Preset)>();
        var cursor = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var ps in preset.Ships)
        {
            var type = ps.ShipTypeId ?? "";
            var i = cursor.GetValueOrDefault(type);
            cursor[type] = i + 1;
            var source = fleet.Where(s => s.TypeId == type).Skip(i).FirstOrDefault();
            if (source is not null) lineup.Add((source, ps));
        }
        return lineup;
    }

    // 读取整合版经济舰队（economy_state 归一化后的 ships）：取不到 GameState / 非字典 → 空列表。
    private List<EconomyShip> ReadEconomyFleet()
    {
        var result = new List<EconomyShip>();
        var root = GetTree().Root;
        if (root.GetNodeOrNull<Node>("GameState") is not { } gameState) return result;
        var state = gameState.Call("get_economy_state");
        if (state.VariantType != Variant.Type.Dictionary) return result;
        var economy = state.AsGodotDictionary();
        if (!economy.ContainsKey("ships")) return result;
        var shipsVar = economy["ships"];
        if (shipsVar.VariantType != Variant.Type.Array) return result;
        foreach (var shipVar in shipsVar.AsGodotArray())
        {
            if (shipVar.VariantType != Variant.Type.Dictionary) continue;
            var ship = shipVar.AsGodotDictionary();
            var typeId = ship.ContainsKey("type_id") ? ship["type_id"].AsString() : "";
            if (!EconomyFleetMapper.KnowsEconomyType(typeId)) continue;
            if (!ship.ContainsKey("id")) continue;
            var equipment = ship.ContainsKey("equipment") && ship["equipment"].VariantType == Variant.Type.Dictionary
                ? ship["equipment"].AsGodotDictionary()
                : new Godot.Collections.Dictionary();
            result.Add(new EconomyShip(
                typeId,
                ReadCountDict(equipment.ContainsKey("weapons") && equipment["weapons"].VariantType == Variant.Type.Dictionary ? equipment["weapons"].AsGodotDictionary() : null),
                ReadCountDict(equipment.ContainsKey("skills") && equipment["skills"].VariantType == Variant.Type.Dictionary ? equipment["skills"].AsGodotDictionary() : null),
                equipment.ContainsKey("armor_level") ? (int)equipment["armor_level"].AsInt64() : 0));
        }
        return result;
    }

    // 装备计数字典（weapons/skills）→ id→数量（忽略无效条目）。
    private static Dictionary<string, int> ReadCountDict(Godot.Collections.Dictionary? dict)
    {
        var result = new Dictionary<string, int>(StringComparer.Ordinal);
        if (dict is null) return result;
        foreach (var key in dict.Keys)
        {
            if (key.VariantType != Variant.Type.String) continue;
            var count = dict[key].AsInt64();
            if (count > 0) result[key.AsString()] = (int)count;
        }
        return result;
    }

    // 经济舰队轻量记录（解析 economy_state ships 后的只读快照）。
    private sealed record EconomyShip(string TypeId, Dictionary<string, int> Weapons, Dictionary<string, int> Skills, int ArmorLevel);

    // 玩家区自动摆位：从区右上往左下扫描合法船头（区内/地形可通行/非残骸/与已放舰不重叠）。朝向固定 East。
    // 校验口径与 ValidatePlacement 一致（不检查敌舰相邻，add 阶段敌舰尚未放置完成）。
    private GridPos? FindSpot(IEnumerable<(GridPos Bow, int Length, CardinalDirection Facing)> placed, ShipDefinition def, Rect2I zone)
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
                foreach (var (pBow, pLen, pFacing) in placed)
                {
                    var pCells = FootprintCells(pBow, pFacing, pLen);
                    if (cells.Any(pCells.Contains)) { ok = false; break; }
                }
                if (!ok) continue;
                return bow;
            }
        }
        return null;
    }


    // ---- CHG-20260818：玩家舰队只读状态（headless 冒烟断言经济舰队映射闭环） ----

    public string PlayerShipType(string shipId) => _battle.ShipOrNull(shipId)?.Definition.Id ?? "";

    // CHG-20260819（F-3）：自由模式玩家布阵区（测试钩子）——供 GDScript 冒烟断言与 ship_screen FORMATION_ZONE 同源。
    public Rect2I PlayerZoneForTest() => PlayerPlacementZone();
    public int PlayerFleetCount() => _battle?.Ships.Values.Count(s => s.Faction == FactionId.Player && s.HitPoints > 0) ?? 0;
    public int StorePresetCount() => FleetStore().Count;
    public bool StoreHasPreset(string name) => FleetStore().Has(name);
    public string StorePresetNames() => string.Join(",", FleetStore().All.OrderBy(p => p.Name, StringComparer.Ordinal).Select(p => p.Name));

    // CHG-20260818 测试钩子：改用固定临时路径的预设库（冒烟跨场景共用同一文件，不污染 user:// 真实预设）。
    // UseFleetPresetsForTest = 指向临时库并载入（保留既有预设，跨场景持久）；ResetFleetPresetsForTest = 再清空全部（冒烟开头用）。
    public void UseFleetPresetsForTest()
    {
        UseFleetPresetsPathForTest(System.IO.Path.Combine(System.IO.Path.GetTempPath(), "naval_fleet_presets_smoke.json"));
    }

    // CHG-20260818：把预设库指向任意路径并载入（映射/往返测试先写 JSON 再让布阵读取，验证共享 schema 跨语言闭环）。
    public void UseFleetPresetsPathForTest(string path)
    {
        _fleetStore = new FleetPresetStore(path);
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
