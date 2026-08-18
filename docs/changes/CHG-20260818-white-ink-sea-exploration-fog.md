# CHG-20260818 海域探索白色水墨迷雾

- Status: done
- Type: content
- Owner: Codex
- Created: 2026-08-18

## Goal and player/project outcome

把海上大地图航行画面与完整海图四周的黑色探索迷雾统一替换为海战已采用的白色像素水墨海雾，使两套海域视觉语言一致，同时保留永久探索、地点显隐和存档规则。

## Scope

- 海上大地图世界遮罩复用 `assets/naval/ui/fog/white_ink_mist_v1.png`。
- 完整海图遮罩复用同一素材，并保留海图专用柔边与稳定水墨扰动。
- 调整两处迷雾着色器的颜色、纹理叠加和透明度，使未知海域显示为连续半透明白雾。
- 更新迷雾专项测试，断言大地图与完整海图都绑定同一战斗白雾素材且不再输出黑色遮罩。

## Non-goals

- 不修改探索位图、揭示范围、初始已知区域或地点名称显隐规则。
- 不修改存档版本、序列化数据、任务文本或海战迷雾实现。
- 不新增或重新生成迷雾美术素材。

## Acceptance checks

- [x] 大地图未探索海域由半透明白色像素水墨雾覆盖，不再显示黑色遮罩。
- [x] 完整海图未探索区域使用同一白雾素材，柔边仍为稳定的不规则水墨轮廓。
- [x] 两处雾层都实际绑定 `white_ink_mist_v1.png`，玩家、已探索区域和地点显隐层级保持正确。
- [x] 探索揭示、跨场景恢复和正式存档数据结构不变。
- [x] `tests/test_sea_fog_of_war.gd` 通过，并完成至少一次 OpenGL 截图检查。

## Documentation impact

- Canonical documents to update before implementation: `docs/design/sea-overworld-design.md`, `docs/design/art-direction.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`
- Decisions/ADRs: 复用海战白雾素材；逻辑位图继续只表达迷雾 Alpha，不承载最终颜色。

## Implementation notes

- Likely files/modules: `scripts/sea_fog_of_war.gd`, `scripts/sea_map_screen.gd`, `shaders/sea_world_fog_edge.gdshader`, `shaders/sea_map_fog_soft_edge.gdshader`, `tests/test_sea_fog_of_war.gd`
- Constraints and risks: 白雾素材透明边缘不能形成可辨认的矩形平铺接缝；雾层须保持足够半透明，避免遮没海面方位与地图结构。

## Verification evidence

- Automated: Godot 4.7.1 .NET `--headless --editor --quit` 资源与 Shader 解析退出 0；`tests/test_sea_fog_of_war.gd` headless 退出 0，断言大地图与完整海图绑定同一白雾素材、着色器不再输出黑色遮罩，并覆盖揭示、地点显隐和跨场景恢复。
- Manual/in-engine: Godot 4.7.1 OpenGL Compatibility 以 `1344×896` 运行专项测试退出 0；检查 `.godot/sea_fog_world_preview.png`、`.godot/sea_fog_map_preview.png` 与 `.godot/sea_fog_route_preview.png`，确认大地图四周和完整海图未知区域均显示连续白色水墨雾，已探索航迹保持清晰。

## Final reconciliation

- Files changed: `scripts/sea_fog_of_war.gd`, `scripts/sea_map_screen.gd`, `shaders/sea_world_fog_edge.gdshader`, `shaders/sea_map_fog_soft_edge.gdshader`, `tests/test_sea_fog_of_war.gd`，以及本记录和四份规范/验收文档。
- Documented limitations/follow-ups: 本次仅替换探索迷雾表现；永久揭示范围、初始已知大陆、地点名称显隐、存档版本和海战实现均未改变。
