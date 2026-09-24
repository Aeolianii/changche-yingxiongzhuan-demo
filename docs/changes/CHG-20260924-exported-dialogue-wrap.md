# CHG-20260924-exported-dialogue-wrap: 发布版对话文字越界

- Status: done
- Type: fix
- Owner: Codex
- Created: 2026-09-24

## Goal and player/project outcome

Windows 发布版的皇宫长对白与 Godot 工程中的对话框保持相同的字体、底板、人物位置和安全行宽；正文完整显示在水墨底板内，不越过边缘或遮挡立绘。

## Scope

- 修复中文长句在第一章、第二章对话 Label 中的换行与可见区域。
- 检查海上大地图遇敌、随机事件、伏波守岭人及倭寇营地最终战共用的 `FieldEventDialogue` 正文和详情文字，并检查胜利过场字幕。
- 将海盗遇敌的四个难度选项与详情文字完整收进屏幕内的对话底板。
- 从 Godot 编辑器运行场景与新导出的 exe 分别截图、测量正文边界，并验证解压 ZIP 后的运行结果。
- 重新交付完整 Windows 目录和 ZIP。

## Non-goals

- 不改剧情文字、对白顺序、人物立绘、底板美术和剧情状态机。
- 不改其他界面的字号或全局字体。

## Acceptance checks

- [x] 截图中的皇帝长对白在 1344×896 下完整换行，无水平或垂直越界。
- [x] 第一章其他说话方、无立绘旁白、第二章对话、海图各类事件对白、守岭人和最终战胜利字幕仍位于各自安全区。
- [x] 海盗四档难度选项和详情不将对话底板顶出屏幕。
- [x] 新导出 exe 与工程在同一对白、分辨率下布局一致，解压 ZIP 可运行。

## Documentation impact

- Canonical documents: `docs/design/palace-scene.md`、`docs/design/sea-overworld-design.md`、`docs/qa/playtest.md`。
- Decisions/ADRs: 无。

## Implementation notes

- Likely files: `scenes/palace/palace_demo.tscn`、`scripts/palace_demo.gd`、第二章对话场景/脚本、`FieldEventDialogue` 场景/脚本、导出检查脚本、发布包。
- Risk: 仅靠编辑器静态场景检查不能证明发布版换行行为；必须运行新 exe 并检查实际渲染。
- Verification-driven decision: 智能按词换行虽解决水平越界，但茶商对白在工程与 exe 中分别占 3 行和 2 行；对话正文改用固定字符边界换行并固定最大宽度，以保证发布版与工程版断行一致。

## Verification evidence

- Automated: Godot 4.7.1 .NET 工程和 Windows 导出版各执行 `--smoke-dialogue-export`；第一章 5 段、第二章 5 段、海图及 Boss 对话 16 段、Boss 胜利字幕 5 段通过。47 条行数、可见行数、文字边界、面板及选项边界记录逐条一致；导出版海战布阵 smoke 通过。ZIP 解压后再执行两项 smoke，退出码均为 0，标准错误为空。
- Visual: 工程和导出版在 1344×896 下分别截图；检查皇帝长对白、海盗四档选项、茶商对白和 Boss 答话均在水墨底板内，正文未压到人物立绘。

## Final reconciliation

- Files changed: 两章对话场景及脚本、海图共用事件对话场景及脚本、发布版布局 smoke、设计与 QA 文档；完整 Windows 目录及 ZIP 交付在 `发布包/厂车英雄传DEMO-Windows-20260924-dialogue-fixed`。
- Limitations/follow-ups: 本轮布局对照分辨率为 1344×896。旧版 `发布包/厂车英雄传DEMO-Windows-20260924` 的 exe 仍在运行，目录被占用，因此保留旧目录；玩家应使用名称含 `dialogue-fixed` 的新版目录或 ZIP。
