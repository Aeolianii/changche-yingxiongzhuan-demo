# CHG-20260812-v4-godot-ai-migration: 建立 V4 并迁移 Godot AI MCP

- Status: done
- Type: configuration / development tooling
- Owner: Codex
- Created: 2026-08-12

## Goal and player/project outcome

从正式仓库远端 `main` 建立独立、干净的 V4 工作副本，并把现有 Godot AI MCP 项目插件迁入 V4。旧版“岭南岛屿游戏”和原正式仓库工作区保持不变，后续商城、物品栏与造船系统可以在最新项目基线上设计和开发。

## Scope

- 在 `C:\Users\wangk\Documents\changche-yingxiongzhuan-v4` 建立正式仓库 `main` 的完整工作副本。
- 把 V4 快进到远端最新提交。
- 迁移 `addons/godot_ai/` Godot 编辑器插件。
- 在 V4 的 `project.godot` 中启用 Godot AI 插件和 `_mcp_game_helper` Autoload。
- 保留 Codex 已有的 `http://127.0.0.1:8000/mcp` 全局连接配置。
- 验证项目解析、插件加载和可确认的 MCP 服务状态。

## Non-goals

- 不覆盖或删除 `C:\Users\wangk\Documents\岭南岛屿游戏`。
- 不修改 `C:\Users\wangk\Documents\changche-yingxiongzhuan-demo` 中的未提交文件。
- 本变更不实现月环商港、物品栏、材料交易、图纸购买或造船规则。
- 不改变游戏入口、场景内容、海战规则或存档格式。

## Acceptance checks

- [x] V4 为正式仓库 `main` 的独立 Git 工作副本。
- [x] V4 `HEAD` 与远端 `main` 最新提交一致。
- [x] `addons/godot_ai/plugin.cfg` 在 V4 中存在，版本与来源插件一致。
- [x] `project.godot` 启用 Godot AI 插件与 `_mcp_game_helper`。
- [x] Godot 能载入 V4 项目且不新增脚本解析错误。
- [x] MCP 服务启动并通过协议调用确认活动项目为 V4。
- [x] 旧 V3 与正式仓库原工作区均未被覆盖。

## Documentation impact

- Canonical documents to update before implementation: `docs/tech/architecture.md`
- Decisions/ADRs: 无；这是开发工具迁移，不改变运行时游戏架构。

## Implementation notes

- Likely files/modules: `addons/godot_ai/**`, `project.godot`, `docs/tech/architecture.md`
- Constraints and risks: 端口 `8000` 同时只能由一个 Godot AI 服务占用；不得为验证而关闭含未保存内容的其他 Godot 编辑器。插件属于编辑器工具，导出时由其导出插件剥离 `_mcp_game_helper`。

## Verification evidence

- Git：V4 `HEAD` 为远端 `main` 的 `9b5a6fe1af1902917ffa8131ec7d254711b3f84e`；V4 建立后先从本机干净提交克隆，再以 `git fetch` + `git merge --ff-only origin/main` 补齐远端增量，未复制原仓库工作区的未提交文件。
- 插件完整性：V3 与 V4 的 Godot AI 迁移源包含 245 个文件、总计 1,430,561 字节；`plugin.cfg` 为 3.0.6，关键文件哈希与现有来源一致。
- Godot 解析：Godot 4.7 stable mono 执行 `--headless --editor --quit-after 8`，退出码 0；插件在 headless 模式按设计禁用，没有新增解析错误。
- 编辑器/MCP：V4 编辑器日志记录 `MCP | plugin loaded`、`started server`、`connected to server`；MCP `session_manage(list)` 返回唯一活动会话 `v4@e106`，项目路径 `C:/Users/wangk/Desktop/厂车v4/`、当前场景 `res://scenes/ui/title_screen.tscn`、readiness `ready`。
- 运行时 helper：通过 MCP `project_run(mode="main")` 启动主场景，返回 `helper_live=true`、`game_status.status="live"`、`current_run_errors=[]`；测试后用 MCP 停止游戏，编辑器恢复 `readiness="ready"`。
- 既有警告：日志仍报告远端 `main` 已有的三项 `SHADOWED_VARIABLE_BASE_CLASS` 警告（`sea_map_screen.gd:310`、`exploration_ui.gd:31`、`exploration_ui.gd:43`）。本迁移不修改这些无关代码。

## Final reconciliation

- Files changed: `addons/godot_ai/**`、`project.godot`、`docs/tech/architecture.md`、本变更记录。
- V4 保留远端 `main` 的游戏内容与入口，只增加编辑器工具集成。V3 编辑器与其正在运行的游戏未被关闭或覆盖。
- Codex 当前线程对首次启动瞬间的 MCP 连接曾缓存一次 HTTP 502；原始 MCP initialize 与后续完整工具调用均为 200，并已确认服务与 V4 会话健康。新连接或后续线程会直接使用现有 `127.0.0.1:8000/mcp`。
