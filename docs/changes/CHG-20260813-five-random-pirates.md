# 大地图五艘随机海盗船

- Status: done
- Date: 2026-08-13

## Goal

每次玩家进入海上大地图时重新随机生成 5 艘海盗船，让海盗分散在不同可航海域，同时保持南海军港附近安全。

## Scope

- 每个大地图场景实例随机生成 5 艘海盗船。
- 出生点必须位于可航水面，与南海军港至少相距 700 像素。
- 海盗出生点之间至少相距 460 像素，避免集中在同一小片海域。
- 海盗出生位置和运行状态不写入存档或跨场景上下文；离开并再次进入大地图时创建新的随机分布。

## Acceptance checks

- 大地图生成且仅生成 5 艘海盗船。
- 所有海盗出生点均在南海军港安全区外。
- 任意两艘海盗出生点距离不少于 460 像素。
- 重新实例化大地图后仍生成 5 艘海盗，且分布重新随机。
- 海盗追逐针对性测试与 `git diff --check` 通过。

## Likely files

- `scripts/sea_overworld.gd`
- `tests/test_sea_overworld_pirate_chase.gd`
- `docs/design/sea-overworld-design.md`

## Verification evidence

- `test_sea_overworld_pirate_chase.gd`：连续 3 次通过；每轮均实例化两次大地图，覆盖每次生成 5 艘、重新随机、军港 700 像素安全区和海盗间 460 像素最小间距。
- `test_sea_overworld_spawn.gd`：通过，确认大地图基础出生流程未回归。
- `git diff --check`：通过。
