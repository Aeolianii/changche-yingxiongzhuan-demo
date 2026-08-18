# CHG-20260806 系统菜单

- Status: done
- Date: 2026-08-06

## Goal

为探索 HUD 的“菜单”入口增加参考用户截图信息结构的系统菜单覆盖层，并实现退出游戏。

## Scope

- 点击右上“菜单”打开中央系统面板，并对后方世界画面和探索 HUD 做实时模糊与轻度压暗。
- 菜单包含“继续游戏、保存进度、读取进度、游戏设置、返回标题、退出游戏”。
- 不包含“新手教程”。
- 右上关闭按钮关闭系统菜单。
- “退出游戏”调用 Godot 场景树退出；其余菜单条目只显示对应功能即将实现。
- 菜单打开时暂停玩家移动，并拦截场景交互输入；关闭后恢复自由移动。
- 场景一和场景二继续共用同一套菜单实现。

## Non-goals

- 不实现继续、存档、读档、设置或返回标题功能。
- 不新增存档格式、设置数据或标题场景。
- 不复用参考截图的游戏背景、人物或受版权保护的 UI 图像。

## Acceptance checks

- 自由移动时点击“菜单”可打开系统菜单，背景明显模糊。
- 菜单完整显示六个指定条目，不存在“新手教程”。
- 点击五个未实现条目分别显示“该功能即将实现”提示。
- 点击右上关闭按钮可返回探索，角色移动恢复。
- 菜单打开期间角色不移动，也不会触发 NPC 交互。
- 点击“退出游戏”执行 `SceneTree.quit()`。
- 1344×896 下菜单居中、无裁切，并保持参考图的黛青黑、旧纸与铜金视觉语言。

## Documentation impact

- `docs/design/art-direction.md`：补充系统菜单视觉与条目。
- `docs/design/scene-flow.md`：补充菜单暂停态。
- `docs/tech/architecture.md`：补充模糊层、菜单状态接口和场景输入协作。
- `docs/qa/playtest.md`：增加菜单验收场景。

## Likely files

- `scripts/exploration_hud.gd`
- `shaders/menu_blur.gdshader`
- `scripts/palace_demo.gd`
- `scripts/Scene2.cs`
- `tests/test_exploration_hud.gd`
- `tests/test_system_menu_exit.gd`
- `tests/verify_merged_project.ps1`

## Verification evidence

- Godot .NET 4.7.1 editor headless import完成，菜单脚本与模糊着色器无解析错误。
- `dotnet build NanjiangFleet.csproj --nologo` 完成，0 warnings、0 errors。
- `tests/verify_merged_project.ps1` 通过，确认六个条目、无新手教程、模糊资源引用及 `SceneTree.quit()` 调用。
- `tests/test_exploration_hud.gd` 通过：菜单打开/关闭、模糊节点、六个条目、五项占位提示、场景一暂停恢复、场景二停止移动均已验证。
- `tests/test_system_menu_exit.gd` 隔离运行通过；点击退出按钮后 Godot 进程以代码 0 主动结束，2 秒看门狗未触发。
- 1344×896 OpenGL 兼容渲染截图确认背景和角落 HUD 均模糊，中央菜单保持清晰、完整且无裁切。
- 既有 `test_scene_portraits.gd`、`test_scene_two_dialogue_background.gd`、`test_scene_transition.gd` 回归通过。
