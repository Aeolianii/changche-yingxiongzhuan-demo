# CHG-20260818 海域分格雾笔迷雾

- Status: complete
- Type: architecture
- Owner: Codex
- Created: 2026-08-18

## Goal and player/project outcome

让海上大地图和完整海图真正复用海战的分格雾笔逻辑：未知海域有明显但自然的浓淡层次、每片纹理不同，并保留少量可见海面的透明孔洞，不再表现为均匀白色滤镜。

## Scope

- 保留现有 8 世界单位探索细格，新增约 224 世界单位的迷雾表现粗格。
- 按海战 `Hash01(x, y, 53)`、每约四格一张、4.4–5.5 格宽、稳定位置偏移和 `0.38` 基础透明度，预生成世界坐标固定的雾笔密度纹理。
- 大地图与完整海图直接复用海战 `white_ink_mist_v1.png`，只采样一张分格雾笔密度纹理，再由原探索位图裁切。
- 移除海图六层全屏纹理平均、高最低雾 Alpha 和覆盖并集饱和逻辑。

## Non-goals

- 不修改探索细格尺寸、揭示范围、地点显隐、初始已知区域或存档格式。
- 不修改海战 `DrawFog()`、海战素材或战斗规则。
- 不增加新的迷雾图片资源。

## Acceptance checks

- [x] 大地图与完整海图都存在独立于探索细格的粗表现格，并使用战斗同款确定性哈希布置雾笔。
- [x] 未知海域具有明显浓淡层次、不同笔触纹理和少量不规则小孔洞，不再是一整块均匀白色。
- [x] 不出现规则行列、矩形接缝或大面积连续透海空白。
- [x] 已探索边缘仍由原探索位图控制，地点名称和玩家标记层级不变。
- [x] 探索、跨场景恢复和专项 OpenGL 截图验证通过。

## Documentation impact

- Canonical documents to update before implementation: `docs/design/sea-overworld-design.md`, `docs/design/art-direction.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`
- Decisions/ADRs: 探索逻辑网格与迷雾表现网格分离；表现纹理预生成一次，揭示过程中只更新探索遮罩。

## Implementation notes

- Likely files/modules: `scripts/sea_fog_of_war.gd`, 两个探索迷雾 Shader、`scripts/sea_map_screen.gd`, `tests/test_sea_fog_of_war.gd`
- Constraints and risks: 粗格纹理必须稳定、低成本；同一格布置算法在世界画面与完整海图中共享，不能因缩放产生不同雾形。

## Verification evidence

- Automated: Godot 4.7.1 .NET `--headless --editor --quit` 资源与 Shader 解析退出 0；`tests/test_sea_fog_of_war.gd` headless 退出 0，覆盖 8 像素探索格、224 世界单位表现格、雾笔透明/淡/浓 Alpha 分区、世界与海图共享纹理、地点显隐、航行揭示和跨场景恢复。
- Manual/in-engine: OpenGL Compatibility 1344×896 实际渲染退出 0，并检查 `.godot/sea_fog_world_preview.png`、`.godot/sea_fog_map_preview.png` 和连续航线截图；未知海域呈连续飞白雾云，无规则分块接缝，已探索边缘与 UI 层级保持正常。

## Final reconciliation

- Files changed: `scripts/sea_fog_of_war.gd`, `scripts/sea_map_screen.gd`, `shaders/sea_world_fog_edge.gdshader`, `shaders/sea_map_fog_soft_edge.gdshader`, `tests/test_sea_fog_of_war.gd`，以及本记录和四份规范/验收文档。
- Documented limitations/follow-ups: 表现纹理在 `SeaFogOfWar.setup()` 时预合成一次，世界尺寸改变时需重新执行 setup；探索和存档仍只记录 8 世界单位细格，不写入表现纹理。
