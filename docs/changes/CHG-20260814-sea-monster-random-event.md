# CHG-20260814：雾中海怪随机事件

- Status: done
- Date: 2026-08-14
- Owner: Codex

## Goal

把“雾中可疑身影”接入海上大地图随机事件池，并让每次进入海图重新抽取最多两个事件；茶叶商事件未完成时必须出现，私盐商船改用与海盗一致的间歇巡航节奏但不追逐玩家。

## Scope

- 每次创建海上大地图实例时重新抽取活动事件，不恢复上一次的事件类型、位置或私盐商巡航进度。
- 茶叶商完成状态写入全局世界状态并随正式存档保留；未完成时固定占用一个事件槽，完成后不再强制刷新。
- 漂流木箱、私盐商船与“雾中可疑身影”参与剩余槽位抽取；同一时刻活动事件最多两个，同类型最多一个。
- “雾中可疑身影”每次从三只海怪中随机选择一种地图雾影和立绘；提供“靠近查看 / 绕行”选项。
- 靠近后显示海怪立绘，并提供参考海霸天流程的默认胜利按钮；胜利后显示“战胜海怪”，发放木材与铁石各 `500`。
- 绕行或完成胜利结算都会移除当前事件，并在玩家当前视野外补充一个新事件。
- 私盐商船使用移动 `1.5–3.5` 秒、停驻 `0.8–1.8` 秒的循环巡航，保持在刷新点 `240` 世界单位内，不进行警戒、追逐或返航追敌。
- 使用 ImageGen 生成三张与现有海图一致的浓白雾、低对比淡黑海怪剪影素材，并通过边缘透明衰减作为海图触发物接入。

## Non-goals

- 不接入正式海怪战斗场景、战斗数值、掉落表权重或战后演出。
- 不修改海盗船的警戒、追逐、返航和战斗占位逻辑。
- 不改变茶叶商、私盐商与漂流木箱既有选项和奖励。
- 不增加随机事件配置后台或概率调节 UI。

## Acceptance checks

- 每次进入海图都重新抽取两个事件；事件类型或位置不会从上次海图实例、伏波返航上下文或场景快照恢复。
- 茶叶商未完成时必定出现，完成一次后全局状态和存档均记为完成，后续进入不再强制出现。
- 活动事件始终不超过两个；完成任一事件后在当前相机视野外补位。
- 私盐商船会按海盗相同时间区间交替移动与停驻，巡航不越出出生半径，也不会因玩家接近进入追逐。
- 三种海怪均有对应雾影地图素材和立绘；“靠近查看 / 绕行”文案准确。
- 靠近、默认获胜后显示战胜反馈，并真实增加木材 `500`、铁石 `500`；绕行不发放奖励。
- 相关 Godot 解析、随机刷新、私盐巡航、海怪分支、茶商完成持久化与存档测试通过。

## Documentation impact

- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `docs/production/backlog.md`
- 本变更记录。

## Likely files

- `scripts/sea_overworld.gd`
- `scripts/core/game_state.gd`
- `assets/sprites/sea_overworld/random_events/sea_monster_mist_1_v1.png`
- `assets/sprites/sea_overworld/random_events/sea_monster_mist_2_v1.png`
- `assets/sprites/sea_overworld/random_events/sea_monster_mist_3_v1.png`
- `tests/test_sea_overworld_random_event_refresh.gd`
- `tests/test_sea_overworld_salt_merchant_event.gd`
- `tests/test_sea_overworld_sea_monster_event.gd`
- `tests/test_main_flow_save.gd`
- 上述受影响文档。

## Verification evidence

- Godot 4.7.1 .NET headless editor import/parse: passed；三张新雾影资源与边缘衰减 shader 均成功导入。
- `tests/test_sea_overworld_sea_monster_event.gd`: passed（headless + Vulkan）；覆盖三种雾影/立绘映射、靠近揭示、绕行、默认胜利、结果文案、木材与铁石各 `500` 的真实入库，以及地图边缘融合截图。
- `tests/test_sea_overworld_random_event_refresh.gd`: passed；覆盖双槽上限、未完成茶商必出、完成后不强制、入图重抽、视野外补位，以及私盐商移动/停驻/对话暂停/不追逐状态。
- `tests/test_sea_overworld_tea_merchant_event.gd`、`test_sea_overworld_salt_merchant_event.gd`、`test_sea_overworld_crate_event.gd`: passed。
- `tests/test_fubo_sea_round_trip.gd` 与 `tests/test_fubo_travel_session.gd`: passed；返航保留船位、朝向、月相和迷雾，同时重新抽取事件。
- `tests/test_sea_overworld_pirate_chase.gd`: passed；海盗原有巡航、追逐、返航与占位战斗未回归。
- `tests/test_main_flow_save.gd` 中新增茶商世界状态正式存读档断言运行通过，但测试套件仍在后续既有“伏波支线任务投射”断言失败；该失败与本次事件状态无关，和修改前脏工作区基线一致。
- Vulkan 实景截图 `res://.godot/sea_overworld_monster_mist_preview.png` 已人工检查：浓雾可见、黑影为低对比剪影、边缘无方形接缝，接触前不暴露彩色海怪细节。

## Actual changed files

- `scripts/sea_overworld.gd`
- `scripts/core/game_state.gd`
- `shaders/sea_event_vignette.gdshader`
- `assets/sprites/sea_overworld/random_events/sea_monster_mist_{1,2,3}_v1.png`
- `assets/sea_overworld/portraits/海怪{1,2,3}.png`（使用用户提供素材）
- `tests/test_sea_overworld_sea_monster_event.gd`
- `tests/test_sea_overworld_random_event_refresh.gd`
- `tests/test_sea_overworld_{tea_merchant,salt_merchant,crate}_event.gd`
- `tests/test_fubo_sea_round_trip.gd`
- `tests/test_main_flow_save.gd`
- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `docs/production/backlog.md`
- 本变更记录。
