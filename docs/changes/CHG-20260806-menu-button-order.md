# CHG-20260806 菜单按钮顺序

- Status: done
- Date: 2026-08-06

## Goal

调整探索 HUD 右上功能按钮顺序，将“菜单”放到最右侧。

## Scope

- 交换“菜单”和“人物”的位置。
- 最终从左到右排列为“人物、物品栏、船只、菜单”。
- 增加运行态顺序断言。

## Non-goals

- 不改变按钮样式、尺寸、点击反馈或功能范围。
- 不调整任务栏和主角状态栏。

## Acceptance checks

- 右上四个按钮从左到右为“人物、物品栏、船只、菜单”。
- “菜单”是功能按钮组最右侧按钮。
- 四个按钮仍能显示“功能即将开放”提示。

## Documentation impact

- 更新 `docs/design/art-direction.md` 中的按钮顺序。

## Likely files

- `scripts/exploration_hud.gd`
- `tests/test_exploration_hud.gd`
- `docs/design/art-direction.md`

## Verification evidence

- `tests/test_exploration_hud.gd` 在 Godot 4.7.1 OpenGL 兼容渲染模式下通过。
- 运行态断言确认按钮节点从左到右为 `CharacterButton`、`InventoryButton`、`ShipButton`、`MenuButton`。
- 1344×896 实际渲染截图确认“菜单”显示在功能组最右侧，其他 HUD 布局未变化。
