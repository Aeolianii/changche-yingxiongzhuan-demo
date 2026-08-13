#nullable enable
using Godot;
using NavalCombat.Core;
using NavalCombat.Integration;
using NavalCombat.Levels;
using System;
using System.Collections.Generic;
using System.Linq;

namespace NanjiangNaval;

// L-3 关卡游玩协调（NavalDemo 根节点下的顶层 CanvasLayer，不随 Node2D 隐藏）：
//   目标条（ObjectiveBar）+ 教学提示条（HintBar）+ 关卡结算面板（ResultPanel：重试/返回关卡选择）。
//   数据源 = LevelSession.PendingLevelId → LevelRegistry 关卡定义；进度 = LevelProgress(user://progress.json)。
//   目标判定（LevelObjective.IsComplete）+ 实时进度（DescribeProgress）+ 教学提示分步推进（随动作触发）。
//   自由模式（PendingLevelId=="free"）→ 本层完全惰性（Visible=false），不干扰自由战斗结算。
//   战斗控制器在每次命令事件后调用 PostEvents（记录追踪器 + 推进提示 + 评估目标 + 刷新双条）；
//   战斗结束由 HandleBattleEnded → OnBattleEnded 走同一结算（ResolveLevelEnd）。
public partial class NavalLevelPlayController : CanvasLayer
{
    private const int HintContentFontSize = 21; // R-2 + V-10：提示条固定可读字号（17→21 加大，保证大字多行可读；不随提示长短变化）
    private LevelDefinition? _level;
    private LevelProgress? _progress;
    private LevelObjectiveTracker _tracker = new();
    private BattleState? _battle;
    private int _hintIndex;
    private int _hintViewIndex; // R-2：浏览视图索引（玩家翻页只改它；进度推进仍走 _hintIndex）
    private bool _levelEnded;
    private bool _victory;
    private BattleResult? _lastResult;
    private string? _hintFeedback; // 提示推进的正向反馈（"✓ 做对了！下一步：…" / 教学完成 / 通关/失败）

    private Panel? _objectiveBar;
    private Label? _objectiveContent;
    private Panel? _hintBar;
    private Label? _hintContent;
    private Button? _hintPrev, _hintNext; // R-2：提示条翻页（上一页/下一页）
    private Label? _hintPage;             // R-2：第 N/共 M 指示
    private bool _hintBarCollapsed;       // U-1：教学提示条是否已收起（收起时不挡地图点击，内容仍随进度刷新）
    private Button? _hintCollapseButton;  // U-1：提示条收起/展开按钮（提示条右侧）
    private Panel? _resultPanel;
    private Label? _resultContent;
    private Button? _nextLevelButton; // V-9：胜利结算面板「进入下一关」（存在已解锁下一关才显示）

    public override void _Ready()
    {
        Visible = false;
        _objectiveBar = GetNodeOrNull<Panel>("ObjectiveBar");
        _objectiveContent = GetNodeOrNull<Label>("ObjectiveBar/Box/Content");
        _hintBar = GetNodeOrNull<Panel>("HintBar");
        _hintContent = GetNodeOrNull<Label>("HintBar/Box/Content");
        _hintPrev = GetNodeOrNull<Button>("HintBar/Box/Nav/Prev");
        _hintNext = GetNodeOrNull<Button>("HintBar/Box/Nav/Next");
        _hintPage = GetNodeOrNull<Label>("HintBar/Box/Nav/Page");
        _resultPanel = GetNodeOrNull<Panel>("ResultPanel");
        _resultContent = GetNodeOrNull<Label>("ResultPanel/Box/Content");
        StyleRibbon(_objectiveBar);
        StyleRibbon(_hintBar);
        StylePanel(_resultPanel);
        if (_objectiveContent is not null) StyleText(_objectiveContent, 15, InkWashTheme.InkDeep);
        if (_hintContent is not null) StyleText(_hintContent, HintContentFontSize, InkWashTheme.TextInk); // R-2：固定可读字号
        if (_hintPage is not null) StyleText(_hintPage, 13, InkWashTheme.Ochre);
        if (_resultContent is not null) StyleText(_resultContent, 18, InkWashTheme.TextInk);
        if (_hintPrev is not null) { InkWashTheme.StyleHudButton(_hintPrev); _hintPrev.FocusMode = Control.FocusModeEnum.None; _hintPrev.Pressed += OnHintPrev; }
        if (_hintNext is not null) { InkWashTheme.StyleHudButton(_hintNext); _hintNext.FocusMode = Control.FocusModeEnum.None; _hintNext.Pressed += OnHintNext; }
        // U-1：目标条/提示条底板不挡地图点击（递归 mouse_filter=Ignore，翻页按钮保留）；提示条右侧提供收起/展开。
        if (_objectiveBar is not null) InkWashTheme.MakeClickTransparent(_objectiveBar);
        if (_hintBar is not null) InkWashTheme.MakeClickTransparent(_hintBar);
        _hintCollapseButton = GetNodeOrNull<Button>("CollapseHintBar");
        if (_hintCollapseButton is not null)
        {
            InkWashTheme.StyleHudButton(_hintCollapseButton);
            _hintCollapseButton.FocusMode = Control.FocusModeEnum.None;
            _hintCollapseButton.Pressed += ToggleHintBarCollapse;
        }
        if (GetNodeOrNull<Button>("ResultPanel/Box/Buttons/Retry") is { } retry)
        {
            StyleButton(retry);
            retry.FocusMode = Control.FocusModeEnum.None;
            retry.Pressed += () => GetTree().ReloadCurrentScene(); // 重试：重载本场景 → 同一关重建（PendingLevelId 仍在本关）
        }
        if (GetNodeOrNull<Button>("ResultPanel/Box/Buttons/Back") is { } back)
        {
            StyleButton(back);
            back.FocusMode = Control.FocusModeEnum.None;
            back.Pressed += () => GetTree().ChangeSceneToFile("res://scenes/naval/LevelSelect.tscn"); // 返回关卡选择
        }
        // V-9：胜利结算面板「进入下一关」——存在已解锁下一关时显示；点击直接进下一关（同关卡选择进入路径）。
        _nextLevelButton = GetNodeOrNull<Button>("ResultPanel/Box/Buttons/Next");
        if (_nextLevelButton is not null)
        {
            StyleButton(_nextLevelButton);
            _nextLevelButton.FocusMode = Control.FocusModeEnum.None;
            _nextLevelButton.Pressed += EnterNextLevel;
        }
        var def = LevelRegistry.GetById(LevelSession.PendingLevelId);
        _level = def is not null && def.Id != "free" ? def : null;
        if (_level is null) { Visible = false; return; } // 自由模式：不显示目标/提示/结算（沿用自由战斗结算）
        _progress = new LevelProgress(LevelRegistry.AllLevelIds, ProgressPath());
        _progress.Load();
        RefreshBars();
        Visible = true;
    }

    // 战斗开始由 BattleController.StartBattle 注入同一 BattleState（关卡战斗构建完成即绑定）。
    // 自由模式（_level==null）惰性：仅记引用，不刷新双条（RefreshBars 依赖 _level 非空）。
    public void BindBattle(BattleState battle)
    {
        _battle = battle;
        if (!LevelMode()) return;
        RefreshBars();
    }

    // 战斗控制器每次命令事件后调用：记录追踪器 → 按事件推进教学提示 → 评估目标（达成/超回合）→ 刷新双条。
    // command 仅玩家命令透传（敌方 AI 命令不传 command，不影响玩家目标计数）。
    public void PostEvents(BattleState battle, IReadOnlyList<BattleEvent> events, BattleCommand? command = null)
    {
        if (!LevelMode() || _levelEnded) return;
        _battle = battle;
        if (command is not null) _tracker.RecordCommand(battle, command, events);
        foreach (var e in events)
        {
            switch (e)
            {
                case ShipMovedEvent m when FactionOf(battle, m.ShipId) == FactionId.Player: TryAdvanceHint("move"); break;
                case ShipTurnedEvent t when FactionOf(battle, t.ShipId) == FactionId.Player: TryAdvanceHint("turn"); break;
                case ShipSunkEvent s when FactionOf(battle, s.ShipId) == FactionId.Enemy: TryAdvanceHint("sunk"); break;
            }
        }
        Evaluate();
        RefreshBars();
    }

    // 战斗结束（BattleEndedEvent → HandleBattleEnded → OnBattleEnded）：目标成败结算。
    // result 由战斗控制器已 Finalize（本层不再重复 Finalize，避免 BattleCleanup 二次执行）。
    public void OnBattleEnded(BattleState battle, BattleResult result)
    {
        if (!LevelMode()) return;
        _battle = battle;
        ResolveLevelEnd(result);
    }

    // ---- 布阵/战斗动作触发教学提示（由 Deployment/BattleController 在对应动作成功后调用） ----

    public void OnPlayerSelected() => TryAdvanceHint("select");
    public void OnRotated() => TryAdvanceHint("turn");
    public void OnEquipOpened() => TryAdvanceHint("equip");
    public void OnDeployConfirmed() => TryAdvanceHint("confirm");

    // ---- 目标评估 / 结算 ----

    private void Evaluate()
    {
        if (!LevelMode() || _levelEnded) return;
        var battle = _battle;
        if (battle is null) return;
        if (battle.BattleEnded) return; // 由 BattleEndedEvent → HandleBattleEnded → OnBattleEnded 统一结算
        // 战斗未结束也可即时达成（抵达目标格/用满技能/存活满回合）或超回合判负 → 强制收尾。
        if (_level!.Objective.ExceededMaxRounds(battle) || _level.Objective.IsComplete(battle, _tracker))
            ResolveLevelEnd();
    }

    // 统一结算：置结束标志 → 战斗未结束则 BattleEnded=true（锁输入）→ 网关 Finalize（战斗已结束由控制器传入结果，
    // 本层不重复 Finalize）→ 判定胜负 → 胜利落盘进度 → 结算面板。
    private void ResolveLevelEnd(BattleResult? result = null)
    {
        if (!LevelMode() || _levelEnded) return;
        var battle = _battle;
        if (battle is null) return;
        _levelEnded = true;
        var victory = _level!.Objective.IsComplete(battle, _tracker);
        if (!battle.BattleEnded) battle.BattleEnded = true;
        _lastResult = result ?? NavalBattleGateway.Finalize(battle);
        _victory = victory;
        if (victory) _progress!.MarkCompleted(_level.Id); // 立即落盘，关卡选择下一关解锁
        _hintIndex = _level.Hints.Count; // 达成/失败 → 教学结束
        _hintFeedback = victory ? "✓ 通关成功！" : "挑战失败，可重试本关";
        RefreshBars();
        ShowResultPanel(victory);
    }

    private void ShowResultPanel(bool victory)
    {
        if (_resultPanel is null || _resultContent is null) return;
        var next = ComputeNextLevelId();
        var nextUnlocked = next.Length > 0 && _progress is not null && _progress.IsUnlocked(next);
        _resultContent.Text = victory
            ? $"{_level!.Title}　通关成功\n目标：{_level.ObjectiveText}\n{ResultFooter(nextUnlocked, next)}"
            : $"{_level!.Title}　挑战失败\n{FailureText()}\n可重试本关或返回关卡选择";
        // V-9：「进入下一关」仅胜利且存在已解锁下一关时显示（失败/无下一关/未解锁隐藏）。
        if (_nextLevelButton is not null) _nextLevelButton.Visible = victory && nextUnlocked;
        _resultPanel.Visible = true;
    }

    // V-9：结算内容第三行——有已解锁下一关 → 引导直接进入；有下一关未解锁 → 提示回关卡选择；
    // 无下一关（最后一关）→ 提示已通关全部。
    private static string ResultFooter(bool nextUnlocked, string next)
        => nextUnlocked ? $"下一关已解锁：{next}（点击「进入下一关」直接开始）"
            : next.Length > 0 ? "下一关尚未解锁，可返回关卡选择查看"
            : "已通关全部关卡，可返回关卡选择重玩";

    // V-9：当前关在 LevelRegistry 线性序中的下一关 id（最后一关/非序列关 → 空串）。
    private string ComputeNextLevelId()
    {
        if (_level is null) return "";
        var ids = LevelRegistry.AllLevelIds;
        for (var i = 0; i < ids.Count - 1; i++)
            if (ids[i] == _level.Id) return ids[i + 1];
        return "";
    }

    // V-9：点击「进入下一关」→ 写 LevelSession + 切关卡游玩场景（与关卡选择点关进入同路径），无需返回关卡选择。
    private void EnterNextLevel()
    {
        var next = ComputeNextLevelId();
        if (next.Length == 0 || _progress is null || !_progress.IsUnlocked(next)) return;
        LevelSession.EnterLevel(next);
        GetTree().ChangeSceneToFile("res://scenes/naval/NavalDemo.tscn");
    }

    private string FailureText()
    {
        var battle = _battle!;
        if (_level!.Objective.ExceededMaxRounds(battle)) return "超出回合限制";
        var playerAlive = battle.Ships.Values.Any(s => s.Faction == FactionId.Player && s.HitPoints > 0);
        return playerAlive ? "目标未达成" : "舰队全灭";
    }

    // ---- 教学提示推进 ----

    // 当前提示与触发动作匹配 → 推进到下一步 + 正向反馈。
    // R-2：自动推进只动进度 _hintIndex；视图 _hintViewIndex 跟随回到当前，玩家翻页仍是纯浏览。
    private void TryAdvanceHint(string trigger)
    {
        if (!LevelMode() || _levelEnded || _hintIndex >= _level!.Hints.Count) return;
        if (!HintMatches(_level.Hints[_hintIndex], trigger)) return;
        _hintIndex++;
        _hintViewIndex = _hintIndex; // 自动推进 → 视图跟随当前提示
        _hintFeedback = _hintIndex < _level.Hints.Count
            ? $"✓ 做对了！下一步：{_level.Hints[_hintIndex]}"
            : "✓ 教学完成！";
        RefreshHintBar(); // 即时刷新提示条，正向反馈立即可见（选中/布阵等非战斗事件路径无 PostEvents 兜底）
    }

    // ---- R-2 翻页（纯浏览视图，不触碰进度 _hintIndex）----

    private void OnHintPrev()
    {
        if (!LevelMode() || _levelEnded || _hintIndex >= _level!.Hints.Count) return;
        if (_hintViewIndex <= 0) return;
        _hintViewIndex--;
        RefreshHintBar();
    }

    private void OnHintNext()
    {
        if (!LevelMode() || _levelEnded || _hintIndex >= _level!.Hints.Count) return;
        if (_hintViewIndex >= _level!.Hints.Count - 1) return;
        _hintViewIndex++;
        RefreshHintBar();
    }

    private static bool HintMatches(string hint, string trigger) => trigger switch
    {
        "select" => hint.Contains("选中") || hint.Contains("点选") || hint.Contains("点击己方舰"),
        "move" => hint.Contains("移动"),
        "turn" => hint.Contains("旋转") || hint.Contains("朝向"),
        "equip" => hint.Contains("装备"),
        "confirm" => hint.Contains("确认布阵") || hint.Contains("开始战斗"),
        "sunk" => hint.Contains("击沉"),
        _ => false,
    };

    // ---- 双条刷新 ----

    private void RefreshBars()
    {
        if (_objectiveContent is not null)
        {
            var text = _level!.ObjectiveText;
            if (_battle is not null) text += "　" + _level.Objective.DescribeProgress(_battle, _tracker);
            _objectiveContent.Text = text;
        }
        RefreshHintBar();
    }

    private void RefreshHintBar()
    {
        if (_hintContent is null || _hintBar is null) return;
        if (!LevelMode()) { _hintBar.Visible = false; return; }
        var count = _level!.Hints.Count;
        var done = _hintIndex >= count; // 教学完成 / 结算后：显示完成反馈，不展示单条提示
        if (done)
        {
            _hintContent.Text = _hintFeedback ?? "教学完成";
        }
        else
        {
            _hintViewIndex = Math.Clamp(_hintViewIndex, 0, count - 1);
            var text = _level.Hints[_hintViewIndex];
            if (_hintViewIndex == _hintIndex)
            {
                // 当前（进度推进到的）提示：带正向反馈时保留"下一步"格式（反馈已含提示则不重复；
                // "✓ 教学完成！" 不含提示 → 追加括号内容供玩家回看）；无反馈时加「〔当前〕」标记。
                _hintContent.Text = _hintFeedback is null
                    ? $"〔当前〕　{text}"
                    : _hintFeedback!.Contains(text)
                        ? _hintFeedback
                        : $"{_hintFeedback}　（{text}）";
            }
            else
            {
                // 翻页浏览已给/未给的提示：只显示该提示文本，不带当前标记。
                _hintContent.Text = text;
            }
        }
        RefreshHintNav(count, done);
        // U-1：收起状态保持条隐藏（内容仍随进度刷新，展开即见最新）。
        _hintBar.Visible = !_hintBarCollapsed;
    }

    // R-2：翻页控件显隐与可用态 + 第 N/共 M 指示（仅多条提示时显示；教学完成后禁用）。
    private void RefreshHintNav(int count, bool done)
    {
        var multi = count > 1;
        if (_hintPrev is not null)
        {
            _hintPrev.Visible = multi;
            _hintPrev.Disabled = done || _hintViewIndex <= 0;
        }
        if (_hintNext is not null)
        {
            _hintNext.Visible = multi;
            _hintNext.Disabled = done || _hintViewIndex >= count - 1;
        }
        if (_hintPage is not null)
        {
            _hintPage.Visible = multi;
            _hintPage.Text = done ? $"第 {count}/{count} 步" : $"第 {_hintViewIndex + 1}/{count} 步";
        }
    }

    // ---- 只读状态（headless 断言用） ----

    public bool LevelMode() => _level is not null;
    public string LevelId() => _level?.Id ?? "";
    public string ObjectiveBarText() => _objectiveContent?.Text ?? "";
    public int HintIndex() => _hintIndex;
    public string HintText() => _hintContent?.Text ?? "";
    // R-2 翻页/字号只读（headless 断言用）：浏览视图索引 / 第 N 共 M 指示 / 上一页/下一页可见与可用 / 固定字号。
    public int HintViewIndex() => _hintViewIndex;
    public string HintPageText() => _hintPage?.Text ?? "";
    public bool HintPrevVisible() => _hintPrev?.IsVisibleInTree() ?? false;
    public bool HintNextVisible() => _hintNext?.IsVisibleInTree() ?? false;
    public bool HintPrevEnabled() => _hintPrev is { Visible: true, Disabled: false };
    public bool HintNextEnabled() => _hintNext is { Visible: true, Disabled: false };
    public int HintFontSize() => _hintContent?.GetThemeFontSize("font_size") ?? 0;
    // V-10：提示条框高（headless 断言框高加大后仍符合；未取到节点返回 -1）。
    public float HintBarHeight() => _hintBar is null ? -1f : _hintBar.Size.Y;
    // U-1：提示条收起/展开切换——收起时整条提示隐去（Visible=false 不挡地图点击），展开恢复。
    public void ToggleHintBarCollapse()
    {
        _hintBarCollapsed = !_hintBarCollapsed;
        if (_hintBar is not null) _hintBar.Visible = !_hintBarCollapsed;
        if (_hintCollapseButton is not null)
            _hintCollapseButton.Text = _hintBarCollapsed ? "展开提示" : "收起提示";
    }

    public bool HintBarCollapsed() => _hintBarCollapsed;
    public bool HintBarVisible() => _hintBar?.Visible ?? false;
    public bool LevelEnded() => _levelEnded;
    public bool LevelVictory() => _victory;
    public bool LevelResultVisible() => _resultPanel?.Visible ?? false;
    public int ResultOutcome() => _lastResult is null ? -1 : (int)_lastResult.Outcome;
    public bool IsCompleted(string id) => _progress?.IsCompleted(id) ?? false;
    public bool IsUnlocked(string id) => _progress?.IsUnlocked(id) ?? false;
    // V-9：「进入下一关」按钮是否可见（headless 断言 通关后下一关解锁可见 / 最后关无按钮）。
    public bool NextLevelButtonVisible() => _nextLevelButton is { Visible: true } && _nextLevelButton.IsVisibleInTree();
    // V-9：当前关线性序下一关 id（最后关空串，headless 断言用）。
    public string NextLevelId() => ComputeNextLevelId();

    // ---- 测试钩子 ----

    // 干净基线：换用临时保存路径的清空进度（不影响 user:// 真实进度；临时文件由 OS 清理）。
    public void ResetProgressForTest()
    {
        if (!LevelMode()) return;
        _progress = new LevelProgress(LevelRegistry.AllLevelIds,
            System.IO.Path.Combine(System.IO.Path.GetTempPath(), $"naval_level_play_{Guid.NewGuid():N}.json"));
        _progress.Load();
    }

    // V-9：测试钩子（headless）——把当前游玩关上下文切到指定关并刷新结算按钮（仿 ResetProgressForTest 风格）。
    // 不重载场景/不重建战斗，仅改 _level/_victory 数据源：断言「最后关（3-2）无下一关按钮」等纯判定用。
    public void ForceLevelContextForTest(string id)
    {
        var def = LevelRegistry.GetById(id);
        if (def is null || def.Id == "free") return;
        _level = def;
        _victory = true; // 模拟"刚胜利"：判定只在 胜利 && 下一关非空且解锁 下显示按钮
        var next = ComputeNextLevelId();
        if (_nextLevelButton is not null)
            _nextLevelButton.Visible = next.Length > 0 && _progress is not null && _progress.IsUnlocked(next);
        if (_resultPanel is not null) _resultPanel.Visible = true; // 模拟结算面板已展示（配合 NextLevelButtonVisible 的树可见性）
    }

    // ---- 辅助 ----

    private static string ProgressPath()
        => ProjectSettings.GlobalizePath("user://progress.json");

    private static FactionId? FactionOf(BattleState battle, string shipId)
    {
        if (battle.Ships.TryGetValue(shipId, out var ship)) return ship.Faction;
        if (battle.RemovedShips.TryGetValue(shipId, out var rec)) return rec.Faction;
        return null;
    }

    private static void StylePanel(Panel? panel)
    {
        if (panel is not null) panel.AddThemeStyleboxOverride("panel", InkWashTheme.PanelCard());
    }

    private static void StyleRibbon(Panel? panel)
    {
        if (panel is not null) panel.AddThemeStyleboxOverride("panel", InkWashTheme.HudRibbon());
    }

    private static void StyleButton(Button b) => InkWashTheme.StyleButton(b);

    private static void StyleText(Label l, int size, Color color)
    {
        l.AddThemeFontOverride("font", InkWashTheme.Font());
        l.AddThemeFontSizeOverride("font_size", size);
        l.AddThemeColorOverride("font_color", color);
    }
}
