# CHG-20260817：海盗战接入随机战斗 + 战斗结果返回处理

- 状态：`done`
- 日期：2026-08-17

## 目标

海上大地图的海盗船接触事件接入项目已有的随机遭遇战系统：将原占位对话框改为 4 个难度选项，选择后生成随机遭遇战（`RandomEncounterGenerator`）并进入 NavalDemo 海战；战斗结算后返回海上大地图，按胜负结果移除/保留海盗、处理玩家复活与提示。

## 范围

- 海盗接触对话框改为 4 个选项：难度一 / 难度二 / 难度三 / 公式难度（按玩家舰队强度计算 1-3）。
- 选择难度 → 生成随机遭遇（难度=所选值；公式难度按经济舰队强度计算）→ `RandomEncounterSession.Begin` → 切换到 NavalDemo。
- 战斗结束结算面板显示「返回海上大地图」；胜利 → 移除本次接触的海盗；失败/逃跑/平局 → 保留海盗 + 玩家在月环商港附近复活 + 提示。
- 新增 headless 验证：4 选项出现；选难度 → 遭遇激活且难度正确并进入 NavalDemo；公式难度随舰队强度映射；胜利清除/失败保留。

## 非目标

- 不修改海盗巡航/追击行为与参数。
- 不修改随机遭遇生成器、战斗规则或其它非海盗入口的随机遭遇流程。
- 不改变月环商港场景本身（仅在海战失败时使用其坐标作复活点）。
- 不引入新依赖包。

## 设计决策

- 跨语言互操作沿用项目既有 meta 模式（`scene_2.gd ↔ LevelSelect`、`sea_overworld ↔ fubo`）：GDScript 侧不能直接调用 C# 静态类，故 sea_overworld 把海盗战请求写入场景根 meta（`sea_pirate_battle_request`，含海盗 id / 难度 / 玩家位置 / 农历日），`NavalDeploymentController._Ready` 消费后生成并 `Begin` 随机遭遇。
- 新增 C# 静态会话 `PirateBattleSession`（`scripts/naval/levels/PirateBattleSession.cs`）承载「本场为海盗战」标记（海盗 id / 难度 / 发起方返回上下文 `ReturnContextCarrier`），结算面板据此显示「返回海上大地图」。
- 返回上下文：请求 meta 被 Deployment 消费后由 `PirateBattleSession.ReturnContextCarrier` 暂存（玩家位置 / 农历日），`NavalBattleController.BuildPirateReturnContext` 以其为基础补写 `outcome`（0 胜 / 1 败 / 2 平）、金币结余与海盗 id 后写入 `sea_pirate_battle_return_context`，再切回海上大地图。这样不残留发起 meta，且中途退出（返回关卡选择）时 NavalBackController 一并清理会话与请求 meta。
- 公式难度：`强度分 = Σ每艘 (1 + 平均 upgrades 等级)`（每舰 4 项 upgrades 各 clamp 0-3 取均值四舍五入），`≤6→1`、`≤12→2`、否则 `3`；读取不到经济状态时保守默认难度 2。
- `NavalBattleController._Ready` 早于 `NavalDeploymentController._Ready` 执行（兄弟节点序 Battle 先于 Deployment），故结算时以 `RandomEncounterSession.Active` 实时读取遭遇，兼容海盗战（会话在部署阶段才 Begin）与既有随机遭遇。
- 胜利返回：海上大地图按海盗节点名（`"PirateShip%d"`）移除对应海盗（本次进入海盗数 5→4），玩家回到战斗前船位；失败/逃跑/平局：海盗保留（重新随机分布仍为 5 艘、恢复巡航），玩家在月环商港坐标 `(3650, 360)` 附近复活并提示休整。海盗不写入存档，每次进入重新随机生成。
- 保留 `finish_pirate_placeholder` 作为隐藏中止路径（既有海盗追击冒烟测试仍走该分支，不回归）。

## 验收检查

- 海盗接触对话框出现 4 个难度选项。
- 选难度一/二/三 → 进入 NavalDemo 且为随机遭遇模式、难度与所选一致。
- 选公式难度 → 难度随舰队强度映射 1-3。
- 结算面板海盗战显示「返回海上大地图」；胜利返回后该海盗被移除（5→4）；失败/逃跑返回后海盗保留、玩家在月环商港附近复活且有提示。
- `dotnet build --no-restore`：0 警告、0 错误。
- headless 冒烟（新海盗战测试 + 既有海盗追击测试不回归）全绿。

## 文档影响

- 更新 `docs/design/sea-overworld-design.md` 第 8.4 节：海盗接触从「正式战斗未接入、提示后移除海盗」改为「4 难度进入正式海战 + 按结果返回」。
- 更新 `docs/qa/playtest.md` 的验收记录。

## 预计文件

- `docs/changes/CHG-20260817-pirate-random-battle.md`（本记录）
- `docs/design/sea-overworld-design.md`
- `docs/qa/playtest.md`
- `scripts/sea_overworld.gd`（4 难度选项 + 公式难度 + 请求/返回 meta + 胜利移除/失败复活）
- `scripts/naval/levels/PirateBattleSession.cs`（新增，海盗战会话 + 返回上下文载体）
- `scripts/naval/presentation/NavalDeploymentController.cs`（消费请求 meta + 生成海盗遭遇）
- `scripts/naval/presentation/NavalBattleController.cs`（结算返回 + 会话实时读取 + 返回上下文构造）
- `scripts/naval/presentation/NavalHud.cs`（「返回海上大地图」按钮）
- `scripts/naval/presentation/NavalBackController.cs`（中止海盗战清理会话与请求 meta）
- `scenes/naval/NavalDemo.tscn`（结算面板新增 ReturnToSeaButton）
- `tests/test_sea_overworld_pirate_battle.gd`（新增：入口 4 选项 + 公式难度 + 选难度写请求 meta）
- `tests/test_sea_overworld_pirate_return.gd`（新增：胜利移除/失败保留 + 月环商港复活）
- `tests/test_naval_pirate_request.gd`（新增：NavalDemo 消费请求 meta 生成遭遇 + 返回上下文）

## 验证证据

- `dotnet build ChangcheHeroes.csproj -c Debug`：0 警告、0 错误。
- headless（Godot 4.7.1 mono，`--headless --script res://tests/...`）：
  - `test_sea_overworld_pirate_battle.gd`：4 个难度选项出现、公式难度对默认舰队（5 艘 upgrades 全 0 → 强度 5）映射难度一、选「难度二」后请求 meta 写入（difficulty=2、pirate_id、player_position）。
  - `test_sea_overworld_pirate_return.gd`：胜利返回海盗数 5→4 且回到战斗前船位；失败返回海盗数保持 5 且玩家在月环商港 `(3650, 360)` 附近复活。
  - `test_naval_pirate_request.gd`：请求 meta → `PirateBattleActive` 真、随机遭遇激活且难度与所选一致、返回上下文保留玩家位置/农历日/海盗 id 并补结算结果（未结算默认平局）。
  - 回归：`test_sea_overworld_pirate_chase.gd`、`test_naval_scene_smoke.gd`、`test_sea_overworld.gd`、`test_fubo_sea_round_trip.gd` 全绿（未引入回归）。
- 说明：整合版项目根目录非 git 仓库（仅有 `.gitignore`），要求的 git 提交未执行（需用户决定是否在别处初始化仓库）。
