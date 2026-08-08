# CHG-20260808 海上大地图 C 区扩展

- 状态：已完成

## 目标

生成并接入第三张海上大地图分块 C 区。世界分区为二乘二结构：A 在左上、B 在右上、C 在 A 正下方、D 预留在 C 右侧；本次为 C 区四个岛屿增加碰撞、靠近提示和进入占位反馈。

## 范围

- 使用 Codex 内置生图工具，以 A、B 区为风格、比例、海水和接缝参考，生成无文字、无船只、无 UI 的 C 区背景。
- C 区固定四个主岛：澄海灯岛、龙门海寨、白沙渔岛、玄潮古屿。
- 四岛采用由西北向东南延伸的不规则折线群岛布局，不组成四角、行列或等距网格；岛距有远有近，最近的两岛之间仍保留可航行海道。
- C 区顶边与 A 区底边使用 120 世界像素的纯海水重叠带和纵向 Alpha 渐变融合。
- 将世界高度、玩家边界、相机边界和完整海图扩展到 A/B 上排与 C 下排组成的 L 形三分块。
- 将 C 区作为 `World/CBackground` 节点序列化到 `sea_overworld.tscn`，使 Godot 场景树与 2D 视图可直接显示。
- 四个地点点击或按 E 后统一显示“该岛屿即将开放”。

## 非目标

- 不制作四岛的小地图、剧情、商店、战斗或实际转场。
- 不新增船只事件、风向、洋流、补给或区域解锁。
- 不改变 A、B 区现有岛屿和场景二往返行为。

## 验收检查

1. A、B 在上排，C 在 A 正下方；A/C 接缝无空白或明显硬边。
2. 船只与相机可从 A 向南连续进入 C 区，完整海图以 L 形同时显示三张纹理，尚未开放的 D 区不可驶入。
3. C 区只有四个主岛，呈不规则折线分布，各组岛距明显不同且均保留可航行间隔。
4. 四个 C 区地点均可靠近、驶离、点击进入并显示“该岛屿即将开放”。
5. `sea_overworld.tscn` 的 `World` 下存在且仅存在一个 `CBackground`。
6. 旧地点、月相、海图、共享 HUD 和场景往返测试保持通过。

## 验证证据

- Godot OpenGL 运行验证：`Sea overworld runtime verification passed.`
- 共享探索 HUD 回归：`Exploration HUD runtime verification passed.`
- 场景二与海图往返回归：`Scene2 and sea-overworld round-trip verification passed.`
- C 区四岛两两中心距离约为 586–1330 世界像素，最近间隔仍可航行，距离差超过 500 世界像素。
- 运行截图：`.godot/sea_overworld_c_zone_preview.png`；完整海图截图：`.godot/sea_overworld_map_preview.png`。
