# CHG-20260814：随机事件单次触发与三槽上限

- Status: done
- Date: 2026-08-14
- Owner: Codex

## Goal

把海上大地图的活动随机事件上限从两个提高到三个；同一种事件在一次海图会话内最多触发一次，并取消茶叶商人的固定优先刷新。

## Scope

- 每次创建或重新初始化海图时，从当前可用事件池随机抽取最多三个不同类型。
- 未完成的茶叶商、私盐商、漂流木箱和雾中海怪按同等候选参与抽取，不保证茶叶商出现。
- 茶叶商全局完成后继续从候选池排除，既有正式存档状态保持有效。
- 任一事件结算后，将其类型登记为本次海图会话已触发；补位时不得再次选择该类型。
- 补位只选择本次尚未触发且当前未激活的类型；没有候选时允许活动事件数量低于三个。
- 重新进入大地图后重建会话记录，各非永久完成事件可在新一轮抽取中再次出现。

## Non-goals

- 不改变四种随机事件的具体对话、选项、奖励、巡航或海怪表现。
- 不把本次海图的已触发类型写入正式存档或伏波返航上下文。
- 不保证任意特定事件每次进入海图都会出现。

## Acceptance checks

- 初始活动随机事件不超过三个且类型不重复。
- 未完成茶叶商不会固定占槽；确定性种子可以抽出不含茶商的三个事件。
- 任一事件结算后不会在同一次海图会话内再次生成。
- 补位优先保持三个活动槽；四种事件都已激活或结算后，槽位可自然减少。
- 重新进入海图后会话记录清空，非永久完成事件恢复抽取资格。
- 随机事件、茶商、私盐商、木箱与海怪相关测试通过。

## Documentation impact

- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `docs/production/backlog.md`
- 本变更记录。

## Likely files

- `scripts/sea_overworld.gd`
- `tests/test_sea_overworld_random_event_refresh.gd`
- `tests/test_sea_overworld_tea_merchant_event.gd`
- `tests/test_sea_overworld_salt_merchant_event.gd`
- `tests/test_sea_overworld_sea_monster_event.gd`
- 上述受影响文档。

## Verification evidence

- `tests/test_sea_overworld_random_event_refresh.gd`：通过；覆盖三槽初始抽取、茶商不保证出现、已触发类型集合、视野外补位、候选耗尽后槽位减少、重复补位不复活旧类型，以及重新入图清空会话记录。
- `tests/test_sea_overworld_tea_merchant_event.gd`：通过；茶商确定性入池、购买/拒绝、完成持久化和完成后其余三种事件填槽均正常。
- `tests/test_sea_overworld_salt_merchant_event.gd`：通过；三种选择、巡航表现和同会话禁止重刷均正常。
- `tests/test_sea_overworld_crate_event.gd`：通过。
- `tests/test_sea_overworld_sea_monster_event.gd`：通过；三种海怪分支在三槽规则下正常。
- `tests/test_fubo_sea_round_trip.gd`：通过；返航重新建立三个普通随机槽，不恢复上次会话记录。
- `tests/test_sea_overworld.gd` 的随机事件相关流程可以运行，但该综合套件仍在既有的海图碰撞节点数量、批准顶点/圆心与入口可达性断言处失败；本次未修改 `sea_overworld.tscn`、碰撞数据或这些断言。

## Actual changed files

- `scripts/sea_overworld.gd`
- `tests/test_sea_overworld_random_event_refresh.gd`
- `tests/test_sea_overworld_tea_merchant_event.gd`
- `tests/test_sea_overworld_salt_merchant_event.gd`
- `tests/test_sea_overworld_sea_monster_event.gd`
- `tests/test_fubo_sea_round_trip.gd`
- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `docs/production/backlog.md`
- 本变更记录。
