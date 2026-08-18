# 海图海盗船巡游与追逐

- Status: done
- Date: 2026-08-13

## Goal

在海上大地图加入会随机出生、间歇巡游、发现主角后持续追逐并在接触时触发战斗占位提示的海盗船，让海域探索具备可观察、可规避的动态威胁。

## Scope

- 每次实例化海图时随机生成 3 艘海盗船，出生点必须位于可航水面，且与南海军港保持至少 700 像素距离。
- 海盗船以出生点为中心在 240 像素巡游半径内交替移动和停驻；巡游移动 1.5–3.5 秒，停驻 0.8–1.8 秒。
- 主角进入 360 像素警戒范围后，海盗船取消休息并以 210 像素/秒持续追逐；主角离开 520 像素脱离范围后恢复巡游，形成距离迟滞，避免边界抖动。
- 海盗船速度低于主角的 260 像素/秒；追逐和巡游均参与海岸、岛屿和礁石物理碰撞。
- 主角与海盗船接触后锁定海图操作并显示“海战界面即将开放”占位对话；关闭提示后移除本次接触的海盗船，避免未接入战斗场景时反复触发。
- 海盗船使用新生成的四方向像素精灵图，航行时复用主角船只尾流图集。

## Non-goals

- 不接入正式海战场景、胜负、掉落或舰队数据。
- 不把海盗船位置与行为阶段写入正式存档或跨场景返航上下文。
- 不实现海上路径规划；海盗船依赖物理碰撞并在巡游受阻时重新选向，追逐时持续朝主角方向施压。

## Acceptance checks

- 海盗船能在出生半径内交替巡游和停驻。
- 进入警戒范围立即持续追逐，离开脱离范围后停止追逐。
- 追逐速度严格低于主角速度。
- 随机出生点远离南海军港且不位于静态碰撞内部。
- 接触玩家时出现战斗占位提示，玩家操作和其他海盗船暂停。
- 四向精灵和移动尾流在运行时随方向正确切换。
- 新增针对性 Godot 测试通过，`git diff --check` 通过。

## Documentation impact

- 更新 `docs/design/sea-overworld-design.md` 与 `docs/tech/architecture.md`，记录动态威胁规则、场景职责和当前战斗占位边界。

## Likely files

- `assets/sprites/sea_overworld/pirate_ship_4dir_states_v1.png`
- `scripts/sea_overworld_pirate.gd`
- `scenes/sea_overworld/sea_overworld_pirate.tscn`
- `scripts/sea_overworld.gd`
- `tests/test_sea_overworld_pirate_chase.gd`
- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/assets/sea-overworld-generated-assets.md`

## Verification evidence

- `test_sea_overworld_pirate_chase.gd`：通过，覆盖随机出生安全距离、巡游/停驻循环、追逐迟滞、速度关系、接触战斗占位和恢复流程。
- `test_sea_overworld_spawn.gd`：通过，确认现有大地图出生流程未回归。
- `test_scene_two_sea_link.gd`：通过，确认场景二与大地图往返入口未回归。
- 海盗船最终图集完成透明底检查和运行时四向切换检查；导入设置关闭 mipmap，使用 nearest 纹理过滤。
- `git diff --check`：通过。
