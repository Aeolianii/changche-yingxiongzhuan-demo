# CHG-20260923-inventory-overlay-polish: 物品页遮挡与顶部笔触调整

- Status: done
- Type: fix
- Owner: Codex
- Created: 2026-09-23

## Goal and player/project outcome

物品页打开后不显示海图入口；标题、关闭按钮和仓格内容与任务/船只页的顶部水墨笔触协调，左上笔触完整露出。

## Scope

- 打开物品页时暂时隐藏右下海图按钮，关闭后按海图按钮原有可见状态恢复。
- 右上关闭入口使用项目现有横向水墨笔触作为文字底图。
- “物品”标题移至左上笔触中央；页签、库藏面板和网格下移，缩短库藏区域，保留 6 列 × 2 行首屏。

## Non-goals

- 不修改物品数据、交易规则或其他覆盖页布局。
- 不新增风格不同的图片素材。

## Acceptance checks

- [x] 海图场景打开物品页时右下按钮消失，关闭后按原状态恢复。
- [x] 关闭文字位于笔触上方，标题居于左上笔触内。
- [x] 左上笔触不被库藏控件遮挡，仓格、详情和底栏无重叠。
- [x] Godot 定向测试与渲染截图通过。

## Documentation impact

- Canonical document to update before implementation: `docs/design/economy-merchant-harbor.md`
- Decisions/ADRs: none

## Implementation notes

- Likely files: `scripts/exploration_hud.gd`, `scripts/ui/inventory_screen.gd`, `tests/test_inventory_screen.gd`, `tests/capture_inventory_screen.gd`.
- Risk: 外部对海图按钮的隐藏状态须在关闭物品页时保留；首屏两排物品格须保持可见。

## Verification evidence

- Automated: Godot 4.7.1 .NET `test_inventory_screen.gd` headless 通过，覆盖海图按钮打开隐藏、关闭恢复与场景强制隐藏状态、6 列 2 排视口和关闭笔触资源。
- In-engine: Vulkan 1344×896 运行 `capture_inventory_screen.gd` 成功生成 `.godot/inventory_screen_preview.png`，已检查笔触、标题、关闭文字、仓格、详情和底栏无明显重叠。

## Final reconciliation

- Files changed: `scripts/exploration_hud.gd`、`scripts/ui/inventory_screen.gd`、`tests/test_inventory_screen.gd`、`tests/capture_inventory_screen.gd`、物品栏设计文档及本记录。
- Limitations: 保留物品栏原有 6 列 × 2 行首屏与排序、详情功能；其他覆盖页布局未调整。
