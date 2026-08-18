# CHG-20260811：全局探索 UI 与伏波古岭正式存档

- Status: done
- Date: 2026-08-11
- Owner: Codex

## Goal

将探索 HUD 改为跨场景唯一的 Autoload，并让伏波古岭完整沿用主系统 UI 与正式单槽存档。

## Player-visible outcome

- 皇宫、场景二、海图和伏波古岭使用同一份水墨像素探索 HUD。
- 伏波的简单方框 UI 被共享 HUD 和既有水墨交互/对话底板替换。
- 伏波稳定探索状态可以正式保存、读取并继续返航海图。

## Scope

- 新增全局 `ExplorationUI` Autoload 与四场景生命周期迁移。
- 增加 `fubo_guling` 任务上下文。
- 重做伏波地图层提示、对话和完成覆盖层样式。
- 将伏波加入 `GameState` 支持场景并实现稳定快照恢复。
- 更新受影响测试和视觉验收。

## Non-goals

- 不修改伏波两个小游戏内部 UI、规则或音频。
- 不持久化小游戏、对白、过场或加载动画的中间状态。
- 不改变四场景剧情、地图、碰撞和移动规则。

## Acceptance checks

- 四个探索场景和标题往返后 SceneTree 中始终只有一份正式探索 HUD。
- 伏波显示完整共享 HUD，任务与七阶段状态机一致，旧左上方框不再显示。
- 伏波底部交互、守岭人对话和完成提示使用现有水墨像素资源。
- 伏波稳定状态存读档恢复位置、朝向、阶段、两项完成标记和海图返航上下文。
- 对话、小游戏、加载和完成覆盖状态拒绝保存且不覆盖旧存档。
- 既有皇宫、场景二、海图、标题、存档和伏波小游戏回归通过。

## Documentation impact

- `docs/specs/2026-08-11-global-exploration-ui-fubo-save-design.md`
- `docs/design/fubo-guling-slice.md`
- `docs/design/scene-flow.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`

## Likely files

- `project.godot`
- `scripts/ui/exploration_ui.gd`
- `scripts/exploration_hud.gd`
- `scripts/ui/quest_screen.gd`
- `scripts/core/game_state.gd`
- `scripts/palace_demo.gd`
- `scripts/scene_2.gd`
- `scripts/sea_overworld.gd`
- `scripts/fubo_guling/fubo_guling.gd`
- `scenes/palace/palace_demo.tscn`
- `scenes/Scene2.tscn`
- `scenes/sea_overworld/sea_overworld.tscn`
- `scenes/fubo_guling/fubo_guling.tscn`
- relevant exploration, scene-flow, save and Fubo tests

## Verification evidence

- Godot 4.7 headless: `test_global_exploration_ui.gd`, `test_exploration_hud.gd`, `test_click_to_move.gd`, `test_scene_transition.gd`, `test_scene_two_dialogue_background.gd`, `test_scene_two_dialogue_patrol.gd`, `test_scene_two_sea_link.gd`, `test_sea_overworld.gd` 全部退出码 0。
- Godot 4.7 headless: `test_fubo_save_state.gd`, `test_main_flow_save.gd`, `test_title_screen.gd`, `test_fubo_guling.gd`, `test_fubo_global_ui.gd`, `test_fubo_fishing_game.gd`, `test_fubo_drum_game.gd`, `test_fubo_minigame_host.gd`, `test_fubo_sea_round_trip.gd` 全部退出码 0。
- 伏波存档覆盖四个稳定阶段的编解码、JSON 往返、位置、朝向、完成标记和返航上下文；磁盘恢复与标题“继续游戏”已实际加载伏波，小游戏中保存不会覆盖旧档。
- Godot 4.7 Vulkan / NVIDIA GeForce RTX 5060 / 1344×896 捕获七个状态：自由探索、守岭人对话、码头提示、任务页、系统菜单、钓鱼中、退出小游戏后。目视确认无旧状态方框、无 HUD 重叠，水墨文字安全区清晰。
- 当前工具列表未暴露可调用的 Godot 编辑器 MCP 操作；运行日志确认 `godot_ai game_helper` 已注册 MCP capture。本次编辑与验证使用项目文件和官方 Godot 4.7 运行器完成，未声称执行了不可用的编辑器 MCP 调用。
- 相关 SceneTree 测试退出时仍会报告项目既有的 RID / ObjectDB 清理警告；没有解析错误、资源加载错误或断言失败。

## Actual changed files

- 全局 UI：`project.godot`、`scripts/ui/exploration_ui.gd`、`scripts/exploration_hud.gd`、`scripts/ui/quest_screen.gd`。
- 四场景迁移：`scripts/palace_demo.gd`、`scripts/scene_2.gd`、`scripts/sea_overworld.gd`、`scripts/fubo_guling/fubo_guling.gd`，以及对应四个 `.tscn`。
- 正式存档：`scripts/core/game_state.gd`、`scripts/fubo_guling/fubo_save_state.gd`。
- 测试：全局 HUD、四场景路径、主流程存档、标题、伏波 UI/存档/小游戏/往返测试，并新增 `tests/test_fubo_visual.gd`。
- 文档：本变更记录、设计规格、伏波切片、场景流、技术架构与 QA 清单。

## 2026-08-11 上传前回归核对

- 全量测试发现 `test_fubo_global_ui.gd` 失败：伏波场景回退为旧 `TitlePanel/FishingPanel/DrumPanel` 方框，并缺少 `SpeakerPlate` 与 `NoticeBackdrop`。
- 根因：Godot 编辑器曾以旧缓存场景覆盖磁盘文件；脚本、设计规格、测试和此前验收记录一致，测试契约未过期。
- 修复范围仅限恢复本变更原定的伏波 HUD 节点结构与水墨资源，不改变剧情、小游戏、碰撞或存档规则。
- 已恢复旧方框删除状态、对话姓名水墨底板与提示水墨底板；`test_fubo_global_ui.gd` 退出码 0。
- Godot 4.7 运行伏波目标场景，截图确认共享 HUD 与码头出生画面正常，游戏日志无错误。
- 上传前重新运行 `tests/test_*.gd` 共 25 项，`TOTAL=25`、`FAILED=0`。
- GitHub 上传清单排除本机 `.superpowers/` 临时会话与 `addons/godot_ai/` 编辑器桥接；`project.godot` 不携带对应 MCP Autoload/编辑器插件配置，游戏功能 Autoload `ExplorationUI` 保留。
