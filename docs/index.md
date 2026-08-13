# Project documents

## Project type and tool boundary

- 本项目是 **Godot 4.7.1 .NET 游戏项目**，规范入口为根目录 `project.godot`，运行与验证使用 Godot .NET 4.7.1。
- 本项目不是离线 H5、互动空间作品或单页 Web 项目，不以 `index.html` / `.zip` 作为交付物。
- 项目开发、场景接入、资源处理、测试和打包均不得调用或套用 `interact-creation` skill；应按 Godot、GDScript、C#、`.tscn` 和项目内测试规范处理。

## Current focus

- Milestone: 场景一至场景二连续可玩原型
- Current playable goal: 从标题界面开始，可继续正式存档或开始新游戏；新游戏从场景一“皇帝召见水师主帅”开始，完成圣旨收尾后自动进入场景二“南疆水师”。
- Top risk: 两个原型合并后必须在 Godot 4.7.1 中持续通过资源加载、GDScript 解析和场景切换验证。
- Fubo art target: 伏波古岭已采用用户选定的一张完整明朗岭南像素背景、红线闭合活动边界和两个地点触发小游戏；四板拼接与环境逐件模块化方案已废止。

## Source of truth

- [Vision](product/vision.md)
- [MVP](product/mvp.md)
- [Project plan](product/project-plan.md)
- [Core loop](design/core-loop.md)
- [Game design V1](design/game-design-v1.md)
- [Equipment and item list V1](design/equipment-items-v1.md)
- [Sea overworld design](design/sea-overworld-design.md)
- [伏波古岭探索切片](design/fubo-guling-slice.md)
- [伏波古岭接入海上大地图设计](specs/2026-08-11-fubo-sea-overworld-integration-design.md)
- [全局探索 UI 与伏波古岭正式存档设计](specs/2026-08-11-global-exploration-ui-fubo-save-design.md)
- [Palace scene](design/palace-scene.md)
- [Scene flow](design/scene-flow.md)
- [Art direction](design/art-direction.md)
- [Art asset requirements (Word)](assets/厂东英雄传-美术素材需求书.docx)
- [Character assets](assets/character-assets.md)
- [Generated backgrounds](assets/generated-backgrounds.md)
- [Sea overworld generated assets](assets/sea-overworld-generated-assets.md)
- [Sea overworld stage-one layout graybox](assets/sea-overworld-stage1-layout.md)
- [伏波古岭生成素材清单](assets/fubo-guling-generated-assets.md)
- [Architecture](tech/architecture.md)
- [Backlog](production/backlog.md)
- [Playtest](qa/playtest.md)
- [Changes](changes/)

Add links here when new canonical documents are introduced.
