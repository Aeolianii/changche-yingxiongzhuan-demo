# 伏波任务归档与南海军港返航修复

- Status: done
- Date: 2026-08-13

## Goal

修复伏波古岭完成任务仍出现在“进行中”，以及玩家离开大地图进入其他地点再返回后无法从南海军港回到 Scene2 的问题。

## Scope

- 任务页重复接管海图/伏波上下文时，继续按世界状态把已完成的伏波任务投影到“已完成”分页。
- 南海军港始终作为 Scene2 的返航入口，不依赖只在首次从 Scene2 出海时存在的瞬态标记。
- 返回 Scene2 后直接恢复操练完成后的稳定阶段，不重播士兵巡视、军官复命、县令首次会谈或水师操练。
- 增加针对任务上下文重置和入口标记丢失情形的回归检查。

## Non-goals

- 不改动伏波古岭任务步骤、小游戏和完成条件。
- 不改动 Scene2 的首次巡视与操练流程。
- 不增加新的存档字段或修改存档版本。

## Acceptance checks

- 伏波进度达到阶段 4 后，任务不在“进行中”，并出现在“已完成”；重新设置任务上下文后结果不回退。
- 即使海图实例已不再保留首次 Scene2 入口标记，点击南海军港仍能返回 Scene2。
- 返回后的 Scene2 任务为“探索海域，完善海图”，阶段为 5，且不播放到达对白或重新操演。
- `test_fubo_side_quest_flow.gd` 与 `test_scene_two_sea_link.gd` 通过。

## Documentation impact

- 更新 `docs/design/scene-flow.md` 和 `docs/tech/architecture.md`，明确军港返航不依赖海图瞬态来源标记，以及任务归档在 HUD 上下文重置后仍保持。

## Likely files

- `scripts/ui/quest_screen.gd`
- `scripts/sea_overworld.gd`
- `tests/test_fubo_side_quest_flow.gd`
- `tests/test_scene_two_sea_link.gd`
- `docs/design/scene-flow.md`
- `docs/tech/architecture.md`

## Verification evidence

- 2026-08-13：`Godot_v4.7.1-stable_mono_win64_console.exe --headless --path . --script res://tests/test_fubo_side_quest_flow.gd` 通过；覆盖伏波完成归档、重新设置海图任务上下文后仍保持在“已完成”、不回到“进行中”。
- 2026-08-13：`Godot_v4.7.1-stable_mono_win64_console.exe --headless --path . --script res://tests/test_scene_two_sea_link.gd` 通过；测试主动清除海图的首次出海来源标记后，南海军港仍返回 Scene2，并验证任务阶段 5、两名士兵汇报完成、无到达对白、任务目标保持为海域探索。
- 2026-08-13：`git diff --check` 通过；未修改工作区已有的 Godot `.import` 变更。
