# CHG-20260806 生成式水墨功能图标

- Status: done
- Date: 2026-08-06

## Goal

将探索界面四个按钮和系统菜单六个按钮中的单字徽章替换为参考示例视觉语言的水墨功能图标，提高辨识度并减少对文字缩写的依赖。

## Scope

- 生成探索界面“人物、物品栏、船只、菜单”四枚水墨图标。
- 生成系统菜单“继续游戏、保存进度、读取进度、游戏设置、返回标题、退出游戏”六枚水墨图标。
- 图标只包含功能图形，不包含文字、字母、数字、按钮底框或游戏背景。
- 在 Godot 中用 `TextureRect` 替换现有 `Symbol` / `EntrySymbol` 文字标签，保留所有按钮名称和点击行为。

## Non-goals

- 不修改水墨按钮底框、菜单条目文字、排列顺序或功能逻辑。
- 不添加新按钮或实现尚未开放的功能。
- 不修改用户已有的 `scenes/Scene2.tscn` 变更。

## Acceptance checks

- 十枚图标均为项目内可加载的透明 PNG，四角透明且无绿色键残留。
- 探索界面四枚图标和系统菜单六枚图标均位于各自菱形底框中央。
- 不再显示“将、囊、舟、≡、续、存、读、设、题、退”等徽章字。
- 按钮中文名称、顺序、菜单打开、占位提示和退出功能保持不变。

## Documentation impact

- 更新 `docs/design/art-direction.md` 的功能图标规范。
- 完成后更新 `docs/qa/playtest.md`。

## Likely files

- `assets/ui/icons/*.png`
- `scripts/exploration_hud.gd`
- `tests/test_exploration_hud.gd`
- `tests/verify_merged_project.ps1`
- `docs/design/art-direction.md`
- `docs/qa/playtest.md`

## Verification evidence

- 使用内置 ImageGen 按两组统一图标表生成十枚水墨图标，经纯绿色键去除、固定网格切分和 128×128 透明画布标准化后接入项目。
- `tests/test_exploration_hud.gd` 在 1344×896 OpenGL compatibility 与 headless 模式均通过；十张 PNG 的透明角、可见像素、按钮映射和旧文字节点移除断言通过。
- 实际渲染确认探索区人物、行囊、帆船、菜单图标及系统菜单六类功能图标均位于菱形中心，中文按钮名称和点击区域不变。
- `tests/test_system_menu_exit.gd` 与 `tests/verify_merged_project.ps1` 均通过。
