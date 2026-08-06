# CHG-20260806 探索 HUD

- Status: done
- Date: 2026-08-06

## Goal

为场景一和场景二增加一套参考用户截图布局、但不复用截图背景和内容的东方武侠风探索 HUD，帮助玩家在自由移动阶段识别主角、任务和四个未来功能入口。

## Scope

- 新增可复用的探索 HUD 场景与脚本。
- 左上显示水师主帅头像，不显示尚未确定的生命、资源等状态。
- 左侧任务栏同时展示主线和支线，以占位人物徽记和示例任务文案表达最终效果。
- 右上提供“菜单”“物品栏”“船只”“人物”四个具名按钮。
- 点击任一功能按钮时显示“功能即将开放”轻提示。
- 场景一与场景二仅在玩家可自由移动且没有对白、操练演示或过场切换时显示 HUD。
- 保留现有世界画面、角色、对话框、交互按钮和剧情流程。

## Non-goals

- 不实现菜单、背包、船只或人物系统。
- 不确定或展示生命、气力、等级、货币等角色状态。
- 不把参考截图中的背景、角色、钓鱼面板和视觉特效带入项目。
- 不改动任务数据持久化或存档结构。

## Acceptance checks

- 自由移动阶段可同时看到主角头像、主线/支线任务栏和四个功能按钮。
- 对话、开场旁白、操练演示和场景淡出期间探索 HUD 不可见。
- 四个功能按钮均显示名称，点击后出现“功能即将开放”提示并自动消失。
- 1344×896 基准分辨率下 HUD 不遮挡底部互动按钮和对话区域。
- 场景一 GDScript 与场景二 C# 均可加载共用 HUD，无解析或编译错误。

## Documentation impact

- `docs/design/art-direction.md`：补充探索 HUD 的视觉规范。
- `docs/design/scene-flow.md`：补充跨场景显示规则。
- `docs/tech/architecture.md`：记录共用 HUD 组件和场景状态同步方式。
- `docs/qa/playtest.md`：增加探索 HUD 验收场景。

## Likely files

- `scenes/ui/exploration_hud.tscn`
- `scripts/exploration_hud.gd`
- `scenes/palace/palace_demo.tscn`
- `scripts/palace_demo.gd`
- `scenes/Scene2.tscn`
- `scripts/Scene2.cs`
- `tests/test_exploration_hud.gd`
- `tests/verify_merged_project.ps1`

## Verification evidence

- Godot .NET 4.7.1 editor headless import completed without GDScript parse errors.
- `dotnet build NanjiangFleet.csproj --nologo` completed with 0 warnings and 0 errors.
- `tests/verify_merged_project.ps1` passed.
- `tests/test_exploration_hud.gd` passed in both headless runtime and OpenGL compatibility rendering mode; rendered 1344×896 preview confirmed corner placement, Chinese labels, task hierarchy and unobstructed bottom interaction area.
- Existing `test_scene_portraits.gd`, `test_scene_two_dialogue_background.gd` and `test_scene_transition.gd` runtime regressions passed.
