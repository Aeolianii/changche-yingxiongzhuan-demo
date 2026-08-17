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
//   干笔教学提示条（HintBar）+ 关卡结算面板（ResultPanel：重试/返回关卡选择）。
//   数据源 = LevelSession.PendingLevelId → LevelRegistry 关卡定义；进度 = LevelProgress(user://progress.json)。
//   目标判定（LevelObjective.IsComplete）+ 实时进度（DescribeProgress）+ 教学提示分步推进（随动作触发）。
//   自由模式（PendingLevelId=="free"）→ 本层完全惰性（Visible=false），不干扰自由战斗结算。
//   战斗控制器在每次命令事件后调用 PostEvents（记录追踪器 + 推进提示 + 评估目标 + 刷新双条）；
//   战斗结束由 HandleBattleEnded → OnBattleEnded 走同一结算（ResolveLevelEnd）。
public partial class NavalLevelPlayController : CanvasLayer
{
    private const int HintTitleFontSize = 24;
    private const int HintContentFontSize = 20;
    private const int HintToggleFontSize = 20;
    private const float HintFadeOutSeconds = 0.18f;
    private const float HintFadeInSeconds = 0.24f;
    private static readonly Color HintTitleGold = new("f0c865");
    private static readonly Color HintBodyPaper = new("f4e8cd");
    private LevelDefinition? _level;
    private LevelProgress? _progress;
    private LevelObjectiveTracker _tracker = new();
    private BattleState? _battle;
    private int _hintIndex;
    private int _hintViewIndex; // 当前正在显示的步骤索引；自动推进时与 _hintIndex 同步。
    private bool _levelEnded;
    private bool _victory;
    private BattleResult? _lastResult;
    private string? _hintFeedback; // 教学完成、通关或失败时的收尾反馈。

    private Panel? _hintBar;
    private Label? _hintTitle;
    private Label? _hintContent;
    private Button? _hintPrev, _hintNext; // 旧翻页节点，仅为场景兼容保留并永久隐藏。
    private Label? _hintPage;             // 旧页码节点，仅为场景兼容保留并永久隐藏。
    private bool _hintBarCollapsed;       // U-1：教学提示条是否已收起（收起时不挡地图点击，内容仍随进度刷新）
    private Button? _hintCollapseButton;  // U-1：提示条收起/展开按钮（提示条右侧）
    private Panel? _resultPanel;
    private Label? _resultContent;
    private Button? _nextLevelButton; // V-9：胜利结算面板「进入下一关」（存在已解锁下一关才显示）
    private Tween? _hintTransitionTween;
    private bool _hintTransitionPending;

    public override void _Ready()
    {
        Visible = false;
        _hintBar = GetNodeOrNull<Panel>("HintBar");
        _hintTitle = GetNodeOrNull<Label>("HintBar/Box/Title");
        _hintContent = GetNodeOrNull<Label>("HintBar/Box/Content");
        _hintPrev = GetNodeOrNull<Button>("HintBar/Box/Nav/Prev");
        _hintNext = GetNodeOrNull<Button>("HintBar/Box/Nav/Next");
        _hintPage = GetNodeOrNull<Label>("HintBar/Box/Nav/Page");
        _resultPanel = GetNodeOrNull<Panel>("ResultPanel");
        _resultContent = GetNodeOrNull<Label>("ResultPanel/Box/Content");
        StyleBrushHint(_hintBar);
        StylePanel(_resultPanel);
        if (_hintTitle is not null) StyleOutlinedText(_hintTitle, HintTitleFontSize, HintTitleGold, 4);
        if (_hintContent is not null) StyleOutlinedText(_hintContent, HintContentFontSize, HintBodyPaper, 4);
        if (_hintPage is not null) StyleText(_hintPage, 13, HintTitleGold);
        if (_resultContent is not null) StyleText(_resultContent, 18, InkWashTheme.TextInk);
        if (_hintPrev is not null) { InkWashTheme.StyleHudButton(_hintPrev); _hintPrev.FocusMode = Control.FocusModeEnum.None; _hintPrev.Pressed += OnHintPrev; }
        if (_hintNext is not null) { InkWashTheme.StyleHudButton(_hintNext); _hintNext.FocusMode = Control.FocusModeEnum.None; _hintNext.Pressed += OnHintNext; }
        // U-1：提示条底板不挡地图点击；旧翻页节点隐藏，提示条右侧只保留收起/展开。
        if (_hintBar is not null) InkWashTheme.MakeClickTransparent(_hintBar);
        _hintCollapseButton = GetNodeOrNull<Button>("CollapseHintBar");
        if (_hintCollapseButton is not null)
        {
            StyleHintToggle(_hintCollapseButton);
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
        _hintTransitionTween?.Kill();
        _hintTransitionTween = null;
        _hintTransitionPending = false;
        if (_hintBar is not null) _hintBar.Modulate = Colors.White;
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

    // 当前提示与触发动作匹配 → 淡出当前墨条并自动进入下一步。
    private void TryAdvanceHint(string trigger)
    {
        if (!LevelMode() || _levelEnded || _hintIndex >= _level!.Hints.Count) return;
        if (!HintMatches(_level.Hints[_hintIndex], trigger)) return;
        _hintIndex++;
        _hintViewIndex = _hintIndex;
        _hintFeedback = _hintIndex < _level.Hints.Count ? null : "已掌握本关操作";
        TransitionToCurrentHint();
    }

    // 完成当前目标后由旧提示淡出，切换内容，再让新提示淡入；headless 直接更新以保持测试确定性。
    private void TransitionToCurrentHint()
    {
        if (_hintBar is null || _hintBarCollapsed || DisplayServer.GetName() == "headless")
        {
            _hintTransitionPending = false;
            RefreshHintBar();
            return;
        }
        _hintTransitionTween?.Kill();
        _hintTransitionPending = true;
        _hintTransitionTween = CreateTween()
            .SetTrans(Tween.TransitionType.Cubic)
            .SetEase(Tween.EaseType.Out);
        _hintTransitionTween.TweenProperty(_hintBar, "modulate:a", 0.0f, HintFadeOutSeconds);
        _hintTransitionTween.TweenCallback(Callable.From(() =>
        {
            _hintTransitionPending = false;
            RefreshHintBar();
        }));
        _hintTransitionTween.TweenProperty(_hintBar, "modulate:a", 1.0f, HintFadeInSeconds)
            .SetEase(Tween.EaseType.In);
    }

    // ---- 旧翻页兼容入口（场景节点隐藏，不再提供给玩家）----

    private void OnHintPrev()
    {
        if (!LevelMode() || _levelEnded || _hintIndex >= _level!.Hints.Count) return;
        if (_hintViewIndex <= 0) return;
        _hintViewIndex--;
        if (!_hintTransitionPending) RefreshHintBar();
    }

    private void OnHintNext()
    {
        if (!LevelMode() || _levelEnded || _hintIndex >= _level!.Hints.Count) return;
        if (_hintViewIndex >= _level!.Hints.Count - 1) return;
        _hintViewIndex++;
        if (!_hintTransitionPending) RefreshHintBar();
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
        if (!_hintTransitionPending) RefreshHintBar();
    }

    private void RefreshHintBar()
    {
        if (_hintTitle is null || _hintContent is null || _hintBar is null) return;
        if (!LevelMode()) { _hintBar.Visible = false; return; }
        var count = _level!.Hints.Count;
        var done = _hintIndex >= count; // 教学完成 / 结算后：显示完成反馈，不展示单条提示
        if (done)
        {
            _hintTitle.Text = "教学完成";
            _hintContent.Text = _hintFeedback ?? "教学完成";
        }
        else
        {
            _hintViewIndex = Math.Clamp(_hintViewIndex, 0, count - 1);
            var text = _level.Hints[_hintViewIndex];
            _hintTitle.Text = $"第{ChineseStep(_hintViewIndex + 1)}步 · {HintActionTitle(text)}";
            _hintContent.Text = text;
        }
        RefreshHintNav(count, done);
        // U-1：收起状态保持条隐藏（内容仍随进度刷新，展开即见最新）。
        _hintBar.Visible = !_hintBarCollapsed;
    }

    // 教程只展示当前步骤并自动推进；旧翻页节点保留兼容场景结构，但始终隐藏。
    private void RefreshHintNav(int count, bool done)
    {
        if (_hintPrev is not null)
        {
            _hintPrev.Visible = false;
            _hintPrev.Disabled = true;
        }
        if (_hintNext is not null)
        {
            _hintNext.Visible = false;
            _hintNext.Disabled = true;
        }
        if (_hintPage is not null)
        {
            _hintPage.Visible = false;
            _hintPage.Text = done ? $"第 {count}/{count} 步" : $"第 {_hintViewIndex + 1}/{count} 步";
        }
    }

    private static string ChineseStep(int step) => step switch
    {
        1 => "一", 2 => "二", 3 => "三", 4 => "四", 5 => "五",
        6 => "六", 7 => "七", 8 => "八", 9 => "九", _ => step.ToString(),
    };

    private static string HintActionTitle(string hint)
    {
        if (hint.Contains("装备")) return "装备舰船";
        if (hint.Contains("确认布阵") || hint.Contains("开始战斗")) return "开始战斗";
        if (hint.Contains("自沉")) return "浅滩自沉";
        if (hint.Contains("撞击")) return "撞击敌舰";
        if (hint.Contains("连锁弹")) return "使用连锁弹";
        if (hint.Contains("砲击")) return "使用砲击";
        if (hint.Contains("击沉") || hint.Contains("箭雨")) return "击沉敌舰";
        if (hint.Contains("抵达")) return "抵达目标";
        if (hint.Contains("选中") || hint.Contains("点选") || hint.Contains("点击己方舰")) return "选中舰船";
        if (hint.Contains("旋转") || hint.Contains("朝向")) return "调整朝向";
        if (hint.Contains("移动") || hint.Contains("目标格")) return "移动舰船";
        return "战术提示";
    }

    // ---- 只读状态（headless 断言用） ----

    public bool LevelMode() => _level is not null;
    public string LevelId() => _level?.Id ?? "";
    public int HintIndex() => _hintIndex;
    public string HintText() => _hintContent?.Text ?? "";
    // 教程提示只读状态（headless 断言用）：当前步骤、旧翻页节点隐藏态、字体与墨条规格。
    public int HintViewIndex() => _hintViewIndex;
    public string HintTitleText() => _hintTitle?.Text ?? "";
    public string HintPageText() => _hintPage?.Text ?? "";
    public bool HintPrevVisible() => _hintPrev?.IsVisibleInTree() ?? false;
    public bool HintNextVisible() => _hintNext?.IsVisibleInTree() ?? false;
    public bool HintPrevEnabled() => _hintPrev is { Visible: true, Disabled: false };
    public bool HintNextEnabled() => _hintNext is { Visible: true, Disabled: false };
    public int HintFontSize() => _hintContent?.GetThemeFontSize("font_size") ?? 0;
    public int HintTitleFontSizeValue() => _hintTitle?.GetThemeFontSize("font_size") ?? 0;
    public int HintToggleFontSizeValue() => _hintCollapseButton?.GetThemeFontSize("font_size") ?? 0;
    public int HintTitleOutlineSize() => _hintTitle?.GetThemeConstant("outline_size") ?? 0;
    public int HintBodyOutlineSize() => _hintContent?.GetThemeConstant("outline_size") ?? 0;
    public string HintTitleColor() => _hintTitle?.GetThemeColor("font_color").ToHtml(false) ?? "";
    public string HintBodyColor() => _hintContent?.GetThemeColor("font_color").ToHtml(false) ?? "";
    public string HintOutlineColor() => _hintContent?.GetThemeColor("font_outline_color").ToHtml(false) ?? "";
    public float HintBarWidth() => _hintBar is null ? -1f : _hintBar.Size.X;
    public float HintTransitionSeconds() => HintFadeOutSeconds + HintFadeInSeconds;
    public bool HintUsesBrushTexture()
        => GetNodeOrNull<TextureRect>("HintBar/Backdrop")?.Texture?.ResourcePath
            == "res://assets/naval/ui/tutorial/tutorial_dry_brush_strip_v1.png";
    // V-10：提示条框高（headless 断言框高加大后仍符合；未取到节点返回 -1）。
    public float HintBarHeight() => _hintBar is null ? -1f : _hintBar.Size.Y;
    // U-1：提示条收起/展开切换——收起时整条提示隐去（Visible=false 不挡地图点击），展开恢复。
    public void ToggleHintBarCollapse()
    {
        _hintBarCollapsed = !_hintBarCollapsed;
        if (_hintBar is not null)
        {
            _hintTransitionTween?.Kill();
            _hintTransitionTween = null;
            _hintTransitionPending = false;
            _hintBar.Modulate = Colors.White;
            if (!_hintBarCollapsed) RefreshHintBar();
            _hintBar.Visible = !_hintBarCollapsed;
        }
        if (_hintCollapseButton is not null)
            _hintCollapseButton.Text = _hintBarCollapsed ? "展开" : "收起";
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

    private static void StyleBrushHint(Panel? panel)
    {
        if (panel is not null) panel.AddThemeStyleboxOverride("panel", new StyleBoxEmpty());
    }

    private static void StyleButton(Button b) => InkWashTheme.StyleButton(b);

    private static void StyleHintToggle(Button button)
    {
        foreach (var state in new[] { "normal", "hover", "pressed", "disabled", "focus" })
            button.AddThemeStyleboxOverride(state, new StyleBoxEmpty());
        button.AddThemeFontOverride("font", InkWashTheme.Font());
        button.AddThemeFontSizeOverride("font_size", HintToggleFontSize);
        button.AddThemeColorOverride("font_color", HintBodyPaper);
        button.AddThemeColorOverride("font_hover_color", HintTitleGold);
        button.AddThemeColorOverride("font_pressed_color", Colors.White);
        button.AddThemeColorOverride("font_outline_color", Colors.Black);
        button.AddThemeConstantOverride("outline_size", 3);
        button.MouseDefaultCursorShape = Control.CursorShape.PointingHand;
    }

    private static void StyleText(Label l, int size, Color color)
    {
        l.AddThemeFontOverride("font", InkWashTheme.Font());
        l.AddThemeFontSizeOverride("font_size", size);
        l.AddThemeColorOverride("font_color", color);
    }

    private static void StyleOutlinedText(Label label, int size, Color color, int outlineSize)
    {
        StyleText(label, size, color);
        label.AddThemeColorOverride("font_outline_color", Colors.Black);
        label.AddThemeConstantOverride("outline_size", outlineSize);
    }
}
