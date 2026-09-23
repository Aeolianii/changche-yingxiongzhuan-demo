# CHG-20260923-windows-demo-export: Windows 试玩包

- Status: done
- Type: feature
- Owner: Codex
- Created: 2026-09-23

## Goal and player/project outcome

将当前 Godot .NET Demo 导出为可分发的 Windows 试玩包。玩家完整解压后双击 exe 即可进入游戏，无需安装 Godot 编辑器或 .NET SDK。

## Scope

- 增加 Windows Desktop x86_64 正式导出预设。
- 在仓库外生成便携发布目录和 ZIP，保留 exe 所需的所有相邻文件。
- 补充发布与运行说明。

## Non-goals

- 不修改玩法、美术或存档格式；不制作安装程序或其他系统版本。
- 不将大体积构建产物提交到源码仓库。

## Acceptance checks

- [x] Godot 4.7.1 .NET 正式导出成功，完整日志中无 `ERROR` 或 `WARNING`。
- [x] 从独立发布目录启动导出程序，无工程路径依赖和启动报错。
- [x] ZIP 包含 exe 与全部运行依赖。

## Documentation impact

- Canonical documents to update before implementation: `docs/tech/architecture.md`；同时更新面向玩家的 `README.md`。
- Decisions/ADRs: 无。

## Implementation notes

- Likely files/modules: `export_presets.cfg`、`ChangcheHeroes.sln`、`README.md`、`docs/tech/architecture.md`、仓库外发布目录。
- Constraints and risks: Godot .NET 的 Windows 导出需要版本匹配的 Mono 导出模板以及与项目同名的 `.sln`；缺少解决方案时 Godot 仍可能返回退出码 0，但会报告 C# 导出错误。发布前必须检查完整导出日志。

## Verification evidence

- Automated: `dotnet build ChangcheHeroes.csproj --nologo -v:q` 成功；正式导出退出码 0，日志无错误；`test_naval_result_ui.gd` 通过；ZIP 共 190 个条目，包含 exe 和 `ChangcheHeroes.dll`。
- Manual/in-engine: 发布目录内 exe 在 `DOTNET_ROOT` 指向不存在目录时仍可无界面运行 120 帧并以 0 退出；图形启动 4 秒保持运行，Vulkan 成功初始化，标准错误为空。

## Final reconciliation

- Files changed: `export_presets.cfg`、`ChangcheHeroes.sln`、`README.md`、`docs/tech/architecture.md`、本变更记录；构建产物在仓库外的 `D:\厂车英雄传DEMO\发布包\`。
- Documented limitations/follow-ups: 旧 `test_naval_scene_smoke.gd` 仍检查已移除的双笔触结果节点而失败；此处使用与当前场景一致的 `test_naval_result_ui.gd` 验证结果界面。图形测试确认启动和持续运行，未逐步通关整个 Demo。
