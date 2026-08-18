# CHG-20260811：伏波古岭鼓令画面与音色重制

- Status: done
- Date: 2026-08-11
- Owner: Codex

## Goal

解决听令回鼓界面像普通按钮原型、三鼓缺乏中式校场氛围且现有合成音色刺耳的问题，同时保留已经通过试玩的记忆与节拍规则。

## Player-visible outcome

- 全屏界面以伏波古岭背景和清爽像素校场作为环境，不再使用纯绿色空底。
- 中央直接显示三面有大小和层次差异的中式朱红战鼓；鼓面可点击，A/S/D 键位按钮保留在下方。
- 示范或玩家击鼓时，对应鼓出现暖金描边、轻微跳动与鼓面冲击圈。
- 三种音色改为许可清楚的独立太鼓单击录音加工：左侧大鼓低沉有尾音，中鼓结实饱满，右侧鼓边短促清脆；音量匹配且差异明显。

## Scope

- 新增代码绘制的像素校场鼓台与可点击鼓面。
- 重排鼓令场景 UI，使用现有透明像素战鼓素材。
- 从明确标注 CC BY 4.0 的独立太鼓单击录音处理三份样本，替换现有三鼓 WAV并登记署名；保留独立失败提示音。Wikimedia CC0 合奏录音因鼓点重叠，仅作调研参考，不进入项目。
- 更新鼓令场景测试、视觉与音频验收记录及素材来源记录。

## Non-goals

- 不改变 4/5/6 拍、BPM、随机序列、时间窗、错误重播或失焦恢复规则。
- 不修改码头钓鱼、伏波主地图或后续观景台流程。
- 不新增角色动画、复杂粒子或第三方音乐。

## Acceptance checks

- 1344×896 下背景、标题、轮次、节拍条、三鼓、键位提示和状态文字完整且不重叠。
- 三面鼓是画面主焦点，可直接点击，A/S/D 与方向键仍可操作。
- 演示和输入时对应鼓有清楚但不刺眼的视觉反馈。
- `drum_low.wav`、`drum_mid.wav`、`drum_rim.wav` 来自许可清楚的独立击鼓录音处理，三者时长、频谱重心与听感职责明显不同，无削波爆音。
- 原鼓令规则测试、伏波流程测试和钓鱼测试继续通过。
- Godot 4.7 能加载场景并以 OpenGL Compatibility 渲染运行画面，无解析或阻断错误。

## Documentation impact

- `docs/design/fubo-guling-slice.md`：补充鼓令呈现和声音职责。
- `docs/assets/fubo-guling-generated-assets.md`：登记鼓素材和 CC0 来源。
- `docs/qa/playtest.md`：扩展鼓令视觉与听感验收。

## Likely files

- `scripts/fubo_guling/minigames/fubo_drum_stage.gd`
- `scripts/fubo_guling/minigames/fubo_drum_minigame.gd`
- `scenes/fubo_guling/minigames/fubo_drum_minigame.tscn`
- `assets/audio/fubo_guling/drum_low.wav`
- `assets/audio/fubo_guling/drum_mid.wav`
- `assets/audio/fubo_guling/drum_rim.wav`
- `assets/audio/fubo_guling/sources/taiko_drum_001_hq.mp3`
- `tests/test_fubo_drum_game.gd`

## Verification evidence

- Godot 4.7 stable headless editor import成功注册 `FuboDrumStage` 和新版 `FuboDrumMinigame`，四份音频均完成资源导入。
- `tests/test_fubo_drum_game.gd`：通过。覆盖随机序列/BPM/节拍、时间窗、错误重播、三鼓可点击区域、大小层级、透明战鼓纹理、四个独立音频流、三种递减尾音长度和来源文件存在性。
- `tests/test_fubo_guling.gd` 与 `tests/test_fubo_fishing_game.gd`：通过，确认伏波流程和码头钓鱼无回归。
- Godot Movie Maker 使用 OpenGL Compatibility 在 1344×896 渲染 30 帧：完整显示伏波背景、清爽像素校场、灰砖墙、双旗、三面朱红战鼓、轮次/BPM、节拍条、键位牌、状态栏和离开按钮；示范鼓出现暖金轮廓、冲击圈和上跳反馈。
- 音频测量：低鼓 1.89 秒 / 峰值 -1.5 dB，中鼓 1.05 秒 / 峰值 -2.5 dB，鼓边 0.35 秒 / 峰值 -3.1 dB；三者均为 44.1 kHz、16-bit、mono，无 0 dBFS 削波。
- Freesound 来源页明确给出 2.438 秒、44.1 kHz、16-bit、mono 和 CC BY 4.0；作者与演奏者署名已经写入素材文档。
- `git diff --check`：通过，仅有仓库既有 LF/CRLF 转换提示。
- 当前会话未暴露 Godot AI MCP 调用工具，因此未记录 MCP 编辑器操作；验证来自 Godot 4.7 引擎导入、专项测试、音频测量和实际 OpenGL 渲染。

## Actual changed files

- `docs/changes/CHG-20260811-fubo-drum-presentation-audio.md`
- `docs/design/fubo-guling-slice.md`
- `docs/assets/fubo-guling-generated-assets.md`
- `docs/qa/playtest.md`
- `assets/audio/fubo_guling/sources/taiko_drum_001_hq.mp3`
- `assets/audio/fubo_guling/drum_low.wav`
- `assets/audio/fubo_guling/drum_mid.wav`
- `assets/audio/fubo_guling/drum_rim.wav`
- `scripts/fubo_guling/minigames/fubo_drum_stage.gd`
- `scripts/fubo_guling/minigames/fubo_drum_minigame.gd`
- `scenes/fubo_guling/minigames/fubo_drum_minigame.tscn`
- `tests/test_fubo_drum_game.gd`
