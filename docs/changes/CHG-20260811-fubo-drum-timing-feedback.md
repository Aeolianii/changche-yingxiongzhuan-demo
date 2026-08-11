# CHG-20260811：鼓令提前输入与节拍反馈

- Status: done
- Date: 2026-08-11
- Owner: Codex

## Goal

让玩家清楚知道鼓令为何失败，取消正确鼓的提前输入失败，并用可见节拍区间替代没有说明的普通进度条和突兀失败音。

## Player-visible outcome

- 正确鼓即使提前按下也算通过，显示“提前·通过”，不再因抢拍重播。
- 正拍显示暖金反馈，稍晚但仍在窗口内显示橙色“稍晚·通过”。
- 只有按错鼓或比目标拍点晚超过 520 ms 才失败；界面常驻显示这两条失败条件。
- 节拍条改为“提前通过 / 正拍 / 稍晚通过”三区色带和移动游标，玩家能看到当前时机。
- 失败提示明确区分“按错鼓”和“慢拍超时”；失败音换成短而轻的木质鼓槌提示。

## Scope

- 修改鼓令纯规则模型的时间判定和时机文字。
- 新增可视化节拍区间控件并接入示范、等待、输入和结果状态。
- 替换 `drum_fail.wav`，更新测试和玩法文档。

## Non-goals

- 不改变随机序列、三轮长度、BPM、三鼓主音色、准备按钮或首拍主动起拍规则。
- 不修改钓鱼、伏波地图或剧情流程。

## Acceptance checks

- 正确鼓在 `-1000 ms`、`-281 ms`、`-120 ms`、`0 ms`、`+280 ms` 和 `+520 ms` 均通过。
- 正确鼓在 `+521 ms` 失败；错误鼓在任何时机均失败。
- 界面显示三段颜色、移动游标和常驻失败规则，不能再把提前与超时混成同一条错误。
- 提前、正拍、稍晚三类成功输入有不同文字/颜色反馈。
- 失败音短于 0.3 秒、峰值低于主鼓且来自已登记的许可鼓样本处理。
- 鼓令、伏波流程和钓鱼专项测试继续通过。

## Documentation impact

- `docs/design/fubo-guling-slice.md`：更新时间窗、提前输入和失败规则。
- `docs/assets/fubo-guling-generated-assets.md`：登记失败提示音派生规则。
- `docs/qa/playtest.md`：加入边界值与可视反馈验收。

## Likely files

- `scripts/fubo_guling/fubo_drum_memory.gd`
- `scripts/fubo_guling/minigames/fubo_timing_meter.gd`
- `scripts/fubo_guling/minigames/fubo_drum_minigame.gd`
- `scenes/fubo_guling/minigames/fubo_drum_minigame.tscn`
- `assets/audio/fubo_guling/drum_fail.wav`
- `tests/test_fubo_drum_game.gd`
- `tests/test_fubo_guling.gd`

## Verification evidence

- TDD red phase: the focused drum test failed on `-1000 ms`, `-281 ms`, `+520 ms` and the new timing labels before the rule implementation; the scene contract then failed on the absent timing meter, labels, rule text and overly long failure cue.
- Godot 4.7 import registered `FuboTimingMeter` and reimported `drum_fail.wav` successfully. The headless editor emitted two pre-existing editor-dialog parenting errors while restoring its saved layout; these were not scene parser/resource failures.
- `test_fubo_drum_game.gd`: exit 0, `Fubo drum game verification passed.` It covers all documented timing boundaries, wrong-drum failure, the three-zone UI contract, persistent rule text, ready gate and failure-cue duration.
- `test_fubo_guling.gd`: exit 0, `Fubo Guling skeleton verification passed.` It retains the existing RID/ObjectDB cleanup warnings at process exit.
- `test_fubo_fishing_game.gd`: exit 0, `Fubo fishing game verification passed.`
- Runtime render at 1344×896 confirmed that the meter, three labels, rule text, ready button, drum stage, controls and status panel fit without overlap. Review capture: `C:\Users\wangk\AppData\Local\Temp\fubo_drum_timing_feedback.png`.
- `drum_fail.wav`: 0.23 seconds, measured peak `-7.3 dB`, SHA-256 `BBE385E80828E1B0F86BF5D48847303D8CD19195289487C14E1A94E9EA11FDCE`.

## Actual changed files

- `docs/changes/CHG-20260811-fubo-drum-timing-feedback.md`
- `docs/design/fubo-guling-slice.md`
- `docs/assets/fubo-guling-generated-assets.md`
- `docs/qa/playtest.md`
- `scripts/fubo_guling/fubo_drum_memory.gd`
- `scripts/fubo_guling/minigames/fubo_timing_meter.gd`
- `scripts/fubo_guling/minigames/fubo_drum_minigame.gd`
- `scenes/fubo_guling/minigames/fubo_drum_minigame.tscn`
- `assets/audio/fubo_guling/drum_fail.wav`
- `tests/test_fubo_drum_game.gd`
