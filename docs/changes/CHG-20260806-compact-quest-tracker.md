# CHG-20260806 紧凑任务栏

- Status: done
- Date: 2026-08-06

## Goal

缩小探索 HUD 左侧任务栏的视野占用，并让具体任务卡片透出游戏画面。

## Scope

- 缩小任务栏整体宽度和高度。
- 压缩主线、支线任务项的徽记、字号和间距，但继续保证中文可读。
- 主线、支线任务卡取消不透明深色背景，保留轻量边框、侧边色条和内容。
- 保留任务栏标题底板作为信息锚点。

## Non-goals

- 不调整左上角色状态栏和右上功能按钮。
- 不改变任务文案、主支线分类或任务数据行为。

## Acceptance checks

- 任务栏比当前版本明显更窄、更矮，减少对左侧世界画面的遮挡。
- 两张具体任务卡的背景透明，可直接看到其后的游戏画面。
- 主线、支线标签、人物徽记、任务名和目标仍清晰可辨。
- 1344×896 下无文字裁切或任务项重叠。

## Documentation impact

- 更新 `docs/design/art-direction.md` 中的任务栏视觉规范。

## Likely files

- `scripts/exploration_hud.gd`
- `tests/test_exploration_hud.gd`
- `docs/design/art-direction.md`

## Verification evidence

- `tests/test_exploration_hud.gd` 在 Godot 4.7.1 OpenGL 兼容渲染模式下通过。
- 运行态断言确认任务栏不超过 286×270，主线和支线任务卡背景 Alpha 均为 0，任务栏主体 Alpha 不高于 0.5。
- 1344×896 实际渲染确认任务栏宽高和间距已收紧，场景细节能透过任务区域，中文无裁切或重叠。
