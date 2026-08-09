# CHG-20260809-sea-overworld-production-map: v4 海上大地图生产落地

- Status: done
- Type: content
- Owner: Codex
- Created: 2026-08-09
- Completed: 2026-08-10

## Goal and player/project outcome

以 `sea_overworld_stage1_graybox_v4.png` 为唯一构图依据，制作并接入可运行的 A/B/C/D 四分块海上大地图，使生产底图、16 个地点、碰撞、入口触发、完整海图和现有航行交互保持一致。

## Scope

- 制作一张 `6528×3604` 生产母图，并裁为四张 `3344×1882` 运行时 PNG。
- 沿用当前每块 `2508×1412` 世界单位、`120` 世界单位重叠带和混合 shader。
- 固定 A4、B5、C4、D3：B 为右上群岛水战区，D 为右下敌方核心海域。
- 按批准坐标重排 16 个地点，并将入口触发对准可见码头或登陆口。
- 按生产底图重做海岸与岛屿碰撞，保留 A→B、A→C、B→D、C→D 和中央十字水门。
- 更新完整海图资源、针对性测试、视觉截图检查与相关设计、资产、QA 文档。
- 接入时适度缩小玩家 Q 版人物、船体和航行特效，并同步收紧玩家碰撞与视觉锚点，强化大地图的开阔感。
- 保留 v1～v4 草图及旧生产背景；新生产资源使用版本化文件名。

## Non-goals

- 不新增、删除或改名现有 16 个地点。
- 不增加天气、风向、洋流、潮汐、暗礁伤害或航海模拟系统。
- 不制作实际登岛小地图、剧情、对话、海战切换或快速移动。
- 不重绘玩家船只，也不改月相 HUD、任务 HUD、存档或场景二主流程；本次只调整船只与人物显示比例及配套锚点、碰撞。
- 不把生产母图和生成中间稿提交到仓库或推送 GitHub；仓库只保存最终运行时分块。

## Acceptance checks

- [x] v4 构图、B/D 职责、四分块尺寸和接缝规格已写入规范文档。
- [x] 四张生产分块均为 `3344×1882`，四组重叠带逐像素一致；游戏内接缝留待 Task 3 接入后验收。
- [x] 运行时和完整海图均使用同一套 A/B/C/D v3 生产分块。
- [x] 16 个地点保持 A4、B5、C4、D3，中心坐标相对批准草案偏差不超过 `±80` 世界单位。
- [x] 所有入口触发对准可见码头或登陆口，月环商港入口位于左侧。
- [x] 玩家船体、尾流和侧浪缩至 `0.28`，Q 版人物缩至 `0.088`，碰撞半径缩至 `19`；人物甲板站位与尾流方向保持稳定。
- [x] 主要岛屿不可穿越，四条跨区路线和中央十字水门均可航行。
- [x] 地点交互、事件船、漂流事件、海图、月相、存档和场景二往返没有回归。
- [x] `tests/test_sea_overworld.gd` 通过，并完成 A/B/C/D、中央接缝和完整海图截图检查。

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
- Player scale contract: ship, wake and side splash use `0.28`; protagonist uses `0.088`; player collision radius uses `19`, with deck and wake offsets recalibrated proportionally.
- Collision contract: use named coastline/island polygons plus short circle chains that follow visible rock bases without closing port basins; the decorative central wreck has no blocker. Keep sampled A→B, A→C, B→D and C→D corridors clear, and reserve at least one clear route above, below, left and right of the central fortress cluster.
- Task 4 water probes: cross A/B near `y=800`, A/C near `x=1700`, B/D near `x=4200`, C/D near `y=1400`; the exact polyline may bend around visible islands but must remain collision-free for the `19`-radius player hull.
- Task 4 collision landing: 14 named polygons and 18 named circle blockers replace the old oversized placeholders. `SOUTH_SEA_HARBOR_SPAWN = Vector2(1300, 850)`; auto triggers move to fishing boat `(1650,1170)`, merchant ship `(2600,760)` and drift event `(1300,1700)`. Cangmen and Shanwan entry rectangles were shifted to their remaining clear-water dock sides.
- Task 5 test landing: direct scene launch now starts at clear water `(1500,800)`; save-restore test water moves to `(2450,1400)`; Scene2 round-trip expectation follows the verified harbor spawn `(1300,850)`. Runtime screenshots remain under `.godot/` and are not committed.
- Primary risks: AI-generated chunk drift can break seams; old runtime data currently places the three D landmarks in the upper-right and five B landmarks in the lower-right; oversized collision shapes can close approved waterways; visual docks can diverge from interaction triggers.
- Task 2 image mode: built-in image generation, `sketch-to-render`, with v4 as the sole edit target and all composition invariants locked.
- Local production render: `D:\厂车英雄传DEMO\artwork\sea_overworld\sea_overworld_production_render_v1.png`.
- Local production master: `D:\厂车英雄传DEMO\artwork\sea_overworld\sea_overworld_master_v1.png`, RGB `6528×3604`, SHA-256 `1F12163B60C790D77FB3017256DCEA1F9D86F07C5D05FAD703ACDD302E7E8E04`.
- Runtime chunk SHA-256: A `ACBB0B091D5F1D9B75EB712C5F048D96DF60A7CC39D520D5AEF98F8049CF03D6`; B `BDA3BD4A2749A39C611F85C48F60358F3DB118DE7257CE6AB4364B35668468D8`; C `04974B2D0FCF139DA6E52C5D62CEE239F2DED9AB98F38265E32786E14EFFC64C`; D `780A6024EE560850D43A31B579751058B93734D980AFA6C841480F1CA95D84A4`.
- Task 3 runtime landing: A/B/C/D v3 textures are serialized and preloaded consistently; all 16 approved coordinates are exact; moon-harbor entry offset is left-facing; compact player visual/collision values follow the player scale contract. Task 4 moves `SOUTH_SEA_HARBOR_SPAWN` to the newly verified clear-water point `Vector2(1300, 850)` while retaining overlap with the harbor entry trigger.

## Verification evidence

- Automated: Task 1 文档检查通过。Task 2 的裁图工具通过 `py_compile`；A/B/C/D 均为 RGB `3344×1882`；四组 `160` 像素重叠带逐像素一致；四块重组后与 `6528×3604` 母图逐像素一致；边缘黑像素比例均为 `0.000%`；Godot 4.7.1 headless editor 成功导入四张 PNG，生成的 `.import` 均使用无损压缩模式。Task 3 通过 Godot 4.7.1 headless 编辑器加载和 8 帧场景 smoke test；临时运行时探针验证四张 v3 纹理、16 个精确坐标、月环商港左侧矩形入口、玩家显示比例和 `19` 碰撞半径。
- Automated: Task 4 导航探针使用半径 `19` 的玩家船体逐段查询并实际驱动 `CharacterBody2D` 通过 A→B、A→C、B→D、C→D 及中央堡垒上、下、左、右共 8 条走廊；同时验证 16 个陆地探针均受阻、16 个地点入口均保留可达水面，出生点、两艘事件船、漂流事件、中央沉船与南澳港外水面均无静态碰撞。Godot 4.7.1 编辑器加载和 8 帧场景 smoke test 均通过。
- Automated: Task 5 的 `tests/test_sea_overworld.gd` 在 Godot 4.7.1 headless 与有窗口 OpenGL Compatibility 两种模式均退出 `0` 并输出 `Sea overworld runtime verification passed.`；`tests/test_main_flow_save.gd` 和 `tests/test_scene_two_sea_link.gd` 分别通过存档恢复与场景二往返回归。
- Manual/in-engine: 已检查 1344×896 的 A 区航行/静止、B、C、D、中央四块交点、完整海图、任务与月相截图。四块无明显硬接缝；16 个标签齐全且没有 B/D 旧职责残留；月环商港朝左，右上地标主次清楚；中央水门与南澳港外水面开阔；缩小后的玩家船体和 Q 版人物不遮挡航道。截图位于 `.godot/sea_overworld_*_preview.png`。

## Final reconciliation

- Production assets: `assets/backgrounds/sea_overworld/guangdong_sea_zone_[a-d]_v3.png` and their four Godot `.import` files.
- Runtime and tooling: `tools/slice_sea_overworld_map.py`, `scripts/sea_overworld.gd`, `scripts/sea_overworld_player.gd`, `scenes/sea_overworld/sea_overworld.tscn`.
- Regression coverage: `tests/test_sea_overworld.gd`, `tests/test_main_flow_save.gd`, `tests/test_scene_two_sea_link.gd`.
- Documentation: `docs/design/sea-overworld-design.md`, `docs/assets/sea-overworld-stage1-layout.md`, `docs/assets/sea-overworld-generated-assets.md`, `docs/qa/playtest.md`, this change record and the implementation plan.
- Automated result: Godot 4.7.1 headless production-map, main-flow save and Scene2 round-trip tests all exit `0`; the map test also passes in windowed OpenGL Compatibility mode.
- Screenshot result: A/B/C/D, central seam and full-map `1344×896` captures show no hard seams or missing labels; Moon Harbor faces left, B/D responsibilities are correct, and the central and Nanao Harbor approaches remain open.
- Documented limitations/follow-ups: the local production master and generation intermediates remain outside the repository; decorative micro-reefs are not all collidable, and the central wreck remains visual-only. Weather, currents, reef damage, landing sub-scenes and naval-combat transitions remain explicitly out of scope.
- Post-acceptance correction: Qingyu Secret Realm moved from the legacy open-water coordinate `(1760,950)` to the visible pagoda island at `(2380,540)`. Its interaction trigger now sits on the south-side water, and its full-map label is placed at the island's upper-right without overlapping adjacent labels.
