# CHG-20260813-integrate-naval-training: 接入海战操演主界面

- Status: done
- Type: feature
- Owner: Codex
- Created: 2026-08-13

## Goal and player/project outcome

把 `D:\新版海战\TSOC_DG01_naval-battle_02-ds-` 的完整海战模块接入主流程：县令首次会谈结束后以黑场过渡进入海战主界面；玩家从海战主界面右上角返回时，从黑场淡入原甲板位置。完成首次操演后，县令闲聊固定提供“出海 / 操演 / 无事”三个选项。

## Scope

- 复制海战模块的场景、C# 脚本、配置与本地资源到主项目对应目录。
- 把主项目升级为 Godot 4.7.1 .NET 混合 GDScript/C# 工程。
- Scene2 保存一次性操演返回上下文，包括人物坐标、朝向、任务阶段和首次完成标记。
- Scene2 与海战主界面双向使用黑场淡入淡出；返回后恢复同一甲板实例语义下的精确人物位置。
- 更新县令操演后闲聊选项及针对性自动验证。

## Non-goals

- 不改写海战核心规则、关卡解锁、布阵、战斗结算和独立进度文件。
- 不把海战进度并入主流程单槽存档。
- 不改变“出海”通往现有岭南海上大地图的行为。

## Acceptance checks

- [x] 首次县令会谈结束后，Scene2 缓慢淡黑并进入 `res://scenes/naval/LevelSelect.tscn`。
- [x] 海战主界面右上角“返回”可用，点击后淡黑切回 Scene2，再缓慢亮起。
- [x] 返回后主角坐标与县令对话开始前一致，首次返回将任务推进到“探索海域，完善海图”。
- [x] 操演后县令闲聊恰有“出海 / 操演 / 无事”三个选项；“出海”和“无事”保持原有行为。
- [x] 再次选择“操演”可重复进入海战主界面，返回仍保持任务阶段和人物位置。
- [x] Godot .NET 构建、场景解析和针对性主流程测试通过。

## Documentation impact

- Canonical documents to update before implementation: `docs/design/scene-flow.md`, `docs/design/naval-tactics-gameplay.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`
- Decisions/ADRs: 使用场景树根节点的一次性字典传递返回上下文；海战模块保持独立 `user://progress.json`。

## Implementation notes

- Likely files/modules: `project.godot`, `ChangcheHeroes.csproj`, `scripts/scene_2.gd`, `scripts/naval/**`, `scenes/naval/**`, `assets/naval/**`, `data/naval/**`, Scene2/海战专项测试。
- Constraints and risks: 主项目此前为纯 GDScript；接入后必须使用 Godot .NET 4.7.1。源海战工作区存在未提交修改，复制时保留其当前工作树内容，不回写源工程。

## Verification evidence

- Automated: `dotnet build ChangcheHeroes.csproj --nologo`（0 warnings / 0 errors）。
- Automated: `tests/test_scene_two_dialogue_patrol.gd` 通过，覆盖首次操演、主界面右上角返回、精确坐标恢复、三选项和重复操演。
- Automated: `tests/test_scene_two_sea_link.gd` 通过，确认“出海”仍沿用既有大地图往返。
- Automated: `tests/test_naval_scene_smoke.gd` 通过，确认海战布阵、配置装配、进入战斗和一次远程攻击均可运行。
- Regression note: `tests/test_main_flow_save.gd` 的 Scene2 恢复断言通过，随后在未改动的伏波古岭支线投影断言失败；该失败不涉及本次修改范围。
- Manual/in-engine: 未进行人工点击试玩；上述流程均以 Godot .NET 4.7.1 headless 运行。

## Final reconciliation

- Files changed: `project.godot`, `ChangcheHeroes.csproj`, `scripts/scene_2.gd`, `assets/naval/**`, `data/naval/**`, `scenes/naval/**`, `scripts/naval/**`, Scene2/海战专项测试，以及本记录列出的权威文档。
- Documented limitations/follow-ups: 海战模块继续使用独立 `user://progress.json`，不并入主流程单槽存档；主项目从此必须使用 Godot .NET 4.7.1。
