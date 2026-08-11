# CHG-20260811：鼓令玩家准备阶段

- Status: done
- Date: 2026-08-11
- Owner: Codex

## Goal

消除鼓令示范结束后立即开始超时判定的问题，让玩家在理解规则并主动确认后才进入跟敲阶段。

## Player-visible outcome

- 每轮示范播放完毕后停在“准备阶段”，不计时、不判错、不会自动重播。
- 玩家点击“准备好了·开始跟敲”或按空格/回车后，显示 3、2、1 倒数。
- 倒数结束后鼓面和 A/S/D 开放；玩家的第一下鼓作为主动起拍，不检查等待时间。
- 从第二拍开始沿用现有节拍间隔和 `±280 ms` 通过窗口；按错或后续拍超时仍只重播当前轮。

## Scope

- 为鼓令场景加入明确的准备按钮和等待状态。
- 调整示范结束、键盘输入、第一拍计时、错误重播和失焦恢复的状态衔接。
- 更新鼓令专项测试与玩法验收文档。

## Non-goals

- 不修改三轮长度、随机序列、BPM、三鼓音色、视觉场景或评分规则。
- 不修改码头钓鱼、伏波地图或剧情门控。

## Acceptance checks

- 示范结束后等待至少 10 秒仍不增加错误、不重播、不改变轮次。
- 准备按钮和空格/回车都能启动 3、2、1 倒数。
- 倒数结束前鼓面与 A/S/D 不接受跟敲输入。
- 第一拍无等待超时；玩家主动击中正确鼓后，第二拍开始按既有时间窗判定。
- 按错或第二拍以后超时仍重播当前轮，并再次回到无限等待的准备阶段。
- 鼓令、伏波流程、钓鱼专项测试继续通过。

## Documentation impact

- `docs/design/fubo-guling-slice.md`：记录玩家主动开始与第一拍规则。
- `docs/qa/playtest.md`：加入示范后长时间等待和准备按钮验收。

## Likely files

- `scripts/fubo_guling/minigames/fubo_drum_minigame.gd`
- `scenes/fubo_guling/minigames/fubo_drum_minigame.tscn`
- `tests/test_fubo_drum_game.gd`

## Verification evidence

- Godot 4.7 stable editor import通过，新准备状态与场景节点无解析错误。
- `tests/test_fubo_drum_game.gd`：通过。测试将场景推进到准备状态并注入 10 秒处理跨度，错误数和轮次均不改变；准备按钮启动倒数；第一下正确鼓返回进度而非超时错误，并在该拍后才关闭首拍豁免。
- `tests/test_fubo_guling.gd` 与 `tests/test_fubo_fishing_game.gd`：通过，确认伏波剧情门控和码头钓鱼无回归。
- 非 headless OpenGL Compatibility 在 1344×896 捕获准备状态：准备按钮、三鼓、键位牌和“等待多久都不会判错”说明完整显示，无重叠或越界。
- 曾在首次导入时发现测试辅助函数缺少协程 `await`，已修复并重新执行全部测试；未把失败轮次计作通过证据。
- 当前会话未暴露 Godot AI MCP 调用工具；验证来自 Godot 4.7 引擎导入、专项状态测试与实际 OpenGL 渲染。

## Actual changed files

- `docs/changes/CHG-20260811-fubo-drum-ready-gate.md`
- `docs/design/fubo-guling-slice.md`
- `docs/qa/playtest.md`
- `scripts/fubo_guling/minigames/fubo_drum_minigame.gd`
- `scenes/fubo_guling/minigames/fubo_drum_minigame.tscn`
- `tests/test_fubo_drum_game.gd`
