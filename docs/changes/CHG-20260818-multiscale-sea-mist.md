# CHG-20260818 海图多尺度三层迷雾

- Status: complete
- Type: visual-system
- Owner: Codex
- Created: 2026-08-18

## Goal and player/project outcome

把完整海图和航行大地图中过大的重复云块改为大量中小尺度、低饱和蓝白与灰白雾团；用三层不同尺度和透明度形成自然纵深，同时保留可辨认的水墨海面并继续隐藏未知建筑。

## Scope

- 用背景、中景、细节三套世界坐标雾场替代单一 224 世界单位粗格雾场。
- 三层分别使用不同格距、哈希盐、透明度、尺寸及镜像方向，降低重复感。
- Shader 分别以灰蓝、蓝白、灰白低饱和色混合三层，保留局部透明度差异。
- 未知区域继续先绘制替代海面；雾较淡处能看到海水纹理，但不能看到真实岛屿或建筑。

## Non-goals

- 不修改探索范围、圆角视野、永久存档、地点显隐或海战迷雾。
- 不新增迷雾图片资源，继续复用战斗 `white_ink_mist_v1.png`。

## Acceptance checks

- [x] 海图由大量中小尺度雾团组成，无占据大半海图的单块云纹。
- [x] 三层尺度、颜色与位置明显不同，不出现可辨认的规则平铺和同步重复。
- [x] 各处为中低透明度并有浓淡变化，海水纹理能隐约显示。
- [x] 未探索建筑、岛屿和港口仍不能通过淡雾显现。
- [x] 大地图与完整海图共享三层世界雾场，专项测试和 OpenGL 截图通过。

## Documentation impact

- Canonical documents: `docs/design/sea-overworld-design.md`, `docs/design/art-direction.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`

## Verification evidence

- Automated: Godot 4.7.1 .NET 资源和 Shader 解析通过；`tests/test_sea_fog_of_war.gd` headless 退出 0，断言三张共享雾场、56 世界单位主格、足量中小落点、三层中低透明度、世界/海图一致、未知地形遮蔽、圆角探索和跨场景恢复。
- Manual/in-engine: OpenGL Compatibility 1344×896 实际渲染退出 0；检查 `.godot/sea_fog_map_preview.png`，确认原超大云块已替换为三层中小云团，灰蓝/蓝白/灰白层次可辨，海水纹理在云间显示，未知建筑与岛屿不透出。

## Final reconciliation

- Files changed: `scripts/sea_fog_of_war.gd`, `scripts/sea_map_screen.gd`, `shaders/sea_world_fog_edge.gdshader`, `shaders/sea_map_fog_soft_edge.gdshader`, `tests/test_sea_fog_of_war.gd`，以及本记录和四份规范/验收文档。
- Documented limitations/follow-ups: 三层仍复用同一战斗雾笔源图，但通过 84/56/40 世界单位格距、53/97/151 哈希盐、7/6/5 落点间隔和四向镜像打散；若未来增加第二张战斗雾素材，可进一步扩大轮廓差异。
