# CHG-20260810-fubo-canal-visual-exit-fix

- Status: done
- Type: minigame visual / UI interaction fix
- Owner: Project owner
- Created: 2026-08-10

## Goal and player-visible outcome

将“三渠引水”从只有绿色底板和文字按钮的功能原型，改为具备明确像素场景表现的完整小游戏界面。玩家能直接看到来水口、石渠、三道闸门、水流方向、当前蓄水量和目标水位；点击右上“暂时离开”或按 `Esc` 能可靠返回伏波古岭地图。

## Scope

- 使用已选伏波古岭背景作为全屏环境底图，并增加暗色遮罩保证玩法信息清晰。
- 为 `CanalDrawing` 增加代码绘制的像素风石渠、闸门、水流、蓄水池、目标线、选中高亮和封闭支渠标识。
- 水流画面与三渠目标、当前水量、封闭支渠和当前选择实时同步。
- “暂时离开”改为单击直接退出；`Esc` 同样直接退出。
- 修正共享 `MinigameHost`、水渠根节点和军鼓根节点错误的 `PROCESS_MODE_WHEN_PAUSED`；宿主并未暂停 SceneTree，因此三者统一改为 `PROCESS_MODE_ALWAYS`，保证两个小游戏都能接收真实输入。
- 更新水渠专项测试，覆盖可见绘图区和退出信号。

## Non-goals

- 不改变三轮题目、可解配置、评价、随机规则或军鼓玩法。
- 不增加复杂流体物理、粒子模拟或新的地图场景。
- 不重新生成伏波古岭主背景。

## Acceptance checks

- [x] 水渠小游戏中间区域不再空白，石渠、三条支渠、三块蓄水池和水流清晰可见。
- [x] 切换支渠、放水、封闭支渠和水位变化都有可见反馈。
- [x] 1344×896 下文字、按钮和玩法图形不重叠、不越界。
- [x] 点击“暂时离开”只需一次操作即可返回地图。
- [x] 按 `Esc` 可以返回地图。
- [x] Godot MCP 指定场景截图、运行日志和水渠/承载窗口测试通过。
- [x] 完整地图承载状态下，水渠根节点、绘图区和按钮均为 `can_process=true`，真实鼠标点击能够改变选择、放水并离开。
- [x] 军鼓根节点在完整地图承载状态下同样为 `can_process=true`，键盘输入不再被处理模式阻断。
- [x] 界面直接显示“①选渠 → ②放水 → ③达到目标水位”的操作说明，并解释目标、封闭支渠和失败重置。

## Documentation impact

- `docs/design/fubo-guling-slice.md`
- `docs/qa/playtest.md`

## Likely files

- `scenes/fubo_guling/minigames/fubo_canal_minigame.tscn`
- `scripts/fubo_guling/minigames/fubo_canal_minigame.gd`
- `scripts/fubo_guling/minigames/fubo_canal_board.gd`
- `tests/test_fubo_canal_game.gd`

## Verification evidence

- Baseline Godot MCP screenshot confirmed that `CanalDrawing` occupies 780×280 but renders no content; only the flat green background, labels and buttons are visible.
- Runtime signal inspection confirmed the exit button has one connection and can reveal the confirmation panel programmatically; the player-facing leave flow is therefore being simplified to a single direct action.
- Final Godot MCP screenshot at 1344×896 confirms the environment backdrop, stone distributor, three timber gates, three basins, target lines, selected-gate highlight and animated water are visible without overlap.
- Hosted runtime exit check: emitting the top-right button returned `active=false`, restored world/HUD visibility, returned phase to `CANAL_AVAILABLE`, and moved the player to `(780, 620)`.
- Hosted `Esc` check returned to the map; the same canal game then reopened successfully and accepted another water release.
- Final game log contains only the MCP game-helper registration line and no runtime error.
- `test_fubo_canal_game.gd`, `test_fubo_minigame_host.gd`, and `test_fubo_guling.gd` all exited `0` and printed their pass messages. The broader Fubo test retains known Godot shutdown leak diagnostics but no test failure.
- Follow-up failure reproduced in the hosted runtime: `tree_paused=false`, while the canal root had `process_mode=2`; `root_can_process`, `board_can_process`, and `exit_can_process` were all `false`. Programmatic signal emission bypassed this state and was therefore insufficient as an input test.
- Root-cause fix: `MinigameHost`, `FuboCanalMinigame`, and `FuboDrumMinigame` now use `PROCESS_MODE_ALWAYS`. Hosted runtime returned `root_can_process=true` and `exit_can_process=true` for both minigames while `tree_paused=false`.
- Real mouse regression: clicking the left-channel button changed selection from `1` to `0`; clicking “放水 +1格” changed levels from `[0,0,0]` to `[1,0,0]` and displayed “左渠进水成功”; clicking the top-right leave button returned `active=false`, restored the map, and placed the player at `(780,620)`.
- Final 1344×896 screenshot shows the persistent three-step instruction, explicit numbered buttons, current selection text, stone channels, gates, pools and target markers without overlap.
- Final regression: canal, drum, minigame-host and Fubo scene tests all exited `0`; final MCP game log contains no runtime error.

## Changed files

- `docs/design/fubo-guling-slice.md`, `docs/qa/playtest.md`, and this change record.
- `scenes/fubo_guling/minigames/fubo_canal_minigame.tscn`.
- `scenes/fubo_guling/minigames/fubo_drum_minigame.tscn` and `scenes/fubo_guling/fubo_guling.tscn` process-mode corrections.
- `scripts/fubo_guling/minigames/fubo_canal_minigame.gd` and new `fubo_canal_board.gd`.
- `tests/test_fubo_canal_game.gd`, `tests/test_fubo_drum_game.gd`, and `tests/test_fubo_guling.gd`.
