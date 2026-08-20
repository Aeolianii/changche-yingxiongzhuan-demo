# CHG-20260819-deploy-range-ship-tooltip: 舰队配置布阵界面优化（缩小布阵区 + 舰船贴图 + 右键悬停提示）

- Status: done
- Type: feature
- Owner: F-3
- Created: 2026-08-19

## Goal and player/project outcome

舰队配置页的小地图阵型编辑器从「22×32 大区」缩小为「正常战斗可配置范围」（12 宽 × 10 高），
与海战自由模式 `PlayerZone` 一致（预设阵型保证能落入战斗布阵区）；小地图舰块从「统一方块」改为
「按经济舰型对应的具体舰船贴图」；在小地图舰块上右键点击显示悬停提示（海战舰型名 + 编号，如「护卫舰 1 号」）。

## Scope

- `scripts/ui/ship_screen.gd`：`FORMATION_ZONE_*` 缩小为 `(1, 12, 12, 10)`（与 C# PlayerZone 同源）；
  `FormationGrid` 改用经济舰型贴图绘制舰块、放大格宽；右键命中舰块显示悬停提示（无命中仍退选）；
  默认阵型改为能容纳于 12 宽区的紧凑横排（逐舰自动换行，5 舰落单行）。
- `scripts/naval/presentation/NavalDeploymentController.cs`：自由模式 `PlayerZone = (1,12,12,10)`、
  `EnemyZone = (14,12,12,10)`（玩家区在左、敌区右移并贴近）；敌方默认阵型移到贴近新玩家区的纵深位置；
  新增 `PlayerZoneForTest()` 测试钩子。
- 测试更新：`test_fleet_formation.gd`（阵型坐标适配新区 + 新区校验 + 贴图校验 + 右键提示校验）、
  `test_naval_scene_smoke.gd`（p4 砲击坐标与点击目标适配新区）。
- `apply_default_formation` 改为按各舰实际长度逐舰排布（紧凑多行，5 舰落 2 行全在区内）。

## Non-goals

- 不改随机遭遇/关卡模式的 `MapScheme` 玩家区/敌区（那些已是正常战斗尺寸，不属本次「自由模式可配置区」）。
- 不改 `FixturesFactory.cs` 的固定战斗夹具坐标（独立测试数据，未引用 PlayerZone）。
- 不改逃跑格规则/位置（`EnsureSafeExits` 逻辑不变，仅玩家区竖直居中到 y[12,22) 使逃跑测试仍可行）。
- 不改海战 AI/规则层。

## Acceptance checks

- [x] 小地图 FORMATION_ZONE 与海战 PlayerZone 同为 12×10，位置一致（GDScript 测试断言两区相等）。
- [x] 缩小后经济舰队 5 舰默认阵型/自动摆位全部落在区内。
- [x] 小地图舰块按经济舰型绘制对应贴图（不再统一方块）。
- [x] 右键舰块显示「舰名 + 编号」悬停提示（海战舰型名 + 舰队序号）。
- [x] `dotnet build` 0 警告 0 错误。
- [x] headless：fleet formation / naval smoke / economy mapping / preset roundtrip 相关测试全绿。

## Documentation impact

- 更新 `scripts/ui/ship_screen.gd` 顶部常量注释（原引用 x[1,23) y[2,34)）。
- 更新 `NavalDeploymentController.cs` 顶部与 `BuildDefaultLineups` 注释。
- 更新 `docs/本地修改记录.md`（F-3 小节）。

## Implementation notes

- 区域选择：新玩家区 `(1,12,12,10)` 竖直居中到地图中部（y∈[12,22)），使逃跑格（x=0 列 y16-18）仍在玩家区
  竖直范围附近，冒烟逃跑测试（p1@(3,17)→出口 (0,17)）无需改动规则。
- 敌区镜像 `(14,12,12,10)`（中间留 1 列交战纵深）；敌方默认阵型：e1(16,12)W e2(17,17)W e3(16,21)W e4(19,19)W，
  全部落在敌区内、且贴近玩家区右缘（砲击冒烟：p4@(12,17)→e2@(17,17) 平方距离 25 = 射程上限）。
- `FormationGrid` 格宽 12→20（小图 12×10，放大让舰船贴图可读）；按钮/说明位随小地图下缘上移。

## Verification evidence

- Automated: `dotnet build` 0 警告 0 错误；headless `test_fleet_formation.gd`（新增 F-3 阶段零：区==PlayerZone、
  5 舰全落区内、贴图路径、右键提示「护卫舰 3 号」）/ `test_naval_scene_smoke.gd`（p4@(12,17) 砲击 e2@(17,17) 平方距离 25）
  / `test_economy_fleet_mapping.gd` / `test_fleet_preset_roundtrip.gd` / `test_ship_screen.gd` /
  `test_ship_screen_accessories.gd` / `test_sea_overworld_pirate_battle.gd` / `test_naval_hunt_request.gd` /
  `test_naval_pirate_request.gd` 全绿。
- Manual/in-engine: 未运行（headless 校验为准）。

## Final reconciliation

- Files changed: scripts/ui/ship_screen.gd、scripts/naval/presentation/NavalDeploymentController.cs、
  tests/test_fleet_formation.gd、tests/test_naval_scene_smoke.gd
- Documented limitations/follow-ups: 小地图仍沿用「格索引==海战坐标」的 1:1 约定，网格右缘 x=12 因海战区含右不
  （x<13）可由 C# FindSpot 兜底，不产生出区摆放；默认阵型改为紧凑多行（单行放不下 5 舰）。
