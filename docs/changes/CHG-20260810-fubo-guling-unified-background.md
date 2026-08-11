# CHG-20260810-fubo-guling-unified-background

- Status: in-progress
- Type: art correction / scene composition
- Owner: Project owner
- Created: 2026-08-10

## Problem

上一轮把多张生成素材表拆成道路、地砖、建筑和植被模块后直接铺入场景。虽然节点、碰撞、Y 排序和玩法均有效，但各模块的比例、透视、边缘和留白不统一，玩家看到的是明显的素材拼贴，缺少完整岛屿场景感。

## Goal and player-visible outcome

改成“一张统一大场景底图 + 少量独立交互/遮挡物”的混合方案。底图统一海岸、地表、山路、院落、古渠基座、校场和观景台的构图，并强化岭南古代军镇而非通用东亚幻想风格；水闸、水池水态、军鼓、号旗、路障、NPC、关键建筑遮挡和树冠仍作为独立节点。

## Scope

- Visual target is bright, fresh Chinese pixel art: light grey brick, blue-grey tile, warm pale-earth roads, fresh spring green, and clear turquoise water. Use low-to-medium contrast, short soft shadows, simple readable shapes, and restrained texture noise.
- Reject dark realistic rendering, heavy weathering, dense micro-detail, dramatic cinematic lighting, and miniature-island diorama composition.

- 通过 Godot MCP 导出隐藏角色、模块和 UI 后的全地图布局参考。
- 用生图模型按该布局生成统一的 2600×1500 视觉底图，并在项目内按最近邻方式使用。
- 删除或隐藏上一轮造成拼贴感的重复道路、地砖和草地贴花。
- 只保留玩法相关小物件、需要 Y 排序的建筑/树木和动态效果。
- 视觉元素以灰砖镬耳山墙、黛瓦硬山屋、石牌门、夯土山路、层叠石阶、古渠石槽、榕树/荔枝林、海防烽燧和朱红军旗为核心。
- 底图表现岛上的广阔局部而非一眼可见的完整岛屿轮廓；陆地占据画面主体，海只在南岸和东北崖边露出，以避免微缩沙盘感。
- 比例以 64×64 角色为锚：主要建筑约 4—5 个角色身宽，普通树冠约 1.5—2 个角色宽，交互机关不得超过主要建筑的视觉权重。
- 减少密集植被和岩石细节，边缘成片、中部留白；扩大道路、院落和各区域之间的步行距离。
- 对大底图与现有碰撞、任务锚点进行运行截图校准。

## Non-goals

- 不改变地图坐标、玩法规则、剧情阶段、相机范围或默认标题入口。
- 不从大底图自动生成碰撞。
- 不把动态水流、旗帜高亮、互动标记或角色烘焙进底图。

## Acceptance checks

- [ ] 全屏截图首先读作一张连续岭南海岛地图，而不是离散素材拼贴。
- [ ] 正常 1344×896 镜头不能同时看清整座岛的完整轮廓；画面具有多屏探索尺度而非微缩沙盘感。
- [ ] 建筑、树木和机关与 64×64 角色比例协调，主要建筑约 4—5 个角色身宽，常规植被不压过建筑。
- [ ] 海岸、山路、守备院、古渠、校场和观景台在同一视角、像素密度、光照与配色下连续衔接。
- [ ] 画面具有明确中式岭南军镇辨识度，不出现日式神社、东南亚寺庙、热带度假岛或通用奇幻村落的主导特征。
- [ ] 底图不包含人物、文字、UI、水闸方向、水流、军鼓、号旗或路障。
- [ ] 建筑、树冠、NPC和玩法物件仍可独立排序、隐藏、开关或高亮。
- [ ] 原有 17 个碰撞/触发形状、两项小游戏和完成重开流程保持有效。
- [ ] Godot MCP 运行截图和日志检查通过，13 个项目测试继续通过。

## Likely files

- `assets/fubo_guling/generated/unified/`
- `scenes/fubo_guling/fubo_guling.tscn`
- `scripts/fubo_guling/fubo_placeholder_world.gd`
- `docs/assets/fubo-guling-generated-assets.md`

## Verification evidence

- Pending.

## Final reconciliation

- Pending.
