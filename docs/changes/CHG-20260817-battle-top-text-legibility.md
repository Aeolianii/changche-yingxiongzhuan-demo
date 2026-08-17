# CHG-20260817：战斗顶部文字可读性试调

- 状态：`done`
- 日期：2026-08-17

## 目标

在不添加背景底板、不改变颜色与布局的前提下，通过增大战斗界面顶部回合文字和操作提示字号、加粗现有描边，提高复杂海面背景上的可读性。

## 范围

- 增大战斗 HUD `StatusLabel` 与 `MessageLabel` 的运行时字号。
- 增加两行文字现有浅色描边宽度。
- 对称扩展第二行透明标签的可用宽度以容纳放大文字，保持中心位置不变。
- 增加定向主题断言，并以实机截图检查显示与裁切。

## 非目标

- 不新增半透明底板、阴影层或渐变。
- 不修改文字颜色、文案、位置、对齐和交互。
- 不修改左上状态卡、回合横幅及其他战斗 UI。
- 不改动任务开始前已有的用户工作树修改与参考图片。

## 验收检查

- 顶部回合文字与第二行操作提示均比当前版本更大。
- 两行文字描边均比当前版本更粗。
- 长操作提示在 1344×896 窗口中不裁切、不重叠。
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

- 顶部回合文字由 `20px / 3px` 描边调整为 `24px / 5px` 描边。
- 第二行操作提示由 `15px / 2px` 描边调整为 `18px / 4px` 描边；保持原有文字与描边颜色。
- 第二行透明标签宽度由 `640px` 对称扩展为 `744px`，中心位置保持不变；当前最长开战提示实测文字宽 `675px`，首尾无裁切。
- `dotnet build --no-restore`：通过，0 警告、0 错误。
- `Godot 4.7.1 .NET --headless --script res://tests/test_naval_scene_smoke.gd`：通过，包含两行字号、描边与提示区域宽度断言。
- 1344×896 OpenGL Compatibility 实机抓图：通过，两行文字完整显示，无重叠。
- `git diff --check`：通过。
