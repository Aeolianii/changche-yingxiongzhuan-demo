# CHG-20260820：海战多格地形印章首版

- Status: done
- Date: 2026-08-20

## 目标

把海战地图中逐格重复的海滩、森林、草地与陆河占位块升级为可跨多个逻辑格绘制的一体化地貌。首版制作一枚 `6×8` 的“林地河源—草地河道—海滩河口”组合印章，并让种子化随机地图在合法区域内放置它，用实际战斗渲染验证整体轮廓、底层规则与舰船可玩性。

## 范围

- 新增一张透明背景、无文字、无格线的像素水墨河口岛地貌素材。
- 地图数据记录印章 ID、纹理路径、左上逻辑格、占地尺寸和旋转象限。
- `RandomMapGenerator` 只在双方布阵区之间、地图范围内且不覆盖出口的位置尝试放置首版印章；印章自己的地形掩码一次写入森林、草地、海滩和陆河格。
- `NavalGridView` 按印章整体矩形绘制一次，并跳过其覆盖区域原有的逐格地形精灵；格子规则、移动、视野、碰撞和射程继续读取底层 `TerrainType`。
- 印章放置后继续执行现有连通性验证；无合法位置或连通性失败时允许重试/回退，不把河流作为孤立散点投放。

## 非目标

- 本次不批量替换港口、小镇、森林、草地等全部正式素材。
- 不改变舰船移动、地形通过性、战争迷雾、攻击规则或地图出口规则。
- 不让运行时从图片颜色或 Alpha 推导地形和碰撞。
- 不修改固定地图方案的现有 ASCII 布局。

## 验收检查

- 相同种子生成相同的印章位置与地形格。
- 首版印章严格占 `6×8`，不越界、不进入双方布阵区、不覆盖出口。
- 河流只存在于完整河口岛组合内部，从林地源头连续通到海滩河口；不存在随机单格河流。
- 地图生成后玩家区到敌区仍连通，安全出口数量与深水属性不回归。
- 战斗运行时只加载并绘制一次大纹理，覆盖格不再叠加单格海滩/森林/草地/河流图。
- Godot 4.7.1 .NET 针对性测试通过，并保存一张实际战场预览截图。

## 文档影响

- `docs/design/art-direction.md`：增加海战多格地形印章的美术规格。
- `docs/tech/architecture.md`：记录印章元数据、随机放置和渲染职责边界。
- `docs/qa/playtest.md`：完成后记录首版预览验收结果。

## 预计文件

- `assets/naval/battle/terrain_stamps/river_mouth_island_v1.png`
- `scripts/naval/core/BattleMap.cs`
- `scripts/naval/levels/LevelMapSpec.cs`
- `scripts/naval/levels/RandomMapGenerator.cs`
- `scripts/naval/presentation/NavalDeploymentController.cs`
- `scripts/naval/presentation/NavalGridView.cs`
- `tests/test_naval_terrain_stamp.gd`

## 验证证据

- `dotnet build ChangcheHeroes.csproj --no-restore`：通过，0 警告、0 错误。
- Godot headless `tests/test_naval_terrain_stamp.gd`：通过；抽查 48 个种子，印章均为一枚完整 `6×8` 地貌，避开布阵区和出口，河道逐行通至底部河口，地图连通。
- Godot Vulkan `tests/test_naval_terrain_stamp.gd`：通过；纹理导入、元数据、48 格覆盖与整图绘制均通过，预览保存到 `.godot/naval_terrain_stamp_preview.png`。
- Godot headless `tests/test_naval_scene_smoke.gd`：通过；既有海战布阵、出口与战斗场景未回归。

## 风格修订

- 根据首版实机预览，将素材升级为 `river_mouth_island_v2.png`：保留同一 `6×8` 逻辑掩码和源头—河口构图，只降低饱和度与写实微细节，并对齐 `sea_ink_pixel.png` 的灰青宣纸像素水墨语言。
- 第二版树冠使用成组墨团与阶梯像素轮廓，河水改为低饱和蓝灰，河口删除亮青色海水块并以稀疏横向墨纹透明渐隐。
- 首版 `v1` 保留作为对照与可回退素材；运行时切换到 `v2`，地图逻辑和测试契约不变。
- `v2` 通过 PNG 四角 Alpha 0 抽查、Godot 纹理导入、headless 专项测试和 Vulkan `1344×896` 实战预览；运行时未再出现棋盘格、矩形底色或亮青河口贴片。
