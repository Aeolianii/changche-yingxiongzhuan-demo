# CHG-20260806 系统框与任务栏润色

- Status: done
- Date: 2026-08-06

## Goal

解决系统菜单最下方按钮压住边框、角色头衔贴近宣纸上缘，以及任务栏灰底和任务卡视觉割裂的问题。

## Scope

- 放大系统菜单水墨主框，为六个加大间距的按钮保留完整底部留白。
- 同步校准“系统”题签和右上关闭按钮相对新外框的位置。
- 将“水师元帅”及其子标题整体下移，维持两级文字间距并确保都在宣纸区内。
- 将任务栏统一灰底向上延伸到标题题签后方，消除中间断层。
- 取消两张任务项的完整矩形边框，仅保留底部分隔线、分类色条和文字层级。

## Non-goals

- 不修改菜单功能、按钮高度、按钮顺序或任务文案。
- 不重新生成水墨素材。
- 不修改用户已有的 `scenes/Scene2.tscn` 变更。

## Acceptance checks

- 系统菜单外框在 1344×896 下完整显示，最下方菱形与底边之间有可见留白。
- “水师元帅”和子标题均处于右侧宣纸框内，标题不贴上边缘。
- 任务栏灰底从标题后方连续铺到框底；任务项无独立矩形轮廓，仅使用轻量分隔线。
- HUD、菜单关闭、退出和功能占位行为不变。

## Documentation impact

- 更新 `docs/design/art-direction.md` 的系统菜单外框和任务栏层级规范。
- 完成后更新 `docs/qa/playtest.md`。

## Likely files

- `scripts/exploration_hud.gd`
- `tests/test_exploration_hud.gd`
- `docs/design/art-direction.md`
- `docs/qa/playtest.md`

## Verification evidence

- `tests/test_exploration_hud.gd` 在 1344×896 OpenGL compatibility 与 headless 模式均通过；菜单框尺寸、底部留白、角色标题偏移、任务底板连续性和分隔线断言通过。
- 系统菜单实际渲染确认最下方按钮与放大后的底边之间有明显留白，标题题签和关闭按钮位置正常。
- 探索 HUD 实际渲染确认“水师元帅”和子标题均在宣纸区内，任务栏为连续灰底且不再呈现两张矩形卡片拼接感。
- `tests/test_system_menu_exit.gd` 与 `tests/verify_merged_project.ps1` 均通过。
