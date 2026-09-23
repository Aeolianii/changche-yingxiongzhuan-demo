# CHG-20260923：海战返回保留海图主线对话状态

- Status: done
- Type: bugfix
- Date: 2026-09-23

## 目标与范围

- 修复已确认“前方已近倭寇营地”警告后，进入海盗战再返回海上大地图却重复触发警告的问题。
- 海盗战及海怪讨伐战返回时，在结算推进探索阶段之前恢复 `GameState` 中的海图主线状态。

## 非目标

- 不改变对话内容、触发半径、战斗结算、随机事件生成或正式存档格式。

## 验收与文档影响

- 已确认的倭寇警告在海盗战胜败返回、海怪讨伐战返回后仍被确认，触发区不再重建；未确认的警告仍可正常触发。
- 返回位置、结算与任务阶段仍按原有规则运行。
- 更新 `docs/design/sea-overworld-design.md` 的战斗返回规则。
- 预计修改：`Scripts/sea_overworld.gd`、针对性回归测试、本记录、海图设计文档。

## 验证证据

- 根因：`SeaOverworld._ready()` 在普通进图时恢复 `GameState.sea_main_quest`，但海盗战和讨伐战返回分支跳过恢复；结算中的 `_advance_exploration_stage(4)` 随后把默认 `false` 警告标志覆盖写回全局状态。
- 两条战斗返回分支现均先调用 `_restore_sea_main_quest_state()`，再执行原有结算；已确认的警告会移除触发区，原战斗位置和奖励逻辑不变。
- Godot 4.7.1 .NET headless：`tests/test_sea_overworld_battle_return_quest_state.gd` 通过，覆盖海盗胜利、海盗失败、海怪讨伐失败三种返回；`tests/test_wokou_main_quest_flow.gd` 通过，确认未触发时警告仍可正常进行。
- 现有 `tests/test_sea_overworld_pirate_return.gd` 的复活点断言失败：运行时选择可航点 `(3593.442, 424.8072)`，距离旧测试期望 `(3650, 360)` 超过 40 像素。该测试两次结果相同，失败涉及既有 `_find_navigable_position` 和地图碰撞，不属于本次主线状态修复；本次未更改复活逻辑。
