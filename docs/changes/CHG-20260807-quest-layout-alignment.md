# CHG-20260807 任务布局对齐

- Status: done
- Date: 2026-08-07

## Goal

根据实际截图微调探索任务栏和完整任务界面的文字对齐：任务栏中的主线、支线内容及左侧分类色条整体略微上移；任务详情摘要中的总任务标题与描述整体右移。

## Scope

- 同步上移探索任务栏的主线和支线任务项，使分类、名称、描述及左侧竖向色条保持一体对齐。
- 同步右移完整任务界面的所选任务标题和任务描述。
- 增加针对上述偏移关系的布局断言。

## Non-goals

- 不修改任务文案、任务数据、任务流程或筛选交互。
- 不调整任务栏外框、任务界面面板和流程列表的尺寸。
- 不修改任何生成式 PNG 素材。
- 不修改用户已有的 `scenes/Scene2.tscn` 及资源导入缓存变更。

## Acceptance checks

- 主线与支线任务项相对原位置统一上移，二者间距保持不变。
- 每项左侧色条与分类、名称、描述一同移动，不发生错位、裁切或重叠。
- 任务详情的所选任务标题与描述使用同一水平起点，并向右收进详情框。
- `tests/test_exploration_hud.gd` 相关运行态回归通过。

## Documentation impact

- 更新 `docs/design/art-direction.md` 的任务栏与任务详情摘要布局规范。
- 完成后在 `docs/qa/playtest.md` 记录验证结果。

## Likely files

- `scripts/exploration_hud.gd`
- `scripts/ui/quest_screen.gd`
- `tests/test_exploration_hud.gd`
- `docs/design/art-direction.md`
- `docs/qa/playtest.md`

## Verification evidence

- Godot 4.7.1 headless：`tests/test_exploration_hud.gd` 通过，验证两项任务统一上移、原有间距不变、色条随任务项移动，以及详情标题与描述同步右移。
- Godot 4.7.1 OpenGL compatibility：同一运行态测试通过并生成 1344×896 截图。
- 实际渲染确认任务栏文字和色条无裁切或重叠，任务详情长描述在右移后仍完整换行于详情内框。
