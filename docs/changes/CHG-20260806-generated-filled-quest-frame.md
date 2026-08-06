# CHG-20260806 生成式带底色任务框

- Status: done
- Date: 2026-08-06

## Goal

用一张自带完整水墨底色的生成式任务框替换“透明水墨边框 + 程序灰色矩形”的组合，消除材质和边缘割裂感。

## Scope

- 重新生成 `quest_tracker_frame.png`，在透明外部轮廓内直接包含深灰黛青水墨底色、顶部题签和水墨外框。
- 生成图不包含“任务”文字、主支线文字、人物徽章、任务内容或独立任务卡。
- 删除 Godot 中额外铺设的 `TrackerBackground` 程序灰底。
- 保留任务栏 286×270 尺寸、透明任务项、轻分隔线和现有任务内容。

## Non-goals

- 不修改角色状态栏、右上功能按钮或系统菜单。
- 不改变任务数据、任务栏显示时机或点击行为。
- 不修改用户已有的 `scenes/Scene2.tscn` 变更。

## Acceptance checks

- 新任务框 PNG 四角透明、框内中心完全不透明且具有连续水墨纹理。
- 运行时不存在 `TrackerBackground`，任务内容直接叠加在生成框底色上。
- “任务”题签、主线和支线内容清晰，无文字裁切或任务项重叠。
- 1344×896 下任务栏仍保持 286×270 紧凑占位。

## Documentation impact

- 更新 `docs/design/art-direction.md` 的任务栏素材规范。
- 完成后更新 `docs/qa/playtest.md`。

## Likely files

- `assets/ui/exploration_hud/quest_tracker_frame.png`
- `scripts/exploration_hud.gd`
- `tests/test_exploration_hud.gd`
- `docs/design/art-direction.md`
- `docs/qa/playtest.md`

## Verification evidence

- 使用内置 ImageGen 生成完整带底色水墨任务框，并经纯绿色键去除、透明边缘处理和 572×540 双倍运行尺寸缩放后接入项目。
- `tests/test_exploration_hud.gd` 在 1344×896 OpenGL compatibility 与 headless 模式均通过；PNG 四角透明、中心不透明且运行时不存在 `TrackerBackground`。
- 实际渲染确认题签、墨锋外框和深灰黛青底色连续，主支线内容清晰，无额外矩形灰底或卡片拼接感。
- `tests/test_system_menu_exit.gd` 与 `tests/verify_merged_project.ps1` 均通过。
