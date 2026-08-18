# CHG-20260807 第一章至第二章章节过场

- Status: done
- Owner: Codex
- Updated: 2026-08-07

## 目标

把第一章皇宫领旨与第二章南疆水师之间的直接跳转改成完整的章节衔接，使玩家明确感知“领旨、南下、抵达、接令巡视”的连续过程。

## 范围

- 保留皇帝圣谕与主帅“臣领旨”回复。
- 圣旨收尾后依次展示“第一章·奉诏入殿 完”、像素水墨南下行程画面、两段旅途旁白和“第二章·南疆水师”。
- 第二章仅在由第一章进入时播放水师副将迎接对白。
- 迎接对白结束后才恢复自由探索 HUD，并把主线任务设为“巡视水师驻地”。
- “立即启程”用于跳过完成旁白的等待时间，不跳过章节过场本身。

## 非目标

- 不实现章节选择、读档、长动画或可跳过的影片播放器。
- 不改写第二章既有县令对话、NPC 交互和操练流程。
- 不新增持久化跨场景存档字段。

## 验收标准

1. 第一章完成后不再直接黑屏跳到第二章。
2. 章节题签、南下行程图、两段旁白和第二章题签按顺序出现。
3. 自动等待与点击“立即启程”只会启动一次过场。
4. 从第一章进入第二章时，玩家不能在副将迎接对白期间移动，探索 HUD 保持隐藏。
5. 迎接对白结束后，探索 HUD 显示，主线任务为“巡视水师驻地”，第一步为巡视中军楼船。
6. 第二章加载失败时仍能回到第一章完成态并点击重试。

## 文档影响

- `docs/design/scene-flow.md`
- `docs/design/palace-scene.md`
- `docs/design/art-direction.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`

## 预计改动

- 新增章节过场场景与脚本。
- 新增像素水墨南下行程背景图。
- 更新 `palace_demo.gd` 的场景切换入口。
- 更新 `Scene2.cs` 的章节入口对白与任务激活时机。
- 更新运行时与静态验证。

## 验证证据

- `dotnet build NanjiangFleet.csproj --no-restore`：0 warnings / 0 errors。
- `tests/verify_merged_project.ps1`：passed。
- `tests/test_scene_transition.gd`：自动等待与点击“立即启程”两条路径均通过；副将迎接、HUD 锁定和任务激活断言通过。
- `tests/test_scene_two_dialogue_background.gd`：passed，确认既有第二章对话 UI 未回归。
- `tests/test_chapter_transition_visual.gd`：Vulkan 渲染通过，截图为 `.godot/chapter_transition_preview.png`。
- 生成资产：`assets/ui/chapter_transition/southbound_journey.png`，1536×1024，无烘焙文字。
