# CHG-20260816-sea-overworld-click-move: 海上大地图点击移动

- Status: done
- Date: 2026-08-16

## Goal

允许玩家在海上大地图左键点击海面，为 Q 版船只设置世界坐标目标并自动直线驶向该位置。

## Player-visible outcome

- 自由航行时左键点击海面，船只立即转向并驶向点击位置。
- 到达目标附近后自动停船；WASD / 方向键输入会立即接管并取消点击目标。
- 打开完整海图、系统菜单、物品栏、对话或转场等输入锁定状态时，既不接受新目标，也会清除旧目标。
- 岛屿、海岸等既有碰撞继续阻挡船只；持续无法接近的目标会自动取消，不穿越陆地。

## Scope

- 为 `SeaOverworldPlayer` 增加点击目标状态、世界坐标换算、自动航行、到达停止、键盘抢占和受阻超时取消。
- 扩展统一点击移动测试，覆盖海图船只的点击、到达、键盘抢占、输入锁和碰撞阻挡。
- 更新海上大地图设计与 QA 验收。

## Non-goals

- 不加入 NavigationAgent2D、自动绕岛、航线规划、寻路预览、快速移动或航行惯性。
- 不修改地图碰撞、地点进入、随机事件、敌船追击、月相、存档或船只速度。
- 不改变右键、地点按钮及其他 UI 的交互。

## Acceptance checks

- 点击坐标经过当前相机画布变换后正确映射到世界坐标。
- 船只在无阻挡水面抵达目标，停止误差不超过 7 世界单位。
- 键盘移动、`controls_enabled = false` 和持续碰撞均会清除点击目标。
- 现有海图与点击移动回归测试通过，指定海图场景可运行且无新增脚本错误。

## Documentation impact

- `docs/design/sea-overworld-design.md`：把操作方式从“仅键盘”改为“键盘 + 左键点击直线航行”。
- `docs/qa/playtest.md`：增加海图点击移动、取消和碰撞验收。

## Likely files

- `scripts/sea_overworld_player.gd`
- `tests/test_click_to_move.gd`
- `docs/design/sea-overworld-design.md`
- `docs/qa/playtest.md`
- `docs/superpowers/plans/2026-08-16-sea-overworld-click-move.md`

## Verification evidence

- 2026-08-16 RED：`tests/test_click_to_move.gd` 在实现前以“Sea-overworld ship must expose the shared click-move target contract”失败。
- 2026-08-16 GREEN：`Godot_v4.7-stable_mono_win64_console.exe --headless --path . --script tests/test_click_to_move.gd` 通过，覆盖世界坐标映射、无阻挡抵达、键盘打断、输入锁清除和碰撞受阻超时。
- `tests/test_global_exploration_ui.gd`、`tests/test_scene_two_sea_link.gd`、`tests/test_sea_overworld_random_event_refresh.gd` 通过。
- `dotnet build ChangcheHeroes.csproj --no-restore` 通过，0 警告、0 错误。
- Godot 编辑器已以 custom scene 模式启动 `res://scenes/sea_overworld/sea_overworld.tscn` 并保留 DEBUG 窗口供人工点击验收；当前运行进程响应正常。编辑器运行助手未连通，报告的是此前保留的 `yuehuan_merchant_harbor.gd:20` 类型缓存错误，本次海图运行日志没有新增条目。
- 已知基线问题：`tests/test_sea_overworld.gd` 的 32 个海图碰撞旧基准与当前已提交场景不一致；`tests/test_main_flow_save.gd` 存在伏波岛支线投影恢复失败；`tests/test_sea_fog_of_war.gd` 第 64 行调用不存在的 `float` 构造器。这些失败不在本次点击移动范围内，本次未修改相关场景、任务或测试基准。

## Actual files changed

- `scripts/sea_overworld_player.gd`
- `tests/test_click_to_move.gd`
- `docs/design/sea-overworld-design.md`
- `docs/qa/playtest.md`
- `docs/changes/CHG-20260816-sea-overworld-click-move.md`
- `docs/superpowers/plans/2026-08-16-sea-overworld-click-move.md`
