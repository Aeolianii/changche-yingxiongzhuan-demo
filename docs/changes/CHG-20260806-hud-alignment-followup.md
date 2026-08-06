# CHG-20260806 HUD 对齐跟进

- Status: done
- Date: 2026-08-06

## Goal

根据实际截图修正系统菜单按钮重叠、任务栏灰底层级、任务标题位置，以及角色头像和两级文字在放大状态框内的对齐。

## Scope

- 增大系统菜单六个按钮的纵向排列步距，避免相邻菱形徽章重合。
- 将不透明灰底从两张具体任务卡移到任务栏框内部的统一底层，任务卡恢复透明。
- 将“任务”标题上移并垂直居中于顶部水墨题签。
- 将主角头像右移并微调垂直位置，使其嵌入左侧菱形框中心。
- 将角色头衔改为“水师元帅”，与“伏波将军 · 南疆水师”子标题共同移入右侧宣纸框。

## Non-goals

- 不修改水墨 PNG 素材、任务内容或菜单功能。
- 不改变任务栏外框尺寸、系统菜单按钮高度和字体字号。
- 不修改用户已有的 `scenes/Scene2.tscn` 变更。

## Acceptance checks

- 系统菜单相邻按钮菱形无重合，六项仍完整位于面板内。
- 任务栏中部使用 Alpha 为 1 的统一灰色背景，两张任务卡自身 Alpha 为 0。
- “任务”标题位于顶部题签中心。
- 主角头像位于菱形框中心；“水师元帅”和子标题均落在右侧宣纸区域内。
- 1344×896 探索 HUD 和系统菜单实际渲染无裁切或新重叠。

## Documentation impact

- 更新 `docs/design/art-direction.md` 的任务栏和角色栏布局规范。
- 完成后更新 `docs/qa/playtest.md`。

## Likely files

- `scripts/exploration_hud.gd`
- `tests/test_exploration_hud.gd`
- `docs/design/art-direction.md`
- `docs/qa/playtest.md`

## Verification evidence

- `tests/test_exploration_hud.gd` 在 1344×896 OpenGL compatibility 与 headless 模式均通过；统一任务底板、透明任务项、标题对齐、角色文字与按钮间距断言通过。
- 探索 HUD 实际渲染确认头像位于菱形中央，“水师元帅”和子标题完整落在宣纸框内，任务标题位于顶部题签中央。
- 系统菜单实际渲染确认六个菱形无重合，最下方按钮未越出面板边框。
- `tests/test_system_menu_exit.gd` 与 `tests/verify_merged_project.ps1` 均通过。
