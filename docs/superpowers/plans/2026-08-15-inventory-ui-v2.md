# 水师大仓 V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有依赖复杂生成底图的水师大仓重做为结构清楚、数据真实且可扩展的 6×2 只读物品栏。

**Architecture:** 保留 `InventoryScreen` 动态构建方式与现有物品数据接口，用代码原生 `PanelContainer`、`MarginContainer` 和布局容器构建宏观底板及状态反馈。底图不再承载页签、槽位、详情分段和资源格，自动化测试只验证产品结构与相对布局，不锁死生成图内部坐标。

**Tech Stack:** Godot 4.7 .NET、GDScript、项目内 SceneTree 测试、Godot AI MCP。

## Global Constraints

- 全局物品栏只读，不修改经济、产出、价格、图纸、造船或存档规则。
- 保留五类筛选、三类排序、数字键 `1–5`、关闭按钮和 `Esc`。
- 首屏 6 列 × 2 行共 12 格；超过 12 个唯一条目时使用滚动区域。
- 只显示真实类型，不新增品质字段或伪品质文案。
- 保留工作树内所有无关用户改动。

---

### Task 1: 更新 V2 界面契约

**Files:**
- Modify: `tests/test_inventory_screen.gd`

**Interfaces:**
- Consumes: `InventoryScreen` 现有节点名与 `selected_entry_for_test()`。
- Produces: 12 格、无 `DetailQuality`、左对齐详情、连续底栏和深色选中态的自动化契约。

- [x] **Step 1: 将旧坐标断言改为 V2 结构断言**

测试应断言 `ItemGrid.columns == 6`、初始子节点数为 12、找不到 `DetailQuality`、三段详情左对齐、存在 `FooterBar` 且资源组合左右分布。

- [x] **Step 2: 运行测试并确认旧实现失败**

Run: Godot headless 执行 `tests/test_inventory_screen.gd`。
Expected: FAIL，原因包含 24 格、伪品质、居中详情或缺少连续底栏。

### Task 2: 重建宏观布局与视觉状态

**Files:**
- Modify: `scripts/ui/inventory_screen.gd`
- Remove runtime dependency: `assets/ui/inventory/inventory_backdrop_v1.png`

**Interfaces:**
- Consumes: `GameState.get_economy_state()`、`ItemCatalog.item()` / `ship()` 和现有图标路径。
- Produces: `InventoryFrame`、`HeaderPanel`、`InventoryPanel`、`DetailPanel`、`FooterBar` 以及稳定的子节点名称。

- [x] **Step 1: 用代码原生宏观面板替换 V1 底图**

构建单一外框、紧凑标题区、左侧暗色仓库区、右侧单张旧纸详情区和连续底栏；不创建预制小框。

- [x] **Step 2: 将页签、工具栏和仓格改为 V2 状态**

页签使用深色底与金色下边缘；排序与“库藏”共处工具栏；卡片选中态保持深色并增加金色描边；首屏补足至 12 格。

- [x] **Step 3: 将详情改为单真实类型与左对齐正文**

删除 `_detail_quality` 和 `_quality_label()`；大图、名称、类型居中，描述、用途、来源左对齐并统一宽度。

- [x] **Step 4: 重建连续底栏**

建立 `FooterBar`，将 `PayBlock` 放左、`FleetBlock` 放右，移除固定的五格坐标假设。

- [x] **Step 5: 运行测试并确认通过**

Run: Godot headless 执行 `tests/test_inventory_screen.gd`。
Expected: PASS 并输出 `Inventory screen verification passed.`。

### Task 3: 编辑器与回归验收

**Files:**
- Modify: `docs/changes/CHG-20260815-inventory-ui-overhaul.md`

**Interfaces:**
- Consumes: 完成后的 `InventoryScreen`。
- Produces: Godot 运行截图、日志和回归证据。

- [x] **Step 1: 通过 Godot 编辑器验证场景和脚本**

验证当前月环商港场景资源无解析错误，再运行精确目标场景。

- [x] **Step 2: 在 1344×896 视觉检查木材、铁石和空分类**

确认无 24 个固定空框、无伪品质、无五段底栏，长来源正常换行，军饷和舰队均不溢出。

- [x] **Step 3: 运行相关回归与静态检查**

Run: 物品栏、探索 HUD、全局探索 UI、月环商港相关测试，`dotnet build`，`git diff --check`。
Expected: 所有命令退出码为 0；日志无新增解析或运行错误。

- [x] **Step 4: 对齐文档并重新运行商城场景**

把实际行为与验证证据写回变更记录，状态设为 `done`；最终保持月环商港运行，供用户直接验收。
