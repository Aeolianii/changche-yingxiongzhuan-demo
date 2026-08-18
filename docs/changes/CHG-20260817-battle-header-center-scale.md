# CHG-20260817：战斗顶部文字居中与加大

- 状态：`done`
- 日期：2026-08-17

## 目标

将战斗界面顶部回合信息与操作提示统一按视口水平中心对齐，并在上一轮可读性调整基础上再增大一级字号与描边。

## 范围

- 主行调整为 `26px` 字号、`6px` 描边。
- 第二行调整为 `20px` 字号、`5px` 描边。
- 两个透明标签区域保持水平中心为 1344×896 基准视口中心；对称扩展第二行宽度以防长提示裁切。
- 增加字号、描边、居中和可用宽度断言，并做实机截图检查。

## 非目标

- 不增加背景底板，不修改文字及描边颜色。
- 不修改第二行文案逻辑、战斗规则或其他 HUD。
- 不改动任务开始前已有的用户工作树修改与参考图片。

## 验收检查

- 两行文字水平中心与视口中心一致。
- 主行和第二行字号、描边均比上一版增大一级。
- 最长开战提示完整显示，不裁切、不与主行重叠。
- Godot 4.7.1 .NET 海战场景 smoke test 通过。

## 文档影响

- 更新 `docs/design/naval-tactics-gameplay.md` 的战斗 HUD 可读性约束。
- 更新 `docs/qa/playtest.md` 的验收记录。

## 预计文件

- `scripts/naval/presentation/NavalHud.cs`
- `scenes/naval/NavalDemo.tscn`
- `tests/test_naval_scene_smoke.gd`
- `docs/design/naval-tactics-gameplay.md`
- `docs/qa/playtest.md`
- 本变更记录

## 验证证据

- 主行运行时样式由 `24px / 5px` 描边调整为 `26px / 6px` 描边；第二行由 `18px / 4px` 调整为 `20px / 5px`。
- 主行透明标签横向范围改为 `x=407..937`，第二行改为 `x=252..1092`，两者中心均为基准视口中心 `x=672`。
- 两行垂直可用区域同步扩展；第二行宽 `840px`，最长开战提示完整显示且与主行无重叠。
- `dotnet build --no-restore`：通过，0 警告、0 错误。
- `Godot 4.7.1 .NET --headless --script res://tests/test_naval_scene_smoke.gd`：通过，包含字号、描边、宽度与中心坐标断言。
- 1344×896 OpenGL Compatibility 实机抓图：通过，两行均水平居中且首尾完整。
- `git diff --check`：通过。
