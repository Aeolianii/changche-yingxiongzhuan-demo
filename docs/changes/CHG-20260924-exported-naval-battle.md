# CHG-20260924-exported-naval-battle: 修复发布包海战空白

- Status: done
- Type: fix
- Owner: Codex
- Created: 2026-09-24

## Goal and player/project outcome

Windows 发布包进入海战布阵时应完整显示海面、地形、舰船和正常初始化后的操作界面。

## Scope

- 海战配置从导出包内的 `res://data/naval/*.json` 读取。
- 导出预设显式包含四份海战 JSON 配置。
- 提供仅由命令行触发的发布版海战检查，并从最终 exe 验证海面与舰船初始化。
- 重新生成并核对完整发布目录和 ZIP。

## Non-goals

- 不修改战斗规则、舰船数值、地图设计或玩家存档。
- 不将发布包二进制文件提交到源码仓库。

## Acceptance checks

- [x] 海战四份 JSON 在导出包中可读取且解析成功。
- [x] 导出 exe 的布阵阶段创建海面、地形与双方舰船，界面没有启动错误。
- [x] ZIP 包含 exe、.NET 运行文件和完整资源；解压后可运行。

## Documentation impact

- Canonical documents to update before implementation: `docs/tech/architecture.md`、`docs/qa/playtest.md`。
- Decisions/ADRs: 无。

## Implementation notes

- Likely files/modules: `scripts/naval/config/NavalConfigLoader.cs`、两个海战入口控制器、`export_presets.cfg`、发布检查脚本、`project.godot`、发布目录。
- Constraints and risks: `ProjectSettings.GlobalizePath("res://")` 不会把打包资源变成真实 Windows 目录；Godot 的 `FileAccess` 可读取明确包含在 PCK 中的原始 JSON。

## Verification evidence

- Automated: `dotnet build ChangcheHeroes.csproj --nologo` 通过，0 警告；Godot 4.7.1 .NET Windows release export 退出码 0。导出的 exe 在 `--headless -- --smoke-naval-export` 与图形模式下均输出 `EXPORT_NAVAL_SMOKE_OK player=5 enemy=4 sprites=9 sea_vertices=4`，退出码 0、无 stderr。ZIP 190 个条目，包含 exe 和 `ChangcheHeroes.dll`；解压到独立目录后同一海战检查通过。
- Manual/in-engine: 从导出 exe 捕获 1344×896 图形截图，海面、地形、双方舰船、选船高亮和底部卷轴操作栏均可见。

## Final reconciliation

- Files changed: `NavalConfigLoader.cs`、两个海战入口控制器、`export_presets.cfg`、`project.godot`、`scripts/core/release_smoke.gd`，以及本记录、架构与 QA 文档。
- Documented limitations/follow-ups: 该自动检查进入自由海战的布阵阶段；其他关卡和完整游戏流程仍由人工游玩验证。
