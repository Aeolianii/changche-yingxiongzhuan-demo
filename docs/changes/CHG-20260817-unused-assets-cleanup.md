# CHG-20260817：清理未使用素材

- 状态：`done`
- 日期：2026-08-17

## 目标

删除当前 Godot 工程不再引用、已被正式版本取代或仅用于一次性处理的素材，减少仓库体积和资源扫描噪声，同时保持现有可玩流程与动态加载资源完整。

## 范围

- 删除 `tmp/imagegen/` 中已完成接入的临时抠图。
- 删除月环商岛、伏波古岭、海上大地图、海战和旧 UI 中已淘汰的版本与处理中间文件。
- Paper UI 仅保留运行时仍加载的金币图标。
- 同步更新当前素材索引，明确追溯依赖 Git 历史而非工作树中的重复文件。

## 非目标

- 不修改脚本、场景、游戏数据或玩法。
- 不删除通过目录/文件名规则动态加载的角色帧、海战舰船、海战地形、商品图标和船型图标。
- 不删除仍处于高清分层重制阶段的海图地点素材。
- 不处理 `ChangcheHeroes.csproj`、`ChangcheHeroes.csproj.old` 和 `assets/ui/inventory/inventory_backdrop_v1.png.import` 的现有用户改动。

## 验收检查

- 全工程文本引用扫描不指向被删除素材。
- Godot 4.7.1 .NET headless 能完成项目导入与资源扫描。
- 运行最相关的合并工程/场景资源验证，确认主流程资源仍可加载。
- Git diff 仅包含本次素材清理、对应导入记录和文档同步，以及清理前已有的用户改动。

## 文档影响

- 更新 `docs/assets/generated-backgrounds.md`、`docs/assets/fubo-guling-generated-assets.md`、`docs/assets/sea-overworld-generated-assets.md` 与 `docs/assets/character-assets.md`。
- 历史变更记录不重写；被删素材仍可从 Git 历史恢复。

## 预计文件

- `assets/` 下明确淘汰或重复的素材及对应 `.import`。
- `tmp/imagegen/`。
- 上述素材索引与本变更记录。

## 验证证据

- 删除 531 个素材、处理中间文件及对应 Godot 导入记录；按 `HEAD` 对象大小统计，工作树减少 `117.38 MiB`。
- 运行时代码、场景、数据与测试中的字面量 `res://assets/...` 路径复查：缺失路径为 0；角色、舰船、地形、商品和船型等动态加载目录另以定向保留清单复核。
- `Godot_v4.7.1-stable_mono_win64_console.exe --headless --editor --quit --path .`：退出码 0，项目资源重新扫描完成。
- 定向运行态测试通过：`test_sea_overworld_sea_monster_event.gd`、`test_fubo_guling.gd`、`test_yuehuan_harbor.gd`、`test_naval_scene_smoke.gd`、`test_exploration_hud.gd`、`test_ship_screen.gd`。
- `test_sea_overworld.gd` 全量测试仍在既有的 32 个海图碰撞节点/坐标基线处失败；失败断言不涉及被删素材路径，本次未扩大范围修改海图碰撞逻辑。
- `git diff --check` 与 `git diff --cached --check`：通过。
- 清理前已有的 `ChangcheHeroes.csproj`、`ChangcheHeroes.csproj.old` 和 `assets/ui/inventory/inventory_backdrop_v1.png.import` 用户改动未纳入本次修改。
