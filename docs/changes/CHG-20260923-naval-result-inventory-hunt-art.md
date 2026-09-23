# CHG-20260923-naval-result-inventory-hunt-art: 结算、物品栏与海怪战地图视觉统一

- Status: done
- Type: content | fix
- Owner: Codex
- Created: 2026-09-23

## Goal and player/project outcome

放大胜利题字；让物品栏与任务、船只页使用同一套水墨背景和 UI 语言；海怪两场讨伐战用连续大地貌取代逐格图章。

## Scope

- 胜利结算题字在当前显示尺寸基础上放大约 30%，保持详情与返回按钮可读。
- 物品栏复用任务/船只页背景和项目现有墨金按钮、面板风格，保留分类、排序、详情与资源数据。
- 海怪第一、二场地图分别接入透明的大地貌素材，原逐格地形规则不变；地貌区内不绘制逐格障碍物。

## Non-goals

- 不调整寻路、碰撞、地图尺寸、舰船平衡或仓库交易规则。
- 不改倭寇营寨终战地图和随机海战五套模板。

## Acceptance checks

- [x] 胜利题字显示尺寸比现值大约 30%，无遮挡。
- [x] 物品栏与任务/船只页背景一致，原有交互与详情完整。
- [x] 海怪两场地图加载连续素材，地形逐格精灵不再透出，规则地图仍可进入战斗。
- [x] Godot 定向验证和截图检查通过。

## Documentation impact

- Canonical documents to update before implementation: `docs/design/art-direction.md`, `docs/tech/architecture.md`, `docs/design/economy-merchant-harbor.md`
- Decisions/ADRs: none

## Implementation notes

- Likely files/modules: `scenes/naval/NavalDemo.tscn`, `scripts/ui/inventory_screen.gd`, `scripts/naval/levels/MapScheme.cs`, `scripts/naval/presentation/NavalGridView.cs`, `assets/naval/battle/terrain_stamps/`, focused tests.
- Constraints and risks: 生成图须透明且与格位轮廓相符；现有其他未提交资源保持原样。

## Verification evidence

- Automated: `dotnet build` 0 警告/错误；Godot 4.7.1 .NET 资源导入退出码 0；`test_naval_result_ui.gd`、`test_inventory_screen.gd`、`test_hunt_terrain_art.gd` headless 均通过。两张新地图左侧布阵区逐格中心 Alpha 最大值分别为 0、2（低于 32）。
- Manual/in-engine: Vulkan 1344×896 截图 `naval_result_preview.png`、`inventory_screen_preview.png`、`hunt_archipelago_terrain_preview.png`、`hunt_lagoon_terrain_preview.png` 已检查；泻湖海岸压到布阵船位的问题已用透明轮廓修整。

## Final reconciliation

- Files changed: `NavalDemo.tscn`、物品页脚本、两场海怪地图及绘制脚本、两张新地貌 PNG 和导入配置、定向测试、上述规范文档。
- Documented limitations/follow-ups: 生成素材已按原格位裁放，地形规则未改；素材样式为低饱和像素水墨。仓库现有其他未提交资源不属于本次变更。

## Asset generation

- Mode: built-in imagegen.
- `hunt_stage1_archipelago_v1.png`: transparent 4:3 top-down pixel-ink terrain with three distinct rocky forest islands and one northeastern reef chain; no sea base, grid, ships, text, or cartoon outlines. The generated landforms were resized and placed over the existing island/reef regions.
- `hunt_stage2_lagoon_v1.png`: transparent 4:3 top-down pixel-ink lagoon with northern/southern shores, sparse central shoals, muted fishing hamlet, and wide sea channel; no sea base, grid, ships, text, or cartoon outlines. Alpha was limited to the existing terrain cells to keep the player deployment water clear.
