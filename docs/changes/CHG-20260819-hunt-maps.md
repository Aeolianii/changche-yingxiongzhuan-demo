# CHG-20260819-hunt-maps: 调整海怪/倭寇营寨讨伐战地图

- Status: done
- Type: content
- Owner: F-2
- Created: 2026-08-19

## Goal and player/project outcome

讨伐章三场战斗各有专属地图，贴合敌/玩家体验：

1. **海怪01**（`hunt_stage1`）：稀疏分散群岛——几个小岛散布、水道开阔、暗礁/浅滩点缀，敌出生在有战术纵深的位置。
2. **海怪02**（`hunt_stage2`）：泻湖——环形陆地围出内湖，陆河/港口/小镇点缀，湖口狭窄，敌出生在湖内。
3. **大本营**（`hunt_stage3`）：城寨单位竖着放在地图最右边，炮台按营地设计沿岸防位布置，敌方守军出生在城寨附近。

## Scope

- 在 `MapSchemeRegistry` 新增 3 张地图方案：`hunt_archipelago`（海怪01）、`hunt_lagoon`（海怪02）、`hunt_stronghold`（大本营）。
- 在 `EncounterDefinitionRegistry` 把 `hunt_stage1/2/3` 从共用 `pirate_stronghold` 改为各自专属图。
- 不改数据层代码逻辑（`PlaceInEnemyZone` / `MapScheme.Validate` / `RandomEncounterGenerator` 全复用），纯数据交付 + 独立校验补强（深水通道等既有校验未覆盖项）。
- 保留 `pirate_stronghold`（不再被 hunt 引用，留作数据历史，不破坏潜在外部引用）。

## Non-goals

- 不动本地海战版（`海战demo03-ui优化版`，只读参考）。
- 不引入新依赖包。
- 不改玩家舰队 / 敌人配置 / 奖励 / 规则层任何逻辑。
- 不动 `LevelRegistry.HuntMode`（讨伐章总览图仍为占位）。

## Design decisions

### 城寨竖放最右的实现（纯数据几何约束）

`EnemyFleetConfig.PlaceInEnemyZone` 逐舰按 West→North→East→South 朝向尝试、整船（`ShipGeometry.Footprint`）必须完整落在 `EnemyZone` 内。
城寨 `wokou_citadel` 为 2×4 矩形（Length=4, Width=2）：若敌区宽度为 2 列，横放（East/West，占 4 列）必然越界，只能竖放（North/South）。
因此把 `hunt_stronghold` 的敌区设计为贴右缘的 2 列窄条 → 城寨必竖放最右，炮台 ×4 与护卫 ×2 沿同区排布（行优先自动放置）。

### 海怪01 深水通道（既有校验未覆盖，补独立验证）

`MapScheme.Validate` 的连通性 BFS 只判"非陆地"，浅滩/礁石可通行；但海怪01 `Passability.DeepWaterOnly` 只能走深水。
群岛图设计上保证敌区 → 玩家区存在一条**全程深水**通道（底部 2 行深水作主航道，浅滩/礁石只做边缘点缀不堵航道），
并补一个独立脚本验证（node，读 ASCII + ships.json 模拟 `PlaceInEnemyZone` 放置 + 深水 BFS）。

### 敌区几何汇总（全部贴右缘、恒深水、玩家区在左）

| 图 | PlayerZone | EnemyZone | 舰队放置 |
|---|---|---|---|
| hunt_archipelago | (1,2,5,14) | (21,2,2,14) | 海怪01 2×2 朝西 (21,3) |
| hunt_lagoon | (1,2,5,14) | (21,3,2,11) | 海怪02 1×2 ×3 |
| hunt_stronghold | (1,2,5,14) | (21,2,2,13) | 城寨 2×4 竖放 (21,2) + 炮台×4 + 护卫×2 |

## Acceptance checks

- [x] `dotnet build ChangcheHeroes.csproj`：0 警告 0 错误（已成功生成）
- [x] 独立校验脚本：三图定宽/合法符号/区恒深水/不重叠/非陆地连通/海怪01 深水通道/敌舰队占格合法（node 校验 + 完整链路）
- [x] headless 测试：`test_naval_hunt_request` / `test_sea_overworld_sea_monster_event` / `test_wokou_main_quest_flow` 全绿
- [x] 相关回归：`test_naval_scene_smoke` / `test_naval_pirate_request` 全绿

## Documentation impact

- 本记录。
- `.superpowers/sdd/f2-report.md`（最终报告）。

## Implementation notes

- 改动文件：`scripts/naval/levels/MapScheme.cs`（新增 3 张图 `hunt_archipelago`/`hunt_lagoon`/`hunt_stronghold`）、`scripts/naval/levels/EnemyFleetConfig.cs`（hunt_stage 引用改为各自专属图）。
- 约束：布阵区恒深水、玩家区在左、连通；深水限定舰（海怪01）移动路径须全程深水。
- 城寨竖放最右实现：敌区 2 列窄区（x21-22）→ 城寨（2×4）横放越界、只能竖放（North），纯数据几何约束。

## Verification evidence

- `dotnet build ChangcheHeroes.csproj`：0 警告、0 错误。
- 独立校验（node，读 ships.json 复刻 `ShipGeometry.Footprint` / `PlaceInEnemyZone` / `PlacePlayerFleet` / BFS）：
  - 三图定宽 24×18、合法符号、区恒深水、不重叠、玩家区在左、非陆地 BFS 连通；hunt_archipelago 深水通道（海怪01 DeepWaterOnly 全程深水可达）。
  - 敌舰放置：海怪01@(21,3)West；海怪02 三鱼@(21,5/6/7)West；营寨城寨@(21,2)North + 炮台×4 + 护卫×2。
  - 玩家舰队 4 舰（旗舰@(3,4) 护卫@(2,6) 运输@(1,8) 商船@(1,10)）全在玩家区深水内。
  - 整合版 ASCII 与设计逐字一致。
- headless：`test_naval_hunt_request` / `test_sea_overworld_sea_monster_event` / `test_wokou_main_quest_flow` / `test_naval_scene_smoke` / `test_naval_pirate_request` 全绿。

## Final reconciliation

- Files changed: `scripts/naval/levels/MapScheme.cs`、`scripts/naval/levels/EnemyFleetConfig.cs`、本记录、`.superpowers/sdd/f2-report.md`、`docs/本地修改记录.md`。
- Documented limitations/follow-ups:
  - `pirate_stronghold` 图保留（不再被 hunt 引用，作数据历史）。
  - 讨伐三阶段地图为手作精品；后续如需变体可按 `VariantGroup` 归族扩展。
  - 未提交：整合版项目根目录非 git 仓库，改动留在文件夹。
