# CHG-20260721 Scene2 对话底板替换

- Status: approved
- Type: content
- Owner: Codex
- Created: 2026-07-21

## Goal and player/project outcome

将场景二对话区域原有的程序生成米黄色长方形底板替换为现有 Paper UI 素材 `BackgroundBar.png`，提高 UI 美术一致性，同时保持玩家已经熟悉的立绘、名牌、选项和正文布局。

## Scope

- 场景二全宽对话底板使用 `res://assest/Paper UI/PNGs/Backgrounds/BackgroundBar.png`。
- 图片直接铺满现有 `1344×190` 对话底板区域，接受由 592×224 原图产生的横向拉伸。
- 保留现有 `FullWidthPaperDialogueBox` 尺寸、层级和所有子节点。
- 保留四周黑色长条、人物名牌、立绘、占位立绘、正文、继续按钮和选项 UI 的位置与尺寸。

## Non-goals

- 不调整立绘位置、裁切方式或尺寸。
- 不修改对话正文、选项内容、按钮样式和交互逻辑。
- 不采用九宫格、切片拼接或重新绘制背景素材。
- 不修改场景一对话框。

## Acceptance checks

- [ ] 场景二对话底板实际使用 `BackgroundBar.png`，不再绘制原米黄色 `StyleBoxFlat`。
- [ ] 底板仍占据 `x=0..1344`、`y=706..896`，正文和选项布局不变。
- [ ] 左右立绘的位置、大小和切换逻辑不变。
- [ ] 黑色长条、人物名牌和选项按钮样式不变。
- [ ] 县令 NPC 对话与场景二主线对话均正常显示。
- [ ] 场景一至场景二自动切换继续通过。

## Documentation impact

- Canonical documents to update before implementation: `docs/design/art-direction.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`
- Decisions/ADRs: none

## Implementation notes

- Likely files/modules: `scripts/Scene2.cs`, `tests/test_scene_two_dialogue_background.gd`, `tests/verify_merged_project.ps1`
- Constraints and risks: 原图与目标区域宽高比不同，方案 A 明确允许整体拉伸；必须保留现有容器内容边距，避免正文产生数像素位移。

## Verification evidence

- Automated: not run
- Manual/in-engine: not run

## Final reconciliation

- Files changed: pending
- Documented limitations/follow-ups: 整图横向拉伸是本次已接受的视觉取舍。
