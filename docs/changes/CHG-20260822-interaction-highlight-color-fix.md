# CHG-20260822：交互高亮人物颜色修复

- Status: done
- Type: UI bugfix
- Date: 2026-08-22

## 目标

修复人物进入交互范围并显示高亮时整体偏红、变暗的问题，使人物保持原始颜色，只在像素轮廓外显示暖金色描边。

## 范围

- 修正共享 `interaction_outline.gdshader` 对 Godot `CanvasItem.COLOR` 的使用方式。
- 皇宫、南疆水师、伏波古岭等所有复用该 Shader 的人物和交互物件同步生效。
- 增加高亮 Shader 契约断言和窗口预览截图。

## 非目标

- 不修改人物 PNG、动画帧、尺寸或交互距离。
- 不调整描边颜色、描边宽度、交互按钮或玩法逻辑。
- 不改变角色原始材质的保存与恢复流程。

## 验收检查

- [x] 高亮人物身体颜色与未高亮时一致，不再偏红或变暗。
- [x] 暖金色只出现在人物透明边缘，人物本体不缩放。
- [x] 离开交互范围后仍能恢复原材质。
- [x] Godot headless 与 OpenGL Compatibility 专项验证通过。

## 技术说明

Godot 4 的 `canvas_item` Shader 在 `fragment()` 中提供的 `COLOR` 已包含默认纹理采样结果。旧实现再次执行 `texture(TEXTURE, UV) * COLOR`，导致人物 RGB 被二次相乘。新实现直接使用 `COLOR` 作为人物本色，并通过 vertex varying 单独保留 CanvasItem 调制色供透明描边使用。

## 验证证据

- Godot headless `tests/test_exploration_hud.gd`：通过；断言 Shader 直接复用已纹理化的 `COLOR`，且不再二次乘人物纹理。
- Godot OpenGL Compatibility `1344×896` 窗口测试：通过，退出码 `0`；预览保存为 `.godot/interaction_highlight_preview.png`。
- 实际渲染确认高亮内侍的蓝白服装、肤色保持原样，暖金色仅贴合人物外轮廓。
- `tests/test_scene_two_dialogue_patrol.gd`、`tests/test_fubo_guling.gd`：通过，共享高亮调用与原材质恢复流程无回归。

## 最终核对

- Files changed: `shaders/interaction_outline.gdshader`、`tests/test_exploration_hud.gd`、本变更记录。
- Limitations/follow-ups: 无。
