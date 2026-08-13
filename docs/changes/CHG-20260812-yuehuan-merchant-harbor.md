# CHG-20260812-yuehuan-merchant-harbor: 月环商港、仓库与造船闭环

- Status: done
- Type: feature
- Owner: Codex
- Created: 2026-08-12

## Goal and player/project outcome

让玩家能从海图进入月环商港，以军饷交易木材、铁石和已有来源的探索货物，购买永久造船图纸并制造舰船；同步开放全局只读物品栏，并让全部经济状态进入正式存档。

## Scope

- 新增全局经济状态、物品目录、交易服务、图纸解锁和造船服务。
- 月环商港由“即将开放”改为可进入独立界面，并可返回原海图位置。
- 商港使用左商店、右仓库的双栏交易布局。
- 右上“物品栏”入口开放为正式只读仓库。
- 伏波钓鱼和三个现有海上事件写入真实库存/军饷产出。
- 存档升级并兼容版本 1。

## Non-goals

- 不制作付费商城、抽卡、限时刷新、动态物价、商人委托或稀有收藏兑换。
- 不制作修船、出航消耗品、采集工具、装备商店或战棋编队重做。
- 不修改现有船只战斗数值。

## Acceptance checks

- [x] 月环商港可从海图进入并返回登港前船位。
- [x] 木材和铁石可批量买卖，价格和库存变化正确且不能产生负数。
- [x] 钓鱼与海上事件的所有商品均进入仓库，商城没有无来源商品。
- [x] 三张图纸只能购买一次；拥有图纸后可重复造船，最多 10 艘。
- [x] 失败的购买、出售或造船不改变任何资源。
- [x] 全局物品栏可在四个探索场景打开并正确阻断/恢复移动。
- [x] 版本 1 存档可读取，版本 2 可保存和恢复经济状态。
- [x] 1344×896 下商港与物品栏无溢出、文字可读、返回路径可用。

## Documentation impact

- Canonical documents: `docs/design/economy-merchant-harbor.md`, `docs/design/game-design-v1.md`, `docs/design/sea-overworld-design.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`, `docs/production/backlog.md`, `docs/index.md`.
- Decisions/ADRs: none；沿用 `GameState.world_state`，不引入新依赖。

## Implementation notes

- Likely files/modules: `scripts/core/game_state.gd`, `scripts/economy/*`, `scripts/ui/*`, `scripts/sea_overworld.gd`, `scripts/fubo_guling/*`, `scenes/ui/*`, `scenes/yuehuan_merchant_harbor/*`, `tests/*`, `project.godot`.
- Constraints and risks: 当前正式设计中的“铜钱”和材料禁售规则必须先被新经济文档取代；V4 迁移相关未提交文件属于同一工作区，需保留且不混淆验证证据。

## Verification evidence

- Automated: `test_economy_trade`, `test_economy_save`, `test_inventory_screen`, `test_yuehuan_harbor`, `test_main_flow_save`, `test_title_screen`, `test_global_exploration_ui`, `test_exploration_hud`, `test_fubo_fishing_game`, `test_fubo_save_state`, `test_fubo_sea_round_trip`、漂流箱/茶商/私盐三套事件测试全部通过且无脚本错误；`verify_merged_project.ps1` 通过。
- Manual/in-engine: Godot 4.7 Vulkan 以 1344×896 渲染商港和物品栏，截图保存为 `.godot/yuehuan_merchant_harbor_preview.png` 与 `.godot/inventory_screen_preview.png`；双栏、分类、详情、军饷、舰队和返回入口均完整可读。

## Final reconciliation

- Files changed: 新增 `scripts/economy/` 三个模型/服务、月环商港场景与脚本、全局物品栏脚本和四套专项测试；修改 `GameState`、共享 HUD、海图、伏波钓鱼、三类海上事件和对应设计/QA/静态验证文档。
- Documented limitations/follow-ups: 首版不含战棋编队界面接入、装备买卖、委托、稀有收藏、动态物价、维修或付费内容；新造舰船已经进入正式舰队存档，后续战棋整合直接读取该列表。
