# CHG-20260806 HUD 可读性布局调整

- Status: done
- Date: 2026-08-06

## Goal

改善探索 HUD 左上角色信息、任务描述、右上功能符号及系统菜单徽章字的对齐和可读性。

## Scope

- 左上角色栏整体宽高放大 50%，同步放大头像区域并舒展名称与描述布局。
- 删除角色栏右下角“帅”字。
- 主线和支线任务卡改用完全不透明的深灰背景。
- 右上四个功能按钮内部符号统一向下移动。
- 系统菜单六个按钮左侧徽章字统一向左移动。

## Non-goals

- 不重新生成或替换水墨 PNG 素材。
- 不修改任务栏总体尺寸、功能按钮顺序、菜单条目或任何点击行为。
- 不修改探索 HUD 与系统菜单的显示时机。

## Acceptance checks

- 角色栏尺寸由 330×128 放大为 495×192，头像、名称和描述不拥挤，且不存在 `StatusSeal`。
- 任务卡背景 Alpha 为 1，任务描述在复杂场景上仍清晰。
- 四个探索功能符号相对原位置下移并保持一致。
- 六个系统菜单徽章字相对原位置左移并保持一致。
- 1344×896 实际渲染无角色栏与任务栏重叠、文字裁切或按钮错位。

## Documentation impact

- 更新 `docs/design/art-direction.md` 的探索 HUD 与系统菜单对齐规范。
- 完成后更新 `docs/qa/playtest.md`。

## Likely files

- `scripts/exploration_hud.gd`
- `tests/test_exploration_hud.gd`
- `docs/design/art-direction.md`
- `docs/qa/playtest.md`

## Verification evidence

- `tests/test_exploration_hud.gd` 在 1344×896 OpenGL compatibility 与 headless 模式均通过；角色栏尺寸、删除状态字、任务卡不透明度及两组符号偏移断言通过。
- 实际渲染确认角色栏与任务栏之间仍有间距，头像和描述不再拥挤，任务文字在复杂场景背景上清晰。
- 系统菜单实际渲染确认六个徽章字水平居中，按钮文字、按钮高度和模糊背景不受影响。
- `tests/test_system_menu_exit.gd` 与 `tests/verify_merged_project.ps1` 均通过。
