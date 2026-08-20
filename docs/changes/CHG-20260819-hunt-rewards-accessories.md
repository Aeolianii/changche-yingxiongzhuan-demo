# CHG-20260819-hunt-rewards-accessories: 讨伐战利品进背包 + 饰品装备与加成

- Status: done
- Type: feature
- Owner: F-1
- Created: 2026-08-19

## Goal and player/project outcome

讨伐章（海怪/营寨）胜利后，战利品真正进入玩家经济背包；三件讨伐专属宝物成为可装备的「饰品」，
装备后战斗中给舰队/旗舰加成：

1. **战利品进背包**：讨伐胜利后，金（入军饷）、铁/木/麻（入物品栏）即时写入玩家 `economy_state`；
   专属饰品进入背包（`economy_state.accessories`），可查看、可装备。
2. **饰品装备**：`ship_screen` 装备页新增「饰品整备」区块，已获得的饰品可装备到舰船、可卸下。
3. **饰品加成**：装备后战斗中生效——
   - 海怪之角：玩家旗舰撞角升级至 Lv4（系数 1.8）；
   - 贯日神枪：玩家旗舰砲击升级至 Lv4（420 伤害）；
   - 倭寇军旗：全舰队射程 +1 格。

## Scope

- `scripts/economy/economy_state.gd`：新增 `accessories` 字段持久化（`owned`/`equipped`）与增删装查 API。
- `scripts/economy/item_catalog.gd`：注册 `hemp`（麻布）物品（讨伐战利品）。
- `scripts/core/game_state.gd`：桥接 `add_economy_accessory` / `equip_economy_accessory` / `unequip_economy_accessory`。
- `scripts/naval/presentation/NavalBattleController.cs`：讨伐胜利结算写入经济奖励 + 饰品入背包；
  `StartBattle` 从 `economy_state.accessories` 读取装备状态并设置 `BattleState` 加成。
- `scripts/naval/core/BattleState.cs`：新增 `FlagshipRamLevel` / `FlagshipBombardmentLevel`（旗舰撞角/砲击升级等级）。
- `scripts/naval/core/RamRules.cs` / `AttackRules.cs`：玩家旗舰按升级等级取 Lv4 系数/伤害（weapons.json 已含 Lv4 数据）。
- `scripts/naval/levels/FleetTreasure.cs`：新增 `TreasureId` → 饰品 id 映射。
- `scripts/ui/ship_screen.gd`：装备页新增「饰品整备」区块。
- 新增 headless 测试 `tests/test_hunt_rewards_economy.gd`、`tests/test_ship_screen_accessories.gd`。

## Non-goals

- 不动本地海战版（`海战demo03-ui优化版`，只读参考）。
- 不引入新依赖包。
- 不改武器/技能/护甲既有装备逻辑与数据（weapons.json Lv4 数据已存在，仅规则层按旗舰升级取用）。
- 不授予海盗战经济奖励（需求仅覆盖海怪/营寨讨伐战）。

## Design decisions

### 饰品数据双通道：规则层库存 + 经济背包

- `FleetTreasureInventory`（`user://treasures.json`）保留为讨伐掉落的规则层库存（既有 Collect/Save 不动）。
- `economy_state.accessories` 为经济背包/装备 UI 的单一事实来源：`owned`（已获饰品 id 数组）+ `equipped`（饰品 id → 舰船 id）。
- 讨伐胜利时两处同步写入（Collect+Save 到 Inventory；`add_economy_accessory` 到 economy）。

### 饰品加成作用于玩家旗舰（与文案一致）

三件饰品文案均以「旗舰」或「全舰队」表述：海怪之角/贯日神枪加成固定作用于玩家旗舰
（`FlagshipRules.ResolveFlagshipId(Player)`），军旗为全舰队射程。economy 侧 `equipped` 的舰船 id
仅作 UI 展示（装备到哪艘舰）；战斗中加成按旗舰判定，不依赖经济舰 id 与战斗舰 id 的映射。

### Lv4 复用 weapons.json 既有数据

`weapons.json` 已含 Lv4 数据：撞角 `MultiplierByLevel[4]=1.8`、砲击 `DamageByLevel[3]=420`。
规则层仅在「玩家旗舰 + 对应饰品已装备」时把撞角/砲击等级提升为 4，复用既有取数路径，零硬编码伤害。

### 装备语义

装备页 + 装备饰品到当前选中舰（`equipped[id]=当前舰`），− 卸下；重复装备自动迁移到当前舰。
战斗内是否生效只由「该饰品是否处于装备状态」决定（装备到任意舰均使旗舰获得加成）。

## Acceptance checks

- [x] `dotnet build ChangcheHeroes.csproj`：0 警告 0 错误
- [x] headless：`test_hunt_rewards_economy`（讨伐胜利 → economy 金/铁/木/麻 + 饰品入背包）全绿
- [x] headless：`test_ship_screen_accessories`（饰品装备/卸下 + 装备后 BattleState 加成）全绿
- [x] 相关回归：`test_naval_hunt_request` / `test_sea_overworld_sea_monster_event` / `test_wokou_main_quest_flow` / `test_ship_screen` / `test_economy_save` / `test_economy_trade` 全绿

## Documentation impact

- 本记录。
- `.superpowers/sdd/f1-report.md`（最终报告）。
- `docs/本地修改记录.md`（项目本地修改记录）。

## Implementation notes

- 改动文件：见 Scope。
- 规则层零 Godot 依赖：`BattleState` / `RamRules` / `AttackRules` 只加纯 C# 字段/分支。
- 掉落时机：`HandleBattleEnded` 玩家胜利且 `HuntBattleSession.Active` 时授予经济奖励；
  饰品 Collect 沿用既有路径（所有 encounter 通用），另同步 economy owned。
- 布阵修复：`NavalDeploymentController.BuildPlayerFleetFromEconomy` / `RestorePlayerEconomyLineup` /
  `TryApplyFormation` 原按静态 `PlayerZone`（自由模式 22 宽）自动摆位，遭遇（讨伐/海盗）玩家区通常窄
  （hunt_stage3 仅 5 宽）→ 摆位落在遭遇区外，`ConfirmDeployment` 报 `deploy.outside_zone`。
  新增 `PlayerPlacementZone()`（遭遇模式用 `_encounter.PlayerZone`，否则静态区），三处摆位统一改用它，
  与 `ValidatePlacement` 校验口径一致（摆位与校验同区，开战通过）。
- 测试钩子：`NavalBattleController` 新增 `RangeBonus` / `FlagshipRamLevel` / `FlagshipBombardmentLevel` /
  `FlagshipRamCoefficient` / `FlagshipBombardmentDamage` 只读；`AttackRules.WeaponPerUnitDamage` 改 public，
  供 headless 直达规则层数值断言（系数 1.8 / 砲击 420）。
