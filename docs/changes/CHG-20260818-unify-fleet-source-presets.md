# CHG-20260818：海战舰队来源统一为经济舰队 + 舰队/装备预设 + 弃用海战旧装备/舰队 UI

- 状态：`done`（未提交——整合版项目根目录非 git 仓库，仅 `.gitignore`）
- 日期：2026-08-18

## 目标

把海战（NavalDemo）布阵阶段的玩家舰队来源从「海战默认阵容」统一为「整合版经济舰队」：
玩家在 ship_screen 装配的装备、增减的舰船直接决定海战出战舰队；旧的海战布阵 F-5 装备面板与 V-7 舰队设计器弃用；
新增命名预设系统（保存/加载/删除），入口放在 ship_screen。

## 范围

- 舰型映射：economy `patrol_boat → frigate（护卫舰）`、`cannon_warship → flagship（旗舰）`、`escort_junk → merchant（商船）`；显示名称按海战模块。
- 舰队来源：自由模式（水师操演/自由部署）玩家舰队从 `economy_state` 读取玩家实际拥有的舰，映射为海战 `ShipState`（用海战 `ShipDefinition` 数值），装备按 economy `equipment` 装配海战 `WeaponCounts/SkillLoadout/ArmorLevel`；出战数量按战斗配置预设（默认 = 拥有数量，可在 ship_screen 增减，上限 = 拥有数量）。敌方保持默认 4 舰。
- 预设系统：命名预设保存「每舰型出战数量 + 每舰装备快照」到 `user://fleet_presets.json`，可保存/列表/载入/删除；「载入」= 设为下次战斗舰队（持久化活动预设）。入口在 ship_screen。
- 弃用：海战布阵 `Equip`（F-5 装备）与 `FleetConfig`（V-7 舰队配置）按钮及其两个面板，从部署场景与控制器中移除；装备配置统一走 ship_screen。
- 回归：随机遭遇 / 关卡 / 海盗战舰队来源不变（遭遇与关卡敌人侧不变）；headless 冒烟全绿。

## 非目标

- 不修改海战战斗规则、天气、技能播种（`SkillSeeding.Seed`）与装备数值。
- 不修改随机遭遇生成器 / 关卡定义的舰队装配。
- 不修改 economy 层装备/升级/造船规则。
- 不引入新依赖包（复用既有 `FleetPresetStore` 与 `user://` JSON 模式）。
- 不做战斗失败复活调整（I-6 另行处理）。

## 设计决策

- **跨语言互操作沿用既有模式**：GDScript（ship_screen）不能直接调用 C# 静态类，故预设持久化共用同一 JSON 文件与 schema（`{ "ActivePreset": "…", "Presets": [{ "Name", "Ships": [{ "ShipTypeId", "Equipment": { "Weapons", "Skills", "ArmorLevel" } }] }] }`）。GDScript 侧重写（保存/载入/删除 + UI），C# 侧重读（布阵装配 + 活动预设）。共享 schema 由跨语言往返测试锁住。
- **复用 `FleetPresetStore`**：其 schema（舰型 id + 装备字典）天然兼容 economy 舰型 id（patrol_boat 等）与同 ID 装备（weapons/skills id 两套一致）。在其上扩展 `ActivePreset` 持久化字段（旧文件缺省 → null，向后兼容）。
- **活动预设持久化**：`载入` 把预设名写入文件 `ActivePreset`；海战布阵 `_Ready` 从 store 读活动预设（不依赖已弃用的内存 `FleetPresetSession`）。返回菜单再进入仍沿用，符合「预设 = 战斗配置」语义。
- **装备口径**：economy `equipment.weapons/skills/armor_level` 直接搬运为海战 `WeaponCounts/SkillLoadout/ArmorLevel`（ID 一致，数量原样，不按海战槽位裁剪——忠实「按 economy 装备装配」；预设舰未存装备时回落该经济舰自身装备）。
- **出战数量上限**：每舰型出战数 ≤ 该舰型拥有数。无预设 → 出战全部经济舰；有预设 → 按预设顺序取对应舰型的舰（超出拥有数部分跳过）。
- **布阵摆放**：玩家舰队沿玩家区自动摆位（复用 `FindSpot` 确定性扫描，朝东），不占用默认阵型坐标；`恢复默认阵型` 对玩家侧重新执行该自动摆位。敌方沿用 `_enemyDefault`。
- **弃用旧 UI 采用删除而非隐藏**：部署场景删除 `Equip`/`FleetConfig` 按钮与 `EquipmentPanel`/`FleetPanel`；控制器删除 F-5/V-7 相关字段与方法（保留只读状态访问器供映射测试断言，保留 `FleetStore` 供活动预设读取）。标题路径 `FleetCommands/Title` 保留（既有冒烟断言其样式）。

## 验收检查

- 自由模式玩家舰队 = 经济舰队映射（默认 5 艘：p1 护卫舰、p2 旗舰、p3 商船、p4 护卫舰、p5 旗舰），装备与 economy 一致。
- ship_screen 预设：保存/列表/载入/删除往返一致；载入后进入海战，出战数量与装备按预设（上限=拥有数量）。
- 部署场景无 `Equip`/`FleetConfig` 按钮与旧面板；装备配置在 ship_screen。
- 随机遭遇/关卡/海盗战不回归；敌人侧不变。
- `dotnet build ChangcheHeroes.csproj -c Debug`：0 警告、0 错误。
- headless 冒烟（更新后 naval smoke + 新增映射/往返测试）全绿。

## 预计文件

- `docs/changes/CHG-20260818-unify-fleet-source-presets.md`（本记录）
- `docs/本地修改记录.md`
- `.superpowers/sdd/i3-report.md`
- `scripts/naval/levels/FleetPreset.cs`（`ActivePreset` 持久化）
- `scripts/naval/levels/EconomyFleetSource.cs`（新增：economy→海战映射 + 拥有数量校验）
- `scripts/naval/presentation/NavalDeploymentController.cs`（舰队来源改造 + 弃用 F-5/V-7 UI）
- `scenes/naval/NavalDeployment.tscn`（移除旧按钮与面板）
- `scripts/ui/ship_screen.gd`（预设面板 + user:// JSON 存取）
- `tests/test_naval_scene_smoke.gd`（更新为 5 舰经济舰队）
- `tests/test_economy_fleet_mapping.gd`（新增：映射/装备/数量）
- `tests/test_fleet_preset_roundtrip.gd`（新增：预设往返）

## 验证证据

- `dotnet build ChangcheHeroes.csproj -c Debug`：0 警告、0 错误（`ChangcheHeroes.dll` 生成成功）。
- headless 测试（`Godot_v4.7.1-stable_mono_win64_console.exe --headless --script`）：
  - `test_naval_scene_smoke.gd` → PASS（更新为 5 舰经济舰队 + 敌人 4 舰；逃跑/砲击命中/令牌组/旗舰镜头等断言全绿）
  - `test_economy_fleet_mapping.gd` → PASS（新增：默认映射/装备/数量；合法子集预设按预设出战并套用装备；超额预设回落全部拥有舰）
  - `test_fleet_preset_roundtrip.gd` → PASS（新增：保存/列表/载入/删除往返一致；共享 schema 写侧内容 + 海战布阵读侧消费跨语言闭环）
  - `test_ship_screen.gd` → PASS（既有 UI 回归，新增预设面板不破坏布局）
  - `test_naval_tutorial_hint.gd` / `test_naval_pirate_request.gd` / `test_sea_overworld_pirate_battle.gd` / `test_sea_overworld_pirate_return.gd` / `test_exploration_hud.gd` → PASS（遭遇/教程/海面入口回归）
- 与本次改动无关的既有失败：`test_sea_overworld`、`test_sea_overworld_entry_alignment`、`test_fubo_sea_round_trip`（海面大地图序列化/伏波导航问题，未引用任何改动文件，本次未触碰）。
