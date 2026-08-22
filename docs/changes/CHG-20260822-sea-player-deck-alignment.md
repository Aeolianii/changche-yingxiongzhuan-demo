# CHG-20260822：海图主角甲板中线校正

- Status: done
- Type: UI bugfix
- Date: 2026-08-22

## 目标

修复海上大地图中船只向前或向后移动时，主角 Q 版形象偏离船体中线的问题。

## 范围

- 分别校正向下和向上朝向的人物横向甲板锚点。
- 保持左右朝向、人物与船体尺度、纵向站位、尾流及移动逻辑不变。
- 增加前后方向运行时断言和实际渲染截图。

## 验收检查

- [x] 向下移动时人物位于船体可见中线。
- [x] 向上移动时人物位于船体可见中线。
- [x] 停止与航行状态切换时人物不跳位。
- [x] 海上大地图专项测试和窗口渲染检查通过。

## 实现依据

人物四格图集内容均接近各自图格中心；船体纵向帧的实际透明内容中线相对图格中心分别约为向下 `+3px`、向上 `-9px`（按运行时 `0.28` 船体缩放换算）。因此只补偿纵向两朝向的人物 `x`，不改素材本身。

## 验证证据

- Godot headless `tests/test_sea_player_deck_alignment.gd`：通过；覆盖向下 `Vector2(3, -16)`、向上 `Vector2(-9, -17)`，并验证停止/航行状态使用同一人物锚点。
- Godot OpenGL Compatibility 窗口测试：通过；放大 QA 预览保存为 `.godot/sea_player_down_deck_alignment.png` 与 `.godot/sea_player_up_deck_alignment.png`，实际确认人物与船体纵向中线一致。
- Godot headless `tests/test_click_to_move.gd`：通过；键盘/点击移动、停止与碰撞受阻处理无回归。
- 完整 `tests/test_sea_overworld.gd` 仍受当前工作区既有的海图碰撞节点与其旧批准基线不一致影响；本次未修改场景碰撞，故使用独立组合专项测试隔离验证。

## 最终核对

- Files changed: `scripts/sea_overworld_player.gd`、`tests/test_sea_overworld.gd`、`docs/design/sea-overworld-design.md`、`docs/assets/character-assets.md`、本变更记录。
- Limitations/follow-ups: 无。
