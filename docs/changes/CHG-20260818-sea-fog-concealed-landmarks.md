# CHG-20260818 海雾下隐藏未知地形

- Status: complete
- Type: visual-behavior
- Owner: Codex
- Created: 2026-08-18

## Goal and player/project outcome

未知海域只显示水墨海水底层与白色迷雾，不提前透出岛屿、港口和陆地轮廓；玩家探亮区域后，真实地图内容才显现，避免地形像贴在半透明雾层中。

## Scope

- 为航行大地图与完整海图的未知区域增加共享海水遮蔽底层。
- 继续在遮蔽底层上渲染分格雾笔的浓淡、纹理与孔洞；孔洞只能看到海水纹理，不能看到未知岛屿。
- 探索遮罩清除后同步移除海水遮蔽与白雾，显露真实地图。

## Non-goals

- 不修改探索范围、8 世界单位逻辑格、224 世界单位表现格或存档。
- 不修改背景地图资源、岛屿位置、地点名称规则或海战迷雾。

## Acceptance checks

- [x] 未探索岛屿、港口和陆地不能透过白雾或雾中孔洞显示。
- [x] 未知区域仍有海水纹理、雾笔浓淡与小孔洞，不变成纯色遮罩。
- [x] 探亮后真实地图内容完整显现，探索边缘保持水墨柔边。
- [x] 航行大地图与完整海图规则一致，地点标签和玩家标记层级不变。
- [x] 专项自动化与 OpenGL 截图验证通过。

## Documentation impact

- Canonical documents: `docs/design/sea-overworld-design.md`, `docs/design/art-direction.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`

## Verification evidence

- Automated: Godot 4.7.1 .NET `--headless --editor --quit` 资源与 Shader 解析退出 0；`tests/test_sea_fog_of_war.gd` headless 退出 0，断言世界与完整海图绑定同一水墨海水遮蔽纹理、未知区输出不再乘雾笔 Alpha、探索揭示和跨场景恢复保持正常。
- Manual/in-engine: OpenGL Compatibility 1344×896 实际渲染退出 0；检查 `.godot/sea_fog_map_preview.png`，确认未探索岛屿和城市全部隐藏、雾中飞白只显示海水、已探索大陆和地点正常显示。

## Final reconciliation

- Files changed: `scripts/sea_fog_of_war.gd`, `scripts/sea_map_screen.gd`, `shaders/sea_world_fog_edge.gdshader`, `shaders/sea_map_fog_soft_edge.gdshader`, `tests/test_sea_fog_of_war.gd`，以及本记录和四份规范/验收文档。
- Documented limitations/follow-ups: 未知区域用现有无缝水墨海纹遮蔽真实地图，颜色由 Shader 统一染成当前海域青蓝色；后续若大地图海水主色调整，应同步修改 `concealment_tint`。
