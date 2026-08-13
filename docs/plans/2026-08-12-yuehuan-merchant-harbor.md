# 月环商港与仓库实现计划

**Goal:** 完成可从海图进入、可交易、可买图纸造船、可存档，并与物品栏和现有产出相连的首版商城闭环。

**Architecture:** 静态目录、经济状态、交易服务和 UI 分离；`GameState` 持有唯一全局状态。月环商港使用独立场景，海图通过一次性上下文往返；共享 HUD 持有只读仓库覆盖层。

**Tech Stack:** Godot 4.7、GDScript、JSON 单槽存档、SceneTree 自动化测试。

## Global constraints

- 货币固定为军饷；仓库无限容量。
- 木材、铁石可买卖，其他首版货物只能出售。
- 图纸一次购买、永久解锁；拥有图纸后可重复造船，舰队上限 10。
- 不制作修船、消耗军需、采集工具、真实付费或装备交易。
- 每件商品必须具有同版本真实产出来源。

### Task 1: 经济模型与原子交易

**Files:** `scripts/economy/item_catalog.gd`, `scripts/economy/economy_state.gd`, `scripts/economy/trade_service.gd`, `tests/test_economy_trade.gd`

- [ ] 先写失败测试，覆盖默认值、材料买卖、只售商品、非法数量、余额/库存不足、图纸幂等和造船上限。
- [ ] 运行测试确认因类缺失失败。
- [ ] 实现目录、状态校验和原子服务。
- [ ] 运行测试确认全部通过。

### Task 2: GameState 与存档迁移

**Files:** `scripts/core/game_state.gd`, `tests/test_economy_save.gd`, `tests/test_main_flow_save.gd`

- [ ] 先写版本 1 迁移和版本 2 往返失败测试。
- [ ] 将经济状态接入 `world_state.economy`，增加受控查询/变更接口和月环场景白名单。
- [ ] 验证旧存档、现有四场景存档和经济往返。

### Task 3: 商港场景与海图往返

**Files:** `scripts/economy/yuehuan_travel_session.gd`, `scripts/yuehuan_merchant_harbor.gd`, `scenes/yuehuan_merchant_harbor/yuehuan_merchant_harbor.tscn`, `scripts/sea_overworld.gd`, `tests/test_yuehuan_round_trip.gd`

- [ ] 先写地点目标、上下文编解码和返回恢复失败测试。
- [ ] 实现独立商港双栏界面、三页商店、仓库筛选、数量交易、返回按钮和海图恢复。
- [ ] 运行目标场景并检查真实交互与错误日志。

### Task 4: 全局只读物品栏

**Files:** `scripts/ui/inventory_screen.gd`, `scripts/exploration_hud.gd`, `tests/test_inventory_screen.gd`, `tests/test_exploration_hud.gd`

- [ ] 先写入口、分类、详情、军饷、图纸、舰队数量和阻断信号失败测试。
- [ ] 将物品栏接入唯一共享 HUD，关闭后恢复场景控制。
- [ ] 验证宫城、水师、海图和伏波共享同一状态。

### Task 5: 商品真实产出

**Files:** `scripts/fubo_guling/fubo_fishing_game.gd`, `scripts/fubo_guling/minigames/fubo_fishing_minigame.gd`, `scripts/fubo_guling/fubo_guling.gd`, `scripts/sea_overworld.gd`, related tests

- [ ] 先写鱼获种类计数、漂流箱、茶商和私盐选择写入经济状态的失败测试。
- [ ] 接入真实奖励且保持事件完成幂等。
- [ ] 验证每个可出售商品至少有一条通过测试的来源。

### Task 6: 集成与视觉验收

**Files:** `tests/verify_merged_project.ps1`, `docs/qa/playtest.md`, `docs/changes/CHG-20260812-yuehuan-merchant-harbor.md`

- [ ] 运行经济、存档、HUD、海图、伏波和全量静态测试。
- [ ] 用 Godot 运行商港与物品栏，检查 1344×896 截图、返回路径和日志。
- [ ] 对照设计逐项验收，回填实际文件和证据，将变更状态设为 `done`。
