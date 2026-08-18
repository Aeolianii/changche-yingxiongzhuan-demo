# 海盗船追击边界与返航

- Status: done
- Date: 2026-08-13

## Goal

放大大地图海盗船，并限制海盗离开出生海域的最远追击距离；追击结束后必须主动回到出生点，再恢复原有巡逻循环。

## Scope

- 海盗船体显示尺寸在当前基础上增大 20%，从 `0.14` 调整为 `0.168`；碰撞范围保持不变。
- 保留玩家距离脱离条件：海盗与玩家距离超过 520 像素时停止追击。
- 新增出生点追击活动半径 720 像素：海盗离出生点超过该范围时，即使玩家仍在附近也停止追击。
- 新增独立返航状态。返航时持续驶向出生点、不停驻且不重新响应玩家警戒；抵达出生点后重新开始巡逻。

## Acceptance checks

- 海盗船体视觉缩放严格为原来的 120%。
- 玩家超过脱离距离时，海盗进入返航状态。
- 海盗超过出生点追击活动半径时，海盗进入返航状态。
- 返航途中玩家靠近不会重新触发追击。
- 海盗抵达出生点后恢复巡逻。
- 针对性 Godot 测试与 `git diff --check` 通过。

## Likely files

- `scripts/sea_overworld_pirate.gd`
- `scenes/sea_overworld/sea_overworld_pirate.tscn`
- `tests/test_sea_overworld_pirate_chase.gd`
- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`

## Verification evidence

- `test_sea_overworld_pirate_chase.gd`：连续 3 次通过，覆盖 120% 船体缩放、玩家距离脱离、出生点活动半径脱离、返航期间忽略玩家和到点恢复巡逻。
- `test_sea_overworld_spawn.gd`：通过，确认大地图出生流程未回归。
- `git diff --check`：通过。
