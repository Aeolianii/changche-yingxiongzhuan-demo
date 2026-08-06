# CHG-20260806 系统菜单按钮高度

- Status: done
- Date: 2026-08-06

## Goal

提升系统菜单六个条目的纵向舒展度，并移除鼠标悬浮高亮。

## Scope

- 纵向拉高“继续游戏、保存进度、读取进度、游戏设置、返回标题、退出游戏”的生成按钮底板。
- 同步扩大按钮点击区域，保证点击区域与新视觉边界一致。
- 保持按钮文字字号为 21，不改变名称、字体颜色和功能。
- 移除六个菜单条目的悬浮背景高亮与悬浮字体变色。

## Non-goals

- 不修改中央菜单框、标题牌、关闭按钮或背景模糊。
- 不修改右上探索 HUD 功能按钮的悬浮反馈。
- 不重新生成图片素材。

## Acceptance checks

- 六个菜单按钮框比当前版本明显更高，纵向不再显得狭窄。
- 六个按钮仍完整位于菜单框内，无相互重叠或裁切。
- 按钮文字字号保持 21。
- 鼠标悬浮时按钮背景与字体视觉不发生变化。
- 点击提示和退出游戏行为保持有效。

## Documentation impact

- 更新 `docs/design/art-direction.md` 的系统菜单按钮交互规范。

## Likely files

- `scripts/exploration_hud.gd`
- `tests/test_exploration_hud.gd`
- `docs/design/art-direction.md`

## Verification evidence

- `tests/test_exploration_hud.gd` 在 Godot 4.7.1 OpenGL 兼容渲染模式下通过。
- 运行态断言确认生成按钮纹理高度从 82 增至 94、点击区域高度从 52 增至 60，菜单文字字号保持 21。
- 悬浮 `StyleBox` 为 `StyleBoxEmpty`，`font_hover_color` 与普通 `font_color` 完全一致；按下反馈仍保留。
- 1344×896 实际渲染确认六个加高按钮无重叠或裁切，标题、关闭钮和背景模糊未变化。
