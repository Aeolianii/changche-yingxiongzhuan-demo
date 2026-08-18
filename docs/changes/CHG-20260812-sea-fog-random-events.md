# CHG-20260812：恢复海图迷雾与海上随机事件

- Status: done
- Date: 2026-08-12
- Owner: Codex

## Goal

把主分支历史中已经完成的海图永久探索迷雾，以及漂流木箱、龙井茶商和私盐商事件，兼容移植到当前伏波古岭版本。

## Scope

- 航行视野揭示、世界迷雾遮罩与完整海图迷雾显示。
- 迷雾跨场景运行时保留、正式单槽存档和旧存档回退。
- 漂流木箱一次性双选项事件及完成状态存档。
- 龙井茶商和私盐商选项事件、原型结果提示与一次性完成状态。
- 随机事件期间锁定航行、隐藏地图入口，结束后恢复当前全局 HUD。
- 保留当前伏波古岭登岛/返航、全局探索 UI、点击移动和对话移动锁。

## Non-goals

- 不合并主分支中与本需求无关的地点改名、碰撞重排、出生点调整或场景删减。
- 不建立完整背包、经济或随机刷新系统；事件沿用历史提交中的原型级临时数值。
- 不改变伏波古岭小游戏与岛内存档格式。

## Acceptance checks

- 从县令进入海图后，初始视野与左上大陆已揭示，视野外海域为黑色迷雾。
- 航行持续揭示矩形相机视野；完整海图与世界使用同一探索数据，未探索地点不显示。
- 迷雾跨 Scene2/伏波古岭往返保留，并能随正式存档恢复；旧存档仍可读取。
- 三类事件均能触发对应纸质对话；事件期间船只不能移动，结束后恢复。
- 木箱和两类商船在任一分支结束后永久移除，载入或伏波返航后不重生。
- 大地图、迷雾、三事件、存档、县令往返和伏波往返的针对性测试通过。

## Documentation impact

- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- 本变更记录。

## Likely files

- `scripts/sea_overworld.gd`
- `scripts/sea_fog_of_war.gd`
- `scripts/core/game_state.gd`
- `scripts/exploration_hud.gd`
- `scripts/sea_map_screen.gd`
- `scripts/ui/field_event_dialogue.gd`
- `scenes/ui/field_event_dialogue.tscn`
- `assets/sprites/sea_overworld/`
- `shaders/sea_map_fog_soft_edge.gdshader`
- `tests/test_sea_fog_*.gd`
- `tests/test_sea_overworld_*event.gd`

## Verification evidence

Godot 4.7.1 stable verification completed on 2026-08-12:

- Project headless editor import/parse: passed.
- `test_sea_fog_of_war.gd`: passed in headless and Vulkan Forward+; verified world overlay ordering, initial/continued reveal, shared full-map texture, water-ink soft edge and hidden unexplored labels.
- `test_sea_fog_persistence.gd`: passed; verified `world_state` save/load and legacy save fallback.
- `test_sea_overworld_crate_event.gd`, `test_sea_overworld_tea_merchant_event.gd`, `test_sea_overworld_salt_merchant_event.gd`: passed; covered every branch, movement lock, map-button visibility, removal and restored completion state.
- `test_sea_overworld.gd`: passed after integrating the new events into the current 15-location production map.
- `test_global_exploration_ui.gd`, `test_main_flow_save.gd`, `test_scene_two_sea_link.gd`, `test_fubo_save_state.gd`, `test_fubo_travel_session.gd`, `test_fubo_sea_round_trip.gd`: passed.
- Visual evidence: `.godot/sea_fog_world_preview.png`, `.godot/sea_fog_map_preview.png`, `.godot/sea_overworld_crate_preview.png`, `.godot/sea_overworld_crate_dialogue_preview.png` at 1344×896.
- `git diff --check`: passed for the implementation commit.

## Actual changed files

- `scripts/sea_overworld.gd`
- `scripts/sea_fog_of_war.gd`
- `scripts/core/game_state.gd`
- `scripts/exploration_hud.gd`
- `scripts/sea_map_screen.gd`
- `scripts/ui/title_screen.gd`
- `scripts/ui/field_event_dialogue.gd`
- `scripts/fubo_guling/fubo_travel_session.gd`
- `scenes/ui/field_event_dialogue.tscn`
- `assets/sprites/sea_overworld/drifting_supply_crate_v1.png`
- `assets/sea_overworld/portraits/大地图茶叶商人.png`
- `assets/sea_overworld/portraits/大地图私盐商人.png`
- `shaders/sea_map_fog_soft_edge.gdshader`
- `tests/test_sea_fog_of_war.gd`
- `tests/test_sea_fog_persistence.gd`
- `tests/test_sea_overworld_crate_event.gd`
- `tests/test_sea_overworld_tea_merchant_event.gd`
- `tests/test_sea_overworld_salt_merchant_event.gd`
- `tests/test_sea_overworld.gd`
- `tests/test_fubo_travel_session.gd`
- `tests/test_fubo_sea_round_trip.gd`
- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/assets/sea-overworld-generated-assets.md`
- `docs/qa/playtest.md`
- 本变更记录。
