# CHG-20260809-sea-overworld-production-map: v4 海上大地图生产落地

- Status: in-progress
- Type: content
- Owner: Codex
- Created: 2026-08-09

## Goal and player/project outcome

以 `sea_overworld_stage1_graybox_v4.png` 为唯一构图依据，制作并接入可运行的 A/B/C/D 四分块海上大地图，使生产底图、16 个地点、碰撞、入口触发、完整海图和现有航行交互保持一致。

## Scope

- 制作一张 `6528×3604` 生产母图，并裁为四张 `3344×1882` 运行时 PNG。
- 沿用当前每块 `2508×1412` 世界单位、`120` 世界单位重叠带和混合 shader。
- 固定 A4、B5、C4、D3：B 为右上群岛水战区，D 为右下敌方核心海域。
- 按批准坐标重排 16 个地点，并将入口触发对准可见码头或登陆口。
- 按生产底图重做海岸与岛屿碰撞，保留 A→B、A→C、B→D、C→D 和中央十字水门。
- 更新完整海图资源、针对性测试、视觉截图检查与相关设计、资产、QA 文档。
- 保留 v1～v4 草图及旧生产背景；新生产资源使用版本化文件名。

## Non-goals

- 不新增、删除或改名现有 16 个地点。
- 不增加天气、风向、洋流、潮汐、暗礁伤害或航海模拟系统。
- 不制作实际登岛小地图、剧情、对话、海战切换或快速移动。
- 不重做玩家船只、月相 HUD、任务 HUD、存档或场景二主流程。
- 不把生产母图和生成中间稿提交到仓库或推送 GitHub；仓库只保存最终运行时分块。

## Acceptance checks

- [x] v4 构图、B/D 职责、四分块尺寸和接缝规格已写入规范文档。
- [ ] 四张生产分块均为 `3344×1882`，重叠带连续且游戏内无明显接缝。
- [ ] 运行时和完整海图均使用同一套 A/B/C/D v3 生产分块。
- [ ] 16 个地点保持 A4、B5、C4、D3，中心坐标相对批准草案偏差不超过 `±80` 世界单位。
- [ ] 所有入口触发对准可见码头或登陆口，月环商港入口位于左侧。
- [ ] 主要岛屿不可穿越，四条跨区路线和中央十字水门均可航行。
- [ ] 地点交互、事件船、漂流事件、海图、月相、存档和场景二往返没有回归。
- [ ] `tests/test_sea_overworld.gd` 通过，并完成 A/B/C/D、中央接缝和完整海图截图检查。

## Documentation impact

- Canonical documents: `docs/design/sea-overworld-design.md`
- Supporting documents: `docs/assets/sea-overworld-stage1-layout.md`, `docs/assets/sea-overworld-generated-assets.md`, `docs/qa/playtest.md`
- Implementation plan: `docs/superpowers/plans/2026-08-09-sea-overworld-production-map.md`
- Decisions/ADRs: none

## Likely files and modules

- Create: `assets/backgrounds/sea_overworld/guangdong_sea_zone_a_v3.png`
- Create: `assets/backgrounds/sea_overworld/guangdong_sea_zone_b_v3.png`
- Create: `assets/backgrounds/sea_overworld/guangdong_sea_zone_c_v3.png`
- Create: `assets/backgrounds/sea_overworld/guangdong_sea_zone_d_v3.png`
- Create: `tools/slice_sea_overworld_map.py`
- Modify: `scripts/sea_overworld.gd`
- Modify: `scenes/sea_overworld/sea_overworld.tscn`
- Modify: `tests/test_sea_overworld.gd`
- Modify: canonical and supporting documents listed above

## Implementation notes

- Composition source: `assets/backgrounds/sea_overworld/concepts/sea_overworld_stage1_graybox_v4.png`
- Local-only artwork directory: `D:\厂车英雄传DEMO\artwork\sea_overworld\`
- Master size: `6528×3604`; crop origins are A `(0,0)`, B `(3184,0)`, C `(0,1722)`, D `(3184,1722)`.
- Runtime chunk size: `3344×1882` source pixels displayed at `0.75` scale as approximately `2508×1412` world units.
- Seam contract: `160` source pixels, corresponding to `120` world units.
- Coordinate contract: approved centers may move at most `±80` world units during art alignment; a larger move requires updating the layout document before implementation.
- Primary risks: AI-generated chunk drift can break seams; old runtime data currently places the three D landmarks in the upper-right and five B landmarks in the lower-right; oversized collision shapes can close approved waterways; visual docks can diverge from interaction triggers.

## Verification evidence

- Automated: Task 1 文档检查通过；变更记录包含目标、范围、非目标、验收项、文件与风险；设计文档和布局文档均锁定 `6528×3604` 母图、`3344×1882` 分块、`160` 源像素 / `120` 世界单位接缝、A4/B5/C4/D3 和 `±80` 坐标容差；Markdown 围栏成对，`git diff --check` 无错误。
- Manual/in-engine: 已人工核对生产目标为右上 B5 群岛水战区、右下 D3 敌方核心海域，并明确区分当前旧运行时布局；生产资产与运行时集成尚未开始，Task 1 不要求引擎验证。

## Final reconciliation

- Files changed: pending until implementation is complete.
- Documented limitations/follow-ups: v4 locks macro composition, not exact decorative reef collision; production landing points will be calibrated against the final art.
