# CHG-20260822：海战敌舰四方向素材更新

- Status: done
- Type: content
- Date: 2026-08-22

## 目标

用用户提供的两张互补船只四视图替换海战中敌方运输船、护卫舰和旗舰的四方向运行时贴图，使敌舰转向后显示对应船头、船尾或侧视形象，不再使用旧敌舰素材。

## 范围

- 替换 `enemy_transport_*`、`enemy_frigate_*`、`enemy_flagship_*` 共 12 张方向贴图。
- 第一张素材使用左侧侧视列和右侧端视列；第二张素材使用右侧侧视列和左侧端视列。
- 源图第一、二、四行分别映射运输船、护卫舰、旗舰。
- 保持 `NavalShipView` 的动态资源路径、战场占格、朝向规则、HUD 舰况卡和玩法不变。

## 非目标

- 不使用两张源图中间的木质甲板俯视列。
- 不接入第三行大型白帆商船，不新增船型。
- 不修改玩家舰船、海怪、鱼群、要塞、炮台或大地图船只素材。
- 不修改舰船数值、碰撞、移动、转向、攻击和 AI。

## 验收检查

- [x] 三种敌舰的 `e/s/w/n` 共 12 张贴图均可由 Godot 加载，背景透明且不存在俯视甲板图。
- [x] 东西方向为互补侧视，南北方向为互补端视，转向后贴图随朝向正确切换。
- [x] 默认海战镜头下三种敌舰仍完整落在既有逻辑占格内，旗帜、船帆和船体不被裁断。
- [x] Godot 资源导入、C# 构建和海战专项 smoke test 通过。

## 验证证据

- Godot 4.7.1 .NET 重新导入 12 张 PNG：通过，退出码 `0`。
- `dotnet build ChangcheHeroes.csproj --no-restore --nologo`：通过，`0` 警告、`0` 错误。
- Godot headless `tests/test_naval_scene_smoke.gd`：通过，确认海战场景、敌舰队生成与运行时资源加载未回归。
- Godot headless/windowed `tests/test_enemy_ship_directional_assets.gd`：直接加载并渲染三船型四方向资源，检查透明边距、有效像素和方向长宽比。
- PNG 合同检查：12 张贴图均有有效 Alpha；东/西贴图宽大于高，南/北贴图高大于宽；透明边距完整。
- 四方向总览检查：三种船型的旗帜、船帆和船体均完整，未出现中间木质甲板俯视图或相邻行残片。
- 窗口 smoke 在既有“点击逃跑格触发逃跑”断言处连续两次失败；该断言发生在敌舰素材加载之后，headless 同脚本通过，本次未修改逃跑、输入或移动代码。

## 方向修正（2026-08-22）

- 用户实机确认敌军三格旗舰的舰艏、舰尾与逻辑朝向相反。
- 已对调 `enemy_flagship_e/w` 与 `enemy_flagship_n/s` 的贴图内容；仅修正旗舰四方向标签，不改占格、位置、数值或其他船型素材。
- 重新运行方向素材专项测试与海战场景 smoke，确认四张资源可加载且战斗场景无回归。
- 用户随后确认敌军一格运输船也存在相同问题；已对调 `enemy_transport_e/w` 与 `enemy_transport_n/s`，护卫舰方向保持不变。

## 最终核对

- Files changed: `assets/naval/battle/ships/enemy_{transport|frigate|flagship}_{e|s|w|n}.png`、`tests/test_enemy_ship_directional_assets.gd`、`docs/design/art-direction.md`、`docs/qa/playtest.md`、本变更记录。
- Limitations/follow-ups: 源图第三行大型白帆商船没有对应当前运行时敌舰类型，按范围保留未接入；窗口 smoke 的逃跑格时序失败作为既有测试问题单独处理。
