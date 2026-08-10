# CHG-20260810 海上大地图碰撞场景化

- 状态：进行中
- 类型：技术 / 场景资源
- 日期：2026-08-10

## 目标

将海上大地图脚本运行时生成的全部静态碰撞准确转换为 `sea_overworld.tscn` 中 `World/WorldCollision` 的可编辑场景节点，使碰撞可在 Godot 2D 编辑器中直接选择和调整，同时彻底停止运行时重复生成。

## 范围

- 原样迁移 14 个 `CollisionPolygon2D`，保留节点名称和每一个多边形顶点。
- 原样迁移 18 个 `CollisionShape2D`，保留节点名称、中心坐标和圆形半径。
- 从 `scripts/sea_overworld.gd` 删除 `_build_world_collisions()` 调用、实现和只为动态静态碰撞服务的辅助函数。
- 为 32 个节点建立名称、节点类型、位置、半径和顶点的精确自动化契约。
- 保留现有陆地探针、四区航路、中央绕行、入口清水和运行时碰撞验证。

## 几何基准

- 多边形 14 个：`NorthwestCoast`、`EastBaySandbar`、`QingyuPagodaIsland`、`CangmenFortress`、`CangmenDock`、`WulanVillageIsland`、`FuboRidge`、`ShanwanMountain`、`ChenghaiLighthouse`、`LongmenStronghold`、`BaishaSandbar`、`RedBayMountain`、`NanaoWestWall`、`NanaoCitadel`。
- 圆形 18 个：`SouthHarborWestRock`、`SouthHarborNorthwestWall`、`SouthHarborNorthWall`、`SouthHarborNortheastWall`、`SouthHarborEastWall`、`SouthHarborEastRock`、`MoonHarborNorthwest`、`MoonHarborNorth`、`MoonHarborCrown`、`MoonHarborEast`、`MoonHarborSoutheast`、`MoonHarborSouth`、`XuanchaoWestReef`、`XuanchaoMainReef`、`XuanchaoSouthReef`、`CentralNorthReef`、`CentralEastReef`、`ShanwanOuterReef`。

## 非目标

- 不改变任何碰撞坐标、半径、顶点、名称或碰撞层。
- 不转换地点和事件的运行时 `Area2D`；本次只处理 `WorldCollision` 下的静态陆地与礁石碰撞。
- 不调整背景、地点、入口、出生点、航线或 UI。

## 验收检查

1. `World/WorldCollision` 在未运行游戏时已有且仅有 32 个可编辑子节点。
2. 14 个多边形和 18 个圆形与迁移前代码基准逐项完全一致。
3. `sea_overworld.gd` 不再调用或声明 `_build_world_collisions()`，运行后子节点数仍为 32，不发生重复。
4. 四区航路、中央四向绕行、陆地阻挡、入口清水与玩家出生探针全部通过。
5. `tests/test_sea_overworld.gd` 与场景二往返验证通过。
6. Godot 编辑器打开 `sea_overworld.tscn` 后，可在 `World/WorldCollision` 下直接选择和编辑全部碰撞节点。

## 文档影响

- 更新 `docs/tech/architecture.md` 的海图碰撞所有权与编辑方式。
- 更新 `docs/assets/sea-overworld-stage1-layout.md` 的最终碰撞存储方式。
- 实现后更新 `docs/qa/playtest.md` 的场景化验证记录。

## 预计文件

- `scenes/sea_overworld/sea_overworld.tscn`
- `scripts/sea_overworld.gd`
- `tests/test_sea_overworld.gd`
- 上述文档文件

## 验证证据

- 待实现后补充。
