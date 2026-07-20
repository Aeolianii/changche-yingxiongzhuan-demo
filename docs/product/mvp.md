# MVP contract

- Status: approved
- Target build/date: 2026-07

## Question this prototype answers

单层俯视场景能否以更低复杂度承载皇宫氛围、移动探索和剧情交互？

## Playable path

1. 阅读岭南急报开场旁白。
2. 太监自动从殿内走到殿外水师主帅身边。
3. 点击“对话”，太监与主帅一起进入正殿。
4. 点击“觐见”，播放皇帝与水师主帅对白。
5. 阅读圣旨旁白并完成场景。

## In scope

- 一张单层皇宫庭院地图。
- 主角四方向待机与行走动画。
- 县令素材暂代皇帝，士兵素材暂代太监。
- 相机跟随、宫殿内外边界碰撞、NPC 自动寻路式直线引导。
- 开场旁白、两处交互按钮、正式觐见对白和圣旨收尾。

## Explicitly out of scope

- 楼层、高度状态、悬崖、斜坡和上下层切换。
- 建筑内部、战斗、任务、存档、经济和 AI Agent。
- 可编辑 TileMap 地形。

## Done when

- [ ] A new player can finish the playable path without developer help.
- [ ] The build has no known progress-blocking defect.
- [ ] The core hypothesis has a recorded playtest result.
- [ ] 从开场旁白到圣旨收尾可以完整走通，不穿墙、不隐身、不被装饰卡脚。

## Risks and shortcuts

- 背景采用生成图片，首版不要求可瓦片化。
- 背景改为剖顶式单平面宫殿；室内和室外是同一物理平面，仅由墙体和门洞限制。
