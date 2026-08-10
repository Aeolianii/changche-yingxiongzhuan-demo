# 伏波古岭中型地图与独立小游戏 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有伏波古岭骨架升级为一张约 3200×2200、相机跟随、移步换景的清新中式地图，并把水渠与军鼓改为地点触发的独立全屏轻量小游戏。

**Architecture:** 主地图只维护探索、触发和阶段门控；`FuboMinigameHost` 在同一 SceneTree 中暂停并隐藏世界，实例化独立全屏 `PackedScene`，完成后恢复原地图。地图背景由四张连续局部生图片组成，非游玩区域用少量大型碰撞封闭，只有关键遮挡物和互动对象保持独立节点。

**Tech Stack:** Godot 4.7.1、GDScript、Godot AI MCP、原生 `Control/CanvasLayer/Area2D/CollisionPolygon2D/AudioStreamPlayer`、Godot headless tests、ImageGen PNG 素材。

## Global Constraints

- 实施前遵守仓库 `AGENTS.md`：先更新变更记录与权威文档，再修改代码、场景、资源或游戏数据。
- `.tscn`、节点、资源分配、碰撞和运行态检查必须通过当前 `厂车v3` Godot MCP 会话完成；先按项目路径重新列出并激活会话，不假设会话 ID 永久不变。
- 脚本、测试和 Markdown 使用 `apply_patch` 修改；不得覆盖无关用户改动。
- 世界有效范围约 `3200×2200`，设计视口 `1344×896`，玩家纹理比例基准 `64×64`。
- 只使用 Godot 原生 GDScript，不引入第三方运行时依赖。
- 小游戏使用独立全屏 `PackedScene`，不是操作系统窗口；地图实例不得重新加载。
- 水渠主要使用鼠标；军鼓使用 `A/S/D`，兼容左/下/右方向键。
- 每项小游戏首次游玩目标时长 1–2 分钟；失败只重置当前小回合。
- 正式军鼓音效必须是三种明显不同的鼓类声音，不得继续使用正弦提示音。
- 地图采用清新明朗中式像素风，禁止完整微缩岛屿、厚重写实、密集旧化、日式神社和东南亚寺庙主导语言。
- 生图底图不承担碰撞；碰撞由 Godot 手工维护。

---

## File Structure

### Create

- `docs/changes/CHG-20260810-fubo-guling-medium-map-minigames.md` — 本轮文档优先变更记录。
- `scripts/fubo_guling/minigames/fubo_minigame_base.gd` — 小游戏统一信号与结果契约。
- `scripts/fubo_guling/minigames/fubo_minigame_host.gd` — 全屏实例生命周期、地图暂停、退出和输入隔离。
- `scripts/fubo_guling/minigames/fubo_canal_minigame.gd` — 水渠全屏表现与鼠标输入。
- `scripts/fubo_guling/minigames/fubo_drum_minigame.gd` — 军鼓演示、键盘输入、失焦暂停与音频播放。
- `scenes/fubo_guling/minigames/fubo_canal_minigame.tscn` — 水渠独立全屏场景。
- `scenes/fubo_guling/minigames/fubo_drum_minigame.tscn` — 军鼓独立全屏场景。
- `tools/generate_fubo_drum_samples.gd` — 一次性生成四份鼓类 WAV 的离线脚本。
- `assets/audio/fubo_guling/drum_low.wav` — 低沉鼓心。
- `assets/audio/fubo_guling/drum_mid.wav` — 中频鼓面。
- `assets/audio/fubo_guling/drum_rim.wav` — 清脆鼓边。
- `assets/audio/fubo_guling/drum_fail.wav` — 独立失败收鼓声。
- `assets/fubo_guling/backgrounds/fubo_plate_sw.png` — 码头与守备院局部底图。
- `assets/fubo_guling/backgrounds/fubo_plate_se.png` — 山腰与古渠下缘局部底图。
- `assets/fubo_guling/backgrounds/fubo_plate_nw.png` — 校场与北侧山路局部底图。
- `assets/fubo_guling/backgrounds/fubo_plate_ne.png` — 古渠上缘与观景台局部底图。
- `tests/test_fubo_minigame_host.gd` — 宿主生命周期测试。
- `tests/test_fubo_canal_game.gd` — 水渠规则与场景契约测试。
- `tests/test_fubo_drum_game.gd` — 军鼓规则、时间窗和音频契约测试。

### Modify

- `docs/design/fubo-guling-slice.md` — 替换旧的场内操作规则、世界尺寸和模块化地表结论。
- `docs/design/art-direction.md` — 记录四块连续局部底图和大块禁行区方案。
- `docs/tech/architecture.md` — 记录小游戏宿主与 `PackedScene` 接口。
- `docs/qa/playtest.md` — 增加地图尺度、返回恢复、Web 失焦和鼓声辨识检查。
- `docs/assets/fubo-guling-generated-assets.md` — 记录四张底图、关键独立物件、生成提示词与用途。
- `scripts/fubo_guling/fubo_canal_puzzle.gd` — 改为三轮目标水量与放水规则模型。
- `scripts/fubo_guling/fubo_drum_memory.gd` — 改为 4/5/6 拍、BPM、节拍偏移和时间判定模型。
- `scripts/fubo_guling/fubo_guling.gd` — 删除场内闸门/走旗输入，接入两个独立小游戏和新地点锚点。
- `scripts/fubo_guling/fubo_placeholder_world.gd` — 停止绘制旧程序化地表，保留可选调试网格。
- `scenes/fubo_guling/fubo_guling.tscn` — 通过 MCP 重建背景板、关键对象、大块碰撞、古渠触发和小游戏宿主。
- `tests/test_fubo_guling.gd` — 更新世界、触发、背景板、碰撞与小游戏集成契约。

---

### Task 1: 文档优先与基线锁定

**Files:**
- Create: `docs/changes/CHG-20260810-fubo-guling-medium-map-minigames.md`
- Modify: `docs/design/fubo-guling-slice.md`
- Modify: `docs/design/art-direction.md`
- Modify: `docs/tech/architecture.md`
- Modify: `docs/qa/playtest.md`

**Interfaces:**
- Consumes: 已批准规格 `docs/superpowers/specs/2026-08-10-fubo-guling-map-minigames-design.md`。
- Produces: 后续任务共同依赖的世界尺寸、地点锚点、小游戏边界和验收清单。

- [ ] **Step 1: 建立变更记录**

创建内容必须包含以下具体字段：

```markdown
# CHG-20260810-fubo-guling-medium-map-minigames

- Status: in-progress
- Type: gameplay / map composition / generated art / audio
- Owner: Project owner
- Created: 2026-08-10

## Goal
将伏波古岭扩展为 3200×2200 的中型跟随相机地图，并接入三渠引水与听令回鼓两个独立全屏小游戏。

## Scope
- 四张连续局部底图与 10–15 个关键独立对象。
- 6–10 个大型禁行碰撞区。
- MinigameHost、两项 PackedScene、鼓类 WAV 和 Web 失焦处理。

## Non-goals
- 不增加第三项小游戏、战斗、室内或完整开放世界。

## Acceptance checks
- [ ] 正常镜头无法同时看清五个地点。
- [ ] 两项小游戏都由地点确认触发并能返回原地图。
- [ ] 水渠鼠标操作、军鼓键盘操作，失败只重置当前轮。
- [ ] 三种鼓声可明显区分。
- [ ] 大块碰撞封闭非游玩区且道路无碎碰撞卡顿。
- [ ] Godot MCP 截图、日志和自动测试通过。

## Documentation impact
- `docs/design/fubo-guling-slice.md`
- `docs/design/art-direction.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `docs/assets/fubo-guling-generated-assets.md`

## Likely files
- `scripts/fubo_guling/`
- `scenes/fubo_guling/`
- `assets/fubo_guling/`
- `assets/audio/fubo_guling/`
- `tests/test_fubo_*.gd`

## Verification evidence
- Task 1 records the baseline command and exit code; Task 8 appends post-change commands, screenshots and log evidence.
```

- [ ] **Step 2: 更新权威文档**

把以下已批准事实写入对应文档，不保留旧的 `2600×1500`、场内逐闸操作、角色走旗输入或“地表必须拆成十余模块”的冲突描述：

```text
World: 3200×2200; viewport: 1344×896
Anchors: dock (420,1850), keeper (1150,1650), canal (2600,1180), drill (1850,620), viewpoint (2550,320)
Map art: four overlapping local background plates
Collision: 6–10 coarse blocked regions plus key wall-foot shapes
Minigames: full-screen PackedScene hosted without reloading map
Canal input: mouse
Drum input: A/S/D plus Left/Down/Right
```

- [ ] **Step 3: 运行现有基线测试**

Run through Godot MCP `test_run` with `res://tests/test_fubo_guling.gd`.

Fallback command:

```powershell
& 'D:\Programs\Godot-4.7.1-dotnet\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --script res://tests/test_fubo_guling.gd
```

Expected: exit `0` and `Fubo Guling skeleton verification passed.` Record the result as the pre-change baseline.

- [ ] **Step 4: Commit**

```powershell
git add -- docs/changes/CHG-20260810-fubo-guling-medium-map-minigames.md docs/design/fubo-guling-slice.md docs/design/art-direction.md docs/tech/architecture.md docs/qa/playtest.md
git commit -m "docs(fubo-guling): define medium map and minigame architecture"
```

---

### Task 2: 全屏小游戏宿主

**Files:**
- Create: `scripts/fubo_guling/minigames/fubo_minigame_base.gd`
- Create: `scripts/fubo_guling/minigames/fubo_minigame_host.gd`
- Create: `tests/test_fubo_minigame_host.gd`
- Modify via Godot MCP: `scenes/fubo_guling/fubo_guling.tscn`

**Interfaces:**
- Consumes: `CanvasItem world_root`, `CanvasItem hud_root`, `FuboMinigameBase` scenes.
- Produces: `open_minigame(scene: PackedScene, game_id: String) -> bool` and signals `minigame_opened(game_id)`, `minigame_finished(result)`, `minigame_cancelled(game_id)`.

- [ ] **Step 1: 写宿主失败测试**

测试必须构造一个带 `completed` 和 `exit_requested` 信号的假小游戏，覆盖：第一次打开成功、第二次打开被拒绝、地图/HUD 隐藏、角色控制锁定、完成和退出都恢复地图。

```gdscript
extends SceneTree

const HOST_SCRIPT := preload("res://scripts/fubo_guling/minigames/fubo_minigame_host.gd")

class FakeGame extends Control:
    signal completed(result: Dictionary)
    signal exit_requested
    var game_id := "fake"

class FakePlayer extends CharacterBody2D:
    var controls_enabled := true
    func cancel_move_target() -> void:
        velocity = Vector2.ZERO

func _run() -> void:
    var world := Node2D.new()
    var hud := Control.new()
    var player := FakePlayer.new()
    var host := Control.new()
    host.set_script(HOST_SCRIPT)
    root.add_child(world)
    root.add_child(hud)
    root.add_child(player)
    root.add_child(host)
    host.configure(world, hud, player)
    var packed := PackedScene.new()
    packed.pack(FakeGame.new())
    assert(host.open_minigame(packed, "fake"))
    assert(not host.open_minigame(packed, "duplicate"))
    assert(not world.visible and not hud.visible and not player.controls_enabled)
    host.active_minigame.completed.emit({"game_id":"fake", "completed":true})
    await process_frame
    assert(world.visible and hud.visible and player.controls_enabled)
    quit(0)
```

- [ ] **Step 2: 运行测试并确认红灯**

Run: `Godot ... --headless --path . --script res://tests/test_fubo_minigame_host.gd`

Expected: FAIL because `fubo_minigame_host.gd` does not exist.

- [ ] **Step 3: 实现统一基类**

```gdscript
class_name FuboMinigameBase
extends Control

signal completed(result: Dictionary)
signal exit_requested
signal round_restarted(round_index: int)

@export var game_id := ""

func build_result(rating: String, mistakes: int, duration_ms: int) -> Dictionary:
    return {
        "game_id": game_id,
        "completed": true,
        "rating": rating,
        "mistakes": maxi(0, mistakes),
        "duration_ms": maxi(0, duration_ms),
    }
```

- [ ] **Step 4: 实现宿主**

宿主必须缓存打开前的 `visible` 和 `process_mode`，而不是假设地图原状态；活动小游戏设为 `PROCESS_MODE_WHEN_PAUSED`，但不暂停整个 SceneTree，只把世界与 HUD 的 `process_mode` 设为 `PROCESS_MODE_DISABLED`。

```gdscript
class_name FuboMinigameHost
extends Control

signal minigame_opened(game_id: String)
signal minigame_finished(result: Dictionary)
signal minigame_cancelled(game_id: String)

var active_minigame: FuboMinigameBase
var _world: CanvasItem
var _hud: CanvasItem
var _player: Node
var _game_id := ""
var _world_visible := true
var _hud_visible := true
var _world_process_mode := Node.PROCESS_MODE_INHERIT
var _hud_process_mode := Node.PROCESS_MODE_INHERIT
var _player_controls_enabled := true

func configure(world: CanvasItem, hud: CanvasItem, player: Node) -> void:
    _world = world
    _hud = hud
    _player = player

func open_minigame(scene: PackedScene, game_id: String) -> bool:
    if active_minigame != null or scene == null:
        return false
    var instance := scene.instantiate() as FuboMinigameBase
    if instance == null:
        return false
    _game_id = game_id
    active_minigame = instance
    _world_visible = _world.visible
    _hud_visible = _hud.visible
    _world_process_mode = _world.process_mode
    _hud_process_mode = _hud.process_mode
    _player_controls_enabled = _player.controls_enabled
    _world.visible = false
    _hud.visible = false
    _world.process_mode = Node.PROCESS_MODE_DISABLED
    _hud.process_mode = Node.PROCESS_MODE_DISABLED
    _player.controls_enabled = false
    _player.cancel_move_target()
    add_child(instance)
    instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    instance.completed.connect(_on_completed, CONNECT_ONE_SHOT)
    instance.exit_requested.connect(_on_exit_requested, CONNECT_ONE_SHOT)
    minigame_opened.emit(game_id)
    return true

func _on_completed(result: Dictionary) -> void:
    _restore_map()
    minigame_finished.emit(result)

func _on_exit_requested() -> void:
    var cancelled_id := _game_id
    _restore_map()
    minigame_cancelled.emit(cancelled_id)

func _restore_map() -> void:
    if active_minigame != null:
        active_minigame.queue_free()
    active_minigame = null
    _game_id = ""
    _world.visible = _world_visible
    _hud.visible = _hud_visible
    _world.process_mode = _world_process_mode
    _hud.process_mode = _hud_process_mode
    _player.controls_enabled = _player_controls_enabled
```

- [ ] **Step 5: 用 Godot MCP 加入宿主节点**

在 `/FuboGuling/Interface` 下创建 `Control` 节点 `MinigameHost`，设置 full rect、`mouse_filter = MOUSE_FILTER_STOP`、`process_mode = PROCESS_MODE_WHEN_PAUSED`、初始 `visible = true`，附加宿主脚本并保存场景。不要直接编辑 `.tscn` 文本。

- [ ] **Step 6: 运行宿主测试**

Expected: exit `0`; repeated open rejected; both finish and cancel restore map and controls.

- [ ] **Step 7: Commit**

```powershell
git add -- scripts/fubo_guling/minigames tests/test_fubo_minigame_host.gd scenes/fubo_guling/fubo_guling.tscn
git commit -m "feat(fubo-guling): add full-screen minigame host"
```

---

### Task 3: 三渠引水规则模型

**Files:**
- Modify: `scripts/fubo_guling/fubo_canal_puzzle.gd`
- Create: `tests/test_fubo_canal_game.gd`

**Interfaces:**
- Produces: `start()`, `release_to(branch: int) -> ReleaseResult`, `get_target()`, `get_levels()`, `get_blocked_branch()`, `get_round_index()`, `get_rating()`, `is_finished()`.
- Consumed by: `FuboCanalMinigame` in Task 4.

- [ ] **Step 1: 写规则失败测试**

```gdscript
var game = FuboCanalPuzzle.new(20260810)
game.start()
assert(game.get_round_index() == 0)
for round_index in 3:
    var target := game.get_target()
    assert(target.size() == 3)
    assert(target[0] + target[1] + target[2] == [3, 4, 5][round_index])
    var blocked := game.get_blocked_branch()
    if blocked >= 0:
        assert(target[blocked] == 0)
    for branch in 3:
        for unit in target[branch]:
            game.release_to(branch)
assert(game.is_finished())

var replay = FuboCanalPuzzle.new(20260810)
replay.start()
var first_target := replay.get_target()
var overflow_branch := first_target.find(first_target.max())
for unit in first_target[overflow_branch] + 1:
    replay.release_to(overflow_branch)
assert(replay.get_round_index() == 0)
assert(replay.get_levels() == PackedInt32Array([0, 0, 0]))
assert(replay.get_target() == first_target)
```

- [ ] **Step 2: 运行并确认旧模型不满足新接口**

Expected: FAIL at missing constructor seed or `release_to`.

- [ ] **Step 3: 实现确定性可解出题器**

使用有限配置池而不是任意随机数，避免无解题：

```gdscript
const ROUND_TOTALS := [3, 4, 5]
const TARGET_POOLS := [
    [PackedInt32Array([1,1,1]), PackedInt32Array([2,1,0]), PackedInt32Array([1,2,0])],
    [PackedInt32Array([2,2,0]), PackedInt32Array([3,1,0]), PackedInt32Array([1,3,0])],
    [PackedInt32Array([2,3,0]), PackedInt32Array([3,2,0]), PackedInt32Array([1,2,2])],
]
```

每轮随机选配置并随机轮转三个分支。目标为 `0` 的分支在第 2、3 轮成为封闭支渠；第一轮不封闭。`release_to` 规则：分支非法/游戏未开始返回 `REJECTED`；流入封闭支渠或超过目标时增加 mistakes、清空当前 levels、发出 `round_restarted` 并返回 `MISTAKE`；达到本轮总量进入下一轮；第三轮结束返回 `FINISHED`。

- [ ] **Step 4: 运行水渠规则测试**

Expected: exit `0`; seeds are reproducible; all three targets are solvable; a mistake resets levels but preserves round and target.

- [ ] **Step 5: Commit**

```powershell
git add -- scripts/fubo_guling/fubo_canal_puzzle.gd tests/test_fubo_canal_game.gd
git commit -m "feat(fubo-guling): add three-round canal allocation rules"
```

---

### Task 4: 三渠引水全屏场景

**Files:**
- Create: `scripts/fubo_guling/minigames/fubo_canal_minigame.gd`
- Create via Godot MCP: `scenes/fubo_guling/minigames/fubo_canal_minigame.tscn`
- Modify: `tests/test_fubo_canal_game.gd`

**Interfaces:**
- Consumes: Task 3 `FuboCanalPuzzle` API and Task 2 `FuboMinigameBase`.
- Produces: scene with `game_id = "canal"`; emits standard completion result.

- [ ] **Step 1: 扩展场景契约红灯测试**

```gdscript
const CANAL_SCENE := preload("res://scenes/fubo_guling/minigames/fubo_canal_minigame.tscn")
var ui = CANAL_SCENE.instantiate()
root.add_child(ui)
await process_frame
assert(ui.game_id == "canal")
assert(ui.get_node("Layout/BranchButtons/Left") is Button)
assert(ui.get_node("Layout/BranchButtons/Center") is Button)
assert(ui.get_node("Layout/BranchButtons/Right") is Button)
assert(ui.get_node("Layout/ReleaseButton") is Button)
assert(ui.get_node("ExitConfirm").visible == false)
```

- [ ] **Step 2: 用 Godot MCP 创建场景树**

创建以下精确结构，根节点使用 full rect、`process_mode = WHEN_PAUSED`：

```text
FuboCanalMinigame (Control, script, game_id="canal")
├─ Background (ColorRect, #b9dc9a)
├─ Layout (Control)
│  ├─ Title (Label, "三渠引水")
│  ├─ RoundLabel (Label)
│  ├─ TargetPanel (HBoxContainer)
│  │  ├─ LeftTarget (Label)
│  │  ├─ CenterTarget (Label)
│  │  └─ RightTarget (Label)
│  ├─ CanalDrawing (Control)
│  ├─ BranchButtons (HBoxContainer)
│  │  ├─ Left (Button, "左渠")
│  │  ├─ Center (Button, "中渠")
│  │  └─ Right (Button, "右渠")
│  ├─ ReleaseButton (Button, "放水")
│  └─ Status (Label)
├─ ExitButton (Button, "暂时离开")
└─ ExitConfirm (PanelContainer, initially hidden)
   └─ VBoxContainer
      ├─ Prompt (Label, "离开后将重置本次挑战")
      └─ Actions (HBoxContainer)
         ├─ Continue (Button, "继续挑战")
         └─ Leave (Button, "暂时离开")
```

- [ ] **Step 3: 实现鼠标交互与动画锁**

控制器必须在水流 Tween 期间禁用三个分支按钮和放水按钮；`_selected_branch` 由鼠标按钮设置，`_release_selected()` 调用模型后，用 `CanalDrawing.queue_redraw()` 和 0.45 秒 Tween 表现水流。测试入口仅包装真实路径：

```gdscript
func choose_branch_for_test(branch: int) -> void:
    _select_branch(branch)

func release_for_test() -> int:
    return _release_selected()
```

完成时调用：

```gdscript
completed.emit(build_result(_game.get_rating(), _game.get_mistakes(), Time.get_ticks_msec() - _started_ms))
```

- [ ] **Step 4: 运行水渠测试并用 MCP 单独运行场景**

Expected: headless contract passes. MCP windowed run shows all controls inside 1344×896, branch selection readable, animation期间无法重复放水，退出确认可恢复。

- [ ] **Step 5: Commit**

```powershell
git add -- scripts/fubo_guling/minigames/fubo_canal_minigame.gd scenes/fubo_guling/minigames/fubo_canal_minigame.tscn tests/test_fubo_canal_game.gd
git commit -m "feat(fubo-guling): add full-screen canal minigame"
```

---

### Task 5: 听令回鼓规则、鼓声与全屏场景

**Files:**
- Modify: `scripts/fubo_guling/fubo_drum_memory.gd`
- Create: `scripts/fubo_guling/minigames/fubo_drum_minigame.gd`
- Create via Godot MCP: `scenes/fubo_guling/minigames/fubo_drum_minigame.tscn`
- Create: `tools/generate_fubo_drum_samples.gd`
- Create: `tests/test_fubo_drum_game.gd`
- Generate: `assets/audio/fubo_guling/*.wav`

**Interfaces:**
- Produces model methods `start()`, `begin_input()`, `submit(drum_index, timing_error_ms)`, `get_current_sequence()`, `get_current_intervals_ms()`, `get_current_bpm()`, `get_round_index()`, `is_finished()`.
- Produces scene with `game_id = "drum"`; emits standard completion result.

- [ ] **Step 1: 写军鼓失败测试**

```gdscript
var drum = FuboDrumMemory.new(20260810)
var sequences := drum.get_sequences_for_test()
assert(sequences.map(func(x): return x.size()) == [4,5,6])
for round_index in 3:
    var bpm := drum.get_round_bpms_for_test()[round_index]
    assert(bpm in [72,84,96])
    if round_index > 0:
        assert(bpm != drum.get_round_bpms_for_test()[round_index - 1])
    for i in range(1, sequences[round_index].size()):
        assert(sequences[round_index][i] != sequences[round_index][i - 1])
assert(sequences[2].has(0) and sequences[2].has(1) and sequences[2].has(2))

drum.start()
drum.begin_input()
var expected := drum.get_current_sequence()[0]
assert(drum.submit(expected, 120) == drum.SUBMIT_PROGRESS)
assert(drum.submit(drum.get_current_sequence()[1], 280) == drum.SUBMIT_PROGRESS)
assert(drum.submit(drum.get_current_sequence()[2], 281) == drum.SUBMIT_MISTAKE)
assert(drum.get_input_index() == 0)
```

- [ ] **Step 2: 实现规则模型**

使用 `ROUND_LENGTHS = [4,5,6]`、`BPMS = [72,84,96]`、`PERFECT_WINDOW_MS = 120`、`PASS_WINDOW_MS = 280`。每拍间隔为 `60000 / bpm` 乘以 `0.92/1.0/1.08` 中的一个随机值；每轮 BPM 不与上一轮相同。`submit` 先验证鼓位，再验证 `abs(timing_error_ms)`；任一错误只把 `_input_index` 清零并保留当前序列、BPM 和间隔。

- [ ] **Step 3: 生成四份鼓类 WAV**

离线生成器采用衰减正弦的快速降频叠加白噪声瞬态，不在运行时合成。参数固定如下：

```gdscript
const SPECS := {
    "drum_low.wav":  {"start_hz": 118.0, "end_hz": 54.0,  "noise": 0.10, "duration": 0.62},
    "drum_mid.wav":  {"start_hz": 190.0, "end_hz": 92.0,  "noise": 0.18, "duration": 0.34},
    "drum_rim.wav":  {"start_hz": 430.0, "end_hz": 245.0, "noise": 0.48, "duration": 0.16},
    "drum_fail.wav": {"start_hz": 92.0,  "end_hz": 42.0,  "noise": 0.22, "duration": 0.78},
}
```

生成 44.1 kHz、16-bit、mono PCM；每份音频做 4 ms attack 和指数衰减。运行命令：

```powershell
& 'D:\Programs\Godot-4.7.1-dotnet\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --script res://tools/generate_fubo_drum_samples.gd
```

Expected: four WAV files exist, sizes and SHA-256 differ, each loads as `AudioStreamWAV`.

- [ ] **Step 4: 用 Godot MCP 创建军鼓场景**

```text
FuboDrumMinigame (Control, script, game_id="drum", full rect)
├─ Background (ColorRect, fresh pale training-yard palette)
├─ Title (Label, "听令回鼓")
├─ RoundLabel (Label)
├─ BeatTrack (Control)
│  ├─ Cursor (ColorRect)
│  └─ BeatMarkers (HBoxContainer)
├─ Drums (HBoxContainer)
│  ├─ LeftDrum (Button, "A\n左鼓")
│  ├─ CenterDrum (Button, "S\n中鼓")
│  └─ RightDrum (Button, "D\n右鼓")
├─ Status (Label)
├─ AudioLow (AudioStreamPlayer)
├─ AudioMid (AudioStreamPlayer)
├─ AudioRim (AudioStreamPlayer)
├─ AudioFail (AudioStreamPlayer)
├─ ExitButton (Button)
├─ ExitConfirm (PanelContainer, initially hidden)
└─ ResumeCountdown (Label, initially hidden)
```

将四份 WAV 逐一分配给对应播放器，不能用 pitch shift 替代独立素材。

- [ ] **Step 5: 实现演示、输入和失焦处理**

```gdscript
func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _focus_paused = true
        _pause_timeline()
    elif what == NOTIFICATION_APPLICATION_FOCUS_IN and _focus_paused:
        _resume_after_countdown.call_deferred()
```

演示阶段忽略玩家提交；输入阶段用 `Time.get_ticks_msec()` 与当前目标拍点计算 `timing_error_ms`。恢复焦点后显示 `3、2、1`，倒数期间不推进节拍。按错或超出 280 ms 时播放 `drum_fail.wav`，0.6 秒后重播当前轮。

- [ ] **Step 6: 运行规则与场景测试**

Expected: deterministic seed, 4/5/6 lengths, BPM constraints, ±120/±280 boundaries, wrong input retains current round; all four audio streams non-null and resource paths distinct.

- [ ] **Step 7: 用 MCP 单独试玩军鼓场景**

按 `A/S/D` 和方向键完成一轮；切出窗口 2 秒再返回，确认倒数后继续且未记录失误。读取游戏日志，必须无输入和释放节点错误。

- [ ] **Step 8: Commit**

```powershell
git add -- scripts/fubo_guling/fubo_drum_memory.gd scripts/fubo_guling/minigames/fubo_drum_minigame.gd scenes/fubo_guling/minigames/fubo_drum_minigame.tscn tools/generate_fubo_drum_samples.gd assets/audio/fubo_guling tests/test_fubo_drum_game.gd
git commit -m "feat(fubo-guling): add keyboard war-drum minigame"
```

---

### Task 6: 中型灰盒地图、触发与小游戏集成

**Files:**
- Modify: `scripts/fubo_guling/fubo_guling.gd`
- Modify: `scripts/fubo_guling/fubo_placeholder_world.gd`
- Modify via Godot MCP: `scenes/fubo_guling/fubo_guling.tscn`
- Modify: `tests/test_fubo_guling.gd`

**Interfaces:**
- Consumes: `FuboMinigameHost.open_minigame`, canal/drum PackedScenes and standard result dictionary.
- Produces: complete linear phase flow and 3200×2200 scene contract.

- [ ] **Step 1: 将集成测试改为新契约并确认红灯**

测试必须断言：

```gdscript
assert(level.get_node("World/WorldObjects/Player/Camera2D").limit_right == 3200)
assert(level.get_node("World/WorldObjects/Player/Camera2D").limit_bottom == 2200)
assert(level.get_node("World/Ground/BackgroundPlates").get_child_count() == 4)
assert(level.get_node("World/Collision/BlockedRegions").get_child_count() >= 6)
assert(level.get_node("World/Collision/BlockedRegions").get_child_count() <= 10)
assert(level.get_node("World/Triggers/CanalTrigger/Shape").shape is CircleShape2D)
assert(level.get_node("Interface/MinigameHost") is Control)
assert(level.get_node("World/WorldObjects").get_child_count() <= 16)
```

新增运行态测试：完成守岭人对话后 phase 进入 `CANAL_AVAILABLE`；只有调用古渠触发测试入口才打开 `canal`；模拟标准完成结果后进入 `DRUM_AVAILABLE` 并恢复地图；军鼓同理进入 `VIEWPOINT_OPEN`。

- [ ] **Step 2: 通过 MCP 扩大并重排灰盒**

停止当前运行，重新打开 `res://scenes/fubo_guling/fubo_guling.tscn`。设置：

```text
Player start: (420, 1850)
Keeper: (1150, 1650)
CanalTrigger: (2600, 1180), radius 120
SchoolTrigger: (1850, 620), radius 130
ViewpointTrigger: (2550, 320), radius 110
Camera limits: left 0, top 0, right 3200, bottom 2200
```

在根节点下创建 `World` Node2D，并把 `Ground`、`Effects`、`WorldObjects`、`Foreground`、`Collision`、`Triggers`、`CollisionDebug` 全部 reparent 到 `World`；`Interface` 与 `Audio` 保持根节点直属。同步把 `fubo_guling.gd` 的所有 `$Ground/...`、`$WorldObjects/...`、`$Collision/...`、`$Triggers/...` 路径改为 `$World/...`。这样宿主只暂停和隐藏 `$World`，不会影响自身。

删除旧 `World/Ground/TerrainArt` 的 18 个拼贴 Sprite2D。创建空 `World/Ground/BackgroundPlates`。把 `World/WorldObjects` 精简为 Player、Keeper、House、Storage、TreeCourtyard、TreePath、TreeCanal、CanalMarker、Drum、三面旗、两道剧情障碍和 Stele，合计不超过 16 个；闸门和池子不再承担地图内操作。

- [ ] **Step 3: 用 6–10 个大块碰撞定义可走廊道**

在 `World/Collision/BlockedRegions` 下创建 8 个 `StaticBody2D`，每个使用 `CollisionPolygon2D`：NorthWestMass、NorthRidge、WestForest、EastCliff、SouthWestSea、SouthCoast、SouthEastSlope、CanalCliff。多边形顶点按灰盒道路外缘绘制，路径净宽 160–240；只保留 HouseFoot、StorageFoot、KeeperBody 和三棵近景树干的小碰撞。开启碰撞调试截图，逐段步行确认没有小缝穿出或尖角卡住。

- [ ] **Step 4: 重构阶段与触发流**

阶段改为：

```gdscript
enum Phase {
    ARRIVAL,
    CANAL_AVAILABLE,
    CANAL_ACTIVE,
    DRUM_AVAILABLE,
    DRUM_ACTIVE,
    VIEWPOINT_OPEN,
    COMPLETE,
}
```

守岭人对话结束只进入 `CANAL_AVAILABLE`。`CanalTrigger` 和 `SchoolTrigger` 进入时显示现场确认；确认后分别调用：

```gdscript
minigame_host.open_minigame(CANAL_SCENE, "canal")
minigame_host.open_minigame(DRUM_SCENE, "drum")
```

统一结果处理：

```gdscript
func _on_minigame_finished(result: Dictionary) -> void:
    if not result.get("completed", false):
        return
    match result.get("game_id", ""):
        "canal": _complete_canal(result)
        "drum": _complete_drum(result)
```

在 `_ready()` 中执行 `minigame_host.configure($World, $Interface/HUD, player)`，并连接 `minigame_finished` 与 `minigame_cancelled`。取消时只把角色放到对应入口的安全落点，不改变 phase。

删除主地图脚本中的 `_nearest_index(GATE_POSITIONS)`、旗帜提交、鼓序列播放和正弦音生成。地图上的闸门、鼓和旗只作地点识别，不接收小游戏输入。

- [ ] **Step 5: 运行集成测试和实际返回测试**

Expected: all new assertions pass. MCP 运行场景，完成/退出两项小游戏各一次，角色回到入口安全点、相机继续跟随、触发不重复创建、任务门控正确。

- [ ] **Step 6: Commit**

```powershell
git add -- scripts/fubo_guling/fubo_guling.gd scripts/fubo_guling/fubo_placeholder_world.gd scenes/fubo_guling/fubo_guling.tscn tests/test_fubo_guling.gd
git commit -m "feat(fubo-guling): integrate location-triggered minigames"
```

---

### Task 7: 四张清新中式局部底图与关键独立物件

**Files:**
- Create: `assets/fubo_guling/backgrounds/fubo_plate_*.png`
- Create or replace selected files under: `assets/fubo_guling/generated/`
- Modify via Godot MCP: `scenes/fubo_guling/fubo_guling.tscn`
- Modify: `docs/assets/fubo-guling-generated-assets.md`
- Modify: `tests/test_fubo_guling.gd`

**Interfaces:**
- Consumes: Task 6 fixed graybox, anchors and blocked regions.
- Produces: four background textures and no more than 10–15 independent visible world objects.

- [ ] **Step 1: 通过 MCP 导出四个无 UI、无角色的局部布局参考**

把相机依次固定到 `(800,1650)`、`(2400,1550)`、`(900,600)`、`(2400,650)`，隐藏 HUD、角色和占位物件，仅显示灰盒道路、院落、海岸和碰撞边界。每个视口按 1536×1024 截图并保存为 `assets/fubo_guling/generated/unified/guide_sw.png` 等四张参考图。

- [ ] **Step 2: 生成西南风格锚点底图**

使用 `guide_sw.png`，提示词必须包含以下原文约束：

```text
Bright fresh Chinese pixel-art RPG local environment, ancient Lingnan coastal military outpost, top-down 3/4 orthographic, clean clustered pixels, light grey brick, blue-grey tile, pale ochre road, clear turquoise water, fresh spring green, low-to-medium contrast, short soft shadows. This is only one local camera neighborhood on a larger island. Land and roads continue beyond the frame. Preserve the guide's walkable road and empty trigger clearings. Bake distant forest, cliffs and unreachable decoration. No complete island silhouette, no miniature diorama, no characters, text, UI, flags, drum, sluice mechanisms or large foreground buildings. Avoid dark realistic rendering, weathering, Japanese shrine and Southeast Asian temple.
```

视觉检查：镜头内只出现码头与守备院邻域，不能出现古渠、校场或观景台；道路宽度相对 64×64 角色至少为 2.5 倍。

- [ ] **Step 3: 依次延展其余三张底图**

每次把上一张的 12–15% 边缘裁片和对应 guide 同时作为参考；复用完全相同的风格段，只替换地点描述。任何一张若擅自画出全部五区、改变光照方向、变暗写实或把地标放大到占据半屏，必须重生，不能靠 Godot 缩放掩盖。

- [ ] **Step 4: 导入并用 MCP 配置背景板**

把最终 PNG 复制到 `assets/fubo_guling/backgrounds/`，保留模型原图。等待 Godot reimport；在 `World/Ground/BackgroundPlates` 下建立 SW、SE、NW、NE 四个 Sprite2D，最近邻过滤、等比缩放不超过 1.25、重叠区 12–15%。通过裁切和节点位置对齐接缝，不做非等比拉伸。

- [ ] **Step 5: 只生成并保留关键独立物件**

生成透明/色键素材：一座 256–320 宽的浅灰砖青瓦守备房、一座较小粮仓、三棵 96–128 宽的榕树/荔枝树冠、地图古渠标识、军鼓和三旗。色键背景必须为纯 `#FF00FF`，使用 `remove_chroma_key.py` 转透明；逐件裁切空白并用最近邻缩放。其余草丛、散石、竹丛和远景墙全部留在底图，不新增节点。

- [ ] **Step 6: 更新素材清单和测试**

素材清单逐项记录：生成模型、完整提示词、原始输出路径、项目路径、透明处理方式、用途和是否独立碰撞。测试加载四张背景并断言纹理非空、`World/Ground/BackgroundPlates` 恰好四个、`World/WorldObjects` 不超过 16 个。

- [ ] **Step 7: MCP 视觉验收**

从码头、守备院、古渠、校场、观景台各截一张 1344×896 运行图；确认没有任何单镜头能看全五区，接缝不显眼，角色与建筑比例正确，至少一房一树的前后遮挡正确。打开碰撞调试，确认大块碰撞与不可进入背景一致。

- [ ] **Step 8: Commit**

```powershell
git add -- assets/fubo_guling/backgrounds assets/fubo_guling/generated scenes/fubo_guling/fubo_guling.tscn docs/assets/fubo-guling-generated-assets.md tests/test_fubo_guling.gd
git commit -m "feat(fubo-guling): add fresh local background plates"
```

---

### Task 8: 回归、Web 行为与文档收尾

**Files:**
- Modify: `docs/changes/CHG-20260810-fubo-guling-medium-map-minigames.md`
- Modify: `docs/qa/playtest.md`
- Modify: `docs/design/fubo-guling-slice.md`, `docs/design/art-direction.md`, `docs/tech/architecture.md` — 即使实现与计划一致，也要核对并记录最终节点名、尺寸和资源路径。

**Interfaces:**
- Consumes: Tasks 1–7 complete implementation.
- Produces: verified, documented deliverable with change record status `done`.

- [ ] **Step 1: 运行专项测试**

通过 Godot MCP `test_run` 逐项运行：

```text
res://tests/test_fubo_minigame_host.gd
res://tests/test_fubo_canal_game.gd
res://tests/test_fubo_drum_game.gd
res://tests/test_fubo_guling.gd
```

Expected: all exit `0`, no parse errors, no orphan-node warnings that originate from these scenes.

- [ ] **Step 2: 运行项目回归**

通过 Godot MCP `test_run` 依次运行以下现有 13 项回归：

```text
res://tests/test_chapter_transition_visual.gd
res://tests/test_click_to_move.gd
res://tests/test_exploration_hud.gd
res://tests/test_fubo_guling.gd
res://tests/test_main_flow_save.gd
res://tests/test_scene_portraits.gd
res://tests/test_scene_transition.gd
res://tests/test_scene_two_dialogue_background.gd
res://tests/test_scene_two_dialogue_patrol.gd
res://tests/test_scene_two_sea_link.gd
res://tests/test_sea_overworld.gd
res://tests/test_system_menu_exit.gd
res://tests/test_title_screen.gd
```

Expected: 13 项全部退出 `0`，与 Task 1 基线一致。

- [ ] **Step 3: 运行桌面完整流程**

用 MCP 精确运行 `res://scenes/fubo_guling/fubo_guling.tscn`：码头 → 守岭人 → 古渠确认 → 中途退出 → 再进入并完成 → 校场军鼓 → 故意失败一轮 → 完成 → 观景台。读取游戏日志；Expected: 没有重复实例、无效节点、输入穿透或恢复失败。

- [ ] **Step 4: 验证 Web 失焦**

在 Web 导出或 Godot 可模拟焦点通知的测试环境中：军鼓输入阶段失焦 2 秒，确认时间线冻结；恢复后显示 3、2、1，再继续同一轮，mistakes 不增加。窗口改为常见宽屏尺寸，两个全屏场景不得裁掉退出按钮、鼓或放水按钮。

- [ ] **Step 5: 记录人工视觉与声音结果**

在 `docs/qa/playtest.md` 记录五处地图截图、四块底图接缝、两项小游戏 1–2 分钟目标、三种鼓声辨识、角色遮挡和大块碰撞巡检结果。若任何一项失败，保持变更记录 `in-progress` 并回到对应任务修正。

- [ ] **Step 6: 对齐文档并完成变更记录**

逐项核对实际节点名、世界尺寸、输入键、回合长度、BPM、音频路径和素材数量。把真实验证命令、退出码、MCP 截图路径和日志摘要写入 `Verification evidence`；全部通过后把状态改为 `done`。

- [ ] **Step 7: Final commit**

```powershell
git add -- docs/changes/CHG-20260810-fubo-guling-medium-map-minigames.md docs/qa/playtest.md docs/design/fubo-guling-slice.md docs/design/art-direction.md docs/tech/architecture.md
git commit -m "docs(fubo-guling): record medium map verification"
```

---

## Final Definition of Done

- 地图为约 3200×2200，中型跟随相机一次无法看全五区。
- 四张局部底图构图、色板、像素密度和接缝统一，不再呈现完整微缩岛屿。
- 非游玩区域由 6–10 个大块碰撞封闭，关键独立视觉对象控制在 10–15 个。
- 守岭人只开放古渠任务；玩家必须到古渠地点确认后才进入水渠小游戏。
- 水渠和军鼓都是独立全屏 PackedScene，退出或完成后恢复同一个地图实例。
- 水渠使用鼠标，军鼓使用 A/S/D 与方向键；失败只重置当前轮。
- 三种鼓声是不同鼓类 WAV，在普通扬声器和低音量下仍易于区分。
- Web 失焦暂停、三拍恢复、重复触发保护和输入隔离全部验证。
- 专项测试、项目回归、MCP 运行截图和日志检查全部通过。
- 权威文档、素材清单、QA 记录与实际行为一致，变更记录为 `done`。
