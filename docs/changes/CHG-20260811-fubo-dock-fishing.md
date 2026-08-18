# CHG-20260811：伏波古岭码头钓鱼

- Status: done
- Date: 2026-08-11
- Owner: Codex

## Goal

删除玩家难以理解的修水渠玩法，将伏波古岭第一项小游戏改为发生在码头的“黄金矿工式钓鱼”，保留现有听令回鼓玩法。

## Player-visible outcome

- 与守岭人交谈后，任务要求玩家返回码头。
- 玩家进入码头触发区后按 `E / 空格`，可选择进入独立全屏钓鱼界面；离开触发区不会自动开局。
- 渔钩在船边左右摆动；玩家按空格、回车或鼠标左键下钩。
- 渔钩碰到鱼获后自动收线。小鱼轻且分少，大鱼重且分高，杂物低分；在 60 秒内达到 500 分即完成。
- 右上“暂时离开”和 `Esc` 直接回到码头；打鼓玩法与后续观景台流程保留。

## Scope

- 新增无场景依赖的钓鱼规则模型、全屏钓鱼场景和代码绘制的像素海面/鱼获画面。
- 将伏波古岭状态机、任务文案、触发点和宿主回调从 `canal` 改为 `fishing`。
- 将原古渠触发点迁移到码头可走区；保留地图背景中的水渠作为环境景物，但不再绑定玩法。
- 更新伏波专项测试和玩法验收文档。

## Non-goals

- 不改听令回鼓的规则、音频或场景。
- 不新增鱼类图集、背包、经济、鱼竿养成或复杂物理绳索。
- 不修改伏波古岭完整背景、活动红线和人物素材。
- 不删除历史水渠文件；它们从当前玩法流程解除引用，便于版本追溯。

## Acceptance checks

- 守岭人对话后只开放码头钓鱼，不能再进入修水渠。
- 钓鱼界面有清楚可见的船边、摆动绳钩、海水、鱼获、分数、目标和倒计时。
- 空闲时渔钩摆动；一次输入只发射一次；命中后自动收线并按鱼获重量改变回收速度。
- 60 秒内达到 500 分发出 `game_id=fishing` 的完成结果；时间耗尽可明确重试，不会软锁。
- 鼠标、键盘、退出按钮和 `Esc` 在宿主中均可处理输入。
- 完成钓鱼后回到原地图并开放打鼓；完成打鼓后开放观景台。
- Godot 4.7 可加载相关场景，伏波钓鱼、打鼓、主场景专项测试通过且无解析错误。

## Documentation impact

- `docs/design/fubo-guling-slice.md`：替换第一项小游戏和线性流程。
- `docs/tech/architecture.md`：规则模型从古渠改为钓鱼。
- `docs/qa/playtest.md`：以码头钓鱼验收替换三渠引水验收。

## Likely files

- `scripts/fubo_guling/fubo_guling.gd`
- `scripts/fubo_guling/fubo_fishing_game.gd`
- `scripts/fubo_guling/minigames/fubo_fishing_minigame.gd`
- `scripts/fubo_guling/minigames/fubo_fishing_board.gd`
- `scenes/fubo_guling/fubo_guling.tscn`
- `scenes/fubo_guling/minigames/fubo_fishing_minigame.tscn`
- `tests/test_fubo_fishing_game.gd`
- `tests/test_fubo_guling.gd`

## Verification evidence

- Godot 4.7 stable editor import registered `FuboFishingGame`、`FuboFishingBoard` 与 `FuboFishingMinigame`，新场景可加载。
- `tests/test_fubo_fishing_game.gd`：通过。覆盖固定种子鱼获、单次发射、命中计分、重物慢收线、达到 500 分、超时重试、空格输入、海面点击和单击退出。
- `tests/test_fubo_guling.gd`：通过。覆盖码头触发点、`fishing` 宿主实例、完成后返回地图并开放打鼓、打鼓后开放观景台。
- `tests/test_fubo_drum_game.gd`：通过，确认保留的打鼓玩法没有回归。
- 使用 Godot Movie Maker 以 OpenGL Compatibility 在 1344×896 渲染钓鱼场景 5 帧；画面显示背景、码头、分层海水、摆钩、鱼/蟹/杂物、500 分目标、60 秒计时、操作按钮和离开按钮。另以非 headless OpenGL 运行态捕获伸长中的绳钩。
- `git diff --check`：通过，仅报告仓库既有的 LF/CRLF 转换提示。
- 当前 Codex 会话未暴露 Godot AI MCP 调用工具，因此未记录 MCP 编辑器操作；以上结论来自 Godot 4.7 引擎导入、专项测试与实际渲染，不冒充 MCP 结果。

## Actual changed files

- `docs/design/fubo-guling-slice.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `docs/changes/CHG-20260811-fubo-dock-fishing.md`
- `scripts/fubo_guling/fubo_guling.gd`
- `scripts/fubo_guling/fubo_fishing_game.gd`
- `scripts/fubo_guling/minigames/fubo_fishing_board.gd`
- `scripts/fubo_guling/minigames/fubo_fishing_minigame.gd`
- `scenes/fubo_guling/fubo_guling.tscn`
- `scenes/fubo_guling/minigames/fubo_fishing_minigame.tscn`
- `tests/test_fubo_fishing_game.gd`
- `tests/test_fubo_guling.gd`
- Removed from active tests: `tests/test_fubo_canal_game.gd`
