# CHG-20260810 完整海图迷雾不规则边缘

- 状态：done
- 类型：海图探索 / 视觉优化
- 日期：2026-08-10

## 目标

在现有圆润柔边基础上加入稳定的低频水墨扰动，让完整海图的已探索轮廓呈现轻微凹凸和错落，进一步消除矩形拼块感，同时确保玩家航行视野仍完整点亮。

## 范围

- 只修改完整海图专用 `sea_map_fog_soft_edge.gdshader` 的显示效果。
- 使用确定性的多尺度低频噪声轻微扭曲采样位置和边缘阈值；相同探索数据每次显示形状一致，不闪烁。
- 扰动只作用于黑白交界区域，已探索内部保持清晰，未探索内部保持黑色。
- 世界迷雾、探索位图、地点判定与存档格式保持不变。

## 验收检查

1. 完整海图探索边缘除圆角外还有自然的轻微凹凸，不再像规则矩形。
2. 边缘不出现逐帧闪烁、孤立透明噪点或大片半透明污迹。
3. 航行画面当前相机视野仍然全部明亮。
4. 远端未探索地点继续隐藏，存档恢复后的探索状态不变。

## 预计文件

- `shaders/sea_map_fog_soft_edge.gdshader`
- `scripts/sea_map_screen.gd`
- `tests/test_sea_fog_of_war.gd`
- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`

## 验证证据

- 自动验证：`tests/test_sea_fog_of_war.gd` 在 Godot 4.7.1 headless 与 OpenGL Compatibility 模式均退出 0；断言确认海图启用至少 `4` 个迷雾纹理单元的采样扭曲和 `0.3` 的边缘噪声强度，而世界迷雾仍不使用该材质。
- 视觉验证：`.godot/sea_fog_map_preview.png` 原始分辨率复核确认长直边已产生稳定的凹凸、错落和大小不同的圆润转折，内部没有透明孔洞；`.godot/sea_fog_world_preview.png` 确认玩家视野继续全亮。
- 持久化边界：探索位图和存档字段没有变更，地点标签继续按原始位集合显隐。
