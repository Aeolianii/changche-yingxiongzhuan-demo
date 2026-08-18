# CHG-20260809-click-to-move: 陆地探索点击移动

- Status: done
- Type: feature
- Owner: Codex
- Created: 2026-08-09

## Goal and player/project outcome

玩家在皇宫和水师驻地的自由探索阶段点击地面后，主角自动朝对应世界位置移动，不再只能依赖键盘方向键。

## Scope

- 为皇宫主角和水师驻地主角增加鼠标左键点击移动。
- 点击目标使用当前相机的画布变换换算为世界坐标。
- 自动移动沿直线使用现有物理碰撞，抵达目标或被障碍持续阻挡时停止。
- 键盘方向输入立即接管并取消当前点击目标。
- 角色输入被对白、系统菜单、操练覆盖层或场景切换锁定时不接受点击移动。
- 增加点击移动、键盘接管和受控状态保护的自动验证。

## Non-goals

- 不新增导航网格、绕路寻路或跨房间路径规划。
- 不改变海上大地图的船只操控。
- 不改变 NPC 交互距离、剧情状态、战斗或船只数值。
- 不保存尚未抵达的临时点击目标。

## Acceptance checks

- [x] 皇宫自由探索时左键点击可行走地面，主角朝目标移动并在附近停下。
- [x] 水师驻地自由探索时左键点击可行走地面，主角朝目标移动并在附近停下。
- [x] 自动移动继续使用既有碰撞，持续受阻后停止，不无限推挤障碍。
- [x] 自动移动期间按方向键会立刻取消点击目标并改由键盘控制。
- [x] 角色输入被对白、菜单、操练或切场锁定时不会因点击世界位置移动。
- [x] 既有存档、剧情串联、HUD 和海图测试继续通过。

## Documentation impact

- `docs/tech/architecture.md`：补充陆地玩家输入仲裁和点击坐标换算。
- `docs/design/scene-flow.md`：补充自由探索点击移动行为与边界。
- `docs/qa/playtest.md`：增加两处陆地场景的点击移动验收。
- `docs/production/backlog.md`：记录本功能进度。
- Decisions/ADRs: none

## Implementation notes

- Likely files/modules: `scripts/player.gd`、`scripts/scene_2.gd`、`tests/test_click_to_move.gd` 及静态验证脚本。
- Constraints and risks: 两个陆地场景的玩家实现不同；首版必须保持各自现有动画、速度、碰撞与剧情锁定契约。

## Verification evidence

- Automated: `tests/verify_merged_project.ps1`、`tests/test_click_to_move.gd`、存档、HUD、场景切换、水师巡视、海图往返与海图运行测试全部通过。
- Manual/in-engine: Godot 4.7.1 无界面运行验证了两处陆地移动、点击坐标换算、抵达停止、键盘接管、输入锁定和碰撞受阻停止。

## Final reconciliation

- Files changed: 修改 `scripts/player.gd`、`scripts/scene_2.gd` 与静态验证；新增 `tests/test_click_to_move.gd` 和本变更记录；同步架构、流程、QA 与待办文档。
- Documented limitations/follow-ups: 首版是直线点击移动并复用现有碰撞，不提供导航网格绕路；海上船只操控不变，点击目标不写入存档。
