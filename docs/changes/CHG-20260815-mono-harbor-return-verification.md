# V4 Mono 环境与月环商港返航验证整合

- Status: done
- Date: 2026-08-15

## Goal

确认 V4 以 Godot 4.7 .NET/Mono 运行并保持 Godot AI MCP 可用，同时修正月环商港返航回归测试中已经落入新版岛屿碰撞区的旧海图坐标。

## Player-visible outcome

不改变玩法、商港场景或真实返航逻辑。自动验证应使用玩家实际可进入月环商港的安全水域位置，避免物理引擎把测试船从岛屿碰撞中推出而产生假失败。

## Scope

- 核对当前 V4 编辑器与 MCP 会话是否由 Godot Mono 进程承载。
- 将 Mono/MCP 的运行约束补入技术文档。
- 更新月环商港返航测试的测试入口位置。
- 使用 Godot Mono 运行 C# 构建、商港返航测试及相关回归验证。

## Non-goals

- 不把现有 GDScript 改写为 C#。
- 不修改月环商港场景碰撞、海图碰撞或玩家可航区域。
- 不修改真实返航上下文的数据格式和恢复逻辑。
- 不推送或提交分支，除非用户另行要求。

## Acceptance checks

- 当前 Godot AI MCP 活跃会话对应 V4，宿主进程是 Godot Mono。
- `dotnet build ChangcheHeroes.csproj` 成功。
- 月环商港返航测试先能稳定复现旧坐标失败，改用真实安全入口位置后通过。
- 月环商岛专项测试与合并项目静态验证通过。
- 验证后工作区不包含 Godot 导入产生的无关文件。

## Documentation impact

- `docs/tech/architecture.md`：明确 MCP 活跃会话也必须由 .NET/Mono 编辑器承载，不能只看版本字符串判断。
- `docs/qa/playtest.md`：明确月环商港返航测试使用可航入口位置，不使用岛屿内部硬编码点。

## Likely files

- `docs/changes/CHG-20260815-mono-harbor-return-verification.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `tests/test_yuehuan_harbor.gd`

## Investigation

- 当前 MCP 活跃会话为 `v4@e106`，项目路径为 `C:/Users/wangk/Desktop/厂车v4/`。
- 会话宿主 PID 31408 的可执行文件是 `Godot_v4.7-stable_mono_win64.exe`；MCP 的 `godot_version` 字段只显示 `4.7-stable (official)`，不能据此区分普通版与 Mono 版。
- 远程 `main` 的海岛碰撞修复使月环商港碰撞真正进入物理空间；测试旧坐标 `Vector2(3610, 520)` 位于/紧邻该碰撞，船只恢复后会被物理解穿，导致严格坐标断言失败。
- 真实进入月环商港时记录的是商港左侧入口的当前船位，因此生产返航上下文链路与测试旧坐标不是同一问题。

## Verification evidence

- MCP session：`v4@e106` 指向 `C:/Users/wangk/Desktop/厂车v4/`；宿主 PID 31408 的进程路径为 `Godot_v4.7-stable_mono_win64.exe`，确认 V4 已由 Mono 编辑器和现有 MCP 插件共同承载，无需迁移插件。
- RED：Godot Mono 原样运行 `tests/test_yuehuan_harbor.gd`，稳定以 `Harbor return must restore the ship's entry position.` 退出码 1。
- GREEN：测试改为从月环商港 `EntryTriggerShape` 动态计算左侧可航返航点后，同一 Godot Mono 命令退出码 0，输出 `Yuehuan harbor verification passed.`。
- C#：`dotnet build ChangcheHeroes.csproj --nologo` 成功，0 警告、0 错误。
- Regression：Godot Mono 运行 `tests/test_yuehuan_merchant_island.gd` 与 `tests/test_fubo_guling.gd` 均退出码 0。
- Static：`tests/verify_merged_project.ps1` 退出码 0，输出 `Merged project static verification passed.`。
- Hygiene：验证后 `git status --short` 只包含本变更的两份权威文档、变更记录和返航测试，没有无关 Godot 导入文件。

## Files changed

- `docs/changes/CHG-20260815-mono-harbor-return-verification.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `tests/test_yuehuan_harbor.gd`

## Final behavior

V4 保持 GDScript/C# 混合工程并继续使用现有 Godot AI MCP 插件；当前活跃编辑器已经是 Mono，无需额外迁移。月环商港生产返航逻辑不变，专项测试改为随场景入口几何计算有效可航返航点，不再受旧岛屿内部坐标影响。
