# CHG-20260811：伏波古岭接入海上大地图

- Status: done
- Date: 2026-08-11
- Owner: Codex

## Goal

让海上大地图中的伏波古岭现在即可进入，并从岛屿码头返回登岛前的海图位置。

## Scope

- 伏波地点专用场景切换与加载反馈。
- 会话级船位、朝向、探索阶段和月相返回上下文。
- 岛屿码头离岛触发区和海图返回切换。
- 海图、岛屿和完整往返测试。

## Non-goals

- 不接入其他地点，不新增剧情门控，不扩展正式存档，不持久化岛内进度。

## Acceptance checks

- 海图伏波地点可通过按钮和 `E` 进入真实岛屿。
- 岛内码头通过 `E` / 空格返回海图，不自动离岛。
- 返回后船位、朝向、探索阶段和月相恢复；上下文异常时使用安全回退点。
- 连续输入不能重复切换；失败时恢复控制并可重试。
- 15 个海图地点、既有占位地点行为和相关回归测试保持稳定。

## Documentation impact

- `docs/specs/2026-08-11-fubo-sea-overworld-integration-design.md`
- `docs/design/sea-overworld-design.md`
- `docs/design/fubo-guling-slice.md`
- `docs/design/scene-flow.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`

## Likely files

- `scripts/sea_overworld.gd`
- `scripts/fubo_guling/fubo_guling.gd`
- `scenes/fubo_guling/fubo_guling.tscn`
- `tests/test_sea_overworld.gd`
- `tests/test_fubo_guling.gd`
- `tests/test_fubo_sea_round_trip.gd`

## Verification evidence

Godot 4.7 stable verification completed on 2026-08-11:

- `test_fubo_travel_session.gd`: passed.
- `test_sea_overworld.gd`: passed after confirming the new assertions failed before implementation.
- `test_fubo_guling.gd`: passed after confirming the missing dock trigger failed before implementation.
- `test_fubo_sea_round_trip.gd`: passed in headless and Vulkan Forward+ modes using the real sea-map `E` input, real island trigger and real `interact` input.
- Adjacent `test_fubo_fishing_game.gd`, `test_fubo_drum_game.gd`, `test_fubo_minigame_host.gd`, `test_main_flow_save.gd` and `test_scene_two_sea_link.gd`: passed.
- Visual evidence: `.godot/fubo_sea_entry_preview.png` and `.godot/fubo_island_return_preview.png` at 1344×896. Entry and return prompts do not overlap the active play route or existing HUD.
- Existing test shutdown reports still include known ObjectDB/RID cleanup warnings; all commands exited 0 and no parser, resource-load or assertion failure remained.

## Actual changed files

- `scripts/fubo_guling/fubo_travel_session.gd`
- `scripts/sea_overworld.gd`
- `scripts/fubo_guling/fubo_guling.gd`
- `scenes/fubo_guling/fubo_guling.tscn`
- `tests/test_fubo_travel_session.gd`
- `tests/test_sea_overworld.gd`
- `tests/test_fubo_guling.gd`
- `tests/test_fubo_sea_round_trip.gd`
- `docs/index.md`
- `docs/specs/2026-08-11-fubo-sea-overworld-integration-design.md`
- `docs/plans/2026-08-11-fubo-sea-overworld-integration.md`
- `docs/design/sea-overworld-design.md`
- `docs/design/fubo-guling-slice.md`
- `docs/design/scene-flow.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `docs/changes/CHG-20260811-fubo-sea-overworld-integration.md`
