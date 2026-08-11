# CHG-20260811-fubo-dock-boundary-spawn: 伏波古岭码头边界与出生点

- Status: planned
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

- [ ] 新场景玩家出生在红叉中心。
- [ ] 码头通往陆地的台阶保持开放。
- [ ] 码头临水三边均不可越过。
- [ ] 钓鱼与返航触发区仍可到达且互不重叠。
- [ ] 邻近非目标边界没有回归。
- [ ] 伏波专项测试和目标场景运行验证通过，无新增阻断错误。

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

- Automated: pending
- In-engine: pending

## Final reconciliation

- Files changed: pending
- Remaining risks: pending

