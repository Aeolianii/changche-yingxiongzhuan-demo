# CHG-20260721 Scene1 对话人物立绘

- Status: done
- Type: feature
- Owner: Codex
- Created: 2026-07-21

## Goal and player/project outcome

为场景一的角色对白补充人物立绘和名牌，让玩家能立即辨认当前说话者；旁白与圣旨继续保持纯文字，避免无角色内容误用立绘。

## Scope

- 保留场景一现有底部羊皮纸对话框。
- 新增位于对话框左右两侧的单人物立绘区域和人物名牌。
- 内侍对白使用 `assets/characters/soldier/picture.png`，显示在右侧。
- 水师主帅对白使用 `assets/characters/protagonist/picture.png`，显示在左侧。
- 皇帝对白暂用右侧暗红金边占位卡，并显示“帝”字。
- 旁白、圣旨、场景加载失败提示不显示人物立绘或名牌。
- 对话关闭时同时隐藏立绘，避免立绘残留在自由移动阶段。

## Non-goals

- 不生成或绘制正式皇帝立绘。
- 不修改人物对白内容、剧情状态顺序或场景切换计时。
- 不重构场景二 C# 对话系统，也不抽取跨语言通用组件。
- 不替换场景世界中的皇帝、太监角色小人素材。

## Acceptance checks

- [x] 两张 600×600 `picture.png` 均能被 Godot 导入并由场景一加载。
- [x] 内侍传召时右侧显示士兵立绘，名牌显示“内侍”。
- [x] 皇帝宣旨时右侧显示“帝”字占位卡，名牌显示“皇帝”。
- [x] 水师主帅回复时左侧显示将军立绘，名牌显示“水师主帅”。
- [x] 开场旁白、圣旨、完成旁白和错误提示均隐藏立绘及名牌。
- [x] 关闭对话后立绘不会残留。
- [x] 原有空格推进、鼠标点击和场景一至场景二切换测试继续通过。

## Documentation impact

- Canonical documents to update before implementation: `docs/design/palace-scene.md`, `docs/assets/character-assets.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`
- Decisions/ADRs: none

## Implementation notes

- Likely files/modules: `assets/characters/*/picture.png`, `scenes/palace/palace_demo.tscn`, `scripts/palace_demo.gd`, `tests/verify_merged_project.ps1`, `tests/test_scene_portraits.gd`
- Constraints and risks: 立绘需要在 1344×896 窗口下避开正文与继续按钮；透明图片缩放时应保持宽高比；旁白与角色对白必须显式切换显示状态。

## Verification evidence

- Automated RED: `tests/verify_merged_project.ps1` 在实现前按预期报告 11 项缺失立绘契约；`tests/test_scene_portraits.gd` 报告立绘节点不完整并以 exit 1 结束。
- Automated GREEN: Godot .NET 4.7.1 素材导入 exit 0；静态合并测试通过；立绘运行态测试通过；场景切换运行态测试通过；Scene1 120 帧启动冒烟测试 exit 0；`dotnet build` 为 0 warning / 0 error。
- Manual/in-engine: 使用 1344×896 OpenGL Compatibility 实际渲染内侍、皇帝和水师主帅画面；两张正式长对白均完整换行，立绘、名牌、正文和继续按钮没有互相遮挡。

## Final reconciliation

- Files changed: 两张 `assets/characters/*/picture.png`、`scenes/palace/palace_demo.tscn`、`scripts/palace_demo.gd`、静态与运行态测试，以及本变更涉及的设计、素材、架构和 QA 文档。
- Documented limitations/follow-ups: 正式皇帝立绘仍待补充；场景世界中的皇帝和内侍小人继续沿用既有占位素材。
