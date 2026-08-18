# CHG-20260806 水墨系统菜单

- Status: done
- Date: 2026-08-06

## Goal

将系统菜单现有偏厚重金属与织物质感的生成组件替换为和探索 HUD 一致的水墨风组件，同时完整保留现有菜单布局与交互要求。

## Scope

- 重新生成系统菜单主框、菜单按钮底框和关闭按钮三类透明 PNG。
- 视觉以墨色干湿笔触、宣纸留白、黛青墨韵和少量暗金细线为主。
- 保留背景实时模糊、六个菜单条目、加高按钮框、固定 21 号字体和无悬浮高亮。
- 保留只有“退出游戏”执行退出，其余五项提示“该功能即将实现”。

## Non-goals

- 不添加“新手教程”。
- 不修改探索 HUD、菜单条目顺序、文字内容或暂停逻辑。
- 不在生成图中烘焙中文、按钮符号、人物或游戏背景。

## Acceptance checks

- 三类水墨素材可由 Godot 加载，四角透明且无绿色键残留。
- 主框四角、顶部标题题签和右上关闭按钮均完整可见。
- 六个按钮的纵向高度不回退，文字字号仍为 21，鼠标悬浮不高亮。
- 菜单背景保持模糊；退出游戏测试和未开放功能提示测试继续通过。
- 1344×896 运行画面无文字裁切、按钮重叠或面板越界。

## Documentation impact

- 更新 `docs/design/art-direction.md` 的系统菜单材质规范。
- 完成后更新 `docs/qa/playtest.md`。

## Likely files

- `assets/ui/system_menu/system_menu_frame.png`
- `assets/ui/system_menu/menu_button.png`
- `assets/ui/system_menu/close_button.png`
- `scripts/exploration_hud.gd`
- `tests/test_exploration_hud.gd`
- `docs/design/art-direction.md`
- `docs/qa/playtest.md`

## Verification evidence

- Godot .NET 4.7.1 headless editor重新导入三张水墨 PNG，无资源或脚本错误。
- `tests/test_exploration_hud.gd` 在 headless 与 1344×896 OpenGL compatibility 模式均通过；三类素材的透明角、按钮高度、字号、标题位置和无悬浮高亮断言通过。
- 实际渲染确认背景模糊、顶部题签、六个加高按钮和右上关闭键无裁切或重叠。
- `tests/test_system_menu_exit.gd` 与 `tests/verify_merged_project.ps1` 均通过。
