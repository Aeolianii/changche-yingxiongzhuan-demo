# CHG-20260720 合并场景一与场景二

- Status: done
- Owner: Codex
- Date: 2026-07-20

## Goal

将当前目录中的皇宫场景一 GDScript 项目与南疆水师场景二 C# 项目合并为一个可独立打开的 Godot .NET 项目，并在场景一完成后自动进入场景二。

## Scope

- 新建独立 `combined-project`，保留两个源项目不变。
- 以场景二的 Godot .NET 4.7.1 配置为基础。
- 合并场景一的 `assets/`、`scripts/`、`scenes/` 与文档。
- 合并输入映射，项目从场景一启动。
- 清理合并副本中从两个项目继承的可再生 `.import` 与 `.translation` 产物，由 Godot 重新导入并分配唯一 UID。
- 场景一完成旁白显示后等待 2.5 秒，淡出并切换场景二；允许点击跳过等待。
- 添加静态资源引用、项目配置和切换契约测试。

## Non-goals

- 不把 Scene2.cs 重写为 GDScript。
- 场景二历史素材后来已统一迁移至 `assets/`。
- 不修改两个场景原有剧情、美术、碰撞和 NPC 玩法。
- 不增加章节选择、跨场景存档或共享角色状态。
- 不删除或覆盖两个源项目。

## Acceptance checks

- `project.godot` 使用 C# 特性并以场景一为 `run/main_scene`。
- 场景一与场景二的所有外部资源路径在合并项目中存在。
- Godot 首次导入后没有重复 UID、资源依赖缺失或 Unicode 解析错误。
- C# 项目可以通过 `dotnet build`。
- 场景一完整流程可达，完成后只触发一次场景切换。
- 计时切换与点击跳过均可进入 `res://scenes/Scene2.tscn`。
- 场景二进入后角色移动、县令对话和操练入口仍可用。
- Godot 运行日志没有新的解析、资源加载或运行时错误。

## Documentation impact

- 更新 `docs/index.md` 当前里程碑。
- 更新 `docs/design/core-loop.md`，加入场景串联步骤。
- 新增 `docs/design/scene-flow.md`。
- 更新 `docs/tech/architecture.md`，记录混合语言与统一项目配置。
- 更新 `docs/qa/playtest.md`，加入跨场景验收。

## Likely files

- `project.godot`
- `NanjiangFleet.csproj`
- `scripts/palace_demo.gd`
- `scenes/palace/palace_demo.tscn`
- `scenes/Scene2.tscn`
- `scripts/Scene2.cs`
- `tests/verify_merged_project.ps1`
- `README.md`

## Verification evidence

- 2026-07-20 RED：静态合并测试在实现前报告 10 个缺失项目/场景/切换契约错误。
- 2026-07-20 GREEN（阶段一）：静态合并测试通过；`dotnet build` 为 0 warning / 0 error。
- 2026-07-20 Godot 首次导入：发现两个源项目的复制素材保留相同 `.import` UID，并伴随生成型 `.translation` 依赖错误；待重新导入修复后复验。
- 2026-07-20 Godot 重新导入：exit 0，0 warnings，0 errors；所有历史重复 UID 已重新生成并更新场景引用。
- 2026-07-20 Scene1 启动：exit 0，0 issues。
- 2026-07-20 Scene2 启动：exit 0，0 issues；C# 根脚本成功实例化。
- 2026-07-20 自动切换测试：2.5 秒计时切换与点击跳过切换均进入 Scene2，exit 0，0 issues。
- 2026-07-20 最终 C# 构建：0 warnings，0 errors。
- 2026-07-20 提交前审查：修复过期 UID 检测，移除可能再次破坏 UID 的一次性清理脚本，确认 `.godot/`、`bin/`、`obj/` 未进入 Git。
