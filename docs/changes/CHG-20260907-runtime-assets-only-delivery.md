# CHG-20260907：GitHub 仅保留运行必需素材

- 状态：`done`
- 日期：2026-09-07

## 目标

GitHub 的 main 分支只保留游戏运行、自动化测试和授权追溯所需的素材，不继续上传生成草稿、构图参考、候选角色或未接入的高清地点样张。

## 清理内容

- 删除 `assets/characters/protagonist_candidate/`：正式主角帧已接入 `assets/characters/protagonist/standard/`，候选帧、原始图集、预览和生成元数据不参与运行。
- 删除 `assets/sprites/sea_overworld/hd_locations/`：独立地点高清样张未接入任何代码、场景、数据或测试，运行时继续使用 A/B/C/D v3 海图分块。
- 删除 `assets/backgrounds/sea_overworld/concepts/`：阶段一灰模已经完成生产参考作用，运行时不加载。
- 删除 `assets/characters/emperor/generation/`：正式皇帝帧已接入，提示词与流水线元数据不参与运行。
- 将 `docs/assets/sea-overworld-stage1-layout.md` 移入 `docs/archive/assets/`，避免历史灰模说明继续出现在现行素材入口。

## 保留内容

- 保留所有代码、场景、数据和测试直接引用的图片与音频。
- 保留角色标准帧、舰船、海战地形、商品和船型等按目录或文件名动态加载的资源。
- 保留 `assets/audio/fubo_guling/sources/taiko_drum_001_hq.mp3`，用于音频授权来源追溯和现有专项测试。
- 保留 A/B/C/D v3 海图分块、伏波古岭正式背景、月环商港正式背景及所有当前 UI 资源。

## 验证

- 共删除 114 个已跟踪文件，减少 25.02 MiB；清理目录在运行时代码、场景、数据、测试和工具中的引用为 0。
- Godot 4.7.1 .NET headless 项目导入与资源扫描通过，退出码 0。
- `test_protagonist_sprite_visual.gd`、`test_scene_portraits.gd`、`test_sea_overworld_sea_monster_event.gd`、`test_naval_terrain_stamp.gd` 与 `test_ship_screen.gd` 均通过。
- Markdown 相对链接和 `git diff --check` 通过；提交前复核暂存范围不包含本地未提交素材与 Godot 生成文件。
