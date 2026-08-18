# CHG-20260814：移除旧海战模块

- Status: done
- Date: 2026-08-14
- Owner: Codex

## Goal

删除两套旧 GDScript 海战原型及其独立官军战役外壳，只保留已经接入剧情“水师操演”的 C# 海战模块。

## Scope

- 删除 `naval_tactics.tscn`、`naval_tactics_v3.tscn` 与 `official_campaign.tscn`。
- 删除旧场景专用的 `scripts/tactics/`、`scripts/tactics_v3/`、`scripts/campaign/`。
- 删除旧模块专用的战棋船只、棋盘、特效、音效素材及相应第三方素材清单条目。
- 删除只验证旧模块的 Godot 验证脚本与 Python 规则模拟器。
- 清理 README 和现行设计文档中的旧入口、旧验证命令与旧原型保留说明。
- 保留 `scenes/naval/`、`scripts/naval/`、`data/naval/`、`assets/naval/` 及其剧情接入和冒烟测试。

## Non-goals

- 不修改当前水师操演的关卡、布阵、战斗规则、进度文件或返回 Scene2 的逻辑。
- 不修改海上大地图中海盗、海怪等尚未接入正式战斗的占位交互。
- 不删除历史变更记录中对旧原型的历史说明。
- 不迁移旧官军战役或旧原型的存档数据。

## Acceptance checks

- 非历史文档与运行时代码不再引用三个旧场景、旧脚本目录或旧验证工具。
- 工程中仅保留 `scenes/naval/` 下的现行海战场景与 `scripts/naval/` 下的现行战斗实现。
- `ChangcheHeroes.csproj` 构建通过。
- 水师操演场景冒烟测试与 Scene2 操演往返测试通过。

## Documentation impact

- `README.md`
- `docs/design/naval-tactics-gameplay.md`
- `docs/tech/architecture.md`
- `assets/THIRD_PARTY.md`
- 本变更记录。

## Likely files

- 上述文档。
- `scenes/naval_tactics.tscn`
- `scenes/naval_tactics_v3.tscn`
- `scenes/official_campaign.tscn`
- `scripts/tactics/`
- `scripts/tactics_v3/`
- `scripts/campaign/`
- `assets/sprites/naval_tactics/`
- `assets/audio/battle_at_sea/`
- `tools/tactics_sim/`
- `tools/verify_naval_tactics.gd`
- `tools/verify_target_tactics_v3.gd`
- `tools/verify_target_tactics_runtime.gd`
- `tools/verify_official_campaign.gd`
- `tools/verify_single_durability_combat.gd`

## Verification evidence

- `dotnet build .\ChangcheHeroes.csproj --nologo`：通过，0 警告、0 错误。
- Godot 4.7.1 .NET headless editor 重新扫描与导入：通过，删除后的工程没有旧资源加载错误。
- `tests/test_naval_scene_smoke.gd`：通过，现行 `NavalDemo.tscn` 可加载并实例化。
- `tests/test_scene_two_dialogue_patrol.gd`：通过，Scene2 操演进入与返回流程未回归。
- `tests/verify_merged_project.ps1`：通过。
- 全仓旧场景、旧脚本、旧素材、旧工具与 `naval_restart` 引用扫描：除历史变更记录外无匹配。

## Actual changed files

- 删除 `scenes/naval_tactics.tscn`、`scenes/naval_tactics_v3.tscn`、`scenes/official_campaign.tscn`。
- 删除 `scripts/tactics/`、`scripts/tactics_v3/`、`scripts/campaign/`。
- 删除 `assets/sprites/naval_tactics/`、`assets/audio/battle_at_sea/`。
- 删除 `tools/tactics_sim/` 与五组旧模块验证脚本及其 UID。
- 删除 `docs/design/naval-tactics-water-surface.md`。
- 更新 `README.md`、`docs/design/naval-tactics-gameplay.md`、`docs/tech/architecture.md`、`assets/THIRD_PARTY.md` 与 `project.godot`。
- 保留 `scenes/naval/`、`scripts/naval/`、`data/naval/`、`assets/naval/` 和现行测试。
