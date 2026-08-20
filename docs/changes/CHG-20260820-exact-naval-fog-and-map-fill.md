# CHG-20260820 完整复用战斗雾与海图满框

- Status: complete
- Type: architecture-and-layout
- Owner: Codex
- Created: 2026-08-20

## Goal and player/project outcome

海域探索雾不再使用放大的粗格近似，而是逐项复用战斗雾的 26 像素格、隐藏邻居、哈希落点、尺寸、偏移、色调和透明度逻辑；完整海图同时纵向铺满内框，去除上下留白。

## Scope

- 航行表现格改为 26 世界单位，海图表现格改为 26 海图像素；两处均按实时探索状态判断隐藏格和九宫格隐藏邻居。
- 完整复用 `Hash01(x,y,53)`、`seed % 4`、4.4–5.5 格宽、0.6875 高宽比、固定偏移、0.38 Alpha 和边缘 0.76 衰减。
- 探索状态变化后重建航行与海图原生雾笔场，使雾笔中心揭示后的移除行为与战斗一致。
- 海图内容、迷雾、地点和玩家坐标使用非等比映射铺满 870×510 内框。

## Non-goals

- 不修改战斗 `DrawFog()`、战斗素材、探索范围、存档或真实地图资源。
- 不改变外层卷轴框和按钮布局。

## Acceptance checks

- [x] 海域雾的格距、哈希、稀疏条件、尺寸、偏移、色调、Alpha 和邻居衰减与战斗一致。
- [x] 雾团为战斗尺度的独立中小雾笔，不再挤成少数超大云块。
- [x] 揭示后以实时隐藏状态重建雾笔，边缘邻居逻辑与战斗一致。
- [x] 海图内容上下铺满 870×510 内框，无额外留白，地点与玩家坐标同步。
- [x] 未知建筑仍隐藏，专项测试和 OpenGL 截图验证通过。

## Documentation impact

- Canonical documents: `docs/design/sea-overworld-design.md`, `docs/design/art-direction.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`

## Verification evidence

- Automated: Godot 4.7.1 .NET 资源与 Shader 解析退出 0；`tests/test_sea_fog_of_war.gd` headless 退出 0，断言世界 26 单位格、海图原生 870×510/26 像素格、独立纹理绑定、战斗素材内置 Tint/Alpha、实时隐藏邻居、海图满框、未知地形遮蔽、圆角探索和跨场景恢复。
- Manual/in-engine: OpenGL Compatibility 1344×896 退出 0；检查 `.godot/sea_fog_stamp_preview.png`，海图原生雾场保留战斗雾的飞白、孔洞和中小雾笔边缘；检查 `.godot/sea_fog_map_preview.png`，地图从内框顶边铺至底边，无上下留白，地点、玩家、雾与地图对齐。

## Final reconciliation

- Files changed: `scripts/sea_fog_of_war.gd`, `scripts/sea_map_screen.gd`, 两个探索迷雾 Shader、`tests/test_sea_fog_of_war.gd`，以及本记录和四份规范/验收文档。
- Documented limitations/follow-ups: 完整海图为填满 870×510 内框而做轻微非等比纵向拉伸；所有地图层和坐标使用同一缩放，因此不产生交互错位。雾笔重建只在探索位图实际变化时发生，两个材质持续复用原 `ImageTexture` 实例。
