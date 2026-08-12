# CHG-20260812：恢复海图迷雾与海上随机事件

- Status: in-progress
- Date: 2026-08-12
- Owner: Codex

## Goal

把主分支历史中已经完成的海图永久探索迷雾，以及漂流木箱、龙井茶商和私盐商事件，兼容移植到当前伏波古岭版本。

## Scope

- 航行视野揭示、世界迷雾遮罩与完整海图迷雾显示。
- 迷雾跨场景运行时保留、正式单槽存档和旧存档回退。
- 漂流木箱一次性双选项事件及完成状态存档。
- 龙井茶商和私盐商双选项事件、临时银钱结算与重复触发规则。
- 随机事件期间锁定航行、隐藏地图入口，结束后恢复当前全局 HUD。
- 保留当前伏波古岭登岛/返航、全局探索 UI、点击移动和对话移动锁。

## Non-goals

- 不合并主分支中与本需求无关的地点改名、碰撞重排、出生点调整或场景删减。
- 不建立完整背包、经济或随机刷新系统；事件沿用历史提交中的原型级临时数值。
- 不改变伏波古岭小游戏与岛内存档格式。

## Acceptance checks

- 从县令进入海图后，初始视野与左上大陆已揭示，视野外海域为黑色迷雾。
- 航行持续揭示矩形相机视野；完整海图与世界使用同一探索数据，未探索地点不显示。
- 迷雾跨 Scene2/伏波古岭往返保留，并能随正式存档恢复；旧存档仍可读取。
- 三类事件均能触发对应纸质对话；事件期间船只不能移动，结束后恢复。
- 木箱任一分支后永久移除；商人事件按历史规则可再次接触。
- 大地图、迷雾、三事件、存档、县令往返和伏波往返的针对性测试通过。

## Documentation impact

- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- 本变更记录。

## Likely files

- `scripts/sea_overworld.gd`
- `scripts/sea_fog_of_war.gd`
- `scripts/core/game_state.gd`
- `scripts/exploration_hud.gd`
- `scripts/sea_map_screen.gd`
- `scripts/ui/field_event_dialogue.gd`
- `scenes/ui/field_event_dialogue.tscn`
- `assets/sprites/sea_overworld/`
- `shaders/sea_map_fog_soften.gdshader`
- `tests/test_sea_fog_*.gd`
- `tests/test_sea_overworld_*event.gd`

## Verification evidence

Pending implementation.

