# CHG-20260806 纯文字任务项

- Status: done
- Date: 2026-08-06

## Goal

精简任务栏信息，删除主线和支线任务旁的“帅”“商”圆形徽章，只保留任务分类、任务名称和简短描述。

## Scope

- 删除两项任务的 `CharacterPlaceholder` 节点及徽章文字。
- 将分类、任务名称和描述整体左移，使用徽章释放出的横向空间。
- 保留水墨任务框、分类色条、主支线颜色和轻分隔线。

## Non-goals

- 不修改任务文案、任务数据或任务栏尺寸。
- 不修改角色状态栏、功能按钮和系统菜单。
- 不修改用户已有的 `scenes/Scene2.tscn` 变更。

## Acceptance checks

- 任务栏中不存在“帅”“商”徽章及 `CharacterPlaceholder` 节点。
- 每项只展示主线/支线、任务名称和简短描述。
- 三层文字左对齐、无裁切，并保持主支线颜色区分。

## Documentation impact

- 更新 `docs/design/art-direction.md` 的任务项信息规范。
- 完成后更新 `docs/qa/playtest.md`。

## Likely files

- `scripts/exploration_hud.gd`
- `tests/test_exploration_hud.gd`
- `docs/design/art-direction.md`
- `docs/qa/playtest.md`

## Verification evidence

- `tests/test_exploration_hud.gd` 在 1344×896 OpenGL compatibility 与 headless 模式均通过；两项任务不存在 `CharacterPlaceholder`，三层文字位置断言通过。
- 实际渲染确认“帅”“商”徽章完全移除，主线/支线、任务名称和简短描述清晰且无裁切。
- `tests/verify_merged_project.ps1` 通过。
