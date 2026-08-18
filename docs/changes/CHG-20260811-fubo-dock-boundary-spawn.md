# CHG-20260811-fubo-dock-boundary-spawn: 伏波古岭码头边界与出生点

- Status: done
- Type: gameplay/content fix
- Owner: Project owner
- Created: 2026-08-11

## Goal and player-visible outcome

玩家首次进入伏波古岭时出现在项目负责人截图红叉所示的码头石台中央。码头临水三边阻止玩家下水，通往陆地的台阶保持可通行。

## Scope

- 局部修正伏波古岭闭合活动边界的码头段。
- 调整新场景出生点和码头安全返回点。
- 更新专项自动检查与碰撞验收记录。

## Non-goals

- 不修改岛内其余活动边界或剧情流程。
- 不修改美术、相机、小游戏规则或正式存档坐标恢复规则。
- 不移动现有触发区，除非运行验证证明不可达。

## Acceptance checks

- [x] 新场景玩家出生在红叉中心。
- [x] 码头通往陆地的台阶保持开放。
- [x] 码头临水三边均不可越过。
- [x] 钓鱼与返航触发区仍可到达且互不重叠。
- [x] 邻近非目标边界没有回归。
- [x] 伏波专项测试和目标场景运行验证通过，无新增阻断错误。

## Documentation impact

- Canonical design: `docs/design/fubo-guling-slice.md`
- QA: `docs/qa/playtest.md`
- Design specification: `docs/superpowers/specs/2026-08-11-fubo-dock-boundary-spawn-design.md`
- ADR: none;沿用现有闭合 `CollisionPolygon2D` 架构。

## Likely files

- `scenes/fubo_guling/fubo_guling.tscn`
- `scripts/fubo_guling/fubo_guling.gd`
- `tests/test_fubo_guling.gd`
- `docs/design/fubo-guling-slice.md`
- `docs/qa/playtest.md`

## Verification evidence

- Automated: `Godot_v4.7-stable_mono_win64.exe --headless --path C:\Users\wangk\Desktop\厂车v3 --script res://tests/test_fubo_guling.gd`，退出码 0，输出 `Fubo Guling skeleton verification passed.`。退出阶段仍有该测试既存的 RID/ObjectDB 释放警告，不影响退出码。
- In-engine: 通过 Godot AI 运行当前场景，确认玩家出生坐标为 `Vector2(220, 868)`；使用 `CharacterBody2D.move_and_collide()` 探测码头下、左、右三侧均发生碰撞，台阶开口探测无碰撞；新一轮场景启动 `current_run_errors=[]`。

## Implementation notes

- Godot 编辑器原先缓存了早于磁盘文件的伏波场景版本。首次结构化保存覆盖了磁盘中的新版返航触发器与局部 HUD 节点；实施已暂停，先按脚本与专项测试契约恢复这些既有节点，再继续验证本次码头改动。

## Final reconciliation

- Files changed: `scenes/fubo_guling/fubo_guling.tscn`、`scripts/fubo_guling/fubo_guling.gd`、`tests/test_fubo_guling.gd`、`docs/design/fubo-guling-slice.md`、`docs/qa/playtest.md`、本变更记录及实施计划。
- Remaining risks: 本次只覆盖码头边界与新场景出生点；正式存档仍按既有规则恢复已保存坐标。专项测试退出阶段的资源释放警告为既存测试清理问题，未在本次范围内处理。
