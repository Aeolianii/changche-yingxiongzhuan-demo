# CHG-20260811：鼓令返回古岭

- Status: done
- Date: 2026-08-11
- Owner: Codex

## Goal

修复鼓令独立试玩时“暂时离开”确认后没有任何反应的问题，并把离开入口改成符合轻量小游戏语义的直接返回操作。

## Player-visible outcome

- 右上按钮改为清晰可点击的朱褐底、铜金边“返回古岭”，不再经过简陋且多余的二次确认框。
- 在伏波地图中打开鼓令时，点击“返回古岭”或按 `Esc` 立即关闭小游戏、恢复原地图与角色控制。
- 直接运行鼓令子场景试玩时，同一操作切换到伏波古岭地图；“返回古岭”在任何运行方式下都不得结束整个游戏进程。

## Scope

- 为小游戏基类增加“有宿主则发出退出信号、无宿主则切换到指定返回场景”的统一退出入口。
- 鼓令按钮和 `Esc` 攓为直接调用统一退出入口。
- 移除鼓令场景中不再使用的确认弹窗及关联逻辑。
- 增加宿主模式、独立模式和界面契约测试。

## Non-goals

- 不改变鼓令节拍、随机序列、音效、胜负判定或准备流程。
- 不改变钓鱼玩法和伏波地图剧情门控。
- 不重做通用系统菜单。

## Acceptance checks

- 鼓令右上按钮文字为“返回古岭”，具有与鼓令键位一致的常态、悬浮和按下样式，场景中不存在二次确认框。
- 有 `exit_requested` 监听者时，退出入口只发出一次信号，不结束整个应用。
- 没有监听者的独立试玩模式调用同一入口时，切换到 `res://scenes/fubo_guling/fubo_guling.tscn`，不得调用 `SceneTree.quit()`。
- `Esc` 与按钮走同一路径。
- 宿主取消后恢复地图显隐、处理模式和角色控制。
- 鼓令、宿主、伏波地图与钓鱼专项测试继续通过。

## Documentation impact

- `docs/design/fubo-guling-slice.md`：明确鼓令与钓鱼统一为直接返回地图。
- `docs/tech/architecture.md`：登记小游戏基类的宿主/独立试玩退出约定。
- `docs/qa/playtest.md`：补充按钮、Esc、宿主和独立试玩验收。

## Likely files

- `scripts/fubo_guling/minigames/fubo_minigame_base.gd`
- `scripts/fubo_guling/minigames/fubo_drum_minigame.gd`
- `scenes/fubo_guling/minigames/fubo_drum_minigame.tscn`
- `tests/test_fubo_drum_game.gd`
- `tests/test_fubo_minigame_host.gd`

## Verification evidence

- 2026-08-11 follow-up: user confirmed the first standalone fallback closed the entire game. Root cause is `_quit_standalone()` calling `SceneTree.quit()` even though the UI promises“返回古岭”。该错误验收结论已作废，并由下面的场景切换验证取代。
- Replacement TDD red phase: host/base tests failed because the standalone path still invoked the legacy quit callback and had no return-scene property; the drum scene test failed because it did not configure a伏波地图返回路径.
- Replacement green phase: `FuboMinigameBase.request_exit()` now emits to an existing host or calls `change_scene_to_file()` with `standalone_return_scene_path`; it contains no `SceneTree.quit()` call. The drum scene configures `res://scenes/fubo_guling/fubo_guling.tscn`.
- Real-scene standalone probe instantiated the drum as `current_scene`, called `request_exit()`, remained alive for subsequent frames and printed `Standalone drum returned to the Fubo map without quitting.` after confirming the new current scene path.
- Root-cause evidence: the launched process was the drum `PackedScene` itself, while its old Leave button only emitted `exit_requested`; `FuboMinigameHost` was the sole receiver, so direct play had no listener and no resulting action.
- TDD red phase: the drum scene test failed because the old confirmation dialog remained, the label was “暂时离开”, button/Esc did not emit directly, and the button had no visible style. The base/host test failed because no unified exit method or standalone fallback existed.
- `test_fubo_drum_game.gd`: exit 0, `Fubo drum game verification passed.` It covers the visible button, bronze-framed styles, absence of confirmation UI, button signal and Esc signal.
- `test_fubo_minigame_host.gd`: exit 0, `Fubo minigame host verification passed.` It covers hosted signal routing, standalone fallback routing and map-state restoration.
- Superseded evidence: the previous standalone probe proved that the process exited; this is now recorded as the reproduced bug, not a passing result.
- `test_fubo_guling.gd`: exit 0, `Fubo Guling skeleton verification passed.` Existing RID/ObjectDB cleanup warnings remain at test-process exit.
- `test_fubo_fishing_game.gd`: exit 0, `Fubo fishing game verification passed.`
- Vulkan 1344×896 render confirmed the “返回古岭” button is fully visible in the upper-right corner with朱褐底、铜金边，且不遮挡标题或节拍区。Review capture: `C:\Users\wangk\AppData\Local\Temp\fubo_drum_direct_exit.png`.

## Actual changed files

- `docs/changes/CHG-20260811-fubo-drum-direct-exit.md`
- `docs/design/fubo-guling-slice.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `scripts/fubo_guling/minigames/fubo_minigame_base.gd`
- `scripts/fubo_guling/minigames/fubo_drum_minigame.gd`
- `scenes/fubo_guling/minigames/fubo_drum_minigame.tscn`
- `tests/test_fubo_drum_game.gd`
- `tests/test_fubo_minigame_host.gd`
