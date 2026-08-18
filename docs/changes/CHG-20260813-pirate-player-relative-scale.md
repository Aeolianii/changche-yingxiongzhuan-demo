# 海盗船按玩家船体比例缩放

- Status: done
- Date: 2026-08-13

## Goal

让海盗船与玩家船只大小接近，并严格保持为玩家船体节点显示缩放的 95%。

## Scope

- 玩家船体 `ShipSprite` 当前缩放为 `0.28`。
- 海盗船体 `ShipSprite` 缩放调整为 `0.28 × 0.95 = 0.266`。
- 尾流、碰撞体、移动速度和追击逻辑保持不变。

## Acceptance checks

- 运行时海盗船体缩放等于玩家船体缩放的 95%。
- 海盗追逐与返航针对性测试通过。
- `git diff --check` 通过。

## Likely files

- `scenes/sea_overworld/sea_overworld_pirate.tscn`
- `tests/test_sea_overworld_pirate_chase.gd`
- `docs/design/sea-overworld-design.md`

## Verification evidence

- `test_sea_overworld_pirate_chase.gd`：通过，运行时确认海盗船体缩放等于玩家船体缩放的 95%，追逐与返航流程未回归。
- `git diff --check`：通过。
