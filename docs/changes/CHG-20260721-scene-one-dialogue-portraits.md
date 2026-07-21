# CHG-20260721 Scene1 对话人物立绘

- Status: approved
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

- [ ] 两张 600×600 `picture.png` 均能被 Godot 导入并由场景一加载。
- [ ] 内侍传召时右侧显示士兵立绘，名牌显示“内侍”。
- [ ] 皇帝宣旨时右侧显示“帝”字占位卡，名牌显示“皇帝”。
- [ ] 水师主帅回复时左侧显示将军立绘，名牌显示“水师主帅”。
- [ ] 开场旁白、圣旨、完成旁白和错误提示均隐藏立绘及名牌。
- [ ] 关闭对话后立绘不会残留。
- [ ] 原有空格推进、鼠标点击和场景一至场景二切换测试继续通过。

## Documentation impact

- Canonical documents to update before implementation: `docs/design/palace-scene.md`, `docs/assets/character-assets.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`
- Decisions/ADRs: none

## Implementation notes

- Likely files/modules: `assets/characters/*/picture.png`, `scenes/palace/palace_demo.tscn`, `scripts/palace_demo.gd`, `tests/verify_merged_project.ps1`, `tests/test_scene_portraits.gd`
- Constraints and risks: 立绘需要在 1344×896 窗口下避开正文与继续按钮；透明图片缩放时应保持宽高比；旁白与角色对白必须显式切换显示状态。

## Verification evidence

- Automated: not run
- Manual/in-engine: not run

## Final reconciliation

- Files changed: pending
- Documented limitations/follow-ups: 正式皇帝立绘仍待补充。
