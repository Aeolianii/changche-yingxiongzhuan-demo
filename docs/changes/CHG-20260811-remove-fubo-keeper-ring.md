# CHG-20260811：移除守岭人交互圆环

- Status: done
- Date: 2026-08-11
- Owner: Codex

## Goal

移除伏波古岭守岭人被交互聚焦时出现的黄色圆环。

## Player-visible outcome

玩家靠近守岭人时不再看到黄色圆环，只通过底部水墨交互提示获知可以对话。

## Scope

- 删除 `FuboWorldProp` 的聚焦圆环绘制。
- 保留交互距离、守岭人状态、底部提示、碰撞与对话流程。

## Non-goals

- 不增加替代光圈、脚标或闪烁效果。
- 不修改其他 NPC、地图、小游戏或全局 HUD。

## Acceptance checks

- 守岭人聚焦后不绘制黄色圆环。
- 靠近守岭人时底部交互提示仍出现。
- 伏波场景与全局 UI 自动化测试通过。

## Documentation impact

本次仅改变局部视觉反馈，无需修改规范性设计文档。

## Likely files

- `scripts/fubo_guling/fubo_world_prop.gd`
- `tests/test_fubo_guling.gd`

## Verification evidence

- `test_fubo_guling.gd`：退出码 0；确认黄色圆环颜色/绘制已移除，守岭人底部交互提示仍出现。
- `test_fubo_global_ui.gd`：退出码 0；共享 HUD、对话和小游戏显隐未受影响。
- Godot 4.7 Vulkan / 1344×896：`01b_keeper_focus_no_ring.png` 实际靠近守岭人截图确认无圆环，底部“与守岭人交谈”提示清晰可见。
- 测试退出仍有项目既有 RID / ObjectDB 清理警告，无解析、资源或断言失败。

## Actual changed files

- `scripts/fubo_guling/fubo_world_prop.gd`
- `tests/test_fubo_guling.gd`
- `tests/test_fubo_visual.gd`
- `docs/changes/CHG-20260811-remove-fubo-keeper-ring.md`
