# CHG-20260820：四张固定海战地图

- Status: done
- Date: 2026-08-20

## 目标

停止在每次遭遇战中随机拼接地形。海战改为维护四张经过人工构图和连通性验证的固定 `24×18` 地图：森林岛、岩山岛、港口小镇、河口岛。进入随机遭遇战时只随机选择地图模板，选中后主印章、伴生印章、散点装饰、出口与逐格地形全部固定。

## 固定模板

| 地图 | 主印章 | 伴生印章 | 构图重点 |
|---|---|---|---|
| 森林岛 | `forest_island_v1` | `grass_sandbar_v1` | 左上森林、右下草洲，斜向夹出中路并保留上下绕行 |
| 岩山岛 | `rocky_island_v1` | `reef_shoal_wide_v1` | 上方扩大险礁、右侧偏置岩山，短危险路与长安全路并存 |
| 港口小镇 | `harbor_town_v1` | `reef_shoal_v1` | 上礁滩、中部港镇，南向港池深水可供小型舰驶入停泊 |
| 河口岛 | `river_mouth_island_v2` | `reef_shoal_v1` | `8×10` 河口岛下移，险礁仍在岛屿上方，两者之间固定留出两行深水通道 |

## 生成与选择规则

- `RandomMapGenerator` 保留现有接口，但种子只用于从四个模板中选择一个；难度不再改变地图障碍数量和位置。
- 标准 `24×18` 地图使用固定的印章原点、固定朝向和固定单格装饰；不再随机寻找印章位置，不再随机生成山地簇、浅滩或礁石散点。
- 玩家区、敌人区和左右安全出口沿用既有规则。每张模板都必须通过玩家区中心至敌人区中心的 BFS 连通性检查。
- `RandomEncounterGenerator` 的地图来源统一改为四张固定地图，不再混用旧方案图、伪随机变体和完全随机海域。
- 相同模板在不同种子、不同难度下的地形行与印章元数据必须完全一致。

## 验收

- 连续种子抽样只出现四种地图，并且四种都能被覆盖。
- 每张地图固定包含一枚主题主印章和一枚指定伴生印章，位置、方向、地形掩码不随种子变化。
- 河口连续、港池可通、印章不进入布阵区或出口，地图保持连通。
- 随机遭遇战的 `MapSourceLabel` 明确显示当前固定地图名称。
- 四张地图分别完成 Vulkan 实际战场预览；既有海战场景与随机遭遇测试不回归。

## 预计文件

- `scripts/naval/levels/RandomMapGenerator.cs`
- `scripts/naval/levels/RandomEncounterGenerator.cs`
- `scripts/naval/presentation/NavalDeploymentController.cs`
- `tests/test_naval_terrain_stamp.gd`
- `docs/tech/architecture.md`
- `docs/design/art-direction.md`
- `docs/qa/playtest.md`

## 验证证据

- `dotnet build ChangcheHeroes.csproj`：通过，0 warning / 0 error。
- Godot headless `tests/test_naval_terrain_stamp.gd`：通过；32 组种子只覆盖四张固定模板，同模板跨种子与难度的地形行、印章位置完全一致，随机遭遇入口和地图名称同步验证通过。
- Godot Vulkan `tests/test_naval_terrain_stamp.gd`：通过；四张固定地图均生成全图预览，确认森林岛、岩山岛、港口小镇、河口岛拥有不同的上下关系、主航道和绕行方向。
- Godot headless `tests/test_naval_scene_smoke.gd`、`tests/test_naval_pirate_request.gd`、`tests/test_sea_overworld_pirate_battle.gd`：通过；海战布阵、海盗请求和海图进入战斗流程未回归。
