# CHG-20260820 精细替代海面与战斗雾覆盖

- Status: complete
- Type: visual-system
- Owner: Codex
- Created: 2026-08-20

## Goal and player/project outcome

为未知海域提供一张细密、没有岛屿或建筑的替代海面，并继续用战斗白色水墨雾笔覆盖；替代层沿用大地图原有青蓝海色，只从新素材提取精细亮纹与水流，既不产生色块接缝，也不会提前暴露真实地形。

## Scope

- 新增高分辨率水墨像素替代海面，增加细小亮纹、暗流和短碎波线。
- 替代海面按完整世界 UV 采样，不重复平铺；以大地图青蓝海色为基准，用生成素材亮度调制细纹。
- 航行大地图和完整海图继续共享战斗 `white_ink_mist_v1.png` 预合成雾笔场。
- 降低雾层总强度，使替代海面的细纹能透过雾层辨认。

## Non-goals

- 不修改探索范围、圆角视野、存档、真实地图或战斗迷雾本身。
- 不允许替代海面出现岛屿、建筑、船只、海岸或地标。

## Acceptance checks

- [x] 未知区域的替代海面有细密亮纹、暗纹和方向变化，无明显大块重复。
- [x] 战斗雾笔仍覆盖替代海面，并保留飞白、浓淡与局部海面可见度。
- [x] 替代海面沿用大地图青蓝海色，探索边缘无灰蓝拼接带；雾色保持蓝白、灰白。
- [x] 未知建筑、岛屿和港口仍完全隐藏，探亮后真实地图正常显示。
- [x] 大地图、完整海图、专项测试和 OpenGL 截图验证通过。

## Documentation impact

- Canonical documents: `docs/design/sea-overworld-design.md`, `docs/design/art-direction.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`

## Verification evidence

- Automated: Godot 4.7.1 .NET 资源导入和 Shader 解析完成；`tests/test_sea_fog_of_war.gd` headless 退出 0，断言两处共享新替代海面、使用完整世界 UV、保持大地图青蓝基准色、战斗雾低于 0.9 强度，并继续覆盖未知建筑、圆角探索和跨场景恢复。
- Manual/in-engine: 检查生成的 1536×1024 资源，确认仅含细亮纹、暗流和水墨海面，无岛屿/建筑/船只；OpenGL Compatibility 1344×896 实际渲染退出 0，检查 `.godot/sea_fog_map_preview.png` 与世界截图，探索边缘保持同一青蓝色相，雾下细纹可辨，未知地形未透出。

## Final reconciliation

- Files changed: `assets/textures/water/sea_concealment_ink_pixel_v1.png`、对应 Godot 导入配置、两个探索迷雾脚本与 Shader、专项测试，以及本记录和四份规范/验收文档。
- Documented limitations/follow-ups: 替代海面的基准色当前显式绑定为 `Color(0.05, 0.56, 0.68)`；若以后调整大地图海水主色，应同步更新世界与海图迷雾材质参数。
