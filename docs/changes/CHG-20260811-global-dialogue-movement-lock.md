# CHG-20260811-global-dialogue-movement-lock：全局对话移动锁

- Status: done
- Type: gameplay input rule
- Owner: Project owner
- Created: 2026-08-11

## Goal and player-visible outcome

任何对话或旁白界面显示期间，玩家角色必须停在原地，不能使用方向键或点击移动；对话关闭且场景允许自由探索后才恢复控制。

## Scope

- 核对皇宫、南疆水师与伏波古岭三个现有陆地探索场景的对话移动锁。
- 对话开始时取消尚未完成的点击移动目标并将角色速度归零。
- 对话结束后仅在自由探索状态恢复控制。
- 增加覆盖三个场景的回归测试。

## Non-goals

- 不改变对话文本、推进方式、交互距离、移动速度或碰撞。
- 不新增暂停菜单或输入系统框架。
- 海上大地图当前没有角色对话界面，不新增无实际用途的对话流程。

## Acceptance checks

- [x] 皇宫旁白和角色对白显示期间，方向键与点击移动都不能改变玩家位置。
- [x] 南疆水师任意线性或选项对话显示期间，玩家保持静止。
- [x] 伏波古岭守岭人对话显示期间，玩家保持静止。
- [x] 对话开始时清除既有点击目标；对话关闭后按场景自由探索条件恢复控制。
- [x] 专项测试与全套回归通过，无新增解析或运行时错误。

## Documentation impact

- Core loop: `docs/design/core-loop.md`
- Technical architecture: `docs/tech/architecture.md`
- QA: `docs/qa/playtest.md`

## Likely files

- `scripts/palace_demo.gd`
- `tests/test_dialogue_movement_lock.gd`
- `docs/design/core-loop.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`

## Verification evidence

- TDD red: 实现前运行 `res://tests/test_dialogue_movement_lock.gd`，明确失败于皇宫“对话未禁用玩家控制”和“玩家仍发生位移”两项断言；南疆水师与伏波古岭断言未失败。
- TDD green: 增加皇宫玩家控制同步后，同一专项测试输出 `Global dialogue player-movement lock verification passed.`，退出码为 0。
- Full regression: 依次运行 `tests/test_*.gd` 共 26 项，结果 `TOTAL=26 FAILED=0`。
- Godot target scene: 编辑器打开并启动 `res://scenes/palace/palace_demo.tscn`，本次启动 `current_run_errors=[]`；运行时辅助桥未连接，因此不把窗口自动操作计入验收。

## Final reconciliation

- Files changed: `scripts/palace_demo.gd`、`tests/test_dialogue_movement_lock.gd`、`docs/design/core-loop.md`、`docs/tech/architecture.md`、`docs/qa/playtest.md`、本变更记录。
- 实际行为：仅锁定玩家控制与玩家点击目标；太监等 NPC 的剧情移动继续由原有 `_move_actor()` 等逻辑执行。
- Remaining risks: 新增对话场景仍需接入同一“对话可见即锁玩家”的架构约束，并加入本专项测试。
