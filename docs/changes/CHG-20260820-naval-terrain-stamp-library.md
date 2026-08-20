# CHG-20260820：海战随机地图障碍印章库

- Status: done
- Date: 2026-08-20

## 目标

在已验证的河口岛印章基础上，把随机海战使用的山地、森林、草地、海滩、浅滩、礁石、港口与小镇升级为同一套多格水墨像素地貌。随机地图从印章池按种子抽取主题组合，整块写入逻辑地形并整图渲染，剩余零碎区域继续使用单格素材兜底。

## 印章清单

| ID | 占地 | 逻辑地形 | 构图职责 |
|---|---:|---|---|
| `river_mouth_island_v2` | 6×8 | 森林、草地、海滩、河流 | 林地源头至开放河口 |
| `forest_island_v1` | 6×6 | 森林、海滩 | 海滩包边的密林岛 |
| `grass_sandbar_v1` | 6×4 | 草地、海滩 | 低矮草洲与沙岸 |
| `reef_shoal_v1` | 5×3 | 浅滩、礁石 | 可通行浅水中的连续暗礁带 |
| `rocky_island_v1` | 5×5 | 山地、海滩 | 石山主体与窄沙岸 |
| `harbor_town_v1` | 7×6 | 港口、小镇、海滩、深水 | 滨海聚落、码头和中央进港水道 |

## 随机生成规则

- `24×18` 等能容纳印章的大随机图，先从河口岛、密林岛、山岩岛、港镇中抽取一枚主题主印章，再从草洲、礁滩中抽取一枚伴生印章。
- 候选矩形必须完整处于地图内并保留一格外海边距，避开双方布阵区、出口和已经写入的印章；透明格同样占用印章矩形，防止其他素材穿插破坏整体轮廓。
- 印章按掩码一次写入底层 `TerrainType`，图片 Alpha 不参与规则；山地、浅滩、礁石等既有散点只在剩余深水格继续生成。
- 每次生成仍执行玩家区至敌区的 BFS 连通性校验；失败时整图重试，最小地图或无合法位置时允许不生成印章。
- 相同种子必须得到相同的印章种类、位置、旋转象限和逐格地形。

## 美术约束

- 六张素材共用 `sea_ink_pixel.png` 与 `river_mouth_island_v2.png` 的低饱和灰青宣纸像素水墨语言。
- 轮廓使用清楚的阶梯像素和大块墨团，控制微细节；河水、浅滩与港池使用战场蓝灰色并向真实透明边缘渐隐。
- 不得包含棋盘格、矩形海水背景、格线、文字、UI、船只、人物、现代建筑、边框或水印。

## 验收检查

- 五张新增 PNG 均为真实 Alpha，尺寸比例与声明占格一致，Godot 可导入加载。
- 96 组随机种子覆盖全部六种印章，所有印章不越界、不重叠、不进入布阵区或出口。
- 同种子结果可复现，地图连通性、安全出口和既有海战冒烟不回归。
- Vulkan 实机预览至少覆盖四种主题主印章，整张绘制且覆盖区不叠加单格障碍图。

## 预计文件

- `assets/naval/battle/terrain_stamps/*.png`
- `scripts/naval/levels/RandomMapGenerator.cs`
- `scripts/naval/presentation/NavalDeploymentController.cs`
- `tests/test_naval_terrain_stamp.gd`
- `docs/design/art-direction.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`

## 验证证据

- `dotnet build ChangcheHeroes.csproj`：通过，0 warning / 0 error。
- Godot headless `tests/test_naval_terrain_stamp.gd`：通过；抽查 96 组种子，覆盖全部六种印章，验证固定种子复现、边界/布阵区/出口避让、印章间距、河流入海、港池深水和全图连通。
- Godot Vulkan `tests/test_naval_terrain_stamp.gd`：通过；六张纹理均加载，四种主题主印章完成实际战场截图，整图绘制方向正确且覆盖区不重复绘制单格障碍。
- Godot headless `tests/test_naval_scene_smoke.gd`：通过；既有布阵、出口与战斗场景未回归。
