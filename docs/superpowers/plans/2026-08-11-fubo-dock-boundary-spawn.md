# 伏波古岭码头边界与出生点实施计划

> **执行要求：** 在当前会话中逐项执行，遵循测试先行；保留工作区内无关改动。

**目标：** 玩家首次进入伏波古岭时出生在码头红叉中心，临水三边不可越过，通往陆地的台阶保持开放。

**实现方式：** 沿用现有闭合分段 `CollisionPolygon2D`，只调整码头段连续顶点；场景出生点和脚本安全返回点共用 `Vector2(220, 868)`。正式存档恢复逻辑不变。

**技术栈：** Godot 4.7、GDScript、`.tscn` 场景、项目现有 `SceneTree` 测试。

## 全局约束

- 不修改岛内其余碰撞、相机、美术、触发区和剧情规则。
- 不覆盖正式存档中的玩家坐标。
- 码头台阶口必须连通，临水三边必须阻挡。

### 任务 1：测试先行并调整码头

**文件：**

- 修改：`tests/test_fubo_guling.gd`
- 修改：`scenes/fubo_guling/fubo_guling.tscn`
- 修改：`scripts/fubo_guling/fubo_guling.gd`

- [x] 将场景契约中的出生点期望改为 `Vector2(220, 868)`，并检查 `DOCK_SAFE_POSITION` 与出生点一致。
- [x] 增加边界几何检查：红叉点位于可活动侧；码头临水采样点被边界隔开；台阶内侧采样点保持连通。
- [x] 运行伏波专项测试，确认它因旧出生点/旧边界而失败。
- [x] 将场景 `Player.position` 与脚本 `DOCK_SAFE_POSITION` 改为 `Vector2(220, 868)`。
- [x] 只替换闭合边界中从码头左台阶侧到右台阶侧的连续顶点，使折线贴合石台外沿。
- [x] 重新运行专项测试，确认通过。

### 任务 2：引擎验证与文档收尾

**文件：**

- 修改：`docs/design/fubo-guling-slice.md`
- 修改：`docs/qa/playtest.md`
- 修改：`docs/changes/CHG-20260811-fubo-dock-boundary-spawn.md`

- [x] 在 Godot 中打开并运行 `res://scenes/fubo_guling/fubo_guling.tscn`。
- [x] 开启碰撞调试并用运行时物理探针确认玩家出生在红叉区域、三侧不能下水、台阶可通行，并检查邻近非目标边界。
- [x] 检查编辑器与游戏日志无新增阻断错误。
- [x] 将验证命令、运行结果和最终文件列表写入变更记录，状态改为 `done`。
