# CHG-20260808 C 区左侧疏散布局

- 状态：已完成

## 目标

重新生成 C 南部海域，使四座大型岛屿整体位于地图左侧，并将右侧两岛与左侧两岛横向拉开，形成宽阔、可航行且视觉明确的纵向海峡；最右侧继续作为未来 D 区接口。

## 范围

- 使用内置生图工具编辑 C 区背景，保持四座岛屿身份、项目既有像素水墨风格和 A/C 顶部纯海水接缝。
- 左侧保留澄海灯岛与白沙渔岛，右侧放置龙门海寨与玄潮古屿；两组之间保留宽海峡。
- 更新四个地点坐标、岛屿碰撞、完整海图纹理及 `sea_overworld.tscn` 的编辑器可见背景节点。
- 四个地点继续使用“该岛屿即将开放”占位反馈。

## 验收

1. C 区只包含四座大型岛屿，无额外礁石、小岛、文字或 UI。
2. 左右两组岛屿之间有明显宽海峡，四岛间均可航行且间距不完全相同。
3. 顶部接缝为纯海水，最右侧保留开阔海面。
4. Godot 运行场景和完整海图均显示新版 C 区。
5. 四个地点均可触发“该岛屿即将开放”。

## 验证证据

- Godot OpenGL 运行验证：`Sea overworld runtime verification passed.`
- 共享探索 HUD 回归：`Exploration HUD runtime verification passed.`
- 场景二与海图往返回归：`Scene2 and sea-overworld round-trip verification passed.`
- 左侧岛组 X 坐标均小于 600，右侧岛组 X 坐标均大于 1400；两组中心横向间隔超过 900 世界像素。
- 运行截图：`.godot/sea_overworld_c_zone_preview.png`；完整海图截图：`.godot/sea_overworld_map_preview.png`。
