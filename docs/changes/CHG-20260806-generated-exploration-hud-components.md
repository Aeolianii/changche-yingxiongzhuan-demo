# CHG-20260806 生成式探索 HUD 组件

- Status: done
- Date: 2026-08-06

## Goal

参考用户提供的东方武侠游戏 HUD 图，为自由移动阶段的探索主界面生成并接入更完整的装饰组件，替换现有以简单色块和几何卡片为主的底板。

## Scope

- 生成并接入左上主角状态框、左侧任务栏边框、右上功能按钮底框三类透明 PNG。
- 生成图以水墨笔触、宣纸留白和黛青墨色为主体，只用少量暗金收边，不烘焙人物、中文、功能图标或游戏背景。
- 保留主角头像、主线/支线占位内容、按钮名称和图标为 Godot 控件绘制层。
- 保留任务栏紧凑尺寸，任务内容区域与具体任务卡继续透明透出世界画面。
- 保留功能按钮从左到右“人物、物品栏、船只、菜单”的顺序及现有点击行为。

## Non-goals

- 不修改系统菜单面板及其六个条目。
- 不增加生命、气力、等级等未确定状态。
- 不改变探索 HUD 在对话、过场、演示和场景切换期间的隐藏规则。
- 不实现人物、物品栏或船只功能。

## Acceptance checks

- 三类新生成组件均为项目内可加载的水墨风透明 PNG，四角不残留色键背景。
- 左上状态框可清楚包围主角头像和名称，且不新增状态条。
- 左侧任务栏不超过现有 286×270 紧凑占位，中部与两张任务卡保持透明。
- 右上四个入口统一使用新菱形底框，中文名称常显，菜单仍位于最右。
- 1344×896 运行画面中无文字裁切、控件重叠或底部交互区域遮挡。

## Documentation impact

- 更新 `docs/design/art-direction.md` 的探索 HUD 生成组件规范。
- 完成后记录 `docs/qa/playtest.md` 的运行验证。

## Likely files

- `assets/ui/exploration_hud/player_status_frame.png`
- `assets/ui/exploration_hud/quest_tracker_frame.png`
- `assets/ui/exploration_hud/function_button.png`
- `scripts/exploration_hud.gd`
- `tests/test_exploration_hud.gd`
- `tests/verify_merged_project.ps1`
- `docs/design/art-direction.md`
- `docs/qa/playtest.md`

## Verification evidence

- Godot .NET 4.7.1 headless editor导入三张新 PNG，无 GDScript 解析错误。
- `tests/test_exploration_hud.gd` 在 headless 与 OpenGL compatibility 模式均通过；断言三类生成图可加载、外角透明、任务框中部透明。
- 1344×896 实际渲染确认水墨组件清晰、任务区域透出世界画面、菜单仍在最右，文字无裁切或重叠。
- `tests/verify_merged_project.ps1`、`tests/test_system_menu_exit.gd` 与 `tests/test_scene_transition.gd` 均通过。
