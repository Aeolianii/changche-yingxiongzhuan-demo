# 海上大地图生产落地 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 以 `sea_overworld_stage1_graybox_v4.png` 为构图唯一依据，制作并接入四分块生产大地图，使 16 个地点、碰撞、入口、海图和现有航行交互全部与新画面一致。

**Architecture:** 保留现有 Godot 4.7.1 的 A/B/C/D 二乘二分块、每块 `2508×1412` 世界单位和 `120` 世界单位重叠带。美术先完成一张统一母图，再按 `160` 源像素重叠裁成四张 `3344×1882` PNG，以确保接缝一致；运行时继续由 `sea_overworld.gd` 构建背景、地点、碰撞与海图数据。

**Tech Stack:** Godot 4.7.1、GDScript、PNG、Python/Pillow（确定性裁图与接缝检查）、现有地图接缝 shader。

---

## 锁定范围

- v4 的岛屿体量、位置、南北气质、中央堡垒和朝左的月环商港全部锁定，不再重新构图。
- 地点分布固定为 A4、B5、C4、D3；B 是右上群岛水战区，D 是右下敌方核心海域。
- 保留当前自由航行、地点进入提示、海上事件、场景二往返、月相和完整海图功能。
- 不增加天气、洋流、暗礁伤害、潮汐玩法、实际登岛场景或海战切换。
- v1～v4 草图继续作为历史记录；生产底图使用新文件名，不覆盖草图和旧生产图。
- 母图与生成中间稿保存在仓库外的 `D:\厂车英雄传DEMO\artwork\sea_overworld\`，不提交或推送；仓库只保存最终四张运行时分块。

## 文件清单

**新增生产资源**

- `assets/backgrounds/sea_overworld/guangdong_sea_zone_a_v3.png`
- `assets/backgrounds/sea_overworld/guangdong_sea_zone_b_v3.png`
- `assets/backgrounds/sea_overworld/guangdong_sea_zone_c_v3.png`
- `assets/backgrounds/sea_overworld/guangdong_sea_zone_d_v3.png`
- 上述 PNG 对应的 Godot `.import` 文件

**新增工具与记录**

- `tools/slice_sea_overworld_map.py`
- `docs/changes/CHG-20260809-sea-overworld-production-map.md`

**修改**

- `scripts/sea_overworld.gd`
- `scenes/sea_overworld/sea_overworld.tscn`
- `tests/test_sea_overworld.gd`
- `docs/design/sea-overworld-design.md`
- `docs/assets/sea-overworld-stage1-layout.md`
- `docs/assets/sea-overworld-generated-assets.md`
- `docs/qa/playtest.md`

## Task 1：锁定生产规格与变更记录

- [x] 创建 `docs/changes/CHG-20260809-sea-overworld-production-map.md`，记录目标、范围、非目标、验收项、文件清单和风险，状态设为 `in-progress`。
- [x] 将 `docs/design/sea-overworld-design.md` 的当前阶段更新为“v4 构图生产落地”，明确 B/D 正确职责、四分块尺寸、接缝和 16 地点不变。
- [x] 在 `docs/assets/sea-overworld-stage1-layout.md` 增加生产落图状态与坐标容差：地点中心允许相对草案最多 `±80` 世界单位，入口触发必须对准可见码头或登陆口。
- [x] 提交文档基线：`docs(sea-map): define production map rollout`。

## Task 2：制作统一母图与四张生产分块

- [x] 以 `assets/backgrounds/sea_overworld/concepts/sea_overworld_stage1_graybox_v4.png` 为构图参考，制作 `6528×3604` 的统一生产母图；只提升岛屿、港口、海岸和海面完成度，不移动主要地点。
- [x] 保持北部繁华港贸、南部蛮荒军事、中央沉船与微型礁石；月环商港开口和主码头必须朝左，沧门礁堡保持中央偏右。
- [x] 创建 `tools/slice_sea_overworld_map.py`，固定输出以下四个裁剪区：

  | 分块 | 母图裁剪矩形 `(x, y, w, h)` | 运行时原点 |
  |---|---|---|
  | A | `(0, 0, 3344, 1882)` | `(0, 0)` |
  | B | `(3184, 0, 3344, 1882)` | `(2388, 0)` |
  | C | `(0, 1722, 3344, 1882)` | `(0, 1292)` |
  | D | `(3184, 1722, 3344, 1882)` | `(2388, 1292)` |

- [x] 脚本保存四张 RGB/RGBA PNG，并逐像素验证 A/B、A/C、B/D、C/D 的 `160` 像素重叠带完全一致；任一接缝不一致时退出码为 1。
- [x] 将最终分块写入四个 `*_zone_[a-d]_v3.png` 文件，运行 Godot 导入，确认每张为 `3344×1882`，无缺图、透明黑边或错误色彩空间。
- [x] 拼回全图做一次原始分辨率检查，重点确认：中央不再空、右上地标不竞争、四条跨区水门清楚、岛链不是等距路径线。
- [x] 在接入代码前设置视觉检查点；只处理局部接缝或明显生成瑕疵，不再改变 v4 构图。
- [x] 提交生产资源与裁图工具：`feat(sea-map): add v4 production map chunks`。

## Task 3：接入新底图并校准区域职责

- [x] 在 `scripts/sea_overworld.gd` 将 `BASE_MAP_TEXTURE`、`EAST_MAP_TEXTURE`、`C_MAP_TEXTURE`、`D_MAP_TEXTURE` 改为语义清楚的 `A_MAP_TEXTURE`、`B_MAP_TEXTURE`、`C_MAP_TEXTURE`、`D_MAP_TEXTURE`，分别预加载四张 v3 分块。
- [x] 保持 `MAP_CHUNK_SIZE = Vector2(2508, 1412)`、`MAP_CHUNK_OVERLAP = 120.0`、四个原点和现有混合 shader 不变。
- [x] 在 `scenes/sea_overworld/sea_overworld.tscn` 同步替换四个背景节点的纹理资源，避免场景序列化资源与运行时 preload 不一致。
- [x] 将 16 个地点更新为已批准坐标：

  | 区域 | 地点与世界坐标 |
  |---|---|
  | A | 南海军港 `(1080,650)`；川山渔村 `(480,1040)`；东湾水寨 `(2040,520)`；青屿秘境 `(1760,950)` |
  | B | 沧门礁堡 `(2780,1080)`；月环商港 `(3650,360)`；雾岚群岛 `(3070,850)`；伏波古岭 `(4260,780)`；珊湾渔链 `(3670,1150)` |
  | C | 澄海灯岛 `(480,1680)`；龙门海寨 `(860,2260)`；白沙渔岛 `(1460,2460)`；玄潮古屿 `(2100,2240)` |
  | D | 红湾卫所 `(2980,1760)`；东极秘岛 `(3730,2110)`；南澳商港 `(4380,2460)` |

- [x] 入口触发按可见登陆方向设置：月环商港使用朝左的矩形触发区；港城、堡垒使用码头侧矩形触发；无人岛和分散礁群使用小范围圆形触发。
- [x] 校准 `SOUTH_SEA_HARBOR_SPAWN` 到南海军港外侧可航水面，保证从场景二进入时不压入海岸碰撞，并仍自动激活南海军港提示。
- [x] 更新 `_configure_sea_map_hud()` 的四分块纹理，使完整海图与主场景使用同一套 A/B/C/D 资源和地点坐标。
- [x] 将玩家船体、尾流和侧浪由 `0.34` 缩至 `0.28`，Q 版人物由 `0.105` 缩至 `0.088`，同步收紧碰撞与甲板、尾流锚点，使大地图观感更开阔且切换航行状态时不跳位。

## Task 4：重做岛屿碰撞与航路留白

- [ ] 以生产底图的世界坐标重新描绘西北大陆海岸 `CollisionPolygon2D`，保留海湾入口与沿岸航道。
- [ ] 为 16 个主要地点建立贴合轮廓的复合圆形或多边形阻挡，不用一个过大的圆覆盖港池、码头入口或岛间海峡。
- [ ] 为不可进入山岛、礁群和中央微型礁石只添加必要阻挡；背景中的沉船保持视觉元素，不新增玩法或伤害。
- [ ] 检查四条必通路线：A→B、A→C、B→D、C→D；中央堡垒上下、左右都必须可绕行，连续可航水门宽度不少于约 `480` 世界单位。
- [ ] 将两艘事件船和漂流事件移到明确水面，避免与新岛屿碰撞、地点触发或场景二出生点重叠。
- [ ] 手工驾驶完成北线、南线和中央横穿三次 smoke test，确认没有隐形墙、穿岛、死胡同或摄像机越界。

## Task 5：更新针对性测试和视觉验收

- [ ] 修改 `tests/test_sea_overworld.gd` 的资源断言，要求四张 v3 分块存在、尺寸正确，并继续验证 A/B/C/D 背景节点序列化完整。
- [ ] 将旧 `_verify_east_expansion()` 与 `_verify_d_expansion()` 的职责改为新布局：B 断言 5 个右上地点且 `y < 1292`，D 断言 3 个右下地点且 `y > 1292`；C 仍为 4 个，A 仍为 4 个。
- [ ] 增加 16 个地点名称、批准坐标容差 `±80`、月环商港左侧入口、南海军港出生点不碰撞的断言。
- [ ] 增加水路探针：四条接缝入口、中央十字水门、B 区宽航道和 D 区终局港外水面必须无静态碰撞；所有主要岛中心必须有静态碰撞。
- [ ] 保留地点主动进入、事件自动触发、海图、月相、存档恢复和场景二往返的现有回归断言。
- [ ] 运行针对性测试：

  ```powershell
  & 'D:\Programs\Godot-4.7.1-dotnet\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --script res://tests/test_sea_overworld.gd
  ```

  预期：退出码 `0`，输出 `Sea overworld runtime verification passed.`。

- [ ] 运行一次有窗口 OpenGL Compatibility 测试，生成 A、B、C、D、中央接缝和完整海图截图；逐张检查接缝、地点标签、入口方向、船只可达性和视觉层级。
- [ ] 提交运行时与测试：`feat(sea-map): integrate v4 production layout`。

## Task 6：文档收口与最终提交

- [ ] 在 `docs/assets/sea-overworld-generated-assets.md` 登记四张生产分块的尺寸、用途、生成方式和 SHA-256。
- [ ] 将 `docs/assets/sea-overworld-stage1-layout.md` 状态改为“生产落图完成”，记录最终地点坐标、入口方向和碰撞校准差异。
- [ ] 更新 `docs/qa/playtest.md`，加入北线、南线、中央通航、16 个地点交互和完整海图检查项。
- [ ] 在变更记录中填写实际文件、自动测试结果、截图检查结果和已知限制，所有验收项通过后将状态改为 `done`。
- [ ] 运行 `git diff --check`，确认只暂存本计划列出的文件，并提交：`docs(sea-map): finalize production map rollout`。
- [ ] 不推送远端；等待用户明确授权后再处理 GitHub。

## 完成标准

- 四张生产分块在游戏和完整海图中无明显接缝，A/B/C/D 职责与 v4 一致。
- 16 个地点标签、入口和占位提示全部落在对应岛屿，不存在 B/D 旧布局残留。
- 玩家可完整走通北线、南线和中央水门，不穿岛、不被隐形碰撞卡死。
- 月环商港朝左，中央沧门礁堡降低留白，右上保持清楚主次层级。
- `tests/test_sea_overworld.gd` 通过，并完成原始分辨率截图检查。
