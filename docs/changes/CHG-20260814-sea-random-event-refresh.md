# CHG-20260814：海上随机事件双槽刷新

- Status: done
- Date: 2026-08-14
- Owner: Codex

## Goal

把海上大地图的茶叶商、私盐商与漂流木箱改为最多同时存在两个的动态随机事件，并让私盐商船在刷新点附近持续小范围巡航。

## Scope

- 玩家首次进入海上大地图时固定生成茶叶商船，并在私盐商船与漂流木箱中随机生成一个。
- 三种事件共用两个活动槽位；任一事件完整结算后移除旧实例，并在玩家当前视野外补充一个未激活类型，使活动事件数恢复为两个。
- 同一事件类型可在后续轮换中再次刷新，每次刷新只允许一个同类型实例。
- 私盐商船围绕本次刷新点做小范围平滑巡航，进入事件对话后停止移动。
- 保存、读取与伏波古岭往返保留当前两个活动事件的类型和位置；旧版一次性完成状态按新双槽规则兼容恢复。

## Non-goals

- 不增加新的事件剧情、事件类型、掉落表或概率权重配置界面。
- 不改变茶叶、私盐与木箱既有对话选项和单次结算数值。
- 不修改海盗船刷新、追逐、战斗占位或海图迷雾规则。
- 不让随机事件在同一时刻出现超过两个，也不允许同类型重复占用两个槽位。

## Acceptance checks

- 新海图实例恰有两个随机事件，且必有茶叶商船，另一个为私盐商船或漂流木箱。
- 任一事件完整结算后，已结算实例消失，活动事件总数仍为两个。
- 补充事件的刷新点位于玩家当前相机视野之外。
- 任一时刻每种事件最多一个实例，总活动事件最多两个。
- 私盐商船会离开刷新点持续移动，但始终保持在刷新点 120 世界单位以内；对话期间不移动。
- 当前两个活动事件经正式存档读取和伏波古岭往返后保持类型与位置，不重复生成。
- 三类事件既有分支测试、大地图基础测试与新增双槽刷新测试通过。

## Documentation impact

- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `docs/production/backlog.md`
- 本变更记录。

## Likely files

- `scripts/sea_overworld.gd`
- `tests/test_sea_overworld_random_event_refresh.gd`
- `tests/test_sea_overworld_crate_event.gd`
- `tests/test_sea_overworld_tea_merchant_event.gd`
- `tests/test_sea_overworld_salt_merchant_event.gd`
- `tests/test_fubo_sea_round_trip.gd`
- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `docs/production/backlog.md`

## Verification evidence

- Godot 4.7.1 .NET headless editor import/parse: passed.
- `tests/test_sea_overworld_random_event_refresh.gd`: passed; verified fixed tea merchant, deterministic second event, maximum two unique slots, off-screen refill, salt patrol radius/dialogue pause, and event-state type/position restoration.
- `tests/test_sea_overworld_crate_event.gd`: passed for salvage, ignore and legacy resolved-state restore.
- `tests/test_sea_overworld_tea_merchant_event.gd`: passed for purchase, decline and legacy resolved-state restore.
- `tests/test_sea_overworld_salt_merchant_event.gd`: passed for confiscate, bribe, release, 120-unit clear-water patrol and legacy resolved-state restore.
- `tests/test_fubo_sea_round_trip.gd`: passed; verified the two active event types survive the real island round trip without duplication.
- `tests/test_fubo_travel_session.gd`: passed.
- `tests/test_sea_overworld.gd` was also run but remains blocked by pre-existing scene collision edits in the dirty worktree: the serialized 32-blocker baseline and many approved vertices/radii do not match. This change does not edit `sea_overworld.tscn` or collision data.
- `tests/test_main_flow_save.gd` was also run but remains blocked by the pre-existing Fubo side-task projection assertion. The event-state restore path is covered by the new focused suite and the Fubo round-trip suite.

## Actual changed files

- `scripts/sea_overworld.gd`
- `tests/test_sea_overworld_random_event_refresh.gd`
- `tests/test_sea_overworld_crate_event.gd`
- `tests/test_sea_overworld_salt_merchant_event.gd`
- `tests/test_fubo_sea_round_trip.gd`
- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `docs/production/backlog.md`
- 本变更记录。
