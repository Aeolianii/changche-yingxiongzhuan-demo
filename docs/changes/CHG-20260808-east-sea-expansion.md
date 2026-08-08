# CHG-20260808 海上大地图东部扩展

- 状态：已完成

## 目标

生成并接入海上大地图 B 区“东部海域扩展”，把现有单张海图横向扩展为两个连续分块，并为东部岛屿增加与旧地点一致的靠近、点击进入和“该岛屿即将开放”占位交互。

## 范围

- 使用 Codex 内置生图工具，以现有广东海岸海图为构图、像素密度和配色参考，生成一张无文字、无角色、无 UI 的东部海域背景。
- 东部扩展与原图保持相同最终像素规格和 `0.75` 场景缩放，西侧预留纯海水衔接带，并在场景中与原图右缘重叠融合。
- 将世界宽度、相机边界、玩家活动边界和完整海图投影扩展到两个地图分块。
- 将 B 区作为 `World/EastBackground` 正式写入 `sea_overworld.tscn`，使编辑器场景树和 2D 视图可直接显示。
- 新增红湾卫所、南澳商港和东极秘岛三个可进入地点，保持岛屿稀疏与远航留白。
- 为主要新岛屿增加手工碰撞；靠近地点显示既有底部水墨进入按钮，点击或按 E 后显示“【地点名】· 该岛屿即将开放”。

## 非目标

- 不制作地点小地图、剧情、商店、海战或实际场景切换。
- 不增加风向、洋流、补给、随机遭遇或区域解锁。
- 不改变旧海图四个地点、场景二往返入口和月相时钟行为。
- 本次不生成南部或东南扩展分块。

## 验收检查

1. 原图与东部扩展在大地图中横向连续显示，衔接处没有空白或明显硬边。
2. 玩家可从旧海域连续航行进入东部海域，相机与活动边界覆盖完整新区域。
3. 三个东部地点均出现在完整海图中，并具有靠近显示、驶离隐藏、鼠标点击和 E 键进入占位反馈。
4. 主要岛屿不可被玩家船只直接穿越，航路之间没有新增死路。
5. 原有四地点、海图、月相、任务、事件与场景二往返测试保持通过。
6. 打开 `sea_overworld.tscn` 时可在 `World` 下直接看到 `EastBackground`，运行后不会重复创建第二张 B 区节点。

## 文档影响

- `docs/design/sea-overworld-design.md`：记录双分块世界、东部地点和占位进入规则。
- `docs/design/art-direction.md`：补充分块海图的接缝与像素密度规范。
- `docs/assets/sea-overworld-generated-assets.md`：记录东部扩展素材和最终提示词。
- `docs/tech/architecture.md`：记录地图分块、世界尺寸和完整海图组合方式。
- `docs/qa/playtest.md`：增加东部扩展航行与地点交互验收。

## 可能修改文件

- `assets/backgrounds/sea_overworld/guangdong_east_sea_expansion_v1.png`
- `shaders/map_chunk_blend.gdshader`
- `scripts/sea_overworld.gd`
- `scripts/sea_overworld_player.gd`
- `scripts/sea_map_screen.gd`
- `tests/test_sea_overworld.gd`
- 上述设计、技术、QA、资产文档及本变更记录。

## 验证证据

- Godot 4.7.1 头部模式：`tests/test_sea_overworld.gd` 通过，覆盖双分块纹理、世界边界、七个地点、三个东部岛屿进入反馈和完整海图。
- Godot 4.7.1 OpenGL 图形模式：`tests/test_sea_overworld.gd` 通过，产出 `.godot/sea_overworld_east_preview.png` 与 `.godot/sea_overworld_map_preview.png` 并完成视觉检查。
- 共享 HUD 回归：`tests/test_exploration_hud.gd` 通过。
- 场景二往返回归：`tests/test_scene_two_sea_link.gd` 通过。
- 场景序列化检查：`tests/test_sea_overworld.gd` 确认 `./World/EastBackground` 存在于 `PackedSceneState`。
