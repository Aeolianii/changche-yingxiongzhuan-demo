# CHG-20260814：海怪透明立绘与深水刷新区

- Status: done
- Date: 2026-08-14
- Owner: Codex

## Goal

清除三张海怪对话立绘的白色底图，并将“雾中可疑身影”限制在用户指定的三片宽广深水区刷新，避免贴近岛屿。

## Scope

- 将三张海怪对话立绘替换为保留本体细节的透明背景 PNG。
- 海怪随机事件只从三处指定的宽广海域锚点中抽取出生点。
- 海怪出生点使用比普通随机事件更大的清水碰撞安全半径。
- 三处锚点均不可用时不回退到岛屿附近的普通随机位置。
- 补充透明背景和深水出生规则的自动验证。

## Non-goals

- 不改变海怪雾影素材、动态雾效果、对话分支或奖励。
- 不改变茶商、私盐商和漂流木箱的刷新规则。
- 不修改岛屿碰撞轮廓或海图美术。

## Acceptance checks

- 三种海怪在对话框中均无白色方底，边缘透明且内部亮色细节保留。
- 海怪只会出现在三处指定深水区之一。
- 三处出生点都通过扩大后的清水碰撞检测，与岛屿保持明显距离。
- 初始抽取和事件补位共用同一套海怪深水刷新规则。
- 海怪及随机事件相关测试通过，并用实际渲染截图复核对话框。

## Documentation impact

- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `docs/production/backlog.md`
- 本变更记录。

## Likely files

- `assets/sea_overworld/portraits/海怪1.png`
- `assets/sea_overworld/portraits/海怪2.png`
- `assets/sea_overworld/portraits/海怪3.png`
- `scripts/sea_overworld.gd`
- `tests/test_sea_overworld_sea_monster_event.gd`
- 上述受影响文档。

## Verification evidence

- Godot 4.7.1 重新导入三张 PNG 成功。
- `tests/test_sea_overworld_sea_monster_event.gd` headless：通过；覆盖三种透明立绘四角、三处指定锚点、各锚点 `220` 单位清水半径、三种分支与奖励。
- `tests/test_sea_overworld_sea_monster_event.gd` Vulkan：通过；实际对话截图确认海怪 2 的白色方底已消失，地图截图确认雾影位于宽广水面。
- `tests/test_sea_overworld_random_event_refresh.gd`：通过；三槽上限、同会话单次触发和补位逻辑未回归。
- `tests/test_fubo_sea_round_trip.gd`：通过；伏波往返后重新抽取随机事件正常。
- `git diff --check`：通过。

## Actual changed files

- `assets/sea_overworld/portraits/海怪1.png`
- `assets/sea_overworld/portraits/海怪2.png`
- `assets/sea_overworld/portraits/海怪3.png`
- `scripts/sea_overworld.gd`
- `tests/test_sea_overworld_sea_monster_event.gd`
- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `docs/production/backlog.md`
- 本变更记录。
