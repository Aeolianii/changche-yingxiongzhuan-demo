# 伏波古岭码头边界与出生点调整设计

- Status: approved for implementation
- Date: 2026-08-11
- Owner: Project owner

## Goal

让玩家首次进入伏波古岭时出生在码头石台中央，并让码头临水三边的碰撞沿可见石台外沿布置，同时保持通往陆地主路的台阶口开放。

## Scope

- 局部调整 `World/Collision/BlockedRegions/WalkableBoundary/Boundary` 的码头段顶点。
- 将新场景玩家出生点调整到项目负责人截图红叉对应的地图坐标，目标约为 `Vector2(220, 868)`。
- 同步码头安全返回点，使钓鱼小游戏结束后回到同一安全区域。
- 更新伏波场景自动检查与碰撞验收说明。

## Non-goals

- 不重画全岛其余活动边界。
- 不改变码头、道路、角色或 UI 美术。
- 不移动钓鱼与返航触发区，除非验证证明调整后的边界使其不可达。
- 不覆盖正式存档中已经记录的玩家坐标。

## Design

继续使用现有单条闭合、分段模式的 `CollisionPolygon2D`。只替换围绕码头的连续顶点，使左侧、外端和右侧临水边界贴近石台外沿；与陆地连接的两侧边界分别终止在台阶两边，台阶中间保持开放。其余岛内顶点、剧情阻挡和触发区保持不变。

新场景的 `Player.position` 与脚本中的 `DOCK_SAFE_POSITION` 使用同一个红叉安全点。新游戏或小游戏返回会落在码头中央；正式存档恢复流程继续优先使用存档坐标。

## Acceptance checks

- 新实例中的玩家位置为经运行画面确认的红叉中心坐标。
- 玩家可以从出生点走上台阶并进入陆地主路。
- 玩家不能从码头左侧、外端或右侧临水边缘进入海面。
- 钓鱼触发区与返航触发区仍可从出生点步行到达且互不重叠。
- 邻近码头的海岸、植被与主路边界保持原有阻挡行为。
- 伏波场景脚本可解析，专项自动检查通过，运行日志无新增阻断错误。

## Likely files

- `scenes/fubo_guling/fubo_guling.tscn`
- `scripts/fubo_guling/fubo_guling.gd`
- `tests/test_fubo_guling.gd`
- `docs/design/fubo-guling-slice.md`
- `docs/qa/playtest.md`
- `docs/changes/CHG-20260811-fubo-dock-boundary-spawn.md`

