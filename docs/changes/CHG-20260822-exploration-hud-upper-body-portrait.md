# CHG-20260822：探索 HUD 主角上半身头像

- Status: done
- Type: UI
- Date: 2026-08-22

## 目标

放大左上角色栏中的主角形象，只显示头部至腰部的上半身，使新全身立绘在菱形头像座内仍有清楚的面部和服装辨识度。

## 范围

- 调整共享探索 HUD 中 `ProtagonistPortrait` 的 UV 裁切区域。
- 保持角色栏外框、菱形区域、名称、称号、位置和整体尺寸不变。
- 皇宫、南疆水师、伏波古岭等陆地探索场景共享同一效果。

## 非目标

- 不修改主角原始立绘 PNG。
- 不修改对话框立绘、世界角色动画或海上大地图月相 HUD。
- 不修改任务栏、功能按钮和任何交互逻辑。

## 验收检查

- [x] 左上菱形头像显示主角头部至腰部，不再显示完整下半身。
- [x] 人物比当前全身显示明显放大，面部、冠饰和胸甲清晰。
- [x] 人物不越过菱形头像座，外框和右侧文字不移动。
- [x] 海上月相模式切换及返回陆地后头像恢复行为不回归。
- [x] Godot headless 与窗口探索 HUD 专项测试通过。

## 验证证据

- Godot headless `tests/test_exploration_hud.gd`：通过；断言 UV 裁切为 `(120, 20, 360, 360)`，裁切下缘不超过源图 `y=380`。
- Godot OpenGL Compatibility `1344×896` 窗口测试：通过，退出码 `0`；预览保存为 `.godot/exploration_hud_preview.png`。
- 实际渲染确认头像从原全身显示改为冠饰、头部、胸甲至腰部，人物明显放大且没有越过菱形金边；角色栏、任务栏和右侧文字位置不变。

## 最终核对

- Files changed: `scripts/exploration_hud.gd`、`tests/test_exploration_hud.gd`、`docs/design/art-direction.md`、`docs/qa/playtest.md`、本变更记录。
- Limitations/follow-ups: 只改变陆地探索 HUD 的显示裁切，原始 600×600 主角立绘与对话框立绘保持不变。
