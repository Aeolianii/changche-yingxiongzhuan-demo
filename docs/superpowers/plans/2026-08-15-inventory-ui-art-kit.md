# 水师大仓素材化美术升级 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用独立生成的像素国风背景、标题牌和 UI 组件替代物品栏中的普通代码方框，同时保持动态数据与现有交互契约。

**Architecture:** 位图只承载装饰与材质，Godot 节点继续承载文字、数值、图标和状态。环境背景单独全屏铺设；标题、页签、槽位、详情和底栏使用可复用透明 PNG 与 `StyleBoxTexture`/`NinePatchRect` 组合，避免再次把布局画死在一张图中。

**Tech Stack:** Godot 4.7 .NET、GDScript、内置 ImageGen、PNG 色键后处理、SceneTree 自动化测试。

## Global Constraints

- 像素国风、深墨绿与暖金主色、旧纸详情面，与月环商港黑金视觉一致。
- 所有中文和动态数值由 Godot 准确渲染，除经人工验字通过的“水师大仓”标题外不在生图中生成文字。
- 不修改经济、仓库、图纸、造船、存档或物品来源规则。
- 保留无关工作树改动，不提交、不推送。

---

### Task 1: 生成并整理 V3 美术素材

**Files:**
- Create: `assets/ui/inventory/v3/inventory_environment_v3.png`
- Create: `assets/ui/inventory/v3/inventory_title_plaque_v3.png`
- Create: `assets/ui/inventory/v3/inventory_tab_v3.png`
- Create: `assets/ui/inventory/v3/inventory_slot_v3.png`
- Create: `assets/ui/inventory/v3/inventory_detail_v3.png`
- Create: `assets/ui/inventory/v3/inventory_footer_v3.png`
- Create: `assets/ui/inventory/v3/inventory_corner_v3.png`

- [x] **Step 1: 生成无文字环境背景**

生成 1344×896 横向像素国风水师仓廒背景，只包含暗色木构、仓架、船具、窗外港湾剪影与低对比纹理，中部保持可承载 UI 的暗色留白，不含文字、框线、物品和按钮。

- [x] **Step 2: 生成透明组件图集**

在纯色键背景上生成无文字的标题牌、页签、方形物品槽、竖向旧纸详情框、横向连续底栏和边角纹样；组件彼此分离、不重叠、无投影污染背景。

- [x] **Step 3: 色键、裁切和视觉检查**

使用技能自带色键脚本去底，再按图集单元裁切为独立 PNG；检查 alpha、边缘残色、像素清晰度和四角覆盖。

### Task 2: 用测试定义素材化界面契约

**Files:**
- Modify: `tests/test_inventory_screen.gd`

- [x] **Step 1: 增加素材节点与纹理契约**

测试要求 `InventoryEnvironment`、`TitlePlaque`、`DetailArtwork`、`FooterArtwork` 存在且引用 V3 PNG；页签和物品槽正常/选中样式使用 `StyleBoxTexture`，不再使用纯色 `StyleBoxFlat`。

- [x] **Step 2: 运行测试确认 V2 失败**

Run: Godot headless 执行 `tests/test_inventory_screen.gd`。
Expected: FAIL，原因是 V2 尚无 V3 素材节点且页签/槽位仍是纯色样式。

### Task 3: 在 Godot 中组合 V3 界面

**Files:**
- Modify: `scripts/ui/inventory_screen.gd`

- [x] **Step 1: 接入环境背景和装饰层**

在遮罩之上、交互控件之下加入全屏环境图；加入标题牌、详情纸面、底栏和边角纹样，保持鼠标穿透。

- [x] **Step 2: 接入标题与专属文字效果**

标题放在独立牌匾上；只有生成标题逐字准确时才直接使用，否则用 Godot 准确文字叠加加粗、金色描边和双层墨影。

- [x] **Step 3: 接入页签和仓格纹理状态**

页签与仓格使用生成纹理；悬停和选中通过主动纹理、金色调制或独立边纹表达，所有状态保持可读。

- [x] **Step 4: 接入详情纸面和连续底栏**

移除详情与底栏的纯色主背景，让生成组件承担材质与边角；动态文字、图标和数值位置不变。

- [x] **Step 5: 运行物品栏测试转绿**

Run: Godot headless 执行 `tests/test_inventory_screen.gd`。
Expected: PASS。

### Task 4: 视觉、回归与文档收口

**Files:**
- Modify: `docs/changes/CHG-20260815-inventory-ui-art-kit.md`
- Modify: `docs/superpowers/plans/2026-08-15-inventory-ui-art-kit.md`

- [x] **Step 1: 生成 1344×896 运行截图并迭代**

检查背景层次、标题验字、组件边缘、页签选中、12 格、详情排版与底栏溢出；发现问题时做单点调整并重拍。

- [x] **Step 2: 运行完整回归和构建**

运行物品栏、探索 HUD、全局探索 UI、月环商岛、月环商港测试，合并项目静态验证、C# 构建与 `git diff --check`。

- [x] **Step 3: 写回证据并重新运行月环商港**

记录最终素材、提示词、验证输出和已知限制，状态设为 `done`；运行精确商港场景并保持开启供验收。
