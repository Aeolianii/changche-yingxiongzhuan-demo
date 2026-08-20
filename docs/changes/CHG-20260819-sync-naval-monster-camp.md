# CHG-20260819：海战模块整体同步 + 海怪战/营寨战海面接入口

- 状态：`done`
- 日期：2026-08-19
- 提交状态：未提交（整合版非 git 仓库，改动留文件夹）

## 目标

把本地海战版（`海战demo03-ui优化版`，只读参考，绝不动）新增/升级的海战模块整体同步进整合版
（`changche-yingxiongzhuan-demo`），并接入两个海面入口：海怪事件 → 海怪战（讨伐章 hunt_stage01/02）、
倭寇营寨 → 大本营战（hunt_stage03），全部走 `RandomEncounterSession.Begin → NavalDemo → 返回海面`
（沿用海盗战集成模式）。

同步遵循「整合版集成 + 本地版新功能」合并原则：保留整合版独有文件与集成
（`ExitCellRules`、`EconomyFleetSource`、`PirateBattleSession`、`FleetPreset` 阵型、`RandomMapGenerator` 出口平衡、
经济舰队映射/预设/布阵页签）。

## 范围（S-1 同步 + S-2 接入口）

### S-1 同步

- 本地 9 个新文件 → 整合版：`core/AiRouter.cs`、`core/SeaMonsterAi.cs`、`core/SeaMonsterRules.cs`、
  `core/FishSchoolAi.cs`、`core/FishSchoolRules.cs`、`core/ShipGeometry.cs`、
  `levels/EncounterBalancer.cs`、`levels/FleetTreasure.cs`、`levels/HuntEncounterGenerator.cs`。
- 纯规则层整体覆盖（core/config/integration 以本地版为准，保留整合版集成调用）：
  `config/NavalConfigLoader.cs`、`core/*`（除 `ExitCellRules`）、`integration/BattleRequest.cs`、
  `integration/BattleResult.cs`、`integration/NavalBattleGateway.cs`（保留 `ExitCellRules.EnsureSafeExits`）。
- levels 层按「保留整合版集成」合并：`EnemyFleetConfig.cs`（讨伐配置+宝物）、`MapScheme.cs`（海盗据点图）、
  `LevelRegistry.cs`（HuntMode）、`LevelDefinition.cs`（Hunt 章节）、`RandomEnemyFleetGenerator.cs`（友好系数）、
  `RandomEncounterGenerator.cs`（ShipGeometry 占格）。保留整合版 `FleetPreset.cs` / `RandomMapGenerator.cs`。
- presentation 层逐个合并：`NavalDeploymentController`（EncounterBalancer 配平）、`NavalBattleController`
  （宝物 RangeBonus / 宝藏拾取 / AiRouter / debug 胜负）、`NavalGridView`/`NavalHud`/`NavalLevelPlayController`
  /`NavalShipView`/`FixturesFactory`/`NavalBackController`/`LevelSelectController` 按需并入新功能。
- 数据：`data/naval/ships.json`（海怪/飞鱼/城寨/炮台 + HP 重平衡）、`weapons.json`（Lv4 撞角/砲击）。
- 资源：新增舰船贴图（enemy_sea_monster / enemy_sea_fish / enemy_citadel / enemy_turret）。

### S-2 接入口

沿用海盗战 meta 互操作模式（`PirateBattleSession` / `sea_pirate_battle_request` / `sea_pirate_battle_return_context`），
新增讨伐会话互操作：`HuntBattleSession`（`sea_hunt_battle_request` / `sea_hunt_battle_return_context`）。

- `scripts/naval/levels/HuntBattleSession.cs`（新）：讨伐战会话登记（`StageId` / `ReturnContextCarrier`），meta 键与海盗战同构。
- `scripts/naval/presentation/NavalDeploymentController.cs`：`_Ready` 消费讨伐请求 meta →
  `HuntEncounterGenerator.CreateStage(_config!, stageId)` 组装 hunt_stage 固定遭遇 + `RandomEncounterSession.Begin`。
- `scripts/naval/presentation/NavalBattleController.cs`：讨伐战结算显示「返回海上大地图」（与海盗战合并判定）；
  `BuildHuntReturnContext` 补写结算结果（保留玩家位置/农历日 + `stage_id` + `outcome`）；`ReturnToSea` 按会话分支写返回 meta。
- `scripts/naval/presentation/NavalBackController.cs`：讨伐战激活时隐藏「返回关卡选择」按钮；返回关卡选择时一并清理讨伐请求/会话。
- `scripts/sea_overworld.gd`：
  - 海怪事件 → `_start_sea_monster_battle()`：变体 0 → `hunt_stage1`（触手），变体 1/2 → `hunt_stage2`（飞鱼群）；
  - 倭寇营寨 → `_start_wokou_camp_battle()`：`hunt_stage3`（城寨/炮台/护卫）；
  - `_start_hunt_battle` 写请求 meta + 切 NavalDemo；`_consume_hunt_battle_return` / `_restore_hunt_battle_return`
    结算返回（胜利回位领奖：海怪标记事件已解决、营寨标记主线完成并补播胜利过场；败退回月环商港复活）。
  - 原「默认获胜 + 木材/铁石 500」占位结算移除，迎战选项文案改为「迎战海怪！」「进军，一决胜负！」。
- `tests/test_naval_hunt_request.gd`（新）：讨伐请求 → NavalDemo 消费 → 组装 hunt_stage 遭遇 → 返回上下文补结算结果。
- `tests/test_sea_overworld_sea_monster_event.gd` / `tests/test_wokou_main_quest_flow.gd`：迎战/进军改为验证请求 meta +
  胜利返回结算（营寨补播胜利过场）。

## 非目标

- 不动本地海战版（`海战demo03-ui优化版`）。
- 不改变海盗战/经济舰队既有集成行为。
- 不引入新依赖包。
- 不删除整合版独有集成文件。

## 设计决策

- 同步基准：本地海战版是功能超集，整合版是集成超集；纯规则层以本地版覆盖（改动小、无集成冲突），
  presentation 层按「整合版集成 + 本地版新功能」逐文件手工合并，防止覆盖整合版布阵/海盗战/经济舰队逻辑。
- 数据/贴图同步后，整合版经济舰队映射（patrol_boat→frigate 等）与既有测试需回归验证。

## 验收检查

- `dotnet build ChangcheHeroes.csproj`：0 警告、0 错误。
- headless 全量测试（既有海盗战/经济舰队/预设/海面 + 海怪/营寨新入口）全绿。
- 海面海怪事件进入海怪战、营寨进入大本营战，胜利返回海面并给宝物。

## 文档影响

- 本记录。
- `.superpowers/sdd/s1-report.md`（最终报告）。

## 预计文件

- `docs/changes/CHG-20260819-sync-naval-monster-camp.md`（本记录）
- 见「范围」所列 C# / GDScript / 数据 / 资源文件。

## 验证证据

- `dotnet build ChangcheHeroes.csproj -c Debug`：0 警告、0 错误（`已成功生成`）。
- 新增贴图执行 `godot --headless --import` 生成 `.ctex` 缓存（首次缺缓存会导致加载报错）。
- headless 测试（`Godot_v4.7.1-stable_mono_win64_console --headless --script res://tests/<t>.gd`）：
  - 新测试 `test_naval_hunt_request`：PASS（讨伐请求 → hunt_stage3 遭遇 → 返回上下文）。
  - `test_sea_overworld_sea_monster_event`：PASS（迎战写 hunt_stage1/2 请求 + 事件解决）。
  - `test_wokou_main_quest_flow`：PASS（进军写 hunt_stage3 请求 + 胜利返回播过场）。
  - 既有回归 `test_naval_scene_smoke` / `test_naval_pirate_request` / `test_economy_fleet_mapping`
    / `test_sea_overworld_*` / `test_sea_fog_*`：PASS。
  - 已知既有失败（与本改动无关，沿用此前状态）：`test_sea_overworld.gd`（场景碰撞串行化 32 节点断言）、
    `test_sea_overworld_entry_alignment.gd`（伏波古岭入口对齐）、`test_sea_overworld_pirate_return.gd`
    （月环商港复活容差，对应待办 I-6 #135）。

## 待办

- I-6（#135）：`test_sea_overworld_pirate_return.gd` 月环商港复活容差修复（既有问题，与本改动无关）。
