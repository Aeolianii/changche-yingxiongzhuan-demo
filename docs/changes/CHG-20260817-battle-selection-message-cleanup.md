# CHG-20260817：战斗选船提示精简

- 状态：`done`
- 日期：2026-08-17

## 目标

精简战斗界面顶部第二行的选船反馈：玩家退选后不显示“已退出选择”，选中船只时不显示船只名字。

## 范围

- 玩家通过右键、点空白或 `deselect` 行为退选时清空第二行。
- 选中己方舰时仅保留剩余移动、行动状态和操作提示。
- 查看敌舰及新回合自动选舰时不在第二行拼接船名。
- 增加定向冒烟断言。

## 非目标

- 不修改移动、攻击、转向等动作完成后的战斗反馈。
- 不修改布阵阶段的选船提示。
- 不修改顶部文字字号、描边、颜色、位置或背景。
- 不改动任务开始前已有的用户工作树修改。

## 验收检查

- 选中己方船后，第二行不包含船名，仍显示剩余移动和操作提示。
- 玩家主动退选后，第二行为空，不显示“已退出选择”。
- Godot 4.7.1 .NET 海战场景 smoke test 通过。

## 文档影响

- 更新 `docs/design/naval-tactics-gameplay.md` 的战斗 HUD 提示约束。
- 更新 `docs/qa/playtest.md` 的验收记录。

## 预计文件

- `scripts/naval/presentation/NavalBattleController.cs`
- `scripts/naval/presentation/NavalHud.cs`
- `tests/test_naval_scene_smoke.gd`
- `docs/design/naval-tactics-gameplay.md`
- `docs/qa/playtest.md`
- 本变更记录

## 验证证据

- 己方选船提示改为“剩余移动 N · 操作提示”，已攻击提示只保留行动状态，不再拼接 `DisplayName`。
- 查看敌舰提示改为通用“查看敌方舰船状态”；新回合自动选舰提示不再拼接船名。
- 右键、点空白和 `deselect` 行为统一清空第二行；规则结果与动作反馈路径保持不变。
- `dotnet build --no-restore`：通过，0 警告、0 错误。
- `Godot 4.7.1 .NET --headless --script res://tests/test_naval_scene_smoke.gd`：通过，包含选船无名称与主动退选清空断言。
- 1344×896 OpenGL Compatibility 实机抓图：通过，选中与退选两种状态显示正确。
- `git diff --check`：通过。
