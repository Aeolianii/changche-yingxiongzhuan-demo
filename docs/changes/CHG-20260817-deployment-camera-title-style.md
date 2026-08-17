# CHG-20260817：布阵选船镜头与标题字样式

- 状态：`done`
- 日期：2026-08-17

## 目标

让布阵阶段选中己方舰船后，镜头像战斗阶段一样平滑居中到该舰；同时提高卷轴上三个分组小标题的对比度。

## 范围

- 布阵选船成功后复用 `NavalGridView.FocusCameraOnShip()`。
- 将“舰船调度”“舰队整备”“决战军令”改为白色填充、较粗黑色描边。
- 增加定向测试，验证布阵选船后镜头中心与舰船中心一致，并验证标题主题覆盖。

## 非目标

- 不修改相机缩放、边界、WASD 平移或战斗阶段镜头行为。
- 不修改按钮、卷轴、布阵规则、舰船位置、选中高亮或面板布局。
- 不改动任务开始前已有的用户工作树修改与用户提供的参考图片。

## 验收检查

- 点选任意己方舰后，相机目标为该舰几何中心；大地图边缘仍受现有背景边界约束。
- 实机沿用现有 `0.28s` 三次缓出镜头动画，无头测试立即定位。
- 三个标题为白色填充、纯黑描边，描边宽度大于原来的 `5px`。
- Godot 4.7.1 .NET 海战场景 smoke test 通过。
- 1344×896 实机截图确认卷轴、标题和按钮可读性。

## 文档影响

- 更新 `docs/design/naval-tactics-gameplay.md` 的布阵界面约束。
- 更新 `docs/qa/playtest.md` 的验收记录。

## 预计文件

- `scripts/naval/presentation/NavalDeploymentController.cs`
- `tests/test_naval_scene_smoke.gd`
- `docs/design/naval-tactics-gameplay.md`
- `docs/qa/playtest.md`
- 本变更记录

## 验证证据

- `NavalDeploymentController.SelectShipForDeploy()` 已复用 `NavalGridView.FocusCameraOnShip()`；实机沿用 `0.28s` Cubic Out 动画，无头环境立即定位。
- 三个分组标题保持 `24px` 字号，主题覆盖为 `Colors.White`、`Colors.Black` 与 `8px` 描边；按钮相关样式未改动。
- `dotnet build --no-restore`：通过，0 警告、0 错误。
- `Godot 4.7.1 .NET --headless --script res://tests/test_naval_scene_smoke.gd`：通过，包含镜头目标和三处标题主题断言。
- 1344×896 OpenGL Compatibility 实机抓图：通过，白字粗黑边在卷轴底纹上清晰，选中舰镜头聚焦生效。
- `git diff --check`：通过。
