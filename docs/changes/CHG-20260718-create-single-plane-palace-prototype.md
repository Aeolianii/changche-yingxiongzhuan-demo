# CHG-20260718-create-single-plane-palace-prototype

- Status: done
- Type: architecture + feature + content
- Owner: Codex
- Created: 2026-07-18

## Goal and player/project outcome

建立独立于旧版的新 Godot 原型，完整实现场景一“皇帝召见水师主帅”：急报旁白、太监传召、共同入殿、君臣对白和圣旨收尾。

## Scope

- 创建新 Godot 4.7 项目。
- 生成一张与 64×64 LPC 角色兼容、同时显示正殿室内与殿外庭院的剖顶宫殿背景。
- 仅导入首版需要的角色帧和授权文件。
- 实现移动、动画、相机、手工碰撞、NPC 剧情移动、可点击交互按钮、正式对白和旁白。

## Non-goals

- 不修改或迁移旧项目。
- 不实现楼层、高度、悬崖、TileMap、建筑内部或战斗。

## Acceptance checks

- [x] 背景视角和比例与角色匹配。
- [x] 主角四方向移动与待机动画正常。
- [x] 所有阻挡区域可在 Godot 编辑器中直接调整。
- [x] 装饰不产生卡脚碰撞。
- [x] 可完成“对话”和“觐见”两次点击交互。
- [x] 场景一从三份急报到圣旨收尾可完整走通。
- [x] 指定场景运行无错误并有运行截图。

## Documentation impact

- 已更新产品、设计、美术、素材、技术、生产和 QA 文档。
- 不需要 ADR；单平面方案是当前原型的固定范围。

## Implementation notes

- 背景目标尺寸约 1536×1024，运行窗口 1280×720。
- 首版角色资源仅包含 idle、walk 与被引用的 UI。
- 碰撞采用手工 `CollisionPolygon2D`，不得自动猜测生成图语义。
- UI 使用 `CanvasLayer/UI -> Overlay` 结构，保证对话框不受相机移动影响。
- 用户补充后，v1 纯室外背景降为参考资产；实际场景改用剖顶宫殿 v2。
- 县令素材暂代皇帝，士兵素材暂代太监。

## Verification evidence

- Automated: 通过 Godot 运行态读取验证剧情状态 0→8；完成时主帅位于 `(768,350)`，太监位于 `(690,350)`。
- Manual/in-engine: run 4 完整点击流程通过；左墙停在 x≈67，宫墙停在 y≈625，中央门洞可进入 y≈422；游戏日志仅有 MCP helper 注册信息，无当前运行错误。

## Final reconciliation

- Files changed: `project.godot`、`assets/backgrounds/`、`assets/characters/`、`assets/ui/`、`scenes/characters/`、`scenes/palace/`、`scripts/` 和本变更涉及的项目文档。
- Documented limitations/follow-ups: 皇帝使用县令素材、太监使用士兵素材、圣旨正文为占位；战斗画面与场景二不在本次范围。
