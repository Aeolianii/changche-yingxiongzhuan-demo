# CHG-20260810 完整海图迷雾圆润边缘

- 状态：done
- 类型：海图探索 / 视觉优化
- 日期：2026-08-10

## 目标

保留玩家航行画面“当前视野内全部点亮”的完整矩形揭示，同时弱化完整海图上的直角拼块感，使已探索区域边缘呈现轻微圆润、柔和的过渡。

## 范围

- 探索位图、存档格式、揭示矩形和世界迷雾遮罩保持不变。
- 仅给 `SeaMapScreen` 的 `FogLayer` 添加海图专用边缘平滑材质。
- 材质对迷雾 Alpha 做小范围邻域采样，让直角转折圆润并产生窄幅柔边；不扩大地点解锁判断范围。
- 地点名称显隐继续查询原始探索位图，不受视觉后处理影响。

## 验收检查

1. 航行画面中玩家当前相机视野四角和边缘全部明亮。
2. 完整海图的已探索边缘不再是生硬直角，转折处有轻微圆润和柔和过渡。
3. 远端未探索海域仍保持黑色，地点名称不会因为柔边提前显示。
4. 返回场景、保存读取后探索范围和圆润显示均保持一致。

## 预计文件

- `shaders/sea_map_fog_soft_edge.gdshader`
- `scripts/sea_map_screen.gd`
- `tests/test_sea_fog_of_war.gd`
- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`

## 验证证据

- 自动验证：`tests/test_sea_fog_of_war.gd` 在 Godot 4.7.1 headless 与 OpenGL Compatibility 模式均退出 0；断言确认世界迷雾不使用柔边材质、完整海图独占 `sea_map_fog_soft_edge.gdshader`。
- 视觉验证：`.godot/sea_fog_map_preview.png` 原始分辨率复核确认相邻矩形探索区的外角和台阶转折已圆润并带窄幅柔边；`.godot/sea_fog_world_preview.png` 确认玩家当前屏幕仍完整明亮。
- 行为边界：地点标签继续依据原始位图查询，远端未探索地点保持隐藏，存档数据结构未改动。
