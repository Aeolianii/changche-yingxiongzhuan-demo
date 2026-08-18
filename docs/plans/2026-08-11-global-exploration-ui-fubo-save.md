# 全局探索 UI 与伏波古岭正式存档实施计划

> **执行约束：** 本计划仅在当前会话内顺序执行；不使用 Superpowers，不创建子代理，不在现有脏工作树上暂存或提交文件。

**Goal:** 将探索 HUD 迁移为进程内唯一的 `ExplorationUI` Autoload，保持皇宫、场景二和海图行为不变，同时让伏波古岭使用完整共享 UI 并支持正式稳定状态存档。

**Architecture:** `ExplorationUI` 作为 `CanvasLayer` Autoload 持有唯一 `ExplorationHUD`，使用 `WeakRef` 管理当前场景所有权并转发四类菜单信号。四个探索场景只提交上下文和可见状态。伏波快照由无场景依赖的 `FuboSaveState` 校验，`GameState` 顶层格式和版本保持不变。

**Tech Stack:** Godot 4.7 stable、GDScript、CanvasLayer Autoload、WeakRef、PackedScene、现有 `GameState` JSON 单槽存档、脚本式 SceneTree 自动测试。

## Global constraints

- 迁移皇宫、场景二、海上大地图和伏波古岭四个探索场景；标题界面不显示探索 HUD。
- SceneTree 中始终只有一份正式 `ExplorationHUD`，场景文件不保留私有实例。
- 保持前三个场景现有剧情、任务、菜单暂停、地图、碰撞、移动与存档行为。
- 伏波两个小游戏内部 UI、规则和音频不改。
- 伏波只保存稳定自由探索状态；不保存对话、小游戏、加载或完成覆盖层。
- `GameState.SAVE_VERSION` 保持 `1`，旧存档继续兼容。
- 所有像素 UI 纹理使用最近邻过滤；验证必须包含 1344×896 Vulkan 截图。
- 保留用户现有未提交修改，不执行 `git add` 或 `git commit`。

---

### Task 1: 唯一全局 ExplorationUI 所有权

**Files:**

- Create: `scripts/ui/exploration_ui.gd`
- Modify: `project.godot`
- Create: `tests/test_global_exploration_ui.gd`

**Interfaces:**

- Produces: `ExplorationUI.acquire(owner: Node, context_id: StringName) -> Control`
- Produces: `ExplorationUI.release(owner: Node) -> void`
- Produces: `ExplorationUI.get_hud() -> Control`
- Produces signals: `menu_visibility_changed(is_open: bool)`, `save_requested`, `load_requested`, `return_title_requested`
- Invariant: `ExplorationUI` owns exactly one child named `HUD` instantiated from `res://scenes/ui/exploration_hud.tscn`.

- [ ] **Step 1: Write the failing Autoload lifecycle test**

Create `tests/test_global_exploration_ui.gd` and assert:

```gdscript
var ui := root.get_node_or_null("ExplorationUI")
_expect(ui != null, "ExplorationUI autoload must exist.")
_expect(ui.get_child_count() == 1, "ExplorationUI must own exactly one HUD.")
var owner_a := Node.new()
var owner_b := Node.new()
root.add_child(owner_a)
root.add_child(owner_b)
var first: Control = ui.call("acquire", owner_a, &"palace")
var second: Control = ui.call("acquire", owner_b, &"scene_two")
_expect(first == second, "All scenes must acquire the same HUD instance.")
ui.call("release", owner_a)
_expect(ui.call("current_owner") == owner_b, "A stale owner must not release the new scene HUD.")
ui.call("release", owner_b)
_expect(not second.visible, "Releasing the current owner must hide the HUD.")
```

- [ ] **Step 2: Run the new test and verify RED**

Run:

```powershell
& 'C:\Users\wangk\Desktop\Godot_v4.7-stable_win64_console.exe' --headless --path . --script res://tests/test_global_exploration_ui.gd
```

Expected: exit 1 because `/root/ExplorationUI` does not exist.

- [ ] **Step 3: Implement the Autoload manager**

Create `scripts/ui/exploration_ui.gd` with this ownership shape:

```gdscript
extends CanvasLayer

const HUD_SCENE := preload("res://scenes/ui/exploration_hud.tscn")

signal menu_visibility_changed(is_open: bool)
signal save_requested
signal load_requested
signal return_title_requested

var _hud: Control
var _owner_ref: WeakRef
var _context_id := &""

func _ready() -> void:
	layer = 90
	_hud = HUD_SCENE.instantiate() as Control
	_hud.name = "HUD"
	add_child(_hud)
	_hud.menu_visibility_changed.connect(func(value: bool) -> void: menu_visibility_changed.emit(value))
	_hud.save_requested.connect(func() -> void: save_requested.emit())
	_hud.load_requested.connect(func() -> void: load_requested.emit())
	_hud.return_title_requested.connect(func() -> void: return_title_requested.emit())
	_hud.call("set_exploration_visible", false)

func acquire(owner: Node, context_id: StringName) -> Control:
	_owner_ref = weakref(owner)
	_context_id = context_id
	if _hud.has_method("reset_context"):
		_hud.call("reset_context", context_id)
	else:
		_hud.call("set_exploration_visible", false)
	return _hud

func release(owner: Node) -> void:
	if current_owner() != owner:
		return
	_hud.call("set_exploration_visible", false)
	_owner_ref = null
	_context_id = &""

func current_owner() -> Node:
	return null if _owner_ref == null else _owner_ref.get_ref() as Node

func get_hud() -> Control:
	return _hud
```

Register after `GameState` in `project.godot`:

```ini
ExplorationUI="*res://scripts/ui/exploration_ui.gd"
```

- [ ] **Step 4: Run the lifecycle test and verify GREEN**

Expected: `Global exploration UI lifecycle verification passed.` and exit 0.

---

### Task 2: 可重置的 HUD 上下文与伏波任务页

**Files:**

- Modify: `scripts/exploration_hud.gd`
- Modify: `scripts/ui/quest_screen.gd`
- Modify: `tests/test_exploration_hud.gd`
- Modify: `tests/test_global_exploration_ui.gd`

**Interfaces:**

- Consumes: `ExplorationUI.acquire(owner, context_id)` from Task 1.
- Produces: `ExplorationHUD.reset_context(context_id: StringName) -> void`
- Produces: `QuestScreen.set_quest_context(context_id: StringName) -> void` for `palace`, `scene_two`, `sea_overworld`, `fubo_guling`.
- Produces: `_make_fubo_guling_quests() -> Array[Dictionary]` and `_make_fubo_guling_main_task(progress_stage: int) -> Dictionary`.

- [ ] **Step 1: Add failing context-reset assertions**

Extend `tests/test_exploration_hud.gd` to acquire the global HUD, switch `sea_overworld -> fubo_guling -> palace`, and assert:

```gdscript
hud.call("reset_context", &"sea_overworld")
_expect(hud.has_node("SeaMapStatus"), "Sea context must expose the map entry.")
hud.call("reset_context", &"fubo_guling")
_expect(not hud.has_node("SeaMapStatus"), "Fubo context must remove sea-only controls.")
hud.call("set_main_task_progress", "伏波古岭", "沿山路寻找守岭人", 0)
_expect((hud.get_node("QuestTracker/MainQuest/TaskName") as Label).text == "伏波古岭", "Fubo tracker must use its own task.")
var quest_screen := hud.get_node("QuestScreen")
_expect(quest_screen.call("quest_context_for_test") == &"fubo_guling", "Quest screen must receive the Fubo context.")
hud.call("reset_context", &"palace")
_expect(hud.get_node("PlayerStatus/PortraitFrame/ProtagonistPortrait").visible, "Land context must restore the protagonist portrait.")
```

- [ ] **Step 2: Run HUD tests and verify RED**

Expected failures: missing `reset_context`, sea-only nodes persist, and `fubo_guling` is ignored.

- [ ] **Step 3: Implement complete reset instead of one-way sea mutation**

Add `reset_context()` and `_disable_sea_map_status()` to `scripts/exploration_hud.gd`. `_disable_sea_map_status()` must:

```gdscript
func _disable_sea_map_status() -> void:
	if not _sea_map_mode:
		return
	_sea_map_mode = false
	if is_instance_valid(_sea_map_status):
		_sea_map_status.queue_free()
	_sea_map_status = null
	if is_instance_valid(_moon_icon):
		_moon_icon.queue_free()
	if is_instance_valid(_moon_phase_label):
		_moon_phase_label.queue_free()
	var status := get_node("PlayerStatus") as Control
	status.position = Vector2(22, 18)
	status.size = Vector2(495, 192)
	(status.get_node("GeneratedStatusFrame") as TextureRect).texture = EXPLORATION_STATUS_FRAME
	var portrait_frame := status.get_node("PortraitFrame") as Control
	portrait_frame.position = Vector2(33, 23)
	portrait_frame.size = Vector2(141, 141)
	portrait_frame.clip_contents = true
	portrait_frame.get_node("ProtagonistPortrait").show()
	status.get_node("NamePlate").show()
```

`reset_context()` first calls `set_exploration_visible(false)`, stops/hides toast, disables sea mode, resets land tracker copy, then enables sea mode only for `&"sea_overworld"`, and finally forwards the exact context to `QuestScreen`.

- [ ] **Step 4: Add Fubo quest data**

Update `QuestScreen.set_quest_context()` to rebuild default quests for land contexts, sea quests for `sea_overworld`, and Fubo quests for `fubo_guling`. The Fubo main quest must expose four steps matching progress stages 0–3:

```gdscript
[
	{"title": "寻找守岭人", "completed": progress_stage >= 1},
	{"title": "码头摆钩钓鱼", "completed": progress_stage >= 2},
	{"title": "完成古校场鼓令", "completed": progress_stage >= 3},
	{"title": "登岭眺望南海", "completed": progress_stage >= 4},
]
```

`_make_main_quest_state()` must route task title `伏波古岭` and its stage-specific titles to `_make_fubo_guling_main_task(progress_stage)`.

- [ ] **Step 5: Run HUD and global lifecycle tests and verify GREEN**

Run both focused tests serially. Expected: one HUD, reversible land/sea context, correct Fubo task page, exit 0.

---

### Task 3: 迁移皇宫、场景二与海上大地图

**Files:**

- Modify: `scenes/palace/palace_demo.tscn`
- Modify: `scenes/Scene2.tscn`
- Modify: `scenes/sea_overworld/sea_overworld.tscn`
- Modify: `scripts/palace_demo.gd`
- Modify: `scripts/scene_2.gd`
- Modify: `scripts/sea_overworld.gd`
- Modify: `tests/test_exploration_hud.gd`
- Modify: `tests/test_click_to_move.gd`
- Modify: `tests/test_scene_transition.gd`
- Modify: `tests/test_scene_two_dialogue_background.gd`
- Modify: `tests/test_scene_two_dialogue_patrol.gd`
- Modify: `tests/test_scene_two_sea_link.gd`
- Modify: `tests/test_sea_overworld.gd`
- Modify: `tests/test_title_screen.gd`

**Interfaces:**

- Consumes: `/root/ExplorationUI.acquire()` and manager signals.
- Preserves: each scene's existing `_on_save_requested`, `_on_load_requested`, `_on_return_title_requested`, menu pause and HUD refresh behavior.

- [ ] **Step 1: Change tests to require no scene-owned HUD**

Add a shared assertion pattern to the affected tests:

```gdscript
var hud := root.get_node("ExplorationUI").call("get_hud") as Control
_expect(scene.get_node_or_null("UI/ExplorationHUD") == null, "Scenes must not own private HUD instances.")
_expect(get_nodes_in_group("exploration_hud").size() <= 1, "Only one global exploration HUD may exist.")
```

Update all direct `scene.get_node("UI/ExplorationHUD/..." )` references to start from the acquired global `hud`.

- [ ] **Step 2: Run scene and HUD tests and verify RED**

Expected: private HUD nodes still exist and global HUD is not configured by the scenes.

- [ ] **Step 3: Remove three serialized HUD instances through Godot editor operations**

For each scene remove only its `ExplorationHUD` instance and unused PackedScene external resource. Do not move dialogue, loading or scene-specific UI nodes.

- [ ] **Step 4: Replace scene-local onready paths with global acquisition**

Each scene declares:

```gdscript
var exploration_hud: Control
var _exploration_ui: Node
```

At the beginning of `_ready()`:

```gdscript
_exploration_ui = get_node("/root/ExplorationUI")
exploration_hud = _exploration_ui.call("acquire", self, &"palace") as Control
_connect_global_hud_signals()
```

Use context IDs `palace`, `scene_two`, and `sea_overworld`. `_connect_global_hud_signals()` connects the manager's four forwarded signals only if not already connected. `_exit_tree()` disconnects those Callables and calls `release(self)`.

Every forwarded-signal handler begins with this stale-owner guard so an inactive scene retained by a test or transition cannot process another scene's menu request:

```gdscript
if _exploration_ui.call("current_owner") != self:
	return
```

- [ ] **Step 5: Preserve scene-specific setup**

- Palace calls its existing `_refresh_exploration_hud()` after acquisition.
- Scene2 restores the correct patrol/drill/sea-departure task before showing HUD.
- SeaOverworld calls `configure_sea_map()`, restores lunar day, then shows HUD.
- Scene transitions call `set_exploration_visible(false)` before loading; failure calls the existing HUD refresh path.

- [ ] **Step 6: Run focused migrations serially and verify GREEN**

Run:

```powershell
test_exploration_hud.gd
test_click_to_move.gd
test_scene_transition.gd
test_scene_two_dialogue_background.gd
test_scene_two_dialogue_patrol.gd
test_scene_two_sea_link.gd
test_sea_overworld.gd
test_title_screen.gd
```

Expected: all exit 0 and no duplicate-signal assertion.

---

### Task 4: 伏波共享 HUD 与水墨地图交互层

**Files:**

- Modify: `scenes/fubo_guling/fubo_guling.tscn`
- Modify: `scripts/fubo_guling/fubo_guling.gd`
- Modify: `tests/test_fubo_guling.gd`
- Modify: `tests/test_fubo_minigame_host.gd`
- Create: `tests/test_fubo_global_ui.gd`

**Interfaces:**

- Consumes: `ExplorationUI.acquire(self, &"fubo_guling")`.
- Produces: `_refresh_exploration_hud() -> void` mapping Fubo phase to tracker progress.
- Preserves node paths: `Interface/HUD/PromptPanel`, `DialoguePanel`, `Overlay` so existing gameplay code remains readable.

- [ ] **Step 1: Write failing Fubo UI contract tests**

Assert:

```gdscript
_check(level.get_node_or_null("Interface/HUD/TitlePanel") == null, "Fubo must remove the old title rectangle.")
var hud := root.get_node("ExplorationUI").call("get_hud") as Control
_check(hud.visible, "Fubo free exploration must show the global HUD.")
_check((hud.get_node("QuestTracker/MainQuest/TaskName") as Label).text == "伏波古岭", "Fubo must project its task into the global tracker.")
var prompt := level.get_node("Interface/HUD/PromptPanel") as TextureRect
_check(prompt.texture.resource_path.ends_with("interaction_button_ink_v1.png"), "Fubo prompt must use the existing ink interaction art.")
var dialogue := level.get_node("Interface/HUD/DialoguePanel") as TextureRect
_check(dialogue.texture.resource_path.ends_with("ink_dialogue_backdrop.png"), "Fubo dialogue must use the shared ink backdrop.")
```

Open and cancel each minigame; assert global HUD hidden while active and restored afterward.

- [ ] **Step 2: Run Fubo UI tests and verify RED**

Expected: old panels exist, no global HUD acquisition, and prompt/dialogue are `ColorRect`.

- [ ] **Step 3: Acquire and drive the global HUD**

In `FuboGuling._ready()`, acquire `fubo_guling`, connect menu/save/load/title signals, and call `_refresh_exploration_hud()`. The phase mapping is:

```gdscript
var task := {
	Phase.ARRIVAL: ["伏波古岭", "沿山路寻找守岭人", 0],
	Phase.FISHING_AVAILABLE: ["伏波古岭", "返回码头，开始摆钩钓鱼", 1],
	Phase.DRUM_AVAILABLE: ["伏波古岭", "沿山路前往古校场", 2],
	Phase.VIEWPOINT_OPEN: ["伏波古岭", "登上观景台眺望南海", 3],
	Phase.COMPLETE: ["伏波古岭", "行程完成", 4],
}[phase]
exploration_hud.call("set_main_task_progress", task[0], task[1], task[2])
```

Menu visibility disables player movement and clears click targets. Dialogue, minigame, loading and complete overlay hide the global HUD; their close/cancel paths call `_refresh_exploration_hud()`.

- [ ] **Step 4: Replace only the simple map-layer panels**

Through Godot scene editing:

- Remove `TitlePanel`, `FishingPanel`, `DrumPanel`.
- Change `PromptPanel` to `TextureRect` with `interaction_button_ink_v1.png`, nearest filtering and a centered text-safe area.
- Change `DialoguePanel` to `TextureRect` with `ink_dialogue_backdrop.png`; add/retain engine text and use `ink_speaker_nameplate.png` for the speaker plate.
- Keep `Overlay` as the full-screen dimmer but add a centered `TextureRect` ink backdrop behind `OverlayText`; the dimmer itself must not look like the message box.
- Preserve all gameplay node paths used by `fubo_guling.gd` except removed status panels.

- [ ] **Step 5: Run Fubo, host and round-trip tests and verify GREEN**

Expected: global HUD restores after both minigames, map interaction UI uses shared art, sea return remains functional.

---

### Task 5: 伏波稳定快照与正式 GameState 接入

**Files:**

- Create: `scripts/fubo_guling/fubo_save_state.gd`
- Modify: `scripts/core/game_state.gd`
- Modify: `scripts/fubo_guling/fubo_guling.gd`
- Create: `tests/test_fubo_save_state.gd`
- Modify: `tests/test_main_flow_save.gd`
- Modify: `tests/test_fubo_global_ui.gd`
- Modify: `tests/test_title_screen.gd`

**Interfaces:**

- Produces class: `FuboSaveState extends RefCounted`.
- Produces: `make_snapshot(player_position: Vector2, player_facing: String, phase: int, sea_return_context: Dictionary) -> Dictionary`.
- Produces: `decode_snapshot(value: Variant) -> Dictionary`.
- Consumes: `FuboTravelSession.decode_context()` for optional return context.

- [ ] **Step 1: Write the failing pure save codec test**

Test stable phase values `0`, `1`, `3`, `5`; reject active/complete phase values `2`, `4`, `6`, non-finite positions, unknown facing, and inconsistent completion flags. Assert invalid/missing sea context normalizes to `{}` without rejecting an otherwise valid Fubo snapshot.

```gdscript
var snapshot := SAVE_STATE.make_snapshot(Vector2(420, 820), "left", 3, valid_sea_context)
_check(snapshot["fishing_completed"] and not snapshot["drum_completed"], "DRUM_AVAILABLE must encode fishing completion only.")
_check(SAVE_STATE.decode_snapshot(snapshot) == snapshot, "Valid Fubo snapshots must round-trip.")
var invalid := snapshot.duplicate(true)
invalid["drum_completed"] = true
_check(SAVE_STATE.decode_snapshot(invalid).is_empty(), "Contradictory completion flags must be rejected.")
```

- [ ] **Step 2: Run codec and GameState tests and verify RED**

Expected: missing `fubo_save_state.gd` and unsupported Fubo scene.

- [ ] **Step 3: Implement the minimal codec**

`FuboSaveState` defines:

```gdscript
const STABLE_PHASES := [0, 1, 3, 5]
const FACINGS := ["up", "left", "down", "right"]

static func completion_for_phase(phase: int) -> Array[bool]:
	return [phase >= 3, phase >= 5]
```

`decode_snapshot()` requires finite two-number position data, facing in `FACINGS`, integer phase in `STABLE_PHASES`, boolean completion fields matching `completion_for_phase()`, and returns normalized optional `sea_return_context` through `FuboTravelSession.decode_context()`.

- [ ] **Step 4: Add Fubo to the existing save whitelist without version bump**

Append exactly:

```gdscript
"res://scenes/fubo_guling/fubo_guling.tscn",
```

to `GameState.ALLOWED_SCENES`. Do not change `SAVE_VERSION` or the JSON top-level structure.

- [ ] **Step 5: Implement Fubo save, load and restore handlers**

Add:

```gdscript
const SCENE_PATH := "res://scenes/fubo_guling/fubo_guling.tscn"

func _on_save_requested() -> void:
	if not _is_stable_save_state():
		_show_save_message(false, "unstable_scene")
		return
	var context := get_tree().root.get_meta(FUBO_TRAVEL.RETURN_CONTEXT_META, {}) as Dictionary
	var snapshot := FuboSaveState.make_snapshot(player.global_position, player.facing, phase, context)
	var result: Dictionary = _game_state().call("save_game", SCENE_PATH, snapshot)
	_show_save_message(bool(result.get("ok", false)), str(result.get("reason", "")))
```

At `_ready()`, consume `GameState.consume_pending_scene_state(SCENE_PATH)`, decode it, restore the player and phase without replaying dialogue/notices, derive barrier/objective state, and restore valid `sea_return_context` to the SceneTree root. Invalid snapshots show an error and retain the normal island start.

`_on_load_requested()` and `_on_return_title_requested()` follow the existing three-scene pattern. Loading failure clears pending state and restores HUD/control.

- [ ] **Step 6: Test disk isolation and title continue route**

Use `GameState.save_path_override = "user://test_fubo_save.json"`; verify save/load and title continue enter Fubo. Hash and timestamp of `user://main_flow_save.json` must remain unchanged during tests.

- [ ] **Step 7: Run save tests and verify GREEN**

Expected: codec, main-flow save, Fubo UI/save and title tests all exit 0.

---

### Task 6: 全量回归、视觉检查与文档对账

**Files:**

- Modify: `docs/specs/2026-08-11-global-exploration-ui-fubo-save-design.md`
- Modify: `docs/changes/CHG-20260811-global-exploration-ui-fubo-save.md`
- Modify: `docs/design/fubo-guling-slice.md`
- Modify: `docs/design/scene-flow.md`
- Modify: `docs/tech/architecture.md`
- Modify: `docs/qa/playtest.md`

**Interfaces:**

- Consumes all prior tasks.
- Produces final verified behavior and `Status: done` change record.

- [ ] **Step 1: Validate touched Godot resources**

Use the live Godot editor/MCP if available to inspect Autoload registration, the single HUD tree, removed scene instances, Fubo texture resources and unsaved state. If MCP remains unavailable, record that limitation and run Godot resource loading plus exact target scenes; do not claim editor inspection.

- [ ] **Step 2: Run focused and adjacent regressions serially**

Run at minimum:

```text
test_global_exploration_ui.gd
test_exploration_hud.gd
test_main_flow_save.gd
test_title_screen.gd
test_scene_transition.gd
test_scene_two_dialogue_patrol.gd
test_scene_two_sea_link.gd
test_sea_overworld.gd
test_fubo_save_state.gd
test_fubo_guling.gd
test_fubo_global_ui.gd
test_fubo_fishing_game.gd
test_fubo_drum_game.gd
test_fubo_minigame_host.gd
test_fubo_sea_round_trip.gd
```

Every command must exit 0. Record existing shutdown-only RID/ObjectDB warnings separately from parser, resource or assertion failures.

- [ ] **Step 3: Run Vulkan visual scenarios at 1344×896**

Capture:

1. Palace free exploration HUD.
2. Scene2 free exploration HUD.
3. Sea map lunar/map HUD.
4. Fubo free exploration HUD.
5. Fubo dock interaction prompt.
6. Fubo keeper dialogue.
7. Fubo task screen.
8. Fubo system menu.
9. Fubo minigame active and post-exit HUD restoration.

Verify no duplicate HUD, old Fubo title rectangle, sea-only icon leakage, overlapping text, stretched nearest-neighbor assets or invisible input blocker.

- [ ] **Step 4: Reconcile documentation**

Replace planned wording with actual class names, node paths, context IDs, snapshot keys and validation output. Mark the four new QA rows passed only after runtime and screenshots succeed. Set the spec to `implemented and verified` and the change record to `done`, listing actual changed files and exact test evidence.

- [ ] **Step 5: Launch the Fubo scene for user playtest**

Run `res://scenes/fubo_guling/fubo_guling.tscn` in Godot 4.7, keep the interactive window open, and report the controls and save/read expectations.
