# CHG-20260813：伏波古岭钓鱼永久可重复

- Status: done
- Date: 2026-08-13

## Goal

明确并锁定伏波古岭钓鱼循环：首次完成只负责把主线阶段推进到校场；此后玩家可无限次返回鱼竿重复游玩，每次完成获得的渔获都加入全局物品栏。

## Player-visible outcome

- 钓鱼小游戏从初次登岛起永久开放，不因首次完成、后续任务推进或伏波支线完成而关闭。
- 首次完成钓鱼后解锁校场阶段。
- 在校场、观景台或支线完成阶段重复钓鱼，退出后恢复进入前的任务阶段，不重复推进任务。
- 每次成功收竿都按本轮 `catches` 将黄花鱼、大石斑、青蟹或旧靴子累计到全局物品栏。

## Scope

- 复核伏波钓鱼完成与阶段恢复逻辑。
- 补充首次及重复完成的物品栏累计回归测试。
- 同步伏波玩法与经济系统的正式设计说明。

## Non-goals

- 不修改钓鱼小游戏的操作、计分、目标分或随机生成。
- 不限制钓鱼次数，不增加体力、鱼饵、冷却或仓库容量。
- 不调整鱼获售价或商城交易规则。

## Acceptance checks

- 首次完成钓鱼后阶段为 `DRUM_AVAILABLE`，本轮鱼获进入物品栏。
- 在 `DRUM_AVAILABLE` 再次完成钓鱼后阶段仍为 `DRUM_AVAILABLE`。
- 第二轮鱼获在已有库存上继续累加，鱼竿仍可再次交互。
- 伏波场景测试、钓鱼小游戏测试及相关经济测试通过。

## Documentation impact

- `docs/design/fubo-guling-slice.md`
- `docs/design/economy-merchant-harbor.md`
- 本变更记录

## Likely files

- `tests/test_fubo_guling.gd`
- 若回归测试暴露偏差：`scripts/fubo_guling/fubo_guling.gd`

## Verification evidence

- 2026-08-13：`Godot_v4.7-stable_win64_console.exe --path . --headless --script res://tests/test_fubo_guling.gd`，退出码 0；覆盖首次完成入库、重复完成阶段保持、库存累加及第三次仍可进入。
- 2026-08-13：`res://tests/test_fubo_fishing_game.gd`，退出码 0。
- 2026-08-13：`res://tests/test_economy_trade.gd`，退出码 0。
- 2026-08-13：`git diff --check`，退出码 0；无未解决合并文件。
- 回归测试首次即通过，确认远程阶段刷新与本地渔获入库的合并结果已具备目标行为；因此无需修改生产脚本。

## Changed files

- `docs/changes/CHG-20260813-repeatable-fubo-fishing.md`
- `docs/design/fubo-guling-slice.md`
- `docs/design/economy-merchant-harbor.md`
- `tests/test_fubo_guling.gd`
