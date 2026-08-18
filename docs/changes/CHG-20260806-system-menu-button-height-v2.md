# CHG-20260806 系统菜单按钮二次加高

- Status: done
- Date: 2026-08-06

## Goal

在上一版基础上继续增加系统菜单六个按钮素材的纵向高度。

## Scope

- 将生成按钮纹理显示高度从 94 提高到 110。
- 同步将点击区域高度从 60 提高到 68。
- 调整条目槽位和间距，使六个按钮仍完整位于菜单框内。
- 字号继续固定为 21，悬浮态继续无高亮。

## Non-goals

- 不修改按钮宽度、文案、图标或功能。
- 不修改菜单框、标题和关闭按钮。

## Acceptance checks

- 按钮视觉高度比上一版进一步增加。
- 六项无重叠、无裁切，点击区域与素材对齐。
- 字号仍为 21，悬浮时不高亮。

## Documentation impact

- 延续 `docs/design/art-direction.md` 已确定的舒展按钮规范，无新增设计方向。

## Likely files

- `scripts/exploration_hud.gd`
- `tests/test_exploration_hud.gd`

## Verification evidence

- `tests/test_exploration_hud.gd` 在 Godot 4.7.1 OpenGL 兼容渲染模式下通过。
- 生成按钮纹理显示高度由 94 增至 110，点击区域由 60 增至 68；槽位高度调整为 76、间距调整为 7。
- 1344×896 实际渲染确认六个按钮进一步加高且无重叠、无裁切。
- 字号仍为 21，悬浮背景仍为 `StyleBoxEmpty`，悬浮字体颜色仍与普通状态一致。
