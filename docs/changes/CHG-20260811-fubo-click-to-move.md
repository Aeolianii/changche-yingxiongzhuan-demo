# CHG-20260811-fubo-click-to-move：伏波古岭点击移动

- Status: done
- Type: gameplay input enhancement
- Owner: Project owner
- Created: 2026-08-11

## Goal and player-visible outcome

玩家在伏波古岭自由探索时，左键点击可行走地面，角色会自动走向点击位置。

## Scope

- 伏波场景明确接收左键世界坐标，并复用玩家现有点击移动逻辑。
- 增加伏波点击移动专项自动检查。
- 记录伏波点击移动的设计与 QA 验收要求。

## Non-goals

- 不增加绕路寻路或导航网格。
- 不改变方向键移动速度、碰撞边界、剧情、触发区和相机。
- 不允许在菜单、对话、小游戏、过场或完成提示期间点击移动。

## Acceptance checks

- [x] 自由探索时左键点击地面，角色走到目标点附近并停止。
- [x] 方向键输入立即取消点击目标并接管移动。
- [x] 碰撞仍阻止角色穿过边界，持续受阻后取消目标。
- [x] 菜单、对话、小游戏和过场期间不接受点击目标。
- [x] 伏波专项测试与全套回归通过，测试运行无新增错误。

## Documentation impact

- Canonical design: `docs/design/fubo-guling-slice.md`
- QA: `docs/qa/playtest.md`

## Files changed

- `scripts/fubo_guling/fubo_guling.gd`
- `tests/test_click_to_move.gd`
- `docs/design/fubo-guling-slice.md`
- `docs/qa/playtest.md`
- `docs/changes/CHG-20260811-fubo-click-to-move.md`

## Verification evidence

- TDD red: 修改实现前运行 `Godot_v4.7-stable_mono_win64_console.exe --headless --path . --script res://tests/test_click_to_move.gd`，伏波目标接收、坐标映射与抵达三项断言失败。
- TDD green: 完成输入转发后运行同一命令，输出 `Click-to-move runtime verification passed.`，退出码为 0。
- Full regression: 依次运行 `tests/test_*.gd` 共 25 项，结果 `TOTAL=25 FAILED=0`。
- 场景级输入验证覆盖：真实左键事件进入伏波根场景、画布坐标转换、角色目标设置、物理帧移动、抵达停止，以及打开系统菜单后清除目标。
- Windows 游戏窗口自动点击未计入验收证据：窗口控制接口错误报告 Godot 窗口归属不一致，未执行不可靠的盲点操作。

## Final reconciliation

- 实际实现与设计文档一致：伏波自由探索接收左键点击；受共享控制状态约束；键盘可接管；碰撞和受阻超时沿用玩家脚本。
- Remaining risk: 点击移动采用直线推进，不会自动绕过树木、建筑或其他障碍；这属于本次明确非目标。
