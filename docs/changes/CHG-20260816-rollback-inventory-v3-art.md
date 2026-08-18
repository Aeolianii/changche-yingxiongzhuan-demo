# CHG-20260816-rollback-inventory-v3-art: 回退水师大仓 V3 素材化界面

- Status: done
- Date: 2026-08-16

## Goal

按用户验收意见撤销水师大仓 V3 生成式美术皮肤，恢复上一版 V2 深墨绿/米色代码原生界面。

## Scope

- 移除 V3 环境背景、生成题字、页签、物品槽、详情框、底栏和边角贴图的运行时接入。
- 恢复 V2 标题、宏观面板、纯代码页签/仓格状态、详情纸面和连续底栏。
- 将物品栏自动化契约恢复为 V2 视觉契约。
- 保留现有物品分类、排序、详情、军饷、舰队、关闭与移动锁逻辑。

## Non-goals

- 不修改商城、商人、地图、碰撞、经济数据、图纸、造船或存档逻辑。
- 不覆盖仓库中其他未提交改动。
- 不删除生成源图；项目内 V3 输出移动到可恢复的临时归档，不继续参与运行时加载。

## Acceptance checks

- 运行截图恢复到上一版 V2 构图，不再显示大型金字牌匾、木雕槽框、仓廒环境和海浪底栏。
- 物品栏现有自动化测试、探索 HUD、商岛与商港回归继续通过。
- Godot 商港场景重新运行并保持开启供验收。

## Documentation impact

- `docs/design/economy-merchant-harbor.md`：撤销 V3 四层生成素材架构，恢复 V2 代码原生界面为当前真相。
- `docs/qa/playtest.md`：移除 V3 专项验收项。
- `docs/changes/CHG-20260815-inventory-ui-art-kit.md`：标记为已回退。

## Likely files

- `scripts/ui/inventory_screen.gd`
- `tests/test_inventory_screen.gd`
- `tests/capture_inventory_screen.gd`
- `assets/ui/inventory/v3/`
- `docs/design/economy-merchant-harbor.md`
- `docs/qa/playtest.md`

## Verification evidence

- `test_inventory_screen.gd` 输出 `Inventory screen verification passed.`。
- `test_exploration_hud.gd`、`test_yuehuan_merchant_island.gd`、`test_yuehuan_harbor.gd` 均退出码 0。
- Vulkan 运行截图成功，人工确认画面恢复为 V2 深墨绿/米色布局，不再加载 V3 标题、环境、槽框、详情框和海浪底栏。
- V3 项目素材已移动至 `.codex_tmp/inventory_v3/archived_project_assets/`，可恢复但不参与运行时加载。
- 未修改商城、经济、物品、图纸、造船、存档或场景碰撞逻辑。
