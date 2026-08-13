#nullable enable
using Godot;
using NavalCombat.Core;
using NavalCombat.Levels;
using System;
using System.Collections.Generic;
using System.Linq;

namespace NanjiangNaval;

// L-2 关卡选择界面（主菜单）：章节分组 → 关卡列表 → 进入关卡/自由模式。
// 数据源 = LevelRegistry（章节/关卡）+ LevelProgress（锁定/可玩/已通关，user://progress.json）。
// 视图两层：章节列表（ChapterRoot）→ 点章节进关卡列表（LevelRoot）。关卡卡片状态由 LevelProgress 判定：
//   已通关（✓ 赭石，可重玩）/ 可进入（墨青）/ 未解锁（淡墨 + 整卡置灰，点按提示解锁条件）。
// 进入关卡/自由模式：记录目标 id + LevelSession.EnterLevel(id) + 切到 NavalDemo.tscn（L-3 改切关卡游玩场景）。
// 水墨风沿用 InkWashTheme 字体与色板，背景、标题牌和按钮框使用生成式像素水墨位图。
public partial class LevelSelectController : Control
{
    private const string SceneTwoPath = "res://scenes/Scene2.tscn";
    private const string ReturnContextMeta = "scene_two_naval_return_context";
    private const float SceneFadeDuration = 0.9f;
    private const string ButtonFramePath = "res://assets/naval/ui/level_select_vertical_frame.png";
    private const string ReturnBrushPath = "res://assets/naval/ui/level_select_return_brush.png";
    private const string PageLeftPath = "res://assets/naval/ui/level_select_page_left.png";
    private const string PageRightPath = "res://assets/naval/ui/level_select_page_right.png";
    private static readonly Rect2 ButtonFrameRegion = new(63, 86, 703, 1749);
    // V-11：一章卡宽 = 章节卡宽 = 三角分页翻动步长（BuildChapterList 卡宽与此同源，保证翻页按一章）。
    private const float ChapterCardWidth = 190f;
    // 章节分组（3 章 + 自由模式 + 实战操演）：章节枚举 / 标题 / 副标题（关卡数取自 LevelRegistry.ByChapter）。
    private static readonly (LevelChapter Chapter, string Title, string Subtitle)[] Chapters =
    {
        (LevelChapter.Chapter1, "第一章 · 基础操控", "移动 / 转向 / 布阵 / 装备"),
        (LevelChapter.Chapter2, "第二章 · 作战进阶", "远程攻击 / 撞击接舷 / 技能运用"),
        (LevelChapter.Chapter3, "第三章 · 环境特殊", "天气 / 地形 / 特殊行动"),
        (LevelChapter.Free, "自由演练", "沙盒演练 · 无固定目标"),
        (LevelChapter.Test, "实战操演", "固定地图×敌人组合演练"),
    };

    private static readonly Color LockedModulate = new(0.70f, 0.70f, 0.66f); // 未解锁卡片整体置灰

    private LevelProgress _progress = null!;
    private string? _lastEnteredLevelId;
    private string _lastMessage = "";
    private int _currentChapter = -1; // -1 = 章节列表视图
    private bool _randomDifficultyView; // 随机遭遇战难度选择视图（点 Level_random 后、进入或返回前）
    private int _seedCounter; // 随机遭遇种子递增（保证重掷/再进换一场）

    private HBoxContainer _chapterRoot = null!;
    private HBoxContainer _levelRoot = null!;
    private ScrollContainer _chapterScroll = null!;
    private Button _scrollLeft = null!;
    private Button _scrollRight = null!;
    private Label _subtitle = null!;
    private Label _progressLabel = null!;
    private Label _hintLabel = null!;
    private Button _levelBack = null!;
    private Texture2D _returnBrush = null!;
    private AtlasTexture _buttonFrame = null!;
    private ColorRect _sceneFade = null!;
    private bool _sceneTransitioning;

    public override void _Ready()
    {
        // U-2c：回到主菜单即结束上一场随机遭遇（NavalDemo 各控制器按 Active 判定遭遇模式）。
        RandomEncounterSession.Clear();
        // V-7：回到主菜单即结束活动舰队预设（布阵「再来一局」沿用同一会话，返回主菜单则重置）。
        FleetPresetSession.Clear();
        // L-1 预留口径：user:// 进度路径 GlobalizePath 解析后传入 LevelProgress。
        _progress = new LevelProgress(LevelRegistry.AllLevelIds, ProgressPath());
        _progress.Load();

        // 章节卡片包进横向 ScrollContainer；滚动条隐藏，只通过两侧翻页钮切换。
        _chapterScroll = GetNode<ScrollContainer>("ChapterScroll");
        _chapterRoot = GetNode<HBoxContainer>("ChapterScroll/ChapterRoot");
        _levelRoot = GetNode<HBoxContainer>("LevelRoot");
        _subtitle = GetNode<Label>("Subtitle");
        _progressLabel = GetNode<Label>("ProgressLabel");
        _hintLabel = GetNode<Label>("HintLabel");
        _levelBack = GetNode<Button>("LevelBack");

        _buttonFrame = new AtlasTexture
        {
            Atlas = GD.Load<Texture2D>(ButtonFramePath),
            Region = ButtonFrameRegion,
        };
        _returnBrush = GD.Load<Texture2D>(ReturnBrushPath);
        // V-11：滚动区两侧水墨像素翻页钮：点一次按一章卡宽分页翻动，钳制在 [0, 最大滚动]。
        _scrollLeft = GetNode<Button>("ScrollLeft");
        _scrollRight = GetNode<Button>("ScrollRight");
        StyleScrollArrow(_scrollLeft, PageLeftPath);
        StyleScrollArrow(_scrollRight, PageRightPath);
        _scrollLeft.Pressed += PageLeft;
        _scrollRight.Pressed += PageRight;
        ConfigureChapterPaging();
        RefreshArrowStates();

        StyleText(GetNode<Label>("Title"), 36, InkWashTheme.PaperLight, 5, InkWashTheme.InkDeep);
        StyleText(_subtitle, 20, new Color("d8d2c2"), 4, InkWashTheme.InkDeep);
        StyleText(_progressLabel, 23, new Color("e4c476"), 4, InkWashTheme.InkDeep);
        StyleText(_hintLabel, 23, InkWashTheme.PaperLight, 4, InkWashTheme.InkDeep);
        StyleVerticalButton(_levelBack, 28);
        _levelBack.FocusMode = Control.FocusModeEnum.None;
        _levelBack.Pressed += GoBack;
        var mainReturn = GetNode<Button>("MainReturnButton");
        StyleMainReturnButton(mainReturn);
        mainReturn.FocusMode = FocusModeEnum.None;
        mainReturn.Pressed += ReturnToSceneTwo;

        BuildChapterList();
        ShowChapterList();
        SetHint("击鼓点将，选择操演章程 · 自由模式随时可入");
        CreateSceneFade();
    }

    private static string ProgressPath()
        => ProjectSettings.GlobalizePath("user://progress.json");

    private bool HasSceneTwoReturnContext()
        => GetTree().Root.HasMeta(ReturnContextMeta);

    private void CreateSceneFade()
    {
        _sceneFade = new ColorRect
        {
            Name = "SceneTransitionFade",
            Color = Colors.Black,
            MouseFilter = MouseFilterEnum.Stop,
            ZIndex = 1000,
        };
        AddChild(_sceneFade);
        _sceneFade.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        if (!HasSceneTwoReturnContext())
        {
            _sceneFade.Hide();
            _sceneFade.MouseFilter = MouseFilterEnum.Ignore;
            return;
        }

        _sceneTransitioning = true;
        _sceneFade.Modulate = Colors.White;
        var fadeIn = CreateTween().SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.InOut);
        fadeIn.TweenProperty(_sceneFade, "modulate:a", 0.0f, SceneFadeDuration);
        fadeIn.Finished += () =>
        {
            _sceneFade.Hide();
            _sceneFade.MouseFilter = MouseFilterEnum.Ignore;
            _sceneTransitioning = false;
        };
    }

    private void ReturnToSceneTwo()
    {
        if (_sceneTransitioning) return;
        if (!HasSceneTwoReturnContext())
        {
            SetHint("当前从独立操演入口启动，没有可返回的甲板场景");
            return;
        }

        _sceneTransitioning = true;
        _sceneFade.Show();
        _sceneFade.MouseFilter = MouseFilterEnum.Stop;
        _sceneFade.Modulate = new Color(1f, 1f, 1f, 0f);
        var fadeOut = CreateTween().SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.InOut);
        fadeOut.TweenProperty(_sceneFade, "modulate:a", 1.0f, SceneFadeDuration);
        fadeOut.Finished += CompleteReturnToSceneTwo;
    }

    private void CompleteReturnToSceneTwo()
    {
        var error = GetTree().ChangeSceneToFile(SceneTwoPath);
        if (error == Error.Ok) return;

        _sceneTransitioning = false;
        SetHint("返回甲板失败，请稍后重试");
        var fadeBack = CreateTween();
        fadeBack.TweenProperty(_sceneFade, "modulate:a", 0.0f, 0.2f);
        fadeBack.Finished += () =>
        {
            _sceneFade.Hide();
            _sceneFade.MouseFilter = MouseFilterEnum.Ignore;
        };
    }

    // ---- 章节列表视图 ----

    private void BuildChapterList()
    {
        ClearChildren(_chapterRoot);
        for (var i = 0; i < Chapters.Length; i++)
        {
            var (_, title, subtitle) = Chapters[i];
            var card = new Button
            {
                Name = $"Chapter_{i}",
                Text = "",
                CustomMinimumSize = new Vector2(ChapterCardWidth, 620),
                SizeFlagsVertical = Control.SizeFlags.ShrinkCenter,
            };
            StyleVerticalButton(card, 19);
            AddVerticalContent(card, title, subtitle, null, 32, 22, 18);
            card.FocusMode = Control.FocusModeEnum.None;
            var index = i;
            card.Pressed += () => OpenChapter(index);
            _chapterRoot.AddChild(card);
        }
    }

    // 隐藏内部横向滚动条，只保留其 Range/Value 作为分页状态来源；
    // 到达左右边界时由 RefreshArrowStates 同步按钮亮暗与可点击状态。
    private void ConfigureChapterPaging()
    {
        var bar = _chapterScroll.GetHScrollBar();
        bar.Visible = false;
        bar.MouseFilter = MouseFilterEnum.Ignore;
        bar.ValueChanged += _ => RefreshArrowStates();
        bar.Connect("changed", Callable.From(RefreshArrowStates));
    }

    // ---- V-11：滚动区两侧左右三角分页翻章 ----

    // 左三角：向前翻一章（scroll_horizontal - 一章卡宽，钳制下限 0）。
    private void PageLeft()
    {
        _chapterScroll.ScrollHorizontal = Mathf.Max(0, _chapterScroll.ScrollHorizontal - (int)ChapterCardWidth);
        RefreshArrowStates();
    }

    // 右三角：向后翻一章（scroll_horizontal + 一章卡宽，钳制上限 = 最大滚动）。
    private void PageRight()
    {
        _chapterScroll.ScrollHorizontal = Mathf.Min(MaxChapterScroll(), _chapterScroll.ScrollHorizontal + (int)ChapterCardWidth);
        RefreshArrowStates();
    }

    // 最大可滚动量：内容总宽 - 视口宽（HScrollBar.MaxValue - Page）。
    private int MaxChapterScroll() => (int)Mathf.Round(_chapterScroll.GetHScrollBar().MaxValue - _chapterScroll.GetHScrollBar().Page);

    // 刷新三角可用态：最左 → 左禁用；最右 → 右禁用。
    // HScrollBar 拖动 / 滚轮横滚 / 三角翻页任一改变 scroll_horizontal 都会触发，边界置灰始终同步。
    private void RefreshArrowStates()
    {
        var max = MaxChapterScroll();
        _scrollLeft.Disabled = _chapterScroll.ScrollHorizontal <= 0;
        _scrollRight.Disabled = _chapterScroll.ScrollHorizontal >= max;
    }

    // 返回章节列表视图。
    public void ShowChapterList()
    {
        _currentChapter = -1;
        _subtitle.Text = Verticalize("厂车县令请检阅南疆水师");
        _levelRoot.Visible = false;
        _levelBack.Visible = false;
        _chapterRoot.Visible = true;
        _scrollLeft.Visible = true;
        _scrollRight.Visible = true;
        RefreshProgressLabel();
    }

    // ---- 关卡列表视图 ----

    // 打开指定章节（0..3）→ 生成该章关卡卡片。
    public void OpenChapter(int index)
    {
        if (index < 0 || index >= Chapters.Length) return;
        _currentChapter = index;
        var (chapter, title, subtitle) = Chapters[index];
        _subtitle.Text = Verticalize($"{title}·{subtitle}");
        _chapterRoot.Visible = false;
        _levelRoot.Visible = true;
        _levelBack.Visible = true;
        _scrollLeft.Visible = false;
        _scrollRight.Visible = false;
        BuildLevelList(chapter);
        SetHint("点选可进入的关卡开始；未解锁关卡会提示解锁条件");
    }

    private void BuildLevelList(LevelChapter chapter)
    {
        ClearChildren(_levelRoot);
        // V-4：测试关卡章——列出固定地图×敌人组合（EncounterDefinitionRegistry 配对）作为可进入测试项。
        if (chapter == LevelChapter.Test)
        {
            BuildTestLevelList();
            return;
        }
        foreach (var level in LevelRegistry.ByChapter(chapter))
        {
            var (badge, locked) = StatusOf(level.Id);
            var card = new Button
            {
                Name = $"Level_{level.Id}",
                Text = "",
                CustomMinimumSize = new Vector2(248, 620),
                SizeFlagsVertical = Control.SizeFlags.ShrinkCenter,
            };
            StyleVerticalButton(card, 18);
            AddVerticalContent(card, level.Title, "", badge, 13, 22, 18);
            card.FocusMode = Control.FocusModeEnum.None;
            if (locked) card.Modulate = LockedModulate; // 锁定：置灰 + 「未解锁」标记
            var id = level.Id;
            card.Pressed += () => EnterLevel(id);
            _levelRoot.AddChild(card);
        }
        // U-2c：自由章额外提供「随机遭遇战」入口卡（难度选择在点击后展开）。
        if (chapter == LevelChapter.Free)
        {
            var card = new Button
            {
                Name = "Level_random",
                Text = "",
                CustomMinimumSize = new Vector2(248, 620),
                SizeFlagsVertical = Control.SizeFlags.ShrinkCenter,
            };
            StyleVerticalButton(card, 18);
            AddVerticalContent(card, "随机遭遇战", "按难度生成一场合法可玩遭遇", null, 13, 22, 18);
            card.FocusMode = Control.FocusModeEnum.None;
            card.Pressed += OpenRandomDifficulty;
            _levelRoot.AddChild(card);
        }
    }

    // V-4：测试关卡章关卡列表——每项 = 固定地图×敌人组合（EncounterDefinitionRegistry 配对），
    // 卡片内容 = 标题 + 「地图名×敌人配置名」+ 简述；点击进入该固定组合的布阵 → 战斗。
    private void BuildTestLevelList()
    {
        foreach (var definition in EncounterDefinitionRegistry.All)
        {
            var (map, enemy) = definition.Resolve();
            var card = new Button
            {
                Name = $"Test_{definition.Id}",
                Text = "",
                CustomMinimumSize = new Vector2(145, 620),
                SizeFlagsVertical = Control.SizeFlags.ShrinkCenter,
            };
            StyleVerticalButton(card, 18);
            AddVerticalContent(card, definition.DisplayName, $"{map.DisplayName}×{enemy.DisplayName}",
                definition.Description, 13, 22, 18);
            card.FocusMode = Control.FocusModeEnum.None;
            var id = definition.Id;
            card.Pressed += () => EnterTestEncounter(id);
            _levelRoot.AddChild(card);
        }
        SetHint("点选测试项进入该固定地图×敌人组合的布阵与战斗（目标：歼灭全部敌舰）");
    }

    // ---- 随机遭遇战（U-2c） ----

    // 点击「随机遭遇战」卡 → 难度选择视图（简单/普通/困难三张卡）。
    private void OpenRandomDifficulty()
    {
        _currentChapter = (int)LevelChapter.Free;
        _randomDifficultyView = true;
        _chapterRoot.Visible = false;
        _levelRoot.Visible = true;
        _levelBack.Visible = true;
        _scrollLeft.Visible = false;
        _scrollRight.Visible = false;
        _subtitle.Text = Verticalize("随机遭遇战·按难度生成");
        BuildDifficultyList();
    }

    private void BuildDifficultyList()
    {
        ClearChildren(_levelRoot);
        for (var i = 0; i < 3; i++)
        {
            var difficulty = i + 1;
            var card = new Button
            {
                Name = $"Diff_{difficulty}",
                Text = "",
                CustomMinimumSize = new Vector2(248, 620),
                SizeFlagsVertical = Control.SizeFlags.ShrinkCenter,
            };
            StyleVerticalButton(card, 18);
            AddVerticalContent(card, $"难度{ChineseNumeral(difficulty)}",
                difficulty switch { 1 => "弱敌稀疏、奖励薄", 2 => "敌我相当、奖励中", _ => "敌强将精、奖励厚" },
                null, 13, 22, 18);
            card.FocusMode = Control.FocusModeEnum.None;
            var d = difficulty;
            card.Pressed += () => EnterRandomEncounter(d);
            _levelRoot.AddChild(card);
        }
        SetHint("选择难度，伪随机生成一场遭遇战（目标：歼灭全部敌舰 · 同种子可复现）");
    }

    // 难度 → 生成随机遭遇 → 会话 Begin → 置 LevelSession 标记 → 切 NavalDemo。
    public void EnterRandomEncounter(int difficulty) => EnterRandomEncounterWithSeed(difficulty, NewSeed());

    // 测试钩子：固定种子进入（headless 冒烟复现同一场遭遇）。
    public void EnterRandomEncounterForTest(int difficulty, int seed) => EnterRandomEncounterWithSeed(difficulty, seed);

    // V-4：测试关卡进入——由 EncounterDefinition 固定配对组装遭遇 → 会话 Begin → 置 LevelSession 标记 → 切 NavalDemo。
    // 与随机遭遇同路径（NavalDemo 部署控制器按 Active 遭遇走遭遇分支；固定遭遇不提供重掷）。
    public void EnterTestEncounter(string definitionId)
    {
        var definition = EncounterDefinitionRegistry.GetById(definitionId);
        if (definition is null) { SetHint($"测试关卡 {definitionId} 不存在"); return; }
        var config = TryLoadConfig();
        if (config is null) { SetHint("测试关卡：加载 data/naval 配置失败"); return; }
        RandomEncounter encounter;
        try
        {
            encounter = RandomEncounterGenerator.CreateFromDefinition(config, definition);
        }
        catch (Exception ex)
        {
            SetHint($"测试关卡 {definitionId} 组装失败：{ex.Message}");
            return;
        }
        RandomEncounterSession.Begin(encounter);
        LevelSession.EnterLevel("random");
        _lastEnteredLevelId = encounter.Id;
        _randomDifficultyView = false;
        GetTree().ChangeSceneToFile("res://scenes/naval/NavalDemo.tscn");
    }

    // 返回：难度视图 → 自由章关卡列表（重置难度视图标记，避免再次返回时仍路由到自由章）；否则章节列表。
    private void GoBack()
    {
        if (_randomDifficultyView)
        {
            _randomDifficultyView = false;
            OpenChapter((int)LevelChapter.Free);
        }
        else ShowChapterList();
    }

    private void EnterRandomEncounterWithSeed(int difficulty, int seed)
    {
        if (difficulty < RandomEncounterGenerator.MinDifficulty || difficulty > RandomEncounterGenerator.MaxDifficulty) return;
        var config = TryLoadConfig();
        if (config is null) { SetHint("随机遭遇战：加载 data/naval 配置失败"); return; }
        var encounter = RandomEncounterGenerator.Generate(config, new RandomEncounterOptions(Difficulty: difficulty, Seed: seed));
        RandomEncounterSession.Begin(encounter);
        LevelSession.EnterLevel("random");
        _lastEnteredLevelId = encounter.Id;
        _randomDifficultyView = false;
        GetTree().ChangeSceneToFile("res://scenes/naval/NavalDemo.tscn");
    }

    // 新种子：TickCount（毫秒）+ 递增计数器，保证连续进入/重掷换场。
    private int NewSeed() => System.Environment.TickCount ^ (_seedCounter++ * 1000003);

    private static NavalRulesConfig? TryLoadConfig()
    {
        try
        {
            var dir = System.IO.Path.Combine(ProjectSettings.GlobalizePath("res://"), "data", "naval");
            return NavalConfigLoader.LoadFromDirectory(dir);
        }
        catch (Exception ex)
        {
            GD.PushError($"随机遭遇战：加载 data/naval 配置失败——{ex.Message}");
            return null;
        }
    }

    private static string ChineseNumeral(int n) => n switch { 1 => "一", 2 => "二", _ => "三" };

    // ---- 状态 / 进入 ----

    // 关卡状态徽记：已通关（✓）/ 可进入 / 未解锁（锁定）。
    private (string Badge, bool Locked) StatusOf(string id)
    {
        if (_progress.IsCompleted(id)) return ("✓ 已通关", false);
        if (_progress.IsUnlocked(id)) return ("可进入", false);
        return ("未解锁", true);
    }

    private bool CanEnter(string id) => _progress.IsCompleted(id) || _progress.IsUnlocked(id);

    // 点击关卡卡片：可进入（可玩/已通关）→ 记目标 id + LevelSession + 切 NavalDemo（L-3 改关卡场景）；
    // 未解锁 → 提示解锁条件，不切换。
    public void EnterLevel(string id)
    {
        if (!CanEnter(id))
        {
            SetHint($"「{id}」尚未解锁：完成上一关即可进入");
            return;
        }
        _lastEnteredLevelId = id;
        LevelSession.EnterLevel(id);
        GetTree().ChangeSceneToFile("res://scenes/naval/NavalDemo.tscn");
    }

    private void RefreshProgressLabel()
    {
        var done = LevelRegistry.AllLevelIds.Count(_progress.IsCompleted);
        _progressLabel.Text = $"已通关 {done} / {LevelRegistry.AllLevelIds.Count}";
    }

    // ---- 只读状态（headless 断言用） ----

    public int ChapterCount() => Chapters.Length;
    public string ChapterTitle(int index) => index >= 0 && index < Chapters.Length ? Chapters[index].Title : "";
    public int LevelCountForChapter(int index)
        => index >= 0 && index < Chapters.Length ? LevelRegistry.ByChapter(Chapters[index].Chapter).Count : 0;
    public string LevelStatus(string id)
        => _progress.IsCompleted(id) ? "completed"
         : _progress.IsUnlocked(id) ? "playable"
         : "locked";
    public string LastEnteredLevelId() => _lastEnteredLevelId ?? "";
    public int CurrentChapter() => _currentChapter;
    // V-8：章节卡片横向滚动只读状态（headless 断言用）：滚动容器 / 可滚动范围（MaxValue>0 表示可滚动）/ 当前偏移。
    public ScrollContainer ChapterScrollContainer() => _chapterScroll;
    public double ChapterScrollRange() => _chapterScroll.GetHScrollBar().MaxValue - _chapterScroll.GetHScrollBar().Page;
    public double ChapterScrollOffset() => _chapterScroll.ScrollHorizontal;
    // V-11：翻页三角只读状态（headless 断言用）：一章卡宽 / 最大滚动 / 左三角禁用 / 右三角禁用。
    public int ChapterScrollPageSize() => (int)ChapterCardWidth;
    public int ChapterScrollMaxOffset() => MaxChapterScroll();
    public bool ChapterScrollArrowLeftDisabled() => _scrollLeft.Disabled;
    public bool ChapterScrollArrowRightDisabled() => _scrollRight.Disabled;
    public bool ChapterListViewVisible() => _chapterRoot.Visible;
    public bool LevelListViewVisible() => _levelRoot.Visible;
    public bool RandomDifficultyView() => _randomDifficultyView;
    public string LastMessage() => _lastMessage;

    // ---- V-4 测试关卡只读状态（headless 断言 列表/每项地图×敌人/简述/进入） ----

    public bool TestLevelViewVisible() => _currentChapter == (int)LevelChapter.Test && _levelRoot.Visible;
    public int TestLevelCount() => EncounterDefinitionRegistry.All.Count;
    public string TestLevelTitle(int index) => TestDefinition(index)?.DisplayName ?? "";
    public string TestLevelDescription(int index) => TestDefinition(index)?.Description ?? "";
    public string TestLevelMapLabel(int index)
        => TestResolve(index) is { } r ? r.Map.DisplayName : "";
    public string TestLevelEnemyLabel(int index)
        => TestResolve(index) is { } r ? r.Enemy.DisplayName : "";

    private EncounterDefinition? TestDefinition(int index)
        => index >= 0 && index < EncounterDefinitionRegistry.All.Count ? EncounterDefinitionRegistry.All[index] : null;

    private (MapScheme Map, EnemyFleetConfig Enemy)? TestResolve(int index)
    {
        var definition = TestDefinition(index);
        if (definition is null) return null;
        try { return definition.Resolve(); }
        catch { return null; } // 引用的 Id 缺失时按未知返回（注册表为静态数据，正常不会发生）
    }

    // ---- 测试钩子（headless 断言 锁定/可玩/已通关 状态控制） ----

    // 干净基线：换用临时保存路径的清空进度（不影响 user:// 真实进度；临时文件由 OS 清理）。
    public void ResetProgressForTest()
    {
        _progress = new LevelProgress(LevelRegistry.AllLevelIds,
            System.IO.Path.Combine(System.IO.Path.GetTempPath(), $"naval_level_select_{Guid.NewGuid():N}.json"));
        _progress.Load();
        _lastEnteredLevelId = null;
        BuildChapterList();
        if (_currentChapter >= 0) OpenChapter(_currentChapter);
        else ShowChapterList();
    }

    // 走真实 LevelProgress.MarkCompleted（含落盘）→ 重建当前视图，状态随之刷新。
    public void MarkCompletedForTest(string id)
    {
        _progress.MarkCompleted(id);
        if (_currentChapter >= 0) OpenChapter(_currentChapter);
        RefreshProgressLabel();
    }

    private void SetHint(string text)
    {
        _lastMessage = text;
        _hintLabel.Text = text;
    }

    // 清空容器子节点：RemoveChild（立即从容器移除）+ QueueFree（延迟销毁，避免重建时旧节点仍被计数）。
    private static void ClearChildren(Container container)
    {
        foreach (var child in container.GetChildren())
        {
            container.RemoveChild(child);
            child.QueueFree();
        }
    }

    private void StyleVerticalButton(Button button, int fontSize)
    {
        button.TextureFilter = CanvasItem.TextureFilterEnum.Nearest;
        button.AddThemeStyleboxOverride("normal", ButtonTextureStyle(Colors.White));
        button.AddThemeStyleboxOverride("hover", ButtonTextureStyle(new Color(1.08f, 1.04f, 0.88f, 1f)));
        button.AddThemeStyleboxOverride("pressed", ButtonTextureStyle(new Color(0.72f, 0.76f, 0.70f, 1f)));
        button.AddThemeStyleboxOverride("disabled", ButtonTextureStyle(new Color(0.58f, 0.60f, 0.58f, 0.78f)));
        button.AddThemeStyleboxOverride("focus", ButtonTextureStyle(new Color(1.08f, 1.04f, 0.88f, 1f)));
        button.AddThemeFontOverride("font", InkWashTheme.Font());
        button.AddThemeFontSizeOverride("font_size", fontSize);
        button.AddThemeColorOverride("font_color", InkWashTheme.PaperLight);
        button.AddThemeColorOverride("font_hover_color", new Color("f0cf79"));
        button.AddThemeColorOverride("font_pressed_color", Colors.White);
        button.AddThemeColorOverride("font_disabled_color", new Color("c0baa9"));
        button.AddThemeColorOverride("font_outline_color", InkWashTheme.InkDeep);
        button.AddThemeConstantOverride("outline_size", 5);
    }

    private StyleBoxTexture ButtonTextureStyle(Color tint)
    {
        var style = new StyleBoxTexture { Texture = _buttonFrame };
        style.Set("texture_margin_left", 32.0f);
        style.Set("texture_margin_right", 32.0f);
        style.Set("texture_margin_top", 110.0f);
        style.Set("texture_margin_bottom", 110.0f);
        style.Set("content_margin_left", 28.0f);
        style.Set("content_margin_right", 28.0f);
        style.Set("content_margin_top", 48.0f);
        style.Set("content_margin_bottom", 48.0f);
        style.Set("modulate_color", tint);
        return style;
    }

    private void StyleMainReturnButton(Button button)
    {
        button.TextureFilter = CanvasItem.TextureFilterEnum.Nearest;
        button.AddThemeStyleboxOverride("normal", ReturnBrushStyle(Colors.White));
        button.AddThemeStyleboxOverride("hover", ReturnBrushStyle(new Color(1.0f, 0.94f, 0.78f, 1.0f)));
        button.AddThemeStyleboxOverride("pressed", ReturnBrushStyle(new Color(0.72f, 0.76f, 0.72f, 1.0f)));
        button.AddThemeStyleboxOverride("focus", ReturnBrushStyle(Colors.White));
        button.AddThemeFontOverride("font", InkWashTheme.Font());
        button.AddThemeFontSizeOverride("font_size", 22);
        button.AddThemeColorOverride("font_color", InkWashTheme.PaperLight);
        button.AddThemeColorOverride("font_hover_color", new Color("f0cf79"));
        button.AddThemeColorOverride("font_pressed_color", Colors.White);
        button.AddThemeColorOverride("font_outline_color", InkWashTheme.InkDeep);
        button.AddThemeConstantOverride("outline_size", 4);
    }

    // V-11：生图水墨像素翻页钮。左右共用同一套纸面/墨青/赭石材质，左钮由右钮无损镜像生成；
    // 各交互态只做克制的整体色调变化，保留原始像素边缘与干笔箭头。
    private static void StyleScrollArrow(Button button, string texturePath)
    {
        var texture = GD.Load<Texture2D>(texturePath);
        button.FocusMode = Control.FocusModeEnum.None;
        button.MouseDefaultCursorShape = Control.CursorShape.PointingHand;
        button.Text = string.Empty;
        button.AddThemeStyleboxOverride("normal", ScrollArrowTexture(texture, Colors.White));
        button.AddThemeStyleboxOverride("hover", ScrollArrowTexture(texture, new Color(1.08f, 1.04f, 0.88f, 1f)));
        button.AddThemeStyleboxOverride("pressed", ScrollArrowTexture(texture, new Color(0.68f, 0.74f, 0.69f, 1f)));
        button.AddThemeStyleboxOverride("disabled", ScrollArrowTexture(texture, new Color(0.58f, 0.60f, 0.58f, 0.62f)));
        button.AddThemeStyleboxOverride("focus", ScrollArrowTexture(texture, Colors.White));
    }

    private static StyleBoxTexture ScrollArrowTexture(Texture2D texture, Color tint)
    {
        var style = new StyleBoxTexture
        {
            Texture = texture,
            ModulateColor = tint,
        };
        style.Set("content_margin_left", 0.0f);
        style.Set("content_margin_right", 0.0f);
        style.Set("content_margin_top", 0.0f);
        style.Set("content_margin_bottom", 0.0f);
        return style;
    }

    private StyleBoxTexture ReturnBrushStyle(Color tint)
    {
        var style = new StyleBoxTexture
        {
            Texture = _returnBrush,
            ModulateColor = tint,
        };
        style.Set("content_margin_left", 28.0f);
        style.Set("content_margin_right", 28.0f);
        style.Set("content_margin_top", 14.0f);
        style.Set("content_margin_bottom", 14.0f);
        return style;
    }

    private void AddVerticalContent(
        Button button,
        string heading,
        string body,
        string? badge,
        int bodyColumnLength,
        int headingFontSize = 20,
        int bodyFontSize = 16)
    {
        button.ClipContents = true;
        var row = new HBoxContainer
        {
            MouseFilter = Control.MouseFilterEnum.Ignore,
            Alignment = BoxContainer.AlignmentMode.Center,
        };
        row.AddThemeConstantOverride("separation", 7);
        button.AddChild(row);
        row.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        row.OffsetLeft = 24;
        row.OffsetTop = 54;
        row.OffsetRight = -24;
        row.OffsetBottom = -54;

        AddVerticalColumn(row, heading, headingFontSize, InkWashTheme.PaperLight);
        foreach (var column in SplitColumns(body, bodyColumnLength))
            AddVerticalColumn(row, column, bodyFontSize, new Color("d8d2c2"));
        if (!string.IsNullOrEmpty(badge))
            AddVerticalColumn(row, badge, bodyFontSize, new Color("e4c476"));
    }

    private static void AddVerticalColumn(HBoxContainer row, string text, int fontSize, Color color)
    {
        var label = new Label
        {
            Text = Verticalize(text),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            SizeFlagsHorizontal = Control.SizeFlags.ShrinkCenter,
            SizeFlagsVertical = Control.SizeFlags.ShrinkCenter,
            MouseFilter = Control.MouseFilterEnum.Ignore,
        };
        StyleText(label, fontSize, color, 3, InkWashTheme.InkDeep);
        row.AddChild(label);
    }

    private static IEnumerable<string> SplitColumns(string text, int maxCharacters)
    {
        var normalized = NormalizeVerticalText(text);
        for (var offset = 0; offset < normalized.Length; offset += maxCharacters)
            yield return normalized.Substring(offset, Math.Min(maxCharacters, normalized.Length - offset));
    }

    private static string Verticalize(string text)
        => string.Join("\n", NormalizeVerticalText(text).Select(character => character.ToString()));

    private static string NormalizeVerticalText(string text)
        => text.Replace(" / ", "、").Replace("/", "、").Replace(" ", "").Replace("\n", "");

    private static void StyleText(Label l, int size, Color color, int outlineSize = 0, Color? outlineColor = null)
    {
        l.AddThemeFontOverride("font", InkWashTheme.Font());
        l.AddThemeFontSizeOverride("font_size", size);
        l.AddThemeColorOverride("font_color", color);
        if (outlineSize > 0)
        {
            l.AddThemeColorOverride("font_outline_color", outlineColor ?? InkWashTheme.InkDeep);
            l.AddThemeConstantOverride("outline_size", outlineSize);
        }
    }
}
