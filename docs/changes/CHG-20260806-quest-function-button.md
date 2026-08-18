# CHG-20260806 任务功能按钮

- Status: done
- Date: 2026-08-06

## Goal

在探索界面右上功能区最左侧新增“任务”按钮，并使用与现有入口一致的水墨图标和菱形底框。

## Scope

- 生成一枚无文字的水墨任务图标。
- 将右上功能区扩展为“任务、人物、物品栏、船只、菜单”五个按钮。
- 调整功能区水平占位，使五个按钮均完整显示且菜单仍在最右侧。
- 点击“任务”按钮显示“任务 · 功能即将开放”。

## Non-goals

- 不实现正式任务界面或修改现有任务栏。
- 不修改人物、物品栏、船只和菜单按钮的既有行为。
- 不修改用户已有的 `scenes/Scene2.tscn` 变更。

## Acceptance checks

- “任务”按钮位于原四个按钮左侧，五个按钮无重叠或屏幕越界。
- 新图标为项目内可加载的透明水墨 PNG，不包含文字或菱形底框。
- 五个按钮名称常显，菜单保持最右；点击任务按钮显示功能即将开放提示。
- 对话和过场期间新按钮随探索 HUD 一同隐藏。

## Documentation impact

- 更新 `docs/design/art-direction.md` 的探索功能区顺序。
- 完成后更新 `docs/qa/playtest.md`。

## Likely files

- `assets/ui/icons/hud_quest.png`
- `scripts/exploration_hud.gd`
- `tests/test_exploration_hud.gd`
- `tests/verify_merged_project.ps1`
- `docs/design/art-direction.md`
- `docs/qa/playtest.md`

## Verification evidence

- 使用内置 ImageGen 生成水墨任务文书图标，经纯绿色键去除和 128×128 透明画布标准化后接入项目。
- `tests/test_exploration_hud.gd` 在 1344×896 OpenGL compatibility 与 headless 模式均通过；图标 Alpha、五按钮顺序、功能条宽度及任务占位提示断言通过。
- 实际渲染确认“任务”位于原四个按钮左侧，五个入口无重叠或越界，菜单仍位于最右。
- `tests/verify_merged_project.ps1` 通过。
