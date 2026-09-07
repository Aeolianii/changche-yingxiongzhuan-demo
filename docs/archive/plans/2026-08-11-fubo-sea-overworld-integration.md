# 伏波古岭接入海上大地图实施计划

**Goal:** 让玩家从海上大地图现有“伏波古岭”入口进入真实岛屿，并从岛内码头返回登岛前船位。

**Architecture:** 使用一个无场景依赖的 `FuboTravelSession` 统一场景路径、SceneTree 元数据键和返回上下文校验。海图负责记录船位并进入岛屿；岛屿码头只发出返回请求；重新实例化海图后消费上下文并恢复船只状态。正式存档格式保持不变。

**Tech Stack:** Godot 4.7、GDScript、Area2D、SceneTree metadata、现有 `SceneLoadingTransition`、现有脚本式 SceneTree 测试。

## Global constraints

- 伏波古岭立即开放，不增加剧情门槛。
- 海图地点总数保持 15，其他 14 个地点仍为占位入口。
- 海图与岛屿之间双向切换均使用现有加载过渡。
- 岛内码头必须按 `E` / 空格确认后才离岛。
- 返回后恢复船位、朝向、探索阶段和月相；坏上下文回退到 `Vector2(4200, 1140)`。
- 不修改正式存档版本，不持久化岛内进度。
- 不使用 Superpowers，不创建子代理。

---

### Task 1: 旅行上下文契约

**Files:**

- Create: `scripts/fubo_guling/fubo_travel_session.gd`
- Create: `tests/test_fubo_travel_session.gd`

**Interfaces:**

- Produces: `FuboTravelSession.make_context(ship_position: Vector2, facing_index: int, exploration_stage: int, lunar_day: float) -> Dictionary`
- Produces: `FuboTravelSession.decode_context(value: Variant) -> Dictionary`
- Constants: `SEA_SCENE_PATH`, `FUBO_SCENE_PATH`, `RETURN_CONTEXT_META`, `RETURN_REQUEST_META`, `FALLBACK_SEA_POSITION`

- [ ] **Step 1: Write the failing pure-model test**

Test exact valid round-trip values and invalid position/day values:

```gdscript
var context := TRAVEL.make_context(Vector2(4210, 1135), 2, 3, 8.5)
_check(TRAVEL.decode_context(context) == context, "Valid Fubo travel context must round-trip.")
_check(TRAVEL.decode_context({"ship_position": Vector2(INF, 0)}).is_empty(), "Non-finite ship positions must be rejected.")
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/test_fubo_travel_session.gd
```

Expected: failure because `fubo_travel_session.gd` does not exist.

- [ ] **Step 3: Implement the minimal context codec**

```gdscript
class_name FuboTravelSession
extends RefCounted

const SEA_SCENE_PATH := "res://scenes/sea_overworld/sea_overworld.tscn"
const FUBO_SCENE_PATH := "res://scenes/fubo_guling/fubo_guling.tscn"
const RETURN_CONTEXT_META := &"fubo_guling_sea_return_context"
const RETURN_REQUEST_META := &"sea_overworld_return_from_fubo_guling"
const FALLBACK_SEA_POSITION := Vector2(4200, 1140)

static func make_context(ship_position: Vector2, facing_index: int, exploration_stage: int, lunar_day: float) -> Dictionary:
	return {
		"ship_position": ship_position,
		"facing_index": maxi(0, facing_index),
		"exploration_stage": clampi(exploration_stage, 0, 4),
		"lunar_day": maxf(0.0, lunar_day),
	}
```

`decode_context()` validates dictionary shape, finite `Vector2`, integer-like indices and finite nonnegative lunar day; invalid input returns `{}`.

- [ ] **Step 4: Run the focused test and verify GREEN**

Expected: `Fubo travel-session verification passed.` and exit 0.

---

### Task 2: 海图伏波入口与返回状态

**Files:**

- Modify: `scripts/sea_overworld.gd`
- Modify: `tests/test_sea_overworld.gd`

**Interfaces:**

- Consumes: `FuboTravelSession` constants and codec.
- Changes: `_build_location(..., entry_message, map_label_offset, target_scene_path := "")`
- Produces: `_enter_location_scene(scene_path: String, loading_text: String) -> void`
- Produces: `_consume_fubo_return() -> Dictionary` and `_restore_fubo_return(context: Dictionary) -> void`

- [ ] **Step 1: Update sea tests before production code**

Add assertions that:

```gdscript
var fubo := _find_location(get_nodes_in_group("sea_location"), "伏波古岭")
_expect(fubo.get_meta("target_scene_path", "") == FuboTravelSession.FUBO_SCENE_PATH, "Fubo must point to its real island scene.")
_expect(str(fubo.get_meta("entry_message", "")) == "进入伏波古岭", "Fubo must no longer use coming-soon copy.")
```

Change B-region placeholder checks so only the four non-Fubo B locations require “该岛屿即将开放”. Add context restore assertions for ship position, facing, stage and lunar day.

- [ ] **Step 2: Run `test_sea_overworld.gd` and verify RED**

Expected: Fubo target-scene and entry-copy assertions fail.

- [ ] **Step 3: Add target-scene metadata and entry transition**

Configure only Fubo as:

```gdscript
_build_location(
	"伏波古岭", Vector2(4260, 780), 220.0,
	Vector2(440, 120), Vector2(0, 175),
	"进入伏波古岭", Vector2.ZERO,
	FuboTravelSession.FUBO_SCENE_PATH
)
```

When an active location has a target scene, store `make_context(player.global_position, player.save_facing_index(), _exploration_stage, _lunar_day)`, disable controls/HUD, play `"正在登陆伏波古岭"`, and change scene. Placeholder locations keep the current toast path.

- [ ] **Step 4: Restore return context in `_ready()`**

Consume `RETURN_REQUEST_META`; then decode and remove `RETURN_CONTEXT_META`. Valid context restores all four fields. Missing/invalid context uses `FALLBACK_SEA_POSITION`, current facing, current stage and root lunar day. Clamp position to movement bounds and keep player controls enabled.

- [ ] **Step 5: Run sea tests and verify GREEN**

Expected: `Sea overworld runtime verification passed.` and exit 0.

---

### Task 3: 岛屿码头离岛入口

**Files:**

- Modify: `scenes/fubo_guling/fubo_guling.tscn`
- Modify: `scripts/fubo_guling/fubo_guling.gd`
- Modify: `tests/test_fubo_guling.gd`

**Interfaces:**

- Adds node: `World/Triggers/SeaReturnTrigger` at `Vector2(235, 835)` with a `CircleShape2D` radius `55`.
- Consumes: `FuboTravelSession.SEA_SCENE_PATH` and `RETURN_REQUEST_META`.
- Produces: `_return_to_sea_overworld() -> void`.

- [ ] **Step 1: Write failing scene-contract and interaction tests**

Assert the return trigger exists, is at the approved dock-tip position, has radius 55, and is more than the sum of both radii from `FishingTrigger`. Simulate body enter/exit and assert prompt text/visibility. Assert interaction requests the sea scene and does not reload or quit.

- [ ] **Step 2: Run `test_fubo_guling.gd` and verify RED**

Expected: missing `SeaReturnTrigger` assertions fail.

- [ ] **Step 3: Add the scene trigger**

```text
World/Triggers/SeaReturnTrigger (Area2D)
  position = Vector2(235, 835)
  collision_layer = 0
  collision_mask = 1
  Shape (CollisionShape2D, CircleShape2D radius 55)
```

- [ ] **Step 4: Add island return behavior**

Connect body-enter/body-exit in `_ready()`. Enter sets `_pending_trigger = "sea_return"` and text `按 E / 空格 乘船返回海图`; exit clears only the matching pending trigger. `_handle_interaction()` handles `sea_return` before fishing/drum.

`_return_to_sea_overworld()` sets `_transitioning`, disables the player, hides prompts, sets `RETURN_REQUEST_META`, plays `"正在返回岭南海图"`, and changes to `SEA_SCENE_PATH`. Failure removes the request flag, resets loading UI and restores controls/prompt.

- [ ] **Step 5: Run Fubo tests and verify GREEN**

Expected: `Fubo Guling skeleton verification passed.` and exit 0.

---

### Task 4: 真实双向场景往返

**Files:**

- Create: `tests/test_fubo_sea_round_trip.gd`

**Interfaces:**

- Consumes only real packed scenes, real trigger/input paths and `FuboTravelSession` metadata.

- [ ] **Step 1: Write the end-to-end test**

The test:

1. Instantiates the sea map as `current_scene`.
2. Moves the ship into Fubo’s verified clear trigger point.
3. Emits the real Enter button press.
4. Waits until `current_scene.scene_file_path == FUBO_SCENE_PATH`.
5. Moves the island player into `SeaReturnTrigger`, sends the real `interact` action, and waits for `SEA_SCENE_PATH`.
6. Asserts process survival, restored ship position/facing/stage/lunar day and consumed metadata.

- [ ] **Step 2: Run the test and verify it detects any missing link**

Expected before all links are complete: focused failure naming the missing transition or restore field.

- [ ] **Step 3: Make only the smallest corrections needed for GREEN**

Do not introduce save-version changes or generic routing registries. Keep the Fubo route explicit.

- [ ] **Step 4: Run in headless and Vulkan modes**

```powershell
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/test_fubo_sea_round_trip.gd
Godot_v4.7-stable_win64_console.exe --path . --script res://tests/test_fubo_sea_round_trip.gd
```

Expected: `Fubo sea round-trip verification passed.` in both modes.

---

### Task 5: 回归、文档对齐与试玩

**Files:**

- Modify: `docs/design/scene-flow.md`
- Modify: `docs/tech/architecture.md`
- Modify: `docs/qa/playtest.md`
- Modify: `docs/changes/CHG-20260811-fubo-sea-overworld-integration.md`

- [ ] **Step 1: Run focused and adjacent regressions serially**

Run travel session, sea map, Fubo, fishing, drum, minigame host, main-flow save and round-trip tests. Every command must exit 0; distinguish existing ObjectDB/RID cleanup warnings from parser, resource or assertion failures.

- [ ] **Step 2: Run exact scenes visually**

Capture the sea map at the Fubo entry prompt and the island at the dock return prompt at 1344×896. Confirm prompts do not overlap existing HUD and the dock trigger lies inside the approved walkable boundary.

- [ ] **Step 3: Reconcile docs**

Record actual constants, node paths, fallback position, test output, screenshot paths and known cleanup warnings. Set the change record to `done` only after the real round trip succeeds.

- [ ] **Step 4: Launch the sea map for user playtest**

Open `res://scenes/sea_overworld/sea_overworld.tscn`, place the ship near the existing Fubo entrance only if using a temporary test harness, and ensure no harness files remain in production.
