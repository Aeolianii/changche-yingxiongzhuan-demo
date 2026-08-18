#nullable enable
using Godot;
using NavalCombat.Core;
using NavalCombat.Integration;
using NavalCombat.Levels; // U-2c：RandomEncounterSession/Generator
using System;
using System.Collections.Generic;
using System.Linq;

namespace NanjiangNaval;

// 战斗控制器：由布阵阶段 ConfirmDeployment 传入同一 BattleState 经 StartBattle 初始化（T8），
// 绑定 GridView/Ships/Hud，分派全部交互命令。
// 交互闭环（UX-3 起交互模式互斥）：点舰船 → Move 模式只显示 QueryMoveRange 移动范围水墨高亮；
// 底部栏点武器/行为 → Attack 模式隐藏移动范围、只显示该行为射界/目标范围（攻击=QueryAttackArcs 射界弧，
// 撞击/接舷=目标舰高亮、连锁弹/火油/布雷=目标格覆盖）→ 点目标格执行 → 攻击禁移（HasAttacked）→ 回移动模式但范围为空、移动被锁。
// → 结束回合（敌方 AI 占位立即结束）→ 迷雾按 AttackRules.VisibleEnemies 每回合/行动刷新（T8）。
// T13：战术（撞击/接舷）与技能（连锁弹/火油/损管/布雷）按钮分派；可用性一律来自规则层只读查询/Validate。
public partial class NavalBattleController : Node, IGridClickReceiver
{
    // UX-3：交互模式互斥——Move 显示移动范围；Attack 显示武器射界/目标范围并隐藏移动范围；None 待选。
    private enum InteractionMode { None, Move, Attack }
    private InteractionMode _mode = InteractionMode.None;

    private BattleState _battle = null!;
    private string? _selectedShip;
    private NavalGridView _grid = null!;
    private NavalHud _hud = null!;
    private Node2D _shipsRoot = null!;
    // F-6：天气视觉覆盖层——WeatherFx(CanvasLayer，控制显隐) 与其内全屏 Fx(Control，实际绘制)。
    private CanvasLayer _weatherFxLayer = null!;
    private NavalWeatherOverlay _weatherOverlay = null!;
    private readonly Dictionary<string, NavalShipView> _shipViews = new();
    // T13 待定目标选择：_pendingTactic = "ram"/"board"（点敌舰执行）；_pendingSkill = "chain_shot"/"fire_oil"/"mine"（点格执行）。
    private string? _pendingTactic;
    private string? _pendingSkill;
    // UX-7：当前展开的攻击方式 "arrow_rain"/"bombardment"/"cannon"（点某攻击方式后，点其可攻击范围格发该具体命令）。
    private string? _pendingWeapon;
    // F-7c：交付舰选择面板中玩家勾选的舰 id（金币不足接受劝降时，确认后随 AcceptSurrenderCommand 交付）。
    private readonly HashSet<string> _deliveryShipIds = new();
    // T13 事件播放计数（headless 冒烟断言"事件订阅接线"）。
    private int _eventsPlayed;
    // T16：本场战斗结果（BattleEnded 后由网关 Finalize 产出，供结算面板/冒烟读取）。未结束为 null。
    private BattleResult? _result;
    // L-3：关卡游玩协调（NavalDemo 根节点 LevelPlay CanvasLayer）——目标/提示/结算；自由模式 null 惰性。
    private NavalLevelPlayController? _levelPlay;
    // U-2c：随机遭遇战（LevelSelect 生成后经 RandomEncounterSession.Begin 传入）。非 null = 遭遇模式。
    private RandomEncounter? _encounter;
    // CHG-20260817：海盗战返回海上大地图的目标场景（sea_overworld 常量同值）。
    private const string SeaOverworldScenePath = "res://scenes/sea_overworld/sea_overworld.tscn";
    // Task 18 B1：敌方回合 AI 驱动。默认开（ChooseNext→TryExecute→PlayEvents→至 EndFactionTurnCommand）；
    // 既有冒烟（水雷链/接舷/回合推进需敌方不动的场景）通过 SetEnemyAiEnabled(false) 关闭。
    private bool _enemyAiEnabled = true;
    private int _enemyCommandsRun;    // AI 驱动敌方回合实际执行成功的命令数（冒烟/调试用）
    private int _enemyTurnRejected;   // AI 命令被规则层拒绝次数（防御：校验不一致即停止，避免死循环）
    private const int MaxEnemyCommandSteps = 100; // AI 循环安全上限，防策略回环
    // UX-9：敌方回合逐动作可视化。动画开（真实窗口）时敌方回合逐命令异步播放（每命令 PlayEvents+移动/转向动画播完再下一步）；
    // headless 无渲染自动关闭动画 → 敌方回合走同步路径一次性完成（与改动前一致，既有冒烟时序不变）。
    private bool _animationsEnabled = true;      // 动画总开关（_Ready 检测 headless 自动关闭；SetAnimationsEnabled 可强制）
    private float _animMoveSecondsPerCell = 0.30f; // 每格平移动画时长（~0.3s/格，UX-9 默认）
    private float _animTurnSeconds = 0.30f;        // 转向动画时长
    private float _enemyStepPauseSeconds = 0.25f;  // 敌方回合步间节奏间隔（让玩家看清每步）
    private const float _animWaitBufferSeconds = 0.05f; // 敌方步动画等待缓冲（覆盖定时器/Tween 时序漂移，防等待短于动画）
    private bool _enemyTurnInProgress;             // 异步敌方回合进行中（EndTurn 防重入）
    private readonly List<int> _enemyStepEventCounts = new();  // 敌方每步事件数（headless 断言"每步确有事件"）
    private readonly List<bool> _enemyStepHadMovement = new(); // 敌方每步是否含移动/转向事件
    // UX-10：区域移动（BFS 路径逐格动画）进行中标志。异步动画期间防重入（再点区域/逐格/转向互踩）。
    private bool _areaMoveInProgress;

    public override void _Ready()
    {
        _grid = GetNode<NavalGridView>("../GridView");
        _shipsRoot = GetNode<Node2D>("../Ships");
        _hud = GetNode<NavalHud>("../Hud");
        // L-3：关卡游玩协调（BattleController 位于 NavalDemo/Battle/ 下，LevelPlay 是 NavalDemo 直接子节点 → 上两级）。
        _levelPlay = GetNodeOrNull<NavalLevelPlayController>("../../LevelPlay");
        // U-2c：随机遭遇战模式（LevelSelect 生成后 Begin；部署控制器同源读取）。
        _encounter = RandomEncounterSession.Active ? RandomEncounterSession.Pending : null;
        // F-6：天气覆盖层（WeatherFx(CanvasLayer) 控制显隐；Fx(Control) 按天气绘制）。
        _weatherFxLayer = GetNode<CanvasLayer>("../WeatherFx");
        _weatherOverlay = GetNode<NavalWeatherOverlay>("../WeatherFx/Fx");
        _grid.ClickReceiver = this;
        // UX-9：headless（无渲染）自动关闭动画 → 敌方回合走同步路径（一次性完成），既有冒烟时序不受影响。
        // 冒烟测试可用 SetAnimationsEnabled(true) 强制开启，验证异步播放路径。
        // 注：本机实测 OS.HasFeature("headless") 在 --headless 下为 false，DisplayServer.GetName()=="headless" 更可靠。
        if (DisplayServer.GetName() == "headless") _animationsEnabled = false;
        // 战斗由布阵阶段 StartBattle 初始化；此处不预建种子战斗（舰队自布阵结果装配）。
    }

    // UX-10：键盘逐格操控——方向键 ↑↓←→ 逐格移动、[ / ] 左右转向（仅当前回合、选中己方舰时生效，规则层拦非法）。
    // 经 _UnhandledInput（本 Godot 绑定 _UnhandledKeyInput 不可重写，GridView 同用 _UnhandledInput 已验证）；
    // HUD 按钮已设 FocusMode=None（NavalHud.ApplyInkWash）→ 方向键不被 GUI 焦点导航吞掉，可靠落到此。
    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is InputEventKey keyEvent) OnKeyEvent(keyEvent);
    }

    // 右键在 UI 或棋盘任意位置都可退选，因此使用 _Input（早于 GUI 消费）而非 _UnhandledInput。
    public override void _Input(InputEvent @event)
    {
        if (@event is not InputEventMouseButton { Pressed: true, ButtonIndex: MouseButton.Right }) return;
        if (OnRightClick()) GetViewport().SetInputAsHandled();
    }

    // 玩家主动退选：退出选择上下文，同时清空只服务于当前选船的第二行提示。
    private void DeselectForPlayer()
    {
        SetSelected(null);
        _hud.SetMessage("");
    }

    public bool OnRightClick()
    {
        if (_battle is null || PlayerInputLocked()) return false;
        if (_selectedShip is null && _pendingTactic is null && _pendingSkill is null && _pendingWeapon is null) return false;
        DeselectForPlayer();
        return true;
    }

    // UX-10：键盘入口（_UnhandledKeyInput 与 headless 测试共用——测试构造 InputEventKey 直接驱动，断言逐格移动/转向）。
    public void OnKeyEvent(InputEventKey keyEvent)
    {
        if (!keyEvent.Pressed || keyEvent.Echo) return;
        // 物理键码优先（方向键/括号在任意键盘布局下位置固定），回退逻辑键码。
        var code = keyEvent.PhysicalKeycode != 0 ? keyEvent.PhysicalKeycode : keyEvent.Keycode;
        switch ((Key)code)
        {
            case Key.Up: OnAction("move_up"); break;
            case Key.Down: OnAction("move_down"); break;
            case Key.Left: OnAction("move_left"); break;
            case Key.Right: OnAction("move_right"); break;
            case Key.Bracketleft: OnAction("turn_left"); break;
            case Key.Bracketright: OnAction("turn_right"); break;
        }
    }

    // 由布阵控制器传入同一 BattleState 开始战斗：附网格、生成舰船视图、初始揭示、显示 HUD。
    public void StartBattle(BattleState battle)
    {
        _battle = battle;
        _grid.Attach(_battle);
        _grid.ClearOverlay();
        var level = LevelRegistry.GetById(LevelSession.PendingLevelId);
        if (level is not null && level.Id != "free" && level.Objective.TargetCell is { } target)
            _grid.ShowPersistentHighlights(new[] { (target, $"{target.X},{target.Y}") });
        else
            _grid.ClearPersistentHighlights();
        SpawnShipViews();
        // V-3（CHG-20260810-fx-vision-recall）：战斗开始种子化视野滞留——初始阵型视野足迹置新鲜度 0。
        // 否则首回合开过的足迹在首次完整回合边界即瞬间归雾（AdvanceVisionRecall 只在玩家回合开始推进）。
        AttackRules.AdvanceVisionRecall(_battle);
        RefreshVisibility(); // 初始揭示：几何可见敌舰一次（T8）
        _hud.ShowTurnStatus(_battle.CurrentFaction, _battle.Round);
        RefreshStatusBars(); // UX-5：初始全局状态栏
        _hud.SetMessage("战斗开始 · 点击己方舰船开始 · 方向键逐格移动 · 右键退选 · WASD 移动镜头");
        _hud.SetTurnEnabled(false);
        // UX-8：战斗阶段恢复战斗 HUD（布阵阶段已隐藏；CanvasLayer 不随父节点显示，须显式恢复）
        _hud.Visible = true;
        // U-1：新战斗重置指令台收起/选择上下文（上一场可能处于收起状态）。
        _hud.ResetContext();
        if (GetParent() is Node2D parent2d) parent2d.Visible = true;
        // F-6：天气覆盖层随战斗开始显示，并把规则层天气/风向传给覆盖层（视觉与状态栏同源）。
        _weatherOverlay.SetWeather(_battle.Weather, _battle.Wind);
        _weatherFxLayer.Visible = true;
        _levelPlay?.BindBattle(battle); // L-3：关卡模式注入同一 BattleState（目标/进度条据此实时刷新）
    }

    private void SpawnShipViews()
    {
        foreach (var ship in _battle.Ships.Values)
        {
            var view = new NavalShipView { Name = ship.Id };
            view.Setup(ship, _grid);
            ApplyTurnReadiness(view, ship);
            _shipsRoot.AddChild(view);
            _shipViews[ship.Id] = view;
        }
    }

    // ---- 对外交互入口（冒烟测试与场景按钮调用） ----

    public void OnShipClicked(string shipId)
    {
        // FIX-1：敌方回合期间锁死玩家输入（点选/操作/键盘全拦）——敌方回合 CurrentFaction==Enemy，
        // 点选敌舰的阵营判定成立，不拦会让玩家手动操作敌方（规则层 OwnedShip 只查阵营==当前，会接受）。
        // V-1：战斗结束后同样锁死（不能再操控舰船）。
        if (PlayerInputLocked()) { _hud.SetMessage(InputLockMessage()); return; }
        var ship = _battle.ShipOrNull(shipId);
        if (ship is null || ship.HitPoints <= 0)
        {
            SetSelected(null);
            _hud.SetMessage("无法指挥该舰");
            return;
        }
        // T13 待定战术（撞击/接舷）目标点击：点敌舰执行，不进入友方选择。
        if (_pendingTactic is not null && ship.Faction != _battle.CurrentFaction)
        {
            TryTacticTarget(_pendingTactic, shipId);
            return;
        }
        if (ship.Faction != _battle.CurrentFaction
            && !AttackRules.VisibleEnemies(_battle, FactionId.Player).Contains(ship))
        {
            SetSelected(null);
            _hud.SetMessage("该敌舰尚未被发现");
            return;
        }
        ClearPendingTargeting();
        SetSelected(shipId);
        if (ship.Faction != _battle.CurrentFaction)
        {
            _mode = InteractionMode.None;
            _grid.ClearOverlay();
            _hud.HideActionPanel();
            _hud.SetMessage("查看敌方舰船状态");
            return;
        }
        // V-5：单结束令——不再有「本回合行动已结束」的舰（每单位结束已移除），任何我方舰都可下指令。
        _levelPlay?.OnPlayerSelected(); // L-3：战斗内选中舰船 → 推进「选中」教学提示（1-1 自动开战无布阵阶段，须在此触发）
        EnterMoveMode(); // UX-3：点单位默认只显示移动范围（水墨高亮），不显示射界红晕（两者互斥）
        _hud.ShowShipActions(ship, ComputeActionFlags(ship));
        _hud.SetActiveAction(CurrentActionId()); // UX-4：新选中默认移动模式 → 无武器高亮
        _hud.SetMessage(ship.HasAttacked
            ? "本回合已攻击 · 本回合不可再移动 · 右键退选"
            : $"剩余移动 {ship.RemainingMovement} · 点击底部栏武器查看射界，或点移动范围格行动 · 右键退选");
    }

    public void OnGridClicked(Vector2 worldPos)
    {
        // FIX-1：敌方回合期间锁死玩家输入（点格同样会被拦——含点敌舰格/移动范围格）。
        // V-1：战斗结束后同样锁死（不能再操控舰船）。
        if (PlayerInputLocked()) { _hud.SetMessage(InputLockMessage()); return; }
        var cell = _grid.WorldToGrid(worldPos);
        if (!_battle.Map.InBounds(cell)) return;
        // T13 待定技能（连锁弹/火油/布雷）目标格点击：优先于射界攻击。
        if (_pendingSkill is not null && _grid.CellOverlayContains(cell))
        {
            TrySkillCell(_pendingSkill, cell);
            return;
        }
        // 射界目标优先：仅 Attack 模式（底部栏选武器后）下点射界格（含敌舰占格）→ 远程攻击，先于舰船选中判定。
        // UX-3：Move 模式（点单位默认）不显示射界，故不触发远程攻击；看射界需先点武器按钮。
        // T13 修复（评审 Critical-1）：战术/技能待定时射界分支不得吞点击——撞击/接舷目标必在船头正前邻格或平行相邻，
        // 恒在箭雨弧（d²≤4 无武器要求）内，若先判射界会误发箭雨而永不执行战术；待定战术点目标舰走下方 OnShipClicked，
        // 待定技能点格走上方技能分支，射界只在无待定目标且 Attack 模式时生效。
        if (_pendingTactic is null && _pendingSkill is null && _mode == InteractionMode.Attack
            && _selectedShip is not null && _grid.AttackTargetOverlayContains(cell))
        {
            TryWeaponAttack(_pendingWeapon ?? "arrow_rain", cell); // UX-7：点哪个攻击方式发哪个命令
            return;
        }
        // F-2：逃跑格是舰体触碰判定，并不一定是多格舰的船头目标，故它通常不在普通船头移动覆盖中。
        // 鼠标点脚印格时，把它换算成“移动后任一舰体格触碰该出口”的最近可达船头，再复用区域移动路径。
        if (_selectedShip is not null && _mode == InteractionMode.Move && _battle.Map.ExitCells.Contains(cell))
        {
            TryMoveToExit(cell);
            return;
        }
        // 点舰船格 → 选中该舰
        var visibleEnemies = AttackRules.VisibleEnemies(_battle, FactionId.Player);
        foreach (var ship in _battle.Ships.Values)
        {
            if (ship.HitPoints <= 0) continue;
            if (ship.Faction == FactionId.Enemy && !visibleEnemies.Contains(ship)) continue;
            if (ship.OccupiedCells().Contains(cell))
            {
                OnShipClicked(ship.Id);
                return;
            }
        }
        // UX-10：点可达范围格 → 区域移动（BFS 最短路径，沿路径逐格平移动画走到目标，每步规则校验扣点）。
        // 取代 T8 的"贪心朝目标走 1 步"（分段可连点）：一次点击走完整个路径，绕路可达格走通。
        if (_selectedShip is not null && _mode == InteractionMode.Move && _grid.RangeOverlayContains(cell))
        {
            var selected = _battle.ShipOrNull(_selectedShip);
            if (selected is null || selected.Faction != _battle.CurrentFaction) { SetSelected(null); return; }
            if (selected.Bow != cell) MoveAreaTo(cell);
            return;
        }
        // UX-3（需求 C）：点击空白（无舰/无覆盖）→ 恢复待选状态，清空移动范围与红晕/目标覆盖。
        if (_selectedShip is not null || _pendingTactic is not null || _pendingSkill is not null)
            DeselectForPlayer();
    }

    public void OnAction(string actionId)
    {
        // FIX-1：敌方回合期间锁死玩家操作（键盘移动经 OnKeyEvent → OnAction 同样被拦）。
        // V-1：战斗结束后同样锁死舰船操控（投降/歼灭终局后不能再操控）；「再来一局」（new_game）、
        // 随机遭遇「重掷换一场」（reroll_encounter）与海盗战「返回海上大地图」（return_to_sea）
        // 是战斗结束后合法的操作（结算面板出口），放行，其余一律拦截。
        if (PlayerInputLocked() && actionId != "new_game" && actionId != "reroll_encounter" && actionId != "return_to_sea")
        {
            _hud.SetMessage(InputLockMessage());
            return;
        }
        switch (actionId)
        {
            // F-7a：方向键按选中舰状态路由——接舷中 → 组合移动（防守方整体平移），否则逐格移动。
            case "move_up": TryMoveOrPairSelected(CardinalDirection.North); break;
            case "move_down": TryMoveOrPairSelected(CardinalDirection.South); break;
            case "move_left": TryMoveOrPairSelected(CardinalDirection.West); break;
            case "move_right": TryMoveOrPairSelected(CardinalDirection.East); break;
            case "turn_left": TryTurnSelected(TurnDirection.Left); break;
            case "turn_right": TryTurnSelected(TurnDirection.Right); break;
            // UX-7：普攻区攻击方式按钮 → 展开该方式可攻击范围（点哪个方式发哪个命令）。
            case "arrow_rain": BeginAttack("arrow_rain"); break;
            case "bombardment": BeginAttack("bombardment"); break;
            case "cannon": BeginAttack("cannon"); break;
            case "attack": BeginAttack("arrow_rain"); break; // 兼容旧冒烟："攻击"=箭雨（始终可用的普攻）
            case "ram": BeginTactic("ram"); break;
            case "board": BeginTactic("board"); break;
            case "board_exchange": DoExchange(); break;
            case "disengage": DoDisengage(); break;
            case "chain_shot": BeginSkill("chain_shot"); break;
            case "fire_oil": BeginSkill("fire_oil"); break;
            case "damage_control": DoDamageControl(); break;
            case "mine": BeginSkill("mine"); break;
            case "self_sink": DoSelfSink(); break; // F-7b：战斗内浅滩自沉（设计 15）
            case "end_turn": EndTurn(); break; // V-5：单结束令——整体结束回合是唯一结束方式
            case "deselect": DeselectForPlayer(); break;
            case "new_game": NewGame(); break;
            case "reroll_encounter": RerollEncounter(); break; // U-2c：随机遭遇重掷（换一场，保留难度）
            case "return_to_sea": ReturnToSea(); break; // CHG-20260817：海盗战结算返回海上大地图
            // F-3：投降交涉（设计 16.2/16.3）——接受/拒绝敌方劝降、我方发起劝降。不走舰船动作，直接调规则层命令。
            case "accept_surrender": DoAcceptSurrender(); break;
            case "reject_surrender": DoRejectSurrender(); break;
            case "offer_surrender": DoOfferSurrender(); break;
            // F-7c：交付舰选择面板（金币不足接受劝降）——确认交付 / 取消（恢复接受/拒绝按钮）。
            case "confirm_delivery": DoConfirmDelivery(); break;
            case "cancel_delivery": DoCancelDelivery(); break;
            default: _hud.SetMessage($"未知操作：{actionId}"); break;
        }
    }

    // ---- 只读状态访问（供 GDScript headless 交互测试断言闭环） ----

    public int CurrentFaction() => (int)_battle.CurrentFaction;
    public int Round() => _battle.Round;
    // F-1：天气/风向只读访问（headless 冒烟断言"战斗开始时随机掷定且符合规则"）。
    // Weather() = 0晴/1阴/2雨/3台风；WindIndex() = -1无风 或 0北/1东/2南/3西。
    public int Weather() => (int)_battle.Weather;
    public int WindIndex() => _battle.Wind is { } w ? (int)w : -1;
    // F-6：天气覆盖层状态只读访问（headless 冒烟断言"天气正确驱动覆盖层"）：
    // WeatherOverlayKind()=0晴/1阴/2雨/3台（与 Weather() 同值）；WeatherOverlayActive()=非晴时覆盖层激活。
    public int WeatherOverlayKind() => _weatherOverlay.Kind();
    public bool WeatherOverlayActive() => _weatherOverlay.Active();
    public bool CellIsVisible(int x, int y) => _grid.FogCellVisible(x, y);
    public int RemainingMovement(string shipId) => _battle.ShipOrNull(shipId)?.RemainingMovement ?? -1;
    public int ShipHitPoints(string shipId) => _battle.ShipOrNull(shipId)?.HitPoints ?? -1;
    public bool ShipHasAttacked(string shipId) => _battle.ShipOrNull(shipId)?.HasAttacked ?? false;
    public int MoveRangeCount(string shipId) => ActionResolver.QueryMoveRange(_battle, shipId).Count;
    // UX-3：覆盖层计数（headless 交互断言"移动/攻击范围分离"用）——当前画面实际渲染的高亮，
    // 与 MoveRangeCount（规则可达查询）区分：断言"点单位只显示移动范围""选武器只显示射界""攻击后两层消失"。
    public int MoveRangeOverlayCount() => _grid.MoveRangeOverlayCount();
    public bool MoveRangeAt(int x, int y) => _grid.RangeOverlayContains(new GridPos(x, y));
    public int AttackArcsOverlayCount() => _grid.AttackArcsOverlayCount();
    public int CellOverlayCount() => _grid.CellOverlayCount();
    public int HighlightShipCount() => _grid.HighlightShipCount();
    // UX-7：当前攻击范围覆盖是否含指定格（headless 断言火炮侧舷格等）。
    public bool AttackArcAt(int x, int y) => _grid.AttackTargetOverlayContains(new GridPos(x, y));
    public int ShipBowX(string shipId) => _battle.ShipOrNull(shipId)?.Bow.X ?? -1;
    public int ShipBowY(string shipId) => _battle.ShipOrNull(shipId)?.Bow.Y ?? -1;
    // 舰船朝向索引（0=N 1=E 2=S 3=W），供冒烟断言布阵位置/朝向正确传入战斗。
    public int ShipFacingIndex(string shipId) => (int)(_battle.ShipOrNull(shipId)?.Facing ?? CardinalDirection.North);
    // 迷雾断言：敌舰视图当前是否可见（初始揭示后应为 true）
    public bool ShipVisible(string shipId) => _shipViews.TryGetValue(shipId, out var view) && view.Visible;
    // 格世界坐标（测试用，避免在 GDScript 中重复 Origin/CellSize）
    public Vector2 CellToWorld(int x, int y) => _grid.GridToWorldCenter(new GridPos(x, y));
    public float CameraZoom() => _grid.CameraZoomValue();
    public float CameraX() => _grid.CameraPositionValue().X;
    public float CameraY() => _grid.CameraPositionValue().Y;
    public void PanCameraForDemo(float x, float y, float seconds) => _grid.PanCamera(new Vector2(x, y), seconds);
    public bool CameraViewInsideBackground() => _grid.CameraViewInsideBackground();
    // T13：事件播放计数（事件订阅接线断言）。
    public int EventsPlayedCount() => _eventsPlayed;
    // R-4：地形只读（0深水/1浅滩/2礁石/3山地；越界 -1），headless 断言"舰船不占山地/岛"。
    public int TerrainIndex(int x, int y)
    {
        var cell = new GridPos(x, y);
        if (_battle is null || !_battle.Map.InBounds(cell)) return -1;
        return (int)_battle.Map.TerrainAt(cell);
    }
    // R-4：舰船任意占格落在山地/岛屿 → true（headless 断言"敌方/AI 不能上岛"）。
    public bool ShipOccupiesMountain(string shipId)
    {
        if (_battle?.ShipOrNull(shipId) is not { } ship) return false;
        return ship.OccupiedCells().Any(c => _battle.Map.InBounds(c) && _battle.Map.TerrainAt(c) == TerrainType.Mountain);
    }
    // T13：当前地图存活水雷数（含未揭示；三雷连锁断言雷被清空）。
    public int MineCount() => _battle.Map.Mines.Count;
    // F-2：出口格只读（headless 冒烟断言"地图有出口边界"）。
    public int ExitCellCount() => _battle.Map.ExitCells.Count;
    public bool IsExitCell(int x, int y) => _battle.Map.ExitCells.Contains(new GridPos(x, y));
    // T13：接舷进度（无链接 -1）。
    public int BoardingProgress(string shipId) => _battle.ShipOrNull(shipId)?.Boarding?.CaptureProgress ?? -1;
    // T13：组合控制方 = 防守方（被接舷舰）id；无链接空串。
    public string BoardingController(string shipId) => _battle.ShipOrNull(shipId)?.Boarding?.DefenderId ?? "";
    // T13：技能剩余次数（未播种/未知 -1）。
    public int ShipSkillUses(string shipId, string skillId) => _battle.ShipOrNull(shipId)?.SkillUsesLeft.GetValueOrDefault(skillId, -1) ?? -1;
    // T13/UX-7：行动可用性全部来自规则层查询（冒烟断言按钮可用性来源）。
    public bool ActionAvailable(string actionId)
    {
        var ship = SelectedOwnedShip();
        if (ship is null) return false;
        var f = ComputeActionFlags(ship);
        return actionId switch
        {
            "arrow_rain" => f.CanArrowRain,
            "bombardment" => f.CanBombardment,
            "cannon" => f.CanCannon,
            "attack" => f.CanArrowRain, // 兼容旧冒烟："攻击"=箭雨
            "ram" => f.CanRam,
            "board" => f.CanBoard,
            "board_exchange" => f.CanExchange,
            "disengage" => f.CanDisengage,
            "chain_shot" => f.CanChainShot,
            "fire_oil" => f.CanFireOil,
            "damage_control" => f.CanDamageControl,
            "mine" => f.CanMine,
            "pair_move" => f.CanPairMove, // F-7a：接舷组合移动（防守方）
            "self_sink" => f.CanSelfSink, // F-7b：战斗内浅滩自沉
            _ => false,
        };
    }
    // T13：HUD 当前消息（事件/反馈提示断言）。
    public string LastMessage() => _hud.MessageText();
    // UX-4：底部行动面板当前是否显示（headless 断言 一弹出/一隐去）。
    public bool ActionPanelVisible() => _hud.ActionPanelVisible();
    public bool ShipStatusPanelVisible() => _hud.ShipStatusPanelVisible();
    public string SelectedShip() => _selectedShip ?? "";
    public bool ShipWaitingHighlighted(string shipId)
        => _shipViews.TryGetValue(shipId, out var view) && view.WaitingForOrders();
    public bool ShipActedDimmed(string shipId)
        => _shipViews.TryGetValue(shipId, out var view) && view.ActedThisTurn();
    // U-1：指令台收起/展开（headless 断言：收起来看清战场/射界，不挡地图点击；展开恢复）。
    public string ShipStatusPanelText() => _hud.ShipStatusPanelText();
    public string CommandCategory() => _hud.CommandCategory();
    public int AttackPageCount() => _hud.AttackPageCount();
    public int AttackPageIndex() => _hud.AttackPageIndex();
    public int VisibleAttackCommandCount() => _hud.VisibleAttackCommandCount();
    // R-3：令牌分组只读访问（headless 冒烟断言武器/技能组结构、分组标签、可用性/次数映射、动作 id 覆盖）。
    public int WeaponGroupTokenCount() => _hud.WeaponGroupTokenCount();
    public int SkillGroupTokenCount() => _hud.SkillGroupTokenCount();
    public int AttackGroupCount() => _hud.AttackGroupCount();
    public string AttackGroupHeader(int index) => _hud.AttackGroupHeader(index);
    public string CurrentAttackGroupLabel() => _hud.CurrentAttackGroupLabel();
    public string[] AllAttackTokenActionIds() => _hud.AllAttackTokenActionIds();
    public bool AttackTokenVisible(string actionId) => _hud.AttackTokenVisible(actionId);
    public bool AttackTokenDisabled(string actionId) => _hud.AttackTokenDisabled(actionId);
    public string AttackTokenText(string actionId) => _hud.AttackTokenText(actionId);
    // UX-4：当前激活武器/行为 id（"attack"/"ram"/"board"/"chain_shot"/"fire_oil"/"mine"），无激活空串（headless 断言切换高亮）。
    public string ActiveAction() => CurrentActionId() ?? "";
    // T16：战斗是否已结束（结果面板已弹出）。冒烟闭环断言。
    public bool BattleEnded() => _battle is not null && _battle.BattleEnded;
    // T16：结果已产出（Finalize 完成）。未结束 -1。
    public int ResultOutcome() => _result is null ? -1 : (int)_result.Outcome;
    public bool ResultVisible() => _result is not null;
    // U-2c：结算面板全文（HUD ResultLabel 文本，含随机遭遇奖励行）。
    public string ResultText() => _hud.ResultText();
    // U-2c：随机遭遇「重掷换一场」按钮是否可见（非遭遇模式隐藏）。
    public bool RerollVisible() => _hud.RerollButtonVisible();
    // F-2：战后结果中某舰的结局分类（ShipLossKind 索引：0存活/1沉没/2逃脱/3被俘/4投降移交/5自沉永久；未知/未结算 -1）。
    public int ResultShipKind(string shipId)
    {
        if (_result is null) return -1;
        var rec = _result.Ships.FirstOrDefault(r => r.ShipId == shipId);
        return rec is null ? -1 : (int)rec.Kind;
    }
    // UX-5：左侧顶栏上下文状态文本（headless 断言 未选中=全局 / 选中=单位详情 / 退选恢复全局）。
    public string StatusLeftText() => _hud.TopLeftBarText();
    // F-3：投降状态只读（headless 冒烟断言闭环）。待决阵营索引（无待决 -1；Player=0 / Enemy=1）。
    public int PendingSurrenderFromIndex() => _battle?.PendingSurrenderFrom is { } f ? (int)f : -1;
    public int PlayerGold() => _battle?.PlayerGold ?? -1;
    public int ShipFactionIndex(string shipId) => (int)(_battle.ShipOrNull(shipId)?.Faction ?? FactionId.Player);
    // 投降交涉面板按钮状态（headless 断言：待决弹出接受/拒绝、优势可用劝降、每回合一次门禁禁用）。
    public bool SurrenderPanelVisible() => _hud.SurrenderPanelVisible();
    public bool OfferSurrenderButtonEnabled() => _hud.OfferSurrenderButtonEnabled();
    public bool AcceptSurrenderButtonVisible() => _hud.AcceptSurrenderButtonVisible();
    public bool RejectSurrenderButtonVisible() => _hud.RejectSurrenderButtonVisible();
    // F-3：船视图当前阵营底色（headless 断言"投降加入后视图重设阵营色"；未知空串）。
    public string ShipHullColor(string shipId) => _shipViews.TryGetValue(shipId, out var v) ? v.HullColorHex() : "";
    // F-7a：接舷组合剩余平移预算（预算 - 已用；无接舷链接 -1）。headless 断言"组合最多移 2 格"。
    public int PairMoveBudgetRemaining(string shipId)
    {
        var link = _battle?.ShipOrNull(shipId)?.Boarding;
        return link is null ? -1 : Math.Max(0, BoardingRules.PairMoveBudget - link.PairMovesUsed);
    }
    // F-7b/V-6：战斗内浅滩自沉按钮是否显示（选中我方舰时始终显示）+ 置灰/原因（不满足资格置灰）。
    public bool SelfSinkButtonVisible() => _hud.SelfSinkButtonVisible();
    public bool SelfSinkButtonDisabled() => _hud.SelfSinkButtonDisabled();
    public string SelfSinkButtonTooltip() => _hud.SelfSinkButtonTooltip();
    // F-7b：舰是否已自沉（headless 断言"战斗自沉置 SelfSunk=true"）。
    public bool ShipSelfSunk(string shipId) => _battle?.ShipOrNull(shipId)?.SelfSunk ?? false;
    // F-7c：交付选舰面板状态（headless 断言"金币不足接受劝降弹出/列出的符合舰数量/需交付数/确认后关闭"）。
    public bool DeliveryPanelVisible() => _hud.DeliveryPanelVisible();
    public int DeliveryRowCount() => _hud.DeliveryRowCount();
    public int DeliveryRequired() => _hud.DeliveryRequired();

    // ---- 命令分派（规则合法性一律交由 ActionResolver.TryExecute 验证） ----

    // F-7a：方向键统一入口——选中舰处于接舷时走组合移动（防守方控制整体平移），否则逐格移动。
    // 键盘方向键（UX-10 OnKeyEvent → OnAction）自动同路由，方向簇按钮语义随选中切换。
    private void TryMoveOrPairSelected(CardinalDirection dir)
    {
        var ship = SelectedOwnedShip();
        if (ship is null) return;
        if (ship.Boarding is not null) { TryPairMoveSelected(ship, dir); return; }
        TryMoveSelected(dir);
    }

    // F-7a：接舷组合移动（设计 11.1）——发 BoardPairMoveCommand（ShipId=防守方，整体平移、不转向）。
    // 预算（2 格/防守方回合）与"仅防守方控制"由规则层 ValidatePairMove 校验；成功刷新组合剩余格数显示。
    private void TryPairMoveSelected(ShipState ship, CardinalDirection dir)
    {
        if (_areaMoveInProgress) return; // UX-10：区域移动动画中禁逐格（组合移动同理防互踩）
        ClearPendingTargeting();
        var pairCommand = new BoardPairMoveCommand(ship.Id, dir);
        var result = ActionResolver.TryExecute(_battle, pairCommand);
        if (!result.Success)
        {
            _hud.SetMessage(DescribeFailure(result.Reason, ship));
            RefreshShipPanel(ship);
            return;
        }
        PlayEvents(result.Events, ship.Id, pairCommand);
        RefreshAllViews();
        _grid.ClearOverlay();
        EnterMoveMode(); // 组合平移后仍为 Move 模式（规则 QueryMoveRange 对接舷舰返回空，无独立移动范围）
        RefreshShipPanel(ship);
        _hud.SetMessage($"{ship.Definition.DisplayName} 组合移动 1 格 · 剩余组合移动 {PairMoveBudgetRemaining(ship.Id)} 格");
    }

    private void TryMoveSelected(CardinalDirection dir)
    {
        if (_areaMoveInProgress) return; // UX-10：区域移动动画中禁逐格（防与异步路径互踩）
        var ship = SelectedOwnedShip();
        if (ship is null) return;
        ClearPendingTargeting();
        var moveCommand = new MoveCommand(ship.Id, dir);
        var result = ActionResolver.TryExecute(_battle, moveCommand);
        if (!result.Success)
        {
            _hud.SetMessage(DescribeFailure(result.Reason, ship));
            RefreshShipPanel(ship);
            return;
        }
        // F-2：统一播放命令事件（含 SettleAfterCommand 附加的逃跑/终局事件）。此前单步移动/转向漏播——
        // 触出口逃跑时 ShipEscapedEvent / BattleEndedEvent 不会驱动视图隐藏与结算（HandleBattleEnded），逃跑终局会卡死。
        PlayEvents(result.Events, ship.Id, moveCommand);
        if (!_battle.Ships.ContainsKey(ship.Id))
        {
            // 逃脱：整舰已移出战场（事件已隐藏视图+播「逃离」提示）；清选中/覆盖，不再走普通移动刷新。
            SetSelected(null);
            return;
        }
        AnimateShipView(ship.Id); // UX-9：我方移动动画（headless 立即落位）
        RefreshVisibility(); // 己方移动后敌舰可见性重估（几何）
        EnterMoveMode(); // UX-3：移动后仍为移动模式，范围随剩余移动缩小；射界红晕不随移动常显
        RefreshShipPanel(ship);
        _hud.SetMessage($"{ship.Definition.DisplayName} 移动 1 格 · 剩余移动 {ship.RemainingMovement}");
    }

    private void TryTurnSelected(TurnDirection turn)
    {
        if (_areaMoveInProgress) return; // UX-10：区域移动动画中禁转向（防与异步路径互踩）
        var ship = SelectedOwnedShip();
        if (ship is null) return;
        ClearPendingTargeting();
        var turnCommand = new TurnCommand(ship.Id, turn);
        var result = ActionResolver.TryExecute(_battle, turnCommand);
        if (!result.Success)
        {
            _hud.SetMessage(DescribeFailure(result.Reason, ship));
            RefreshShipPanel(ship);
            return;
        }
        // F-2：统一播放命令事件（同 TryMoveSelected——转向可让船体格摆上出口列触发逃跑/终局）。
        PlayEvents(result.Events, ship.Id, turnCommand);
        if (!_battle.Ships.ContainsKey(ship.Id))
        {
            // 逃脱：整舰已移出战场；清选中/覆盖，不再走普通转向刷新。
            SetSelected(null);
            return;
        }
        AnimateShipView(ship.Id); // UX-9：我方转向动画（headless 立即落位）
        RefreshVisibility();
        EnterMoveMode(); // UX-3：转向后回到移动模式，范围随剩余移动缩小；射界红晕不常显
        RefreshShipPanel(ship);
        _hud.SetMessage($"{ship.Definition.DisplayName} 转向 · 剩余移动 {ship.RemainingMovement}");
    }

    // UX-10：区域移动——点击移动范围格 → BFS 最短路径 → 沿路径逐格平移动画走到目标。
    // 每步走规则层 MoveCommand（校验、按实际步数扣点）；某步被拒（地形/舰/残骸/移动点不足）→ 停在最后合法格并提示。
    // 设计 5.1：平移不自动改朝向（路径只平移不做转向）。headless 动画关闭 → 同步一次性走到（既有冒烟时序不变）。
    private async void MoveAreaTo(GridPos target)
    {
        if (_areaMoveInProgress) return; // 防并发区域移动
        var ship = SelectedOwnedShip();
        if (ship is null || ship.Bow == target) return;
        _areaMoveInProgress = true;
        try
        {
            var path = ActionResolver.QueryMovePath(_battle, ship, target);
            var steps = path.Count > 0 ? path.Count - 1 : 0; // 段数 = 格序列长度-1
            if (steps <= 0)
            {
                _hud.SetMessage($"{ship.Definition.DisplayName} 该格不可达（路径被阻挡）");
                return;
            }
            steps = Math.Min(steps, ship.RemainingMovement); // 移动点上限：最多走到剩余移动点格（规则层每步扣 1）
            var walked = 0;
            var escaped = false; // F-2：某步触出口逃跑 → 停止路径剩余步，不覆写「逃离」消息
            for (var i = 0; i < steps; i++)
            {
                var dir = DirectionBetween(path[i], path[i + 1]);
                if (dir is null) break; // 防御：路径应逐格相邻（不应发生）
                ship = SelectedOwnedShip();
                if (ship is null || ship.HasAttacked) break;
                var stepCommand = new MoveCommand(ship.Id, dir.Value);
                var result = ActionResolver.TryExecute(_battle, stepCommand);
                if (!result.Success)
                {
                    _hud.SetMessage(DescribeFailure(result.Reason, ship)); // 规则拒绝该步 → 停在最后合法格
                    RefreshShipPanel(ship);
                    break;
                }
                walked++;
                PlayEvents(result.Events, ship.Id, stepCommand);
                if (!_battle.Ships.ContainsKey(ship.Id))
                {
                    // F-2：触出口逃跑（整舰已移出，事件已隐藏视图+播「逃离」）；清选中并停止剩余路径。
                    SetSelected(null);
                    escaped = true;
                    break;
                }
                // 逐格平移动画（UX-9 AnimateToShip）；headless 动画关闭直接落位（同步）。
                if (_animationsEnabled)
                {
                    if (_shipViews.TryGetValue(ship.Id, out var view)
                        && view.AnimateToShip(_grid, _animMoveSecondsPerCell, _animTurnSeconds) is { } tween)
                        await ToSignal(tween, Tween.SignalName.Finished);
                }
                else
                {
                    SyncShipView(ship.Id);
                }
                RefreshVisibility();
                EnterMoveMode(); // 范围随剩余移动缩小；面板 ShipInfo 实时显示剩余移动点
                RefreshShipPanel(ship);
            }
            // 全路径走完才覆写汇总消息；被拒提前停时保留拒绝提示；逃跑后保留「逃离」提示。
            if (!escaped && walked == steps && ship is not null && ship.Faction == _battle.CurrentFaction)
                _hud.SetMessage($"{ship.Definition.DisplayName} 移动 {walked} 格 · 剩余移动 {ship.RemainingMovement}");
        }
        catch (Exception ex)
        {
            GD.PushError($"区域移动动画异常：{ex}"); // 防御：动画/等待异常不崩溃（节点释放等极端情况）
        }
        finally
        {
            _areaMoveInProgress = false;
        }
    }

    // UX-7：点普攻区某攻击方式按钮 → 展开该方式的"可攻击范围"（规则层 QueryWeaponArcs 单武器弧，实心=可命中/空心=盲射），
    // 隐藏移动范围（Attack 模式互斥）；无可用目标（含未装载武器）则提示原因、不进攻击模式。
    private void BeginAttack(string weapon)
    {
        var ship = SelectedOwnedShip();
        if (ship is null) return;
        if (ship.HasAttacked)
        {
            _hud.SetMessage($"{ship.Definition.DisplayName} 本回合已攻击");
            return;
        }
        var kind = weapon switch
        {
            "bombardment" => WeaponKind.Bombardment,
            "cannon" => WeaponKind.Cannon,
            _ => WeaponKind.ArrowRain,
        };
        var arcs = AttackRules.QueryWeaponArcs(_battle, ship, kind);
        if (arcs.Count == 0)
        {
            _hud.SetMessage(weapon switch
            {
                "bombardment" => $"{ship.Definition.DisplayName} 砲击无可用目标（需装载砲击，最近格距3-5）",
                "cannon" => $"{ship.Definition.DisplayName} 火炮无可用目标（需装载火炮、侧舷对齐，距4-6）",
                _ => $"{ship.Definition.DisplayName} 箭雨无可用目标（最近格距≤2）",
            });
            return;
        }
        EnterAttackMode(); // UX-3：选攻击方式隐藏移动范围，只显示该方式可攻击范围（互斥）
        _pendingWeapon = weapon;
        _grid.ShowAttackArcs(arcs);
        _hud.SetActiveAction(CurrentActionId()); // UX-4：该攻击方式按钮激活高亮
        _hud.SetMessage(weapon switch
        {
            "bombardment" => $"{ship.Definition.DisplayName} 已选砲击：点击砲击范围格（实心=可命中，空心=盲射）",
            "cannon" => $"{ship.Definition.DisplayName} 已选火炮：点击侧舷范围格（实心=可命中，空心=盲射）",
            _ => $"{ship.Definition.DisplayName} 已选箭雨：点击箭雨范围格（实心=可命中，空心=盲射）",
        });
    }

    // UX-7：点击当前展开攻击方式的可攻击范围格 → 发该具体命令（不再"箭雨→砲击→火炮顺序试"）。Level 取 1（演示等级）。
    private void TryWeaponAttack(string weapon, GridPos cell)
    {
        var ship = SelectedOwnedShip();
        if (ship is null) return;
        BattleCommand command = weapon switch
        {
            "bombardment" => new BombardmentCommand(ship.Id, cell, 1),
            "cannon" => new CannonCommand(ship.Id, cell, 1),
            _ => new ArrowRainCommand(ship.Id, cell),
        };
        var result = ActionResolver.TryExecute(_battle, command);
        if (!result.Success)
        {
            _hud.SetMessage(DescribeFailure(result.Reason, ship));
            RefreshShipPanel(ship);
            return;
        }
        PlayEvents(result.Events, ship.Id, command);
        SyncShipView(ship.Id);
        RefreshShipPanel(ship);
        RefreshVisibility();
        _grid.ClearOverlay();
        _pendingWeapon = null;
        _mode = InteractionMode.Move; // UX-3：攻击成功 → 清射界与移动范围，移动/转向被规则锁死（HasAttacked）
        _hud.SetMessage(weapon switch
        {
            "bombardment" => $"{ship.Definition.DisplayName} 砲击开火 · 本回合不可再移动",
            "cannon" => $"{ship.Definition.DisplayName} 火炮开火 · 本回合不可再移动",
            _ => $"{ship.Definition.DisplayName} 箭雨攻击 · 本回合不可再移动",
        });
    }

    // ---- T13 战术（撞击/接舷）----

    private void BeginTactic(string tactic)
    {
        var ship = SelectedOwnedShip();
        if (ship is null) return;
        List<string> targets = tactic == "ram"
            ? RamRules.QueryRamTargets(_battle, ship.Id)
            : BoardingRules.QueryBoardTargets(_battle, ship.Id);
        if (targets.Count == 0)
        {
            _hud.SetMessage(tactic == "ram"
                ? $"{ship.Definition.DisplayName} 当前无撞击目标（需船头朝敌且最后一步为接近移动）"
                : $"{ship.Definition.DisplayName} 当前无接舷目标（需平行且相邻）");
            return;
        }
        EnterAttackMode(); // UX-3：选战术（撞击/接舷）隐藏移动范围，只显示目标舰高亮（互斥）
        _pendingTactic = tactic;
        _grid.ShowShipTargets(targets);
        _hud.SetActiveAction(CurrentActionId()); // UX-4：撞击/接舷按钮激活高亮
        _hud.SetMessage(tactic == "ram"
            ? "已选撞击：点击高亮的敌舰执行"
            : "已选接舷：点击高亮的敌舰执行");
    }

    private void TryTacticTarget(string tactic, string targetId)
    {
        var ship = SelectedOwnedShip();
        if (ship is null) { ClearPendingTargeting(); return; }
        BattleCommand command = tactic == "ram"
            ? new RamCommand(ship.Id, targetId)
            : new BoardCommand(ship.Id, targetId);
        var result = ActionResolver.TryExecute(_battle, command);
        ClearPendingTargeting();
        if (!result.Success)
        {
            _hud.SetMessage(DescribeFailure(result.Reason, ship));
            RefreshShipPanel(ship);
            return;
        }
        PlayEvents(result.Events, ship.Id, command);
        RefreshAllViews();
        _grid.ClearOverlay();
        _mode = InteractionMode.Move; // UX-3：战术成功 → 清覆盖，移动被规则锁死（HasAttacked）
        RefreshShipPanel(ship);
        var target = _battle.ShipOrNull(targetId);
        var targetName = target?.Definition.DisplayName ?? targetId;
        _hud.SetMessage(tactic == "ram"
            ? $"{ship.Definition.DisplayName} 撞击 {targetName}"
            : $"{ship.Definition.DisplayName} 发起接舷 {targetName}");
    }

    private void DoExchange()
    {
        var ship = SelectedOwnedShip();
        if (ship is null) return;
        var exchangeCommand = new BoardingExchangeCommand(ship.Id);
        var result = ActionResolver.TryExecute(_battle, exchangeCommand);
        DispatchSimpleResult(result, ship, exchangeCommand, $"{ship.Definition.DisplayName} 接舷交换（可能触发俘获判定）");
    }

    private void DoDisengage()
    {
        var ship = SelectedOwnedShip();
        if (ship is null) return;
        var disengageCommand = new DisengageCommand(ship.Id);
        var result = ActionResolver.TryExecute(_battle, disengageCommand);
        DispatchSimpleResult(result, ship, disengageCommand, $"{ship.Definition.DisplayName} 尝试脱离接舷");
    }

    // ---- T13 技能（连锁弹/火油/损管/布雷）----

    private void BeginSkill(string skill)
    {
        var ship = SelectedOwnedShip();
        if (ship is null) return;
        switch (skill)
        {
            case "chain_shot":
            {
                var cells = StatusRules.QueryChainShotCells(_battle, ship);
                if (cells.Count == 0) { _hud.SetMessage($"{ship.Definition.DisplayName} 连锁弹不可用（次数耗尽或射程 3-5 内无目标格）"); return; }
                EnterAttackMode(); // UX-3：选技能隐藏移动范围，只显示目标格覆盖（互斥）
                ShowSkillOverlays(cells, skill);
                _hud.SetActiveAction(CurrentActionId()); // UX-4：连锁弹按钮激活高亮
                _hud.SetMessage("已选连锁弹：点击目标格（实心=有目标，空心=盲射落空仍耗动作）");
                break;
            }
            case "fire_oil":
            {
                var cells = StatusRules.QueryFireOilCells(_battle, ship);
                if (cells.Count == 0) { _hud.SetMessage($"{ship.Definition.DisplayName} 火油不可用（次数耗尽或射程 3-4 内无目标格）"); return; }
                EnterAttackMode(); // UX-3：选技能隐藏移动范围，只显示目标格覆盖（互斥）
                ShowSkillOverlays(cells, skill);
                _hud.SetActiveAction(CurrentActionId()); // UX-4：火油按钮激活高亮
                _hud.SetMessage("已选火油：点击目标格（实心=有目标，空心=盲射落空仍耗动作）");
                break;
            }
            case "mine":
            {
                if (ship.SkillUsesLeft.GetValueOrDefault("mine", 0) < 1) { _hud.SetMessage($"{ship.Definition.DisplayName} 水雷次数已用完"); return; }
                var cells = MineRules.QueryMineCells(_battle, ship);
                if (cells.Count == 0) { _hud.SetMessage($"{ship.Definition.DisplayName} 无可布雷格（需舰侧/尾相邻空格）"); return; }
                EnterAttackMode(); // UX-3：选布雷隐藏移动范围，只显示目标格覆盖（互斥）
                _pendingSkill = "mine";
                _grid.ShowCellOverlay(cells, new Color(0.25f, 0.80f, 0.35f, 0.30f), true);
                _hud.SetActiveAction(CurrentActionId()); // UX-4：布雷按钮激活高亮
                _hud.SetMessage("已选布雷：点击高亮绿色格放置水雷");
                break;
            }
        }
    }

    // 连锁弹/火油格覆盖：实心（格内有敌舰）/空心（盲射格）分色。
    private void ShowSkillOverlays(List<GridPos> cells, string skill)
    {
        var color = skill == "chain_shot"
            ? new Color(0.30f, 0.55f, 0.90f, 0.55f)
            : new Color(0.85f, 0.55f, 0.15f, 0.55f);
        _pendingTactic = null;
        _pendingSkill = skill;
        var overlays = new List<(GridPos Cell, Color Color, bool Solid)>();
        // Task 18 B3：hasTarget 只对当前可见敌舰生效（与射界弧同口径），沉舰/隐藏舰不再误标实心。
        var visibleEnemies = AttackRules.VisibleEnemies(_battle, _battle.CurrentFaction);
        foreach (var c in cells)
        {
            var hasTarget = visibleEnemies.Any(s => s.OccupiedCells().Contains(c));
            overlays.Add((c, color, hasTarget));
        }
        _grid.ShowCellOverlays(overlays);
    }

    private void TrySkillCell(string skill, GridPos cell)
    {
        var ship = SelectedOwnedShip();
        if (ship is null) { ClearPendingTargeting(); return; }
        BattleCommand? command = skill switch
        {
            "chain_shot" => new ChainShotCommand(ship.Id, cell),
            "fire_oil" => new FireOilCommand(ship.Id, cell),
            "mine" => new PlaceMineCommand(ship.Id, cell),
            _ => null,
        };
        if (command is null) { ClearPendingTargeting(); return; }
        var result = ActionResolver.TryExecute(_battle, command);
        ClearPendingTargeting();
        if (!result.Success)
        {
            _hud.SetMessage(DescribeFailure(result.Reason, ship));
            RefreshShipPanel(ship);
            return;
        }
        PlayEvents(result.Events, ship.Id, command);
        RefreshAllViews();
        _grid.ClearOverlay();
        _mode = InteractionMode.Move; // UX-3：技能成功 → 清覆盖，移动被规则锁死（HasAttacked）
        RefreshShipPanel(ship);
        _hud.SetMessage(skill switch
        {
            "chain_shot" => $"{ship.Definition.DisplayName} 连锁弹命中目标",
            "fire_oil" => $"{ship.Definition.DisplayName} 火油命中目标",
            "mine" => $"{ship.Definition.DisplayName} 放置水雷",
            _ => "技能施放",
        });
    }

    private void DoDamageControl()
    {
        var ship = SelectedOwnedShip();
        if (ship is null) return;
        var damageControlCommand = new DamageControlCommand(ship.Id);
        var result = ActionResolver.TryExecute(_battle, damageControlCommand);
        DispatchSimpleResult(result, ship, damageControlCommand, $"{ship.Definition.DisplayName} 损管：回血并启动持续恢复");
    }

    // F-7b：战斗内浅滩主动自沉（设计 15）——SelfSinkCommand（DeploymentPhase=false，扣 15% 最大生命）。
    // 浅滩 → 成为固定火力点：SelfSunk=true、保留生命/占格、永失移动转向（规则层 MovementRules 拦）；
    // 视觉「浸水/沉」标记由 NavalShipView._Draw 依 SelfSunk 自动绘制（复用，无需额外表现代码）。
    private void DoSelfSink()
    {
        var ship = SelectedOwnedShip();
        if (ship is null) return;
        ClearPendingTargeting();
        var selfSinkCommand = new SelfSinkCommand(ship.Id);
        var result = ActionResolver.TryExecute(_battle, selfSinkCommand);
        if (!result.Success)
        {
            _hud.SetMessage(DescribeFailure(result.Reason, ship));
            RefreshShipPanel(ship);
            return;
        }
        PlayEvents(result.Events, ship.Id, selfSinkCommand);
        RefreshAllViews();
        _grid.ClearOverlay();
        RefreshShipPanel(ship); // 自沉后 SelfSunk=true → 移动/转向/再自沉全部禁用，面板刷新
        _hud.SetMessage($"{ship.Definition.DisplayName} 浅滩自沉 · 本舰固守当前浅滩，可继续每回合攻击");
    }

    // 无目标命令（损管/交换/脱离）通用结算：清待定、播事件、刷新面板。
    private void DispatchSimpleResult(ActionResult result, ShipState ship, BattleCommand command, string successMessage)
    {
        ClearPendingTargeting();
        if (!result.Success)
        {
            _hud.SetMessage(DescribeFailure(result.Reason, ship));
            RefreshShipPanel(ship);
            return;
        }
        PlayEvents(result.Events, ship.Id, command);
        RefreshAllViews();
        _grid.ClearOverlay();
        _mode = InteractionMode.Move; // UX-3：交换/脱离/损管成功 → 清覆盖；损管等置 HasAttacked → 移动被锁
        RefreshShipPanel(ship);
        _hud.SetMessage(successMessage);
    }

    // V-5：单结束令——「结束本舰」已移除，整体「结束回合」（EndTurn）是唯一结束方式。

    // ---- F-3 投降交涉（设计 16.2/16.3）：接受/拒绝敌方劝降、我方发起劝降 ----

    // 玩家接受敌方劝降（被劝降方=我方，设计 16.3）：持有 ≥500 金 → 支付 500 金保全（空交付）；
    // 不足 → 弹出交付选舰面板，玩家勾选 ⌊符合舰数÷3⌋ 艘后确认交付。规则合法性由 ResolveAccept 校验。
    private void DoAcceptSurrender()
    {
        if (_battle is null) return;
        // F-7c：金币不足 → 交付路径（不扣现有金币，交付指定舰船）。打开选舰面板让玩家勾选。
        if (_battle.PlayerGold < SurrenderRules.SurrenderGoldCost)
        {
            var eligible = SurrenderRules.EligibleForDelivery(_battle);
            var deliverCount = eligible.Count / 3;
            if (deliverCount <= 0)
            {
                // 符合舰不足 3 艘（⌊÷3⌋=0）→ 空交付直接结算（规则允许）。
                ExecuteAcceptSurrender(Array.Empty<string>());
                return;
            }
            _deliveryShipIds.Clear();
            _hud.HideSurrenderPanel(); // 交付面板打开期间隐藏接受/拒绝按钮，避免双面板混淆
            _hud.ShowDeliveryPanel(eligible.Select(s => (s.Id, s.Definition.DisplayName)).ToList(), deliverCount);
            _hud.SetMessage($"接受劝降需交付 {deliverCount} 艘舰船：勾选后点「确认交付」");
            return;
        }
        // 持有 ≥500 金 → 支付保全（与既有 surrender_smoke 完全一致）。
        ExecuteAcceptSurrender(Array.Empty<string>());
    }

    // 统一执行 AcceptSurrenderCommand：成功关交付面板（若开着）并刷新；失败保留面板供玩家重选（数量不符/重复/不可交付）。
    private void ExecuteAcceptSurrender(string[] deliveredIds)
    {
        var result = ActionResolver.TryExecute(_battle, new AcceptSurrenderCommand(deliveredIds));
        if (!result.Success)
        {
            _hud.SetMessage(DescribeFailure(result.Reason, null));
            return;
        }
        PlayEvents(result.Events);
        RefreshAllViews();
        RefreshStatusBars(); // 响应后刷新待决面板（按钮消失/结算消息）
        _hud.HideDeliveryPanel();
    }

    // F-7c：交付面板勾选/取消勾选（CheckBox Toggled 回调；确认时读取 _deliveryShipIds）。
    public void OnDeliveryShipToggled(string shipId, bool on)
    {
        if (on) _deliveryShipIds.Add(shipId);
        else _deliveryShipIds.Remove(shipId);
    }

    // F-7c：确认交付——以勾选舰为交付列表发 AcceptSurrenderCommand；规则拒绝（数量不符等）→ 提示并保留面板重选。
    private void DoConfirmDelivery()
    {
        if (_battle is null) return;
        ExecuteAcceptSurrender(_deliveryShipIds.ToArray());
    }

    // F-7c：取消交付——清选择、关面板、重显接受/拒绝按钮（待决仍在，玩家可重新考虑）。
    private void DoCancelDelivery()
    {
        _deliveryShipIds.Clear();
        _hud.HideDeliveryPanel();
        RefreshStatusBars(); // 重显投降响应面板（待决未清除）
    }

    // 玩家拒绝敌方劝降：清除待决并继续战斗。
    private void DoRejectSurrender()
    {
        if (_battle is null) return;
        var result = ActionResolver.TryExecute(_battle, new RejectSurrenderCommand());
        if (!result.Success)
        {
            _hud.SetMessage(DescribeFailure(result.Reason, null));
            return;
        }
        PlayEvents(result.Events);
        RefreshStatusBars(); // 响应后刷新待决面板（按钮消失）
    }

    // 我方发起劝降（优势方=我方，目标=敌方）：掷骰成功 → 敌降即时结算（存活敌舰加入我方 + 可能触发终局）；
    // 失败 → 提示成功率。每回合一次门禁由规则层 LastOfferedRounds 拒绝再发。
    private void DoOfferSurrender()
    {
        if (_battle is null) return;
        var result = ActionResolver.TryExecute(_battle, new OfferSurrenderCommand(FactionId.Player));
        if (!result.Success)
        {
            _hud.SetMessage(DescribeFailure(result.Reason, null));
            RefreshStatusBars();
            return;
        }
        PlayEvents(result.Events);
        RefreshAllViews();
        RefreshStatusBars(); // 刷新劝降按钮（本回合已发起 → 禁用）
    }

    // FIX-1：玩家输入是否应被锁死——异步敌方回合播放中，或当前阵营=敌方（同步路径的敌方回合）。
    // 敌方回合期间 CurrentFaction==Enemy：点选敌舰的阵营判定（ship.Faction==CurrentFaction）成立，
    // 若不加门，玩家可手动操作敌方（规则层 OwnedShip 只查阵营==当前会接受）——既破坏"敌方自动行动"，
    // 又会因玩家操作杀 tween 卡死异步敌方回合。三个输入入口（OnShipClicked/OnGridClicked/OnAction）统一在此拦截。
    private bool PlayerInputLocked()
        // FIX-1 + V-1：异步敌方回合播放中 / 当前阵营=敌方（同步敌方回合） / 战斗已结束（投降或歼灭终局）
        // 均锁死玩家输入——战斗结束后不能再操控舰船（规则层投降命令亦已拒 BattleEnded）。
        => _battle is not null && (_enemyTurnInProgress || _battle.CurrentFaction == FactionId.Enemy || _battle.BattleEnded);

    // V-1：输入锁提示——战斗结束后提示"战斗已结束"（区别于敌方回合"请等待"）。
    private string InputLockMessage()
        => _battle is not null && _battle.BattleEnded ? "战斗已结束" : "敌方回合，请等待";

    private void EndTurn()
    {
        if (_enemyTurnInProgress) return; // UX-9：异步敌方回合播放中，防重入（当前阵营为敌方，玩家操作已被规则层拒绝）
        ClearPendingTargeting();
        var result = ActionResolver.TryExecute(_battle, new EndFactionTurnCommand());
        if (!result.Success)
        {
            _hud.SetMessage(DescribeFailure(result.Reason, null));
            return;
        }
        SetSelected(null);
        RefreshTurnReadinessViews();
        // Task 18 B1：玩家回合结束 → 敌方回合推进。开 AI 时由 NavalAi 完整驱动（命令/事件照常播放）；
        // 关 AI（既有冒烟/调试场景）时敌方回合无行动直接结束。玩家回合结束自身事件按原语义静默。
        // UX-9：敌方回合收尾（视图/覆盖/回合栏）统一由敌方回合路径完成（异步路径在动画播完后收尾）。
        RunEnemyTurn();
    }

    // 敌方回合推进（UX-9 重构）。开 AI：
    //   - 动画开启（真实窗口）→ 逐命令异步播放（每命令 PlayEvents+移动/转向动画播完再下一步，步间节奏间隔）；
    //   - headless 动画关闭 → 同步一次性完成（与改动前行为一致，既有冒烟时序不变）。
    // 关 AI：敌方回合无行动直接结束（占位语义，供既有冒烟/调试控制敌方不动的场景）。
    public void RunEnemyTurn()
    {
        _enemyStepEventCounts.Clear();   // 每回合重置逐步统计
        _enemyStepHadMovement.Clear();
        if (!_enemyAiEnabled)
        {
            ActionResolver.TryExecute(_battle, new EndFactionTurnCommand());
            FinishEnemyTurn();
            return;
        }
        if (_animationsEnabled)
        {
            _enemyTurnInProgress = true;
            _hud.SetMessage("敌方回合 · 敌方舰队行动中…");
            RunEnemyTurnAnimated();
            return;
        }
        RunEnemyTurnSynchronous();
    }

    // 同步敌方回合：逐命令 ChooseNext → TryExecute → 事件播放 + 逐步视图同步，至敌方回合结束或战斗结束。
    // 每步命令均由规则层复刻校验（NavalAi 保证合法）；Rejected 计数 + 步数上限双保险防死循环。
    private void RunEnemyTurnSynchronous()
    {
        var guard = 0;
        while (!_battle.BattleEnded && _battle.CurrentFaction == FactionId.Enemy && guard++ < MaxEnemyCommandSteps)
        {
            var cmd = NavalAi.ChooseNext(_battle, FactionId.Enemy);
            var result = ActionResolver.TryExecute(_battle, cmd);
            if (!result.Success)
            {
                _enemyTurnRejected++;
                break; // 防御：停止敌方回合（冒烟用 Rejected 计数暴露不一致）
            }
            _enemyCommandsRun++;
            PlayEnemyStep(result.Events);
            SyncMovedViews(result.Events); // headless：逐步视图直接落位，保证任意时刻视图=状态
            if (cmd is EndFactionTurnCommand) break;
        }
        FinishEnemyTurn();
    }

    // 异步敌方回合（UX-9 核心）：逐命令播放，每个命令的事件播放后启动移动/转向动画，用「固定时长等待」
    // 覆盖动画（FIX-1：不 await tween Finished——tween 被 Kill/零时长/已结束时信号永不发出，await 会卡死），
    // 步间留节奏间隔让玩家看清。headless 不走此路径（动画关闭）；等待只依赖 SceneTreeTimer.Timeout（恒可靠）。
    private async void RunEnemyTurnAnimated()
    {
        try
        {
            var guard = 0;
            while (!_battle.BattleEnded && _battle.CurrentFaction == FactionId.Enemy && guard++ < MaxEnemyCommandSteps)
            {
                var cmd = NavalAi.ChooseNext(_battle, FactionId.Enemy);
                var result = ActionResolver.TryExecute(_battle, cmd);
                if (!result.Success)
                {
                    _enemyTurnRejected++;
                    break; // 防御：停止敌方回合
                }
                _enemyCommandsRun++;
                PlayEnemyStep(result.Events);
                // 移动/转向动画：启动本步动画，用「固定时长等待」代替 await tween Finished。
                // FIX-1：tween 被 Kill（同视图二次动画）/零时长/已结束时，其 finished 信号不会发出，
                // 在信号之后 ToSignal 订阅将永不返回 → 异步方法卡死 → FinishEnemyTurn 永不执行 →
                // _enemyTurnInProgress 恒 true → 敌方回合永远不结束。固定时长等待只依赖
                // SceneTreeTimer.Timeout（恒可靠），动画照常播放、等待不依赖 tween 信号 → 绝不卡死。
                var animWaitSeconds = AnimateMovedViews(result.Events) + _animWaitBufferSeconds;
                await WaitForSeconds(animWaitSeconds);
                await WaitForSeconds(_enemyStepPauseSeconds); // 步间节奏间隔
                if (cmd is EndFactionTurnCommand) break;
            }
        }
        catch (Exception ex)
        {
            // 防御：动画/等待异常不崩溃（节点被释放等极端情况），报错后照常收尾。
            GD.PushError($"敌方回合动画播放异常：{ex}");
        }
        finally
        {
            if (IsInstanceValid(this) && _battle is not null) FinishEnemyTurn();
            else _enemyTurnInProgress = false; // 节点已释放/战斗已清空：仅清标志，不再触碰场景
        }
    }

    // 敌方回合收尾：重置视图到状态（最终位置一致）、清覆盖、隐藏面板、更新回合状态栏。
    // 异步路径在全部动画播放完后调用；同步路径在循环结束后调用。
    private void FinishEnemyTurn()
    {
        _enemyTurnInProgress = false;
        RefreshAllViews();
        _grid.ClearOverlay();
        _hud.HidePanel();
        if (_battle.BattleEnded) return; // AI 歼灭玩家已由 HandleBattleEnded 展示结算面板，不再覆写回合提示
        if (_battle.CurrentFaction == FactionId.Player)
        {
            AutoSelectPlayerShipAtTurnStart();
            _hud.ShowPlayerTurnStart(_battle.Round);
            return;
        }

        _hud.ShowTurnStatus(_battle.CurrentFaction, _battle.Round);
        _hud.SetMessage($"第 {_battle.Round} 回合 · 敌方回合");
    }

    private void TryMoveToExit(GridPos exitCell)
    {
        var ship = SelectedOwnedShip();
        if (ship is null) return;
        var direction = ship.Facing.Vector();
        GridPos? bestTarget = null;
        var bestSteps = int.MaxValue;

        // 船头向后第 i 格落在出口时，船头应位于 exit + facing * i。
        for (var i = 0; i < ship.Length; i++)
        {
            var bowTarget = exitCell + direction * i;
            var footprint = Enumerable.Range(0, ship.Length)
                .Select(segment => bowTarget - direction * segment)
                .ToList();
            if (!MovementRules.FootprintValid(_battle, footprint, ship)) continue;
            var path = ActionResolver.QueryMovePath(_battle, ship, bowTarget);
            var steps = path.Count > 0 ? path.Count - 1 : int.MaxValue;
            if (steps <= 0 || steps > ship.RemainingMovement) continue;
            if (steps >= bestSteps) continue;
            bestSteps = steps;
            bestTarget = bowTarget;
        }

        if (bestTarget is { } target)
        {
            MoveAreaTo(target);
            return;
        }
        _hud.SetMessage($"{ship.Definition.DisplayName} 本回合无法抵达该逃跑格");
    }

    // 敌方行动结束后主动把控制权交到一艘可指挥的我方舰上。
    // 优先指挥舰；若指挥舰已沉没/自沉，则选择第一艘仍可正常机动的存活舰。
    private ShipState? AutoSelectPlayerShipAtTurnStart()
    {
        var survivors = _battle.Ships.Values
            .Where(ship => ship.Faction == FactionId.Player && ship.HitPoints > 0)
            .OrderBy(ship => ship.Id, StringComparer.Ordinal)
            .ToList();
        if (survivors.Count == 0) return null;

        var flagshipId = FlagshipRules.ResolveFlagshipId(_battle, FactionId.Player);
        var flagship = flagshipId is null ? null : survivors.FirstOrDefault(ship => ship.Id == flagshipId);
        var selected = flagship is { SelfSunk: false }
            ? flagship
            : survivors.FirstOrDefault(ship => !ship.SelfSunk) ?? survivors[0];

        ClearPendingTargeting();
        SetSelected(selected.Id);
        EnterMoveMode();
        _hud.ShowShipActions(selected, ComputeActionFlags(selected));
        _hud.SetActiveAction(null);
        return selected;
    }

    // 敌方单步：播放该命令全部事件，并记录本步事件数/是否含移动转向（headless 断言"每步确有动作"用）。
    private void PlayEnemyStep(IReadOnlyList<BattleEvent> events)
    {
        PlayEvents(events);
        _enemyStepEventCounts.Add(events.Count);
        _enemyStepHadMovement.Add(events.Any(e => e is ShipMovedEvent or ShipTurnedEvent));
    }

    // 同步本步发生移动/转向的舰船视图到其当前状态位置（headless 同步路径：直接落位，视图=状态）。
    private void SyncMovedViews(IReadOnlyList<BattleEvent> events)
    {
        foreach (var e in events)
        {
            if (e is ShipMovedEvent m && _shipViews.TryGetValue(m.ShipId, out var mv)) mv.SyncToShip(_grid);
            else if (e is ShipTurnedEvent t && _shipViews.TryGetValue(t.ShipId, out var tv)) tv.SyncToShip(_grid);
        }
    }

    // 启动本步移动/转向舰视图的动画，返回本步动画最长时长（秒）——供异步路径「固定时长等待」。
    // 时长取自 NavalShipView.AnimSecondsFor（与 AnimateToShip 同口径，动画实际播放时长）；无动画/视图缺失返回 0。
    private float AnimateMovedViews(IReadOnlyList<BattleEvent> events)
    {
        var waitSeconds = 0f;
        foreach (var e in events)
        {
            if (e is ShipMovedEvent m && _shipViews.TryGetValue(m.ShipId, out var mv))
            {
                waitSeconds = Mathf.Max(waitSeconds, mv.AnimSecondsFor(_grid, _animMoveSecondsPerCell, _animTurnSeconds));
                mv.AnimateToShip(_grid, _animMoveSecondsPerCell, _animTurnSeconds);
            }
            else if (e is ShipTurnedEvent t && _shipViews.TryGetValue(t.ShipId, out var tv))
            {
                waitSeconds = Mathf.Max(waitSeconds, tv.AnimSecondsFor(_grid, _animMoveSecondsPerCell, _animTurnSeconds));
                tv.AnimateToShip(_grid, _animMoveSecondsPerCell, _animTurnSeconds);
            }
        }
        return waitSeconds;
    }

    // 等待指定秒数（步间节奏/动画间隙；headless 动画关闭时不进入此路径）。
    private SignalAwaiter WaitForSeconds(float seconds)
        => ToSignal(GetTree().CreateTimer(seconds), SceneTreeTimer.SignalName.Timeout);

    // Task 18 B1：敌方回合 AI 开关（既有冒烟需敌方不动的场景调用 false）。默认开。
    public void SetEnemyAiEnabled(bool enabled) => _enemyAiEnabled = enabled;
    public bool EnemyAiEnabled() => _enemyAiEnabled;
    public int EnemyCommandsRun() => _enemyCommandsRun;
    public int EnemyTurnRejectedCount() => _enemyTurnRejected;
    // UX-9：动画开关/参数（headless 自动关闭动画 → 敌方回合同步完成；冒烟可 SetAnimationsEnabled(true) 强制开异步路径、
    // SetAnimationParams 调小时长快速播放）。SetAnimationParams(0,0,0) 亦可让动画即时完成但保留异步时序。
    public void SetAnimationsEnabled(bool enabled) => _animationsEnabled = enabled;
    public bool AnimationsEnabled() => _animationsEnabled;
    public void SetAnimationParams(float moveSecPerCell, float turnSec, float stepPauseSec)
    {
        _animMoveSecondsPerCell = moveSecPerCell;
        _animTurnSeconds = turnSec;
        _enemyStepPauseSeconds = stepPauseSec;
    }
    // 异步敌方回合是否播放中（冒烟断言"end_turn 返回后异步逐命令播放、播完收尾"）。
    public bool EnemyTurnInProgress() => _enemyTurnInProgress;
    // UX-10：区域移动（BFS 路径动画）是否进行中（冒烟断言"点可达格后异步逐格播放、播完收尾"）。
    public bool AreaMoveInProgress() => _areaMoveInProgress;
    // UX-9：敌方回合已播放步数（每步=一条 AI 命令的事件集）。每步事件数/是否含移动转向（headless 断言"每步确有动作"）。
    public int EnemyStepsPlayed() => _enemyStepEventCounts.Count;
    public int EnemyStepEventCount(int step) => step >= 0 && step < _enemyStepEventCounts.Count ? _enemyStepEventCounts[step] : -1;
    public bool EnemyStepHadMovement(int step) => step >= 0 && step < _enemyStepHadMovement.Count && _enemyStepHadMovement[step];
    // 舰船视图当前世界坐标 / 状态期望中心坐标（headless 断言"动画后视图位置与 battle.Ships 状态一致"）。未找到 -1。
    public float ShipViewPosX(string shipId) => _shipViews.TryGetValue(shipId, out var v) ? v.Position.X : -1f;
    public float ShipViewPosY(string shipId) => _shipViews.TryGetValue(shipId, out var v) ? v.Position.Y : -1f;
    public float ShipStateCenterX(string shipId)
    {
        var ship = _battle is null ? null : _battle.ShipOrNull(shipId);
        return ship is null ? -1f : _grid.ShipCenterToWorld(ship.Bow, ship.Length, ship.Facing).X;
    }
    public float ShipStateCenterY(string shipId)
    {
        var ship = _battle is null ? null : _battle.ShipOrNull(shipId);
        return ship is null ? -1f : _grid.ShipCenterToWorld(ship.Bow, ship.Length, ship.Facing).Y;
    }

    // ---- 行动可用性（全部来自规则层查询/Validate，T13）----

    private ShipActionFlags ComputeActionFlags(ShipState ship)
    {
        // V-5：单结束令——移除每单位结束，canIssueOrders 仅需阵营匹配（本回合所有我方舰都可下指令）。
        var canIssueOrders = ship.Faction == _battle.CurrentFaction;
        var canMove = canIssueOrders && !ship.HasAttacked && !ship.SelfSunk && ship.RemainingMovement > 0 && ship.Boarding is null;
        var turnCost = MovementRules.TurnCost(ship);
        // UX-7：每回合一次单位行为（普攻或技能）——执行其一后（HasAttacked）其余普攻/技能均不可用。
        var canAct = canIssueOrders && !ship.HasAttacked;
        // F-7a：接舷组合移动可用性（设计 11.1）——选中舰是防守方 + 未攻击 + 预算未耗尽（防守方回合控制整体平移）。
        var canPairMove = canIssueOrders && ship.Boarding is { } link
            && ship.Id == link.DefenderId
            && !ship.HasAttacked
            && link.PairMovesUsed < BoardingRules.PairMoveBudget;
        // F-7b：战斗内浅滩自沉（设计 15）——通过性 1/2（FreeAll=3 排除）+ 船头在浅滩，未攻击/未自沉/非接舷。
        // 与布阵 CanSelfSinkInDeploy 同口径（浅滩固守语义；礁石/深水即时沉没移除不做按钮）。
        var canSelfSink = canAct
            && !ship.SelfSunk
            && ship.Boarding is null
            && ship.Definition.Passability != Passability.FreeAll
            && (_battle.Map.TerrainAt(ship.Bow) == TerrainType.Shallow
                || _battle.Map.TerrainAt(ship.Bow) == TerrainType.River); // U-2a：陆河按浅滩类似，可自沉成火力点
        return new ShipActionFlags(
            CanMove: canMove,
            CanTurn: canMove && ship.RemainingMovement >= turnCost,
            CanArrowRain: canAct, // 箭雨始终可用（无装载要求、无次数限制），是否命中取决于目标格
            CanBombardment: canAct && ship.WeaponCounts.GetValueOrDefault("bombardment", 0) > 0,
            CanCannon: canAct && ship.WeaponCounts.GetValueOrDefault("cannon", 0) > 0,
            CanRam: canAct && RamRules.QueryRamTargets(_battle, ship.Id).Count > 0,
            CanBoard: canAct && BoardingRules.QueryBoardTargets(_battle, ship.Id).Count > 0,
            CanExchange: canAct && ship.Boarding is not null,
            CanDisengage: canAct && ship.Boarding is not null,
            CanChainShot: canAct && StatusRules.QueryChainShotCells(_battle, ship).Count > 0,
            CanFireOil: canAct && StatusRules.QueryFireOilCells(_battle, ship).Count > 0,
            CanDamageControl: canAct && StatusRules.ValidateDamageControl(_battle, new DamageControlCommand(ship.Id)) is null,
            CanMine: canAct && ship.SkillUsesLeft.GetValueOrDefault("mine", 0) > 0 && ship.Boarding is null
                && MineRules.QueryMineCells(_battle, ship).Count > 0,
            CanPairMove: canPairMove,
            CanSelfSink: canSelfSink);
    }

    // ---- 表现：迷雾 / 伤害数字 / 状态图标 / 连线 / 特效（T13 全事件扩展） ----

    // 迷雾（几何可见性，设计 7.2）：按 AttackRules.VisibleEnemies 刷新敌舰视图可见性；不可见敌舰不显示。
    // V-3（CHG-20260810-fx-vision-recall）：迷雾数据源改用 RevealedCells = 当前可见 ∪ 滞留 3 回合内的格——
    // 船开走后开过视野的位置保持可见 3 回合再归雾（AdvanceVisionRecall 在玩家回合边界推进）。
    private void RefreshVisibility()
    {
        var visible = AttackRules.VisibleEnemies(_battle, FactionId.Player);
        foreach (var id in _shipViews.Keys)
        {
            var ship = _battle.ShipOrNull(id);
            if (ship is null) { _shipViews[id].Visible = false; continue; }
            _shipViews[id].Visible = ship.HitPoints > 0 && (ship.Faction == FactionId.Player || visible.Contains(ship));
        }
        // F-6：战争迷雾——视野外格子画墨色覆盖。规则层只读查询（UI 不重复实现视野规则），随每回合/行动刷新。
        _grid.ShowFog(AttackRules.RevealedCells(_battle, FactionId.Player));
    }

    // 伤害数字播放：范围伤害飘「-伤害」，盲射命中飘「命中」（不揭示舰体，T13 只提示"命中"），沉没隐藏舰视图。
    // T13 扩展：撞击（反伤/推动/入礁/箭头）、接舷（连线/进度/交换/俘获）、技能状态图标、水雷（爆炸圈/逐格伤害）全部在此播放。
    private void PlayEvents(IReadOnlyList<BattleEvent> events, string? actorId = null, BattleCommand? command = null)
    {
        _eventsPlayed += events.Count;
        foreach (var e in events)
        {
            switch (e)
            {
                case AreaDamageEvent d:
                    _hud.ShowDamageText(_grid.GridToWorldCenter(d.Cell), $"-{d.Amount}", new Color(0.80f, 0.15f, 0.12f));
                    break;
                case HiddenHitEvent d:
                    // T13：隐藏命中只显示"命中"提示，不揭示目标舰体。
                    _hud.ShowDamageText(_grid.GridToWorldCenter(d.Cell), "命中", new Color(0.62f, 0.64f, 0.72f));
                    break;
                case ShipSunkEvent s:
                    if (_shipViews.TryGetValue(s.ShipId, out var sunkView)) sunkView.Visible = false;
                    _hud.SetMessage($"{NameOf(s.ShipId)} 沉没");
                    break;
                case ShipEscapedEvent esc:
                    // F-2：逃跑（设计 16.1）——整舰移出战场：隐藏船视图 + 船位置播「逃离!」浮动文本 + HUD 提示。
                    // 舰已从 battle.Ships 移除，显示名取船视图（DisplayName）。
                    if (_shipViews.TryGetValue(esc.ShipId, out var escView))
                    {
                        escView.Visible = false;
                        _hud.SetMessage($"{escView.DisplayName} 逃离战场");
                        _hud.ShowDamageText(escView.Position, "逃离!", new Color(0.95f, 0.82f, 0.30f));
                    }
                    _grid.QueueRedraw();
                    break;
                case RamHitEvent r:
                    PlayRamHit(r, actorId);
                    break;
                case BoardingLinkedEvent b:
                    _hud.ShowDamageText(ShipViewCenter(b.InitiatorId), $"-{b.InitiatorDamage}", new Color(0.85f, 0.4f, 0.25f));
                    _hud.ShowDamageText(ShipViewCenter(b.DefenderId), $"-{b.DefenderDamage}", new Color(0.85f, 0.4f, 0.25f));
                    _grid.QueueRedraw();
                    _hud.SetMessage($"接舷达成：{NameOf(b.InitiatorId)} × {NameOf(b.DefenderId)}");
                    break;
                case BoardingDamageEvent b:
                {
                    // 事件只带 ActorId；发起/防守方从 Actor 的接舷链接解析。
                    var link = _battle.ShipOrNull(b.ActorId)?.Boarding;
                    if (link is not null)
                    {
                        _hud.ShowDamageText(ShipViewCenter(link.InitiatorId), $"-{b.InitiatorDamage}", new Color(0.85f, 0.4f, 0.25f));
                        _hud.ShowDamageText(ShipViewCenter(link.DefenderId), $"-{b.DefenderDamage}", new Color(0.85f, 0.4f, 0.25f));
                        if (b.Captured == true) _hud.SetMessage($"俘获成功！{NameOf(link.DefenderId)} 被俘获");
                    }
                    _grid.QueueRedraw();
                    break;
                }
                case BoardingDisengagedEvent b:
                    _hud.SetMessage(b.Success ? $"{NameOf(b.ActorId)} 脱离接舷成功" : $"{NameOf(b.ActorId)} 脱离失败（成功率 {b.SuccessRate:P0}）");
                    _grid.QueueRedraw();
                    break;
                case BoardingPairMovedEvent b:
                    RefreshAllViews();
                    break;
                case CaptureProgressChangedEvent p:
                    _grid.QueueRedraw();
                    _hud.SetMessage($"俘获进度：{NameOf(p.DefenderId)} {p.Progress}%（{(p.Reason == "advantage" ? "优势晋级" : "无优势衰减")}）");
                    break;
                case ShipCapturedEvent c:
                    if (_shipViews.TryGetValue(c.ShipId, out var capturedView)) capturedView.Visible = false;
                    _grid.QueueRedraw();
                    _hud.SetMessage($"{NameOf(c.ShipId)} 被 {NameOf(c.CaptorId)} 俘获");
                    break;
                case ChainShotAppliedEvent c:
                    RedrawShip(c.ShipId);
                    _hud.SetMessage($"{NameOf(c.ShipId)} 被连锁弹减速 {c.SlowRoundsLeft} 回合");
                    break;
                case BurnAppliedEvent b:
                    RedrawShip(b.ShipId);
                    _hud.SetMessage($"{NameOf(b.ShipId)} 着火（{b.Rounds} 回合）");
                    break;
                case BurnTickEvent b:
                    _hud.ShowDamageText(ShipViewCenter(b.ShipId), $"-{b.Amount}", new Color(0.95f, 0.5f, 0.1f));
                    RedrawShip(b.ShipId);
                    break;
                case BurnEndedEvent b:
                    RedrawShip(b.ShipId);
                    _hud.SetMessage($"{NameOf(b.ShipId)} 火势熄灭");
                    break;
                case ShipHealedEvent h:
                    _hud.ShowDamageText(ShipViewCenter(h.ShipId), $"+{h.Amount}", new Color(0.25f, 0.80f, 0.35f));
                    RedrawShip(h.ShipId);
                    break;
                case RepairsInterruptedEvent i:
                    _hud.SetMessage($"{NameOf(i.ShipId)} 损管被打断");
                    RedrawShip(i.ShipId);
                    break;
                case MinePlacedEvent m:
                    _grid.QueueRedraw();
                    _hud.SetMessage($"{NameOf(m.ShipId)} 布雷于 ({m.Cell.X},{m.Cell.Y})");
                    break;
                case MineTriggeredEvent t:
                    _hud.ShowDamageText(_grid.GridToWorldCenter(t.Cell), $"-{t.Amount}", new Color(0.70f, 0.80f, 0.30f));
                    _grid.QueueRedraw();
                    _hud.SetMessage($"{NameOf(t.ShipId)} 触雷 -{t.Amount}");
                    break;
                case MineDamagedEvent md:
                    _grid.QueueRedraw();
                    _hud.SetMessage($"水雷 ({md.Cell.X},{md.Cell.Y}) 受创 {md.Amount}，剩余 {md.HitPoints}");
                    break;
                case MineExplodedEvent me:
                    _grid.ShowExplosion(me.Cell);
                    if (me.Damage > 0)
                        _hud.ShowDamageText(_grid.GridToWorldCenter(me.Cell), $"-{me.Damage}", new Color(0.98f, 0.5f, 0.15f));
                    break;
                case RevealShipEvent rv:
                    // 命中可见舰揭示确认：几何迷雾已覆盖，视图可见性由 RefreshVisibility 刷新。
                    break;
                // F-3：投降事件（设计 16.2/16.3）。
                case SurrenderOfferedEvent so:
                    // 劝降掷骰提示（成功率）。敌方劝降成功 → 刷新面板弹出 接受/拒绝 按钮（玩家响应）。
                    if (so.Success)
                        _hud.SetMessage(so.OfferingFaction == FactionId.Enemy
                            ? "敌方提议投降：你可选择 接受投降 或 拒绝投降"
                            : "劝降成功：敌方愿降，其存活舰船加入我方");
                    else
                        _hud.SetMessage($"{OfferingSide(so.OfferingFaction)} 劝降失败（成功率 {so.SuccessRate}%）");
                    RefreshSurrenderPanel();
                    break;
                case EnemySurrenderedEvent en:
                    // 敌降加入我方：重新 Setup 视图刷新阵营色（敌冷灰 → 我暖黄），提示加入。
                    // 已沉/被俘/逃脱舰不在 battle.Ships → 天然不在 JoinedShipIds。
                    foreach (var id in en.JoinedShipIds)
                    {
                        if (_shipViews.TryGetValue(id, out var joinedView) && _battle.ShipOrNull(id) is { } joined)
                            joinedView.Setup(joined, _grid);
                    }
                    _hud.SetMessage($"{string.Join("、", en.JoinedShipIds.Select(NameOf))} 投降加入我方");
                    RefreshSurrenderPanel();
                    break;
                case PlayerSurrenderedEvent ps:
                    // 我方接受劝降：支付 500 金保全（PaidGold）或交付舰船（已移出战场）。
                    _hud.SetMessage(ps.PaidGold
                        ? $"接受劝降：支付 {ps.GoldPaid} 金币保全舰队"
                        : $"接受劝降：交付 {ps.DeliveredShipIds.Length} 艘舰船");
                    RefreshSurrenderPanel();
                    break;
                case PlayerSurrenderRejectedEvent pr:
                    _hud.SetMessage("拒绝劝降：战斗继续");
                    RefreshSurrenderPanel();
                    break;
                case BattleEndedEvent:
                    // T16 闭环：战斗结束 → 网关 Finalize（清理+结果）→ 免费维修 → 结算面板。
                    HandleBattleEnded();
                    break;
                case ShipMovedEvent sm:
                case ShipTurnedEvent st:
                case ShipMarkedAttackEvent sa:
                case FactionTurnEndedEvent ft:
                case RoundAdvancedEvent ra:
                    break;
            }
        }
        // 事件后统一刷新网格（水雷/接舷连线/特效）。
        _grid.QueueRedraw();
        // L-3：每次命令/事件流后通知关卡协调——记录目标追踪器（玩家命令 command 非空才计）、
        // 按移动/转向/击沉事件推进教学提示、评估目标（达成/超回合即时收尾）、刷新目标条+提示条。
        // 敌方 AI 命令（command=null）只评估目标（回合/存活类），不计入玩家目标计数。
        _levelPlay?.PostEvents(_battle, events, command);
        if (_battle.BattleEnded) _grid.ClearPersistentHighlights();
    }

    // ---- T16 战斗结束闭环（BattleEnded → 结果 → 免费维修 → 返回 Demo 入口） ----

    // 战斗结束统一收尾：网关 Finalize（清除临时状态 + 生成 BattleResult）→ 免费即时修满 → 显示结算面板。
    // 防重复（终局只发一次 BattleEndedEvent，防御多路径）。
    private void HandleBattleEnded()
    {
        if (_result is not null) return;
        _grid.ClearOverlay();
        _grid.ClearPersistentHighlights();
        _hud.HidePanel();
        _hud.HideSurrenderPanel(); // F-3：战斗结束 → 投降交涉面板不再有意义
        _hud.HideDeliveryPanel(); // F-7c：战斗结束 → 交付选舰面板不再有意义
        var result = NavalBattleGateway.Finalize(_battle);
        _result = result;
        RepairService.RepairAll(_battle.Ships.Values); // 存活/自沉/投降移交舰免费修满；沉没舰永久损失
        RefreshAllViews();
        if (_levelPlay is { } lp && lp.LevelMode())
        {
            // L-3：关卡模式由 LevelPlay 结算（目标成败 + MarkCompleted + 结算面板），不弹 HUD 通用结果面板。
            _hud.HideResult();
            lp.OnBattleEnded(_battle, result);
            return;
        }
        // CHG-20260817：本控制器 _Ready 早于 Deployment._Ready，海盗战（Deployment 消费 meta 后 Begin）
        // 在此刻会话才激活——以会话实时状态统一判定遭遇模式，兼容既有随机遭遇与海盗战。
        var encounter = _encounter ?? (RandomEncounterSession.Active ? RandomEncounterSession.Pending : null);
        if (encounter is not null)
        {
            // U-2c：随机遭遇结算——HUD 结果 + 奖励行 + 重掷入口（目标=歼灭敌人，默认）。
            // V-4：固定测试关卡不提供重掷（每项 = 指定地图×敌人组合，重掷会破坏测试意义）。
            // CHG-20260817：海盗战不重掷，改为显示「返回海上大地图」。
            _hud.ShowResult(result, EncounterResultText(encounter));
            _hud.SetRerollVisible(!encounter.IsFixed && !PirateBattleSession.Active);
            _hud.SetPirateReturnVisible(PirateBattleSession.Active);
            return;
        }
        _hud.ShowResult(result);
        _hud.SetRerollVisible(false);
        _hud.SetPirateReturnVisible(false);
    }

    // 演示/冒烟收尾钩子（设计裁定 7）：把敌方留场舰 HP 置 0 后走真实终局判定（SettleAfterCommand）并触发
    // BattleEndedEvent → 走与"正常歼灭"相同的结算闭环。不属于剧情层正常调用边界（T17 前无 AI）。
    public void ForceBattleEndForDemo()
    {
        if (_battle is null || _battle.BattleEnded) return;
        foreach (var s in _battle.Ships.Values)
            if (s.Faction == FactionId.Enemy) s.HitPoints = 0;
        if (_battle.BattleEnded) return;
        // Task 18 B7：胜负由 SettleAfterCommand 统一判定（同归于尽=平局 winner=null），只播放其事件一次。
        // 此前"手动重算 Player:Enemy + 另发 BattleEndedEvent"会在互毁时误判敌方胜，且与规则事件双发。
        var result = BattleEndRules.SettleAfterCommand(_battle, ActionResult.Ok(Array.Empty<BattleEvent>()));
        if (_battle.BattleEnded) PlayEvents(result.Events);
    }

    // F-3 演示/冒烟钩子（与 ForceBattleEndForDemo 同源）：直接置敌方劝降待决态（PendingSurrenderFrom=Enemy），
    // 让"接受/拒绝"响应面板无需真实掷骰即可在 Demo/冒烟中演示。规则层劝降成功路径已由 OfferSurrenderCommand 覆盖，
    // 本钩子只构造待决状态（触发同一套 刷新面板 → 接受/拒绝 → 结算 闭环）。
    public void ForcePendingSurrenderForDemo()
    {
        if (_battle is null || _battle.BattleEnded) return;
        _battle.PendingSurrenderFrom = FactionId.Enemy;
        RefreshStatusBars();
    }

    // F-3 演示/冒烟钩子：直接置某舰生命（构造投降优势/歼灭用；ForceBattleEndForDemo 的逐舰版）。
    public void SetShipHitPointsForDemo(string shipId, int hitPoints)
    {
        if (_battle is null) return;
        var ship = _battle.ShipOrNull(shipId);
        if (ship is null) return;
        ship.HitPoints = Math.Max(hitPoints, 0);
        RefreshAllViews();
    }

    // F-7a 演示/冒烟钩子（与 ForcePendingSurrenderForDemo 同源）：直接构造接舷链接，让玩家舰成为组合移动的
    // 防守方（真实接舷需敌方发起，AI 关闭时无法自然触发）。两舰共享同一 BoardingLink 实例。
    public void ForceBoardingForDemo(string defenderId, string initiatorId)
    {
        if (_battle is null || _battle.BattleEnded) return;
        var defender = _battle.ShipOrNull(defenderId);
        var initiator = _battle.ShipOrNull(initiatorId);
        if (defender is null || initiator is null || defender.HitPoints <= 0 || initiator.HitPoints <= 0) return;
        var link = new BoardingLink { InitiatorId = initiatorId, DefenderId = defenderId, CaptureProgress = 0 };
        defender.Boarding = link;
        initiator.Boarding = link;
        RefreshAllViews();
        RefreshStatusBars();
    }

    // F-7c 演示/冒烟钩子：直接置玩家金币（demo 默认 500 走支付路径，改低以演示交付舰选择）。
    public void SetPlayerGoldForDemo(int gold)
    {
        if (_battle is null) return;
        _battle.PlayerGold = Math.Max(gold, 0);
        RefreshStatusBars();
    }

    // 返回 Demo 入口（再来一局）：清空本场战斗表现状态，交由布阵控制器重建全新舰队并重新进入布阵阶段。
    public void NewGame()
    {
        if (_enemyTurnInProgress) return; // UX-9：异步敌方回合播放中，防 _battle 被清空导致异步循环空引用
        // L-3：关卡模式结算出口是 LevelPlay 的 重试/返回（重载本关场景），HUD「再来一局」不进入本路径；防御兜底。
        if (_levelPlay is { } lp && lp.LevelMode()) { GetTree().ReloadCurrentScene(); return; }
        _hud.HideResult();
        _hud.HidePanel();
        _hud.HideSurrenderPanel(); // F-3：再来一局清投降交涉面板
        _hud.HideDeliveryPanel(); // F-7c：再来一局清交付选舰面板
        _deliveryShipIds.Clear();
        _hud.SetActiveAction(null); // UX-4：再来一局清武器/行为激活高亮
        _grid.ClearOverlay();
        // Task 18 B2：移除视图同时 QueueFree 释放节点，避免旧舰视图滞留场景树（再来一局内存/显示泄漏）。
        foreach (var child in _shipsRoot.GetChildren()) { _shipsRoot.RemoveChild(child); child.QueueFree(); }
        _shipViews.Clear();
        _selectedShip = null;
        _pendingTactic = null;
        _pendingSkill = null;
        _pendingWeapon = null;
        _mode = InteractionMode.None;
        _result = null;
        _battle = null!;
        // F-6：返回布阵阶段隐藏天气覆盖层（CanvasLayer 不随父节点隐藏，与 HUD 一起显式隐藏；布阵阶段不显示天气）。
        _weatherFxLayer.Visible = false;
        // BattleController 位于 NavalDemo/Battle/ 下，Deployment 是 NavalDemo 的直接子节点 → 需上两级。
        GetNodeOrNull<NavalDeploymentController>("../../Deployment")?.ResetForNewGame();
    }

    // U-2c：随机遭遇「重掷换一场」——同难度 Seed+101 重新生成一场并 Begin，重载当前场景重新布阵。
    // 仅结算面板出口调用（OnAction("reroll_encounter") 已放行）；非遭遇模式防御性忽略。
    public void RerollEncounter()
    {
        if (_encounter is null) return;
        if (_encounter.IsFixed) return; // V-4：固定测试关卡不重掷（指定地图×敌人组合，重掷破坏测试意义）
        if (_enemyTurnInProgress) return; // UX-9：异步敌方回合播放中，防竞态（与 NewGame 同源防护）
        var next = RandomEncounterGenerator.Generate(_battle.Config,
            new RandomEncounterOptions(_encounter.Difficulty, _encounter.Seed + 101, true));
        RandomEncounterSession.Begin(next);
        _hud.HideResult();
        GetTree().ReloadCurrentScene();
    }

    // U-2c：随机遭遇结算奖励行文本（金/铁/木/麻），由 HandleBattleEnded 追加到 HUD 结果。
    // 入参为结算时实时遭遇（海盗战来自 RandomEncounterSession，无法依赖 _Ready 时的缓存）。
    private string EncounterResultText(RandomEncounter encounter)
    {
        var r = encounter.Rewards;
        return r is null ? "" : $"战利品 金{r.Gold} · 铁{r.Iron} · 木{r.Wood} · 麻{r.Hemp}";
    }

    // ---- CHG-20260817：海盗战结算返回海上大地图 ----

    // 构造返回上下文：以发起方请求 meta（经 PirateBattleSession.ReturnContextCarrier 暂存）为基础，
    // 保留 玩家位置/农历日，补写结算结果。独立公开供 headless 断言（不触发场景切换）。
    // outcome：0 胜 / 1 败 / 2 平（BattleOutcome 顺序）。
    public Godot.Collections.Dictionary BuildPirateReturnContext()
    {
        var root = GetTree().Root;
        Godot.Collections.Dictionary context;
        if (PirateBattleSession.ReturnContextCarrier is { } carrier)
        {
            context = new Godot.Collections.Dictionary();
            foreach (var key in carrier.Keys)
                context[key] = carrier[key];
        }
        else if (root.HasMeta(PirateBattleSession.ReturnMetaKey))
            context = (Godot.Collections.Dictionary)root.GetMeta(PirateBattleSession.ReturnMetaKey);
        else
            context = new Godot.Collections.Dictionary();
        context["outcome"] = (int)(_result?.Outcome ?? BattleOutcome.Draw);
        context["player_gold_remaining"] = _result?.PlayerGoldRemaining ?? 0;
        // 海盗 id 只保存在本进程 C# 会话（PirateBattleSession），发起时 GDScript 写入的请求 meta 已被
        // Deployment._Ready 消费；这里补写回返回 meta，供海上大地图按名移除/保留海盗。
        if (PirateBattleSession.PirateId is { } pirateId)
            context["pirate_id"] = pirateId;
        return context;
    }

    // 结算面板「返回海上大地图」：写返回 meta → 清会话 → 切回海上大地图。仅战斗结束后可用。
    public void ReturnToSea()
    {
        if (_enemyTurnInProgress) return; // UX-9：与 NewGame 同源防竞态
        if (_result is null) return;
        GetTree().Root.SetMeta(PirateBattleSession.ReturnMetaKey, BuildPirateReturnContext());
        RandomEncounterSession.Clear();
        PirateBattleSession.Clear();
        _hud.HideResult();
        GetTree().ChangeSceneToFile(SeaOverworldScenePath);
    }

    // 只读状态（headless 断言：海盗战模式激活）。
    public bool PirateBattleActive() => PirateBattleSession.Active;

    // 撞击表现：目标伤害 + 撞击方反伤 + 推动/入礁文字 + 撞击方向箭头（撞击舰船头→目标）。
    private void PlayRamHit(RamHitEvent r, string? actorId)
    {
        var rammerId = actorId ?? _selectedShip ?? r.ShipId;
        _hud.ShowDamageText(ShipViewCenter(r.ShipId), $"-{r.Amount}", new Color(0.85f, 0.2f, 0.12f));
        if (r.RammerDamage > 0)
            _hud.ShowDamageText(ShipViewCenter(rammerId), $"-{r.RammerDamage}", new Color(0.85f, 0.4f, 0.2f));
        if (r.IntoReef && r.ReefDamage > 0)
            _hud.ShowDamageText(ShipViewCenter(r.ShipId), $"入礁 -{r.ReefDamage}", new Color(0.55f, 0.45f, 0.3f));
        else if (r.Pushed)
            _hud.ShowDamageText(ShipViewCenter(r.ShipId), "推动!", new Color(0.55f, 0.7f, 0.9f));
        else if (r.PushBlocked)
            _hud.ShowDamageText(ShipViewCenter(r.ShipId), "受阻", new Color(0.7f, 0.6f, 0.4f));
        // 撞击方向箭头：撞击舰船头朝目标。
        var rammer = _battle.ShipOrNull(rammerId);
        var target = _battle.ShipOrNull(r.ShipId);
        if (rammer is not null && target is not null)
        {
            var from = _grid.ShipCenterToWorld(rammer.Bow, rammer.Length, rammer.Facing);
            var to = _grid.ShipCenterToWorld(target.Bow, target.Length, target.Facing);
            _grid.ShowRamArrow(from, to);
        }
        RedrawShip(rammerId);
        RedrawShip(r.ShipId);
    }

    private void RedrawShip(string shipId)
    {
        if (_shipViews.TryGetValue(shipId, out var view)) view.QueueRedraw();
    }

    private Vector2 ShipViewCenter(string shipId)
    {
        var ship = _battle.ShipOrNull(shipId);
        if (ship is null) return _grid.GridToWorldCenter(new GridPos(0, 0));
        return _grid.ShipCenterToWorld(ship.Bow, ship.Length, ship.Facing);
    }

    private string NameOf(string shipId) => _battle.ShipOrNull(shipId)?.Definition.DisplayName ?? shipId;

    // ---- 辅助 ----

    private ShipState? SelectedOwnedShip()
    {
        if (_selectedShip is null) return null;
        var ship = _battle.ShipOrNull(_selectedShip);
        if (ship is null || ship.Faction != _battle.CurrentFaction || ship.HitPoints <= 0)
        {
            SetSelected(null);
            return null;
        }
        return ship;
    }

    private void SetSelected(string? shipId)
    {
        if (_selectedShip is not null && _shipViews.TryGetValue(_selectedShip, out var old))
            old.SetSelected(false);
        _selectedShip = shipId;
        if (_selectedShip is not null && _shipViews.TryGetValue(_selectedShip, out var view))
        {
            view.SetSelected(true);
            if (_battle.ShipOrNull(_selectedShip) is { } selected)
            {
                _grid.FocusCameraOnShip(selected);
                _hud.ShowShipStatus(_battle, selected);
            }
        }
        if (shipId is null)
        {
            _mode = InteractionMode.None; // UX-3：退出选择/点空白 → 待选状态，清移动范围与红晕
            ClearPendingTargeting();
            _grid.ClearOverlay();
            _hud.HidePanel();
            _hud.SetActiveAction(null); // UX-4：退出选择清武器/行为激活高亮
            _hud.SetTurnEnabled(false);
        }
        RefreshStatusBars(); // UX-5：选中/退选切换顶栏（选中=单位详情，退选=全局）
    }

    // UX-4：当前武器/行为高亮来源——待定技能 > 待定战术 > 当前展开攻击方式 > 其它无。
    private string? CurrentActionId()
    {
        if (_pendingSkill is not null) return _pendingSkill;
        if (_pendingTactic is not null) return _pendingTactic;
        return _pendingWeapon;
    }

    // UX-3：进入移动/转向模式（Move）——只显示移动范围（本回合可移动时，规则 QueryMoveRange 为空则清空），
    // 清射界/技能/战术目标覆盖，保证与 Attack 模式互斥不重叠。
    private void EnterMoveMode()
    {
        _mode = InteractionMode.Move;
        _pendingTactic = null;
        _pendingSkill = null;
        _pendingWeapon = null;
        _grid.ShowAttackArcs(Array.Empty<AttackArcOption>());
        _grid.ShowCellOverlays(Array.Empty<(GridPos, Color, bool)>());
        _grid.ShowShipTargets(Array.Empty<string>());
        _grid.ShowMoveRange(_selectedShip is { } id
            ? ActionResolver.QueryMoveRange(_battle, id)
            : Array.Empty<GridPos>());
    }

    // UX-3：进入武器/行为模式（Attack）——隐藏移动范围并清其它覆盖（射界/技能格/目标舰），
    // 随后由各武器入口显示自己的射界/目标范围；保证移动高亮与射界红晕不重叠。
    private void EnterAttackMode()
    {
        _mode = InteractionMode.Attack;
        _pendingTactic = null;
        _pendingSkill = null;
        _pendingWeapon = null;
        _grid.ShowMoveRange(Array.Empty<GridPos>());
        _grid.ShowAttackArcs(Array.Empty<AttackArcOption>());
        _grid.ShowCellOverlays(Array.Empty<(GridPos, Color, bool)>());
        _grid.ShowShipTargets(Array.Empty<string>());
    }

    // 清空待定战术/技能/攻击方式目标选择（覆盖层与标志）。
    private void ClearPendingTargeting()
    {
        if (_pendingTactic is null && _pendingSkill is null && _pendingWeapon is null) return;
        _pendingTactic = null;
        _pendingSkill = null;
        _pendingWeapon = null;
        _grid.ShowShipTargets(Array.Empty<string>());
        _grid.ShowCellOverlays(Array.Empty<(GridPos, Color, bool)>());
    }

    private void SyncShipView(string shipId)
    {
        if (_shipViews.TryGetValue(shipId, out var view))
        {
            view.SyncToShip(_grid);
            ApplyTurnReadiness(view, _battle.ShipOrNull(shipId));
        }
    }

    // UX-9：船视图同步——动画开启（真实窗口）时平移动画到新位置/朝向，否则直接落位（headless 时序不变）。
    // 我方移动/转向与敌方回合移动走同一动画路径，视觉一致。
    private void AnimateShipView(string shipId)
    {
        if (_shipViews.TryGetValue(shipId, out var view))
        {
            ApplyTurnReadiness(view, _battle.ShipOrNull(shipId));
            if (_animationsEnabled) view.AnimateToShip(_grid, _animMoveSecondsPerCell, _animTurnSeconds);
            else view.SyncToShip(_grid);
        }
    }

    private void RefreshShipPanel(ShipState ship)
    {
        if (_shipViews.TryGetValue(ship.Id, out var view)) ApplyTurnReadiness(view, ship);
        if (_selectedShip == ship.Id)
        {
            _hud.ShowShipStatus(_battle, ship);
            _hud.ShowShipActions(ship, ComputeActionFlags(ship));
            _grid.FocusCameraOnShip(ship);
        }
        _hud.SetActiveAction(CurrentActionId()); // UX-4：移动/转向/行动完成/切换后统一同步武器/行为高亮（切换而非叠加）
        RefreshStatusBars(); // UX-5：移动/行动后同步选中舰详情（生命/移动/行动摘要变化）
    }

    private void RefreshAllViews()
    {
        foreach (var id in _shipViews.Keys)
            SyncShipView(id);
        RefreshVisibility();
        RefreshStatusBars(); // UX-5：事件后（伤害/状态/捕获）同步顶栏
    }

    private void RefreshTurnReadinessViews()
    {
        foreach (var (id, view) in _shipViews)
            ApplyTurnReadiness(view, _battle.ShipOrNull(id));
    }

    private void ApplyTurnReadiness(NavalShipView view, ShipState? ship)
    {
        var showPlayerReadiness = !_battle.BattleEnded
            && _battle.CurrentFaction == FactionId.Player
            && ship is { Faction: FactionId.Player, HitPoints: > 0 };
        var acted = showPlayerReadiness && (ship!.HasAttacked || ship.SpentMovement > 0);
        view.SetTurnReadiness(showPlayerReadiness && !acted, acted);
    }

    // UX-5：上下文状态栏刷新——有选中舰=单位详情（附规则层行动可用性），无选中=全局信息。
    private void RefreshStatusBars()
    {
        if (_battle is null) return;
        // V-5：单结束令——待命舰 = 本阵营存活且未自沉（每单位结束已移除，不再有"已结束待命外"的舰）。
        var readyShips = _battle.Ships.Values.Count(s => s.Faction == _battle.CurrentFaction
            && s.HitPoints > 0 && !s.HasAttacked && s.SpentMovement == 0);
        var ship = _selectedShip is null ? null : _battle.ShipOrNull(_selectedShip);
        if (ship is null || ship.HitPoints <= 0)
            _hud.ShowContextStatus(_battle, null, null, readyShips);
        else
        {
            _hud.ShowShipStatus(_battle, ship);
            _hud.ShowContextStatus(_battle, ship, ComputeActionFlags(ship), readyShips);
        }
        RefreshSurrenderPanel(); // F-3：投降面板随状态刷新（待决响应按钮 / 我方劝降可用 / 每回合一次门禁）
    }

    // F-3：投降交涉面板状态（规则层只读查询驱动，UI 只映射显隐/禁用）：
    //  - 敌方劝降待决（PendingSurrenderFrom==Enemy）→ 显示 接受/拒绝 按钮；
    //  - 我方满足投降优势（CanOfferSurrender(Player)）且本回合为玩家、无待决、战斗未结束 → 显示 劝降 按钮；
    //    LastOfferedRounds[Player]==Round（本回合已发起）→ 禁用（每回合一次门禁，设计 16.2）；其余隐藏。
    private void RefreshSurrenderPanel()
    {
        if (_battle is null) { _hud.HideSurrenderPanel(); return; }
        var pending = _battle.PendingSurrenderFrom;
        if (pending is { } p && p == FactionId.Enemy)
            _hud.ShowSurrenderButtons();
        else
            _hud.HideSurrenderButtons();
        var playerCanOffer = _battle.CurrentFaction == FactionId.Player
            && pending is null
            && !_battle.BattleEnded
            && SurrenderRules.CanOfferSurrender(_battle, FactionId.Player);
        var offeredThisTurn = playerCanOffer
            && _battle.LastOfferedRounds.TryGetValue(FactionId.Player, out var lastRound)
            && lastRound == _battle.Round;
        if (playerCanOffer) _hud.ShowSurrenderOffer(!offeredThisTurn);
        else _hud.HideSurrenderOffer();
    }

    private static string OfferingSide(FactionId faction)
        => faction == FactionId.Player ? "我方" : "敌方";

    // 点格子移动：选船头到目标格在 4 方向上最接近的一步。
    private static CardinalDirection? StepToward(GridPos from, GridPos target)
    {
        var dx = target.X - from.X;
        var dy = target.Y - from.Y;
        if (dx == 0 && dy == 0) return null;
        if (Math.Abs(dx) >= Math.Abs(dy)) return dx > 0 ? CardinalDirection.East : CardinalDirection.West;
        return dy > 0 ? CardinalDirection.South : CardinalDirection.North;
    }

    // UX-10：路径相邻格 → 平移方向（正交，设计 5.1）。非正交相邻返回 null。
    private static CardinalDirection? DirectionBetween(GridPos from, GridPos to)
    {
        var dx = to.X - from.X;
        var dy = to.Y - from.Y;
        if (dx == 1 && dy == 0) return CardinalDirection.East;
        if (dx == -1 && dy == 0) return CardinalDirection.West;
        if (dx == 0 && dy == 1) return CardinalDirection.South;
        if (dx == 0 && dy == -1) return CardinalDirection.North;
        return null;
    }

    private static string DescribeFailure(string? reason, ShipState? ship)
    {
        var who = ship is null ? "" : $"{ship.Definition.DisplayName}";
        return reason switch
        {
            "movement.no_points" => $"{who} 移动点不足",
            "movement.not_enough_points" => $"{who} 移动点不足以转向",
            "movement.blocked" or "movement.turn_blocked" => $"{who} 目标被阻挡",
            "action.attack_ended_movement" => $"{who} 已攻击，本回合不能再移动",
            "action.self_sunk_immobile" => $"{who} 已自沉，无法行动",
            // F-7b：战斗内浅滩自沉（设计 15）失败原因（规则层 ValidateSelfSink）。
            "self_sink.already_sunk" => $"{who} 已自沉",
            "self_sink.captured" => $"{who} 已被俘获，无法自沉",
            "self_sink.boarding" => $"{who} 接舷中，无法自沉",
            "self_sink.passability" => $"{who} 该舰型无法浅滩自沉",
            "self_sink.wrong_terrain" => $"{who} 需在浅滩才能自沉",
            "action.unknown_ship" => "无法指挥该舰",
            "action.no_weapon" => $"{who} 未装备该武器",
            "action.out_of_range" => $"{who} 目标超出射程",
            "action.not_broadside" => $"{who} 火炮需侧舷对齐",
            "action.blocked_by_terrain" => $"{who} 射线上有山地阻挡",
            "boarding.locked" => $"{who} 接舷中，组合需整体行动",
            "boarding.not_boarding" => $"{who} 未处于接舷状态",
            "boarding.not_parallel_adjacent" => $"{who} 需平行且与目标相邻",
            "boarding.only_defender_controls" => "仅防守方可控制接舷组合平移",
            "boarding.pair_budget_exhausted" => "接舷组合本回合平移预算已用完",
            "ram.requires_approach_move" => $"{who} 需最后一步朝目标接近才能撞击",
            "ram.target_not_in_front" => $"{who} 目标不在船头正前方",
            "ram.target_is_friendly" => "不能撞击友军",
            "skill.no_uses" => $"{who} 该技能次数已用完",
            "mine.invalid_cell" => $"{who} 该格不能布雷（需舰侧/尾相邻空格）",
            // F-3：投降交涉（设计 16.2/16.3）失败原因。
            "surrender.battle_ended" => "战斗已结束，无法劝降",
            "surrender.pending" => "已有待决的劝降请求，无法再次发起",
            "surrender.not_advantaged" => "当前不具备劝降优势（需敌方指挥舰沉没且其存活舰数不超过开战一半）",
            "surrender.already_offered" => "本回合已发起过劝降",
            "surrender.not_offered" => "当前没有待决的劝降请求",
            "surrender.gold_path_no_delivery" => "支付保全路径不接受交付",
            "surrender.delivery_count_mismatch" => "交付数量不符（应为 ⌊符合条件现存舰数÷3⌋）",
            "surrender.duplicate_delivery" => "交付舰不能重复",
            "surrender.ineligible_delivery" => "存在不可交付的舰船",
            null or "" => "操作失败",
            _ => $"操作失败：{reason}",
        };
    }
}
