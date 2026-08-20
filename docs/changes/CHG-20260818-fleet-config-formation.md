# CHG-20260818：舰队配置页签（勾选出战 + 小地图阵型编辑器 + 预设）+ 布阵阶段用预设阵型

- 状态：`done`（未提交——整合版项目根目录非 git 仓库，仅 `.gitignore`）
- 日期：2026-08-18

## 目标

在整合版 ship_screen 新增第三个「舰队配置」页签（与船体/装备并列），提供：

1. **勾选出战舰**：每艘拥有的船一个勾选框，勾选 = 出战（修复"无法勾选"——此前只有全舰/预设整档，无逐船勾选）。
2. **小地图阵型编辑器**：页签内一个小地图（玩家布阵区 22×32 缩小网格），把勾选出的舰放到格位上规划初始阵型（初始朝向统一朝东，可旋转）。
3. **预设管理**：保存 / 载入 / 删除 / 设默认。预设存「出战哪些舰 + 各舰阵型位置/朝向」；「载入」= 设 ActivePreset（下次出战用，既有语义保留）；**默认预设 = 全舰一字排开**。
4. **布阵阶段用预设阵型**：海战布阵读取活动预设时，若预设带阵型则玩家舰按阵型位置摆位（而非 `FindSpot` 自动扫描朝东）；无阵型/回落时仍用 `FindSpot` 自动摆位。玩家在布阵界面仍可手动移动（`OnGridClicked`），不被预设覆盖。

## 范围

- schema 扩展（向后兼容）：`FleetPreset` 增 `Formation:[{ Slot, X, Y, Facing }]`（Slot = Ships 数组下标，即出战序列槽位；X/Y 为海战布阵坐标；Facing ∈ east/west/north/south）。旧文件无 Formation → null → 布阵回落 `FindSpot`。
- `ship_screen.gd`：舰队配置页签（勾选列表 + 小地图阵型编辑器 + 预设管理 UI），移除旧的左下角舰队预设栏（功能迁入页签）。
- `NavalDeploymentController`：自由模式玩家舰队装配应用活动预设阵型；恢复默认阵型（`AutoDeployDefault`）对玩家侧重新应用预设阵型，否则回落自动摆位。
- 测试：新增 `test_fleet_formation.gd`（勾选出战→布阵只有勾选舰；阵型保存/加载→布阵按阵型摆位；默认预设一字排开；布阵手动调整不被预设覆盖）。

## 非目标

- 不改海战战斗规则、天气、技能播种与装备数值。
- 不改随机遭遇 / 关卡 / 海盗战舰队来源（遭遇与关卡仍用遭遇/关卡规格，预设阵型只作用于自由模式）。
- 不改 economy 层装备/升级/造船规则。
- 不引入新依赖包。
- 小地图编辑器仅"格子 + 舰块"的简单实现，不做拖拽/撤销等精细交互（UI 后续统一优化）。

## 设计决策

- **坐标约定**：小地图 = 玩家布阵区 `Rect2I(1, 2, 22, 32)`（与 C# `NavalDeploymentController.PlayerZone` 同源）缩小网格；编辑器记录并持久化**海战布阵坐标**（X/Y），C# 布阵侧在 `PlayerZone` 内校验并按阵型摆位，非法格（越界/地形/重叠）回落 `FindSpot`。这样小地图 ↔ 布阵坐标 1:1，无需换算。
- **阵型槽位**：`Formation.Slot` = `Ships` 数组下标 = 布阵出战序列（p1..）。`SelectBattleLineup` 产出与 Ships 顺序一致，故槽位与海战 `p{i+1}` 一一对应；`RestorePlayerEconomyLineup` 按 p 序号取槽位重放。
- **勾选语义**：`_checked[ship_id]`（economy 唯一 id，如 ship_001）→ 出战；未勾选舰不入预设 Ships、不画在小地图、不参战。默认全勾选。
- **默认一字排开**：「设默认」= 将当前勾选舰按 economy 顺序排成单行（朝东，同行，船头递进不重叠）并保存为预留预设「默认阵型」+ 设为下次出战；无任何预设时布阵回落 `FindSpot`（同样呈横向一排，兼容既有冒烟）。
- **载入 = 设 ActivePreset 保留**：`_load_fleet_preset` 同时把预设的 Ships/Formation 载入编辑器（勾选/摆位反映该预设），满足"载入后下次出战用该预设"。
- **布阵手动调整不被预设覆盖**：预设阵型仅在 `BuildPlayerFleetFromEconomy` / `AutoDeployDefault` 时应用；布阵界面 `PlaceShip`/`OnGridClicked` 移动立即生效，`ConfirmDeployment` 不重放预设。

## 验收检查

- `dotnet build ChangcheHeroes.csproj -c Debug`：0 警告、0 错误。
- ship_screen 舰队配置页签：勾选/取消逐船出战；小地图点选摆位/旋转；保存预设含 Ships+Formation；载入设活动并回填编辑器；删除；设默认 = 一字排开。
- 布阵：活动预设带阵型 → 玩家舰按阵型位置/朝向；无阵型/回落 → `FindSpot` 自动摆位；手动移动不被预设覆盖；布阵→战斗仍通。
- 回归：`test_economy_fleet_mapping` / `test_fleet_preset_roundtrip` / `test_naval_scene_smoke` / `test_ship_screen` / 海盗战 / 关卡教学固定舰队 全绿。
- 新增 `test_fleet_formation.gd` 全绿（勾选出战、阵型摆位、默认一字排开、手动调整不覆盖）。

## 预计文件

- `docs/changes/CHG-20260818-fleet-config-formation.md`（本记录）
- `docs/本地修改记录.md`
- `.superpowers/sdd/i7-report.md`
- `scripts/naval/levels/FleetPreset.cs`（Formation 持久化）
- `scripts/naval/presentation/NavalDeploymentController.cs`（布阵按阵型摆位）
- `scripts/ui/ship_screen.gd`（舰队配置页签 + 小地图 + 预设扩展）
- `tests/test_fleet_formation.gd`（新增）

## 验证证据

- `dotnet build ChangcheHeroes.csproj -c Debug`：0 警告、0 错误（已完成，2026-08-18）。
- 新增 `tests/test_fleet_formation.gd` 全绿（`PASS: fleet formation (勾选出战 / 阵型摆位 / 默认一字排开 / 手动不被覆盖)`），覆盖：
  - 勾选出战：取消 2 艘 → 布阵只出战 3 舰，p1/p2/p3 = 护卫舰/商船/护卫舰。
  - 阵型摆位：5 舰按 (5,6)东 / (10,8)北 / (15,12)西 / (5,20)东 / (10,24)东 保存→载入→布阵逐格验证 BowX/BowY/FacingIndex。
  - 默认一字排开：活动预设「默认阵型」，5 舰同行朝东，(2,5)/(5,5)/(9,5)/(11,5)/(14,5)。
  - 手动调整：PlaceShip p2→(18,20)南 → ConfirmDeployment 后仍保留，布阵→战斗 Round=1 正常开始。
- 回归 headless：naval scene smoke / economy fleet mapping / fleet preset roundtrip / ship_screen / naval tutorial hint / naval pirate request / sea overworld pirate battle / exploration hud 全绿。
- 既有无关失败（本次未触碰，与 I-3/4/5 报告一致）：`test_sea_overworld`、`test_sea_overworld_entry_alignment`、`test_fubo_sea_round_trip`（海面地图序列化 / 伏波岛导航问题）。
- 附带发现：`test_sea_overworld_pirate_return` 失败（`Defeat return must respawn the player near Moon-ring harbor (got (3570.0, 440.0))`）——由同会话 I-6 复活可航行修复（`_respawn_player_near_moon_harbor` 改用 `_find_navigable_position`，CHG-20260818）与既有 40px 容差冲突所致，非本变更回归；I-6 由任务 #135 单独跟踪。
