# CHG-20260721 Scene2 对话底板替换

- Status: approved
- Type: content
- Owner: Codex
- Created: 2026-07-21

## Goal and player/project outcome

将场景二对话区域原有的程序生成米黄色长方形底板替换为现有 Paper UI 素材 `BackgroundBar.png`，提高 UI 美术一致性，同时保持玩家已经熟悉的立绘、名牌、选项和正文布局。

## Scope

- 场景二全宽对话底板使用 `res://assest/Paper UI/PNGs/Backgrounds/BackgroundBar.png`。
- 使用用户重新裁剪后的 512×144 `BackgroundBar.png`，直接整图铺满现有 `1344×190` 对话底板区域，不设置二次裁剪区域。
- 只将黑色描边外侧、与画布四角相连的白色底变为透明；黑色描边和描边内的米白纸张保持完全不透明。
- 保留现有 `FullWidthPaperDialogueBox` 尺寸、层级和所有子节点。
- 保留四周黑色长条、人物名牌、立绘、占位立绘、正文、继续按钮和选项 UI 的位置与尺寸。

## Non-goals

- 不调整立绘位置、裁切方式或尺寸。
- 不修改对话正文、选项内容、按钮样式和交互逻辑。
- 不采用九宫格、切片拼接或额外纹理区域裁剪。
- 不把黑色描边内部的米白纸张改成透明。
- 不修改场景一对话框。

## Acceptance checks

- [x] 场景二对话底板实际使用 `BackgroundBar.png`，不再绘制原米黄色 `StyleBoxFlat`。
- [ ] 可见纸张边框覆盖完整的 `x=0..1344`、`y=706..896` 底部区域，不再因透明留白缩在中间。
- [ ] 黑色描边外侧为透明并显示游戏背景，描边和框内米白纸张保持不透明。
- [x] 底板仍占据 `x=0..1344`、`y=706..896`，正文和选项布局不变。
- [x] 左右立绘的位置、大小和切换逻辑不变。
- [x] 黑色长条、人物名牌和选项按钮样式不变。
- [x] 县令 NPC 对话与场景二主线对话均正常显示。
- [x] 场景一至场景二自动切换继续通过。

## Documentation impact

- Canonical documents to update before implementation: `docs/design/art-direction.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`
- Decisions/ADRs: none

## Implementation notes

- Likely files/modules: `scripts/Scene2.cs`, `tests/test_scene_two_dialogue_background.gd`, `tests/verify_merged_project.ps1`
- Constraints and risks: 512×144 新图与目标区域宽高比不同，方案 A 明确允许整体拉伸；必须保留现有容器内容边距，避免正文产生数像素位移。

## Verification evidence

- Automated RED: 静态测试在实现前报告目标图片路径、`StyleBoxTexture` 和旧米黄色样式共 3 项失败；Scene2 运行态测试确认对话容器仍为 `StyleBoxFlat` 并以 exit 1 结束。
- Automated GREEN: Godot .NET 4.7.1 导入 exit 0；静态合并测试、Scene2 对话底板运行态测试、Scene1 立绘测试和跨场景切换测试全部通过；Scene2 120 帧启动冒烟测试 exit 0；`dotnet build` 为 0 warning / 0 error。
- Manual/in-engine: 使用 1344×896 OpenGL Compatibility 实际渲染 Scene2 对话画面，确认 `BackgroundBar.png` 的透明边缘、纸张缺口和描边正常，立绘、黑色名牌、正文和继续按钮保持既有位置。
- Revision pending: 512×144 新图的外侧白底需要透明化；透明候选图已验证四角 Alpha=0、黑框与框内纸张 Alpha=255，尚待替换项目资源并在 Godot 中复验。

## Final reconciliation

- Files changed: pending revision reconciliation
- Documented limitations/follow-ups: 新裁剪图片的横向拉伸是本次已接受的视觉取舍。
