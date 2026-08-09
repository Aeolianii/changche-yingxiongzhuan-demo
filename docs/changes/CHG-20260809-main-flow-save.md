# CHG-20260809-main-flow-save: 正式主流程单槽存档

- Status: done
- Type: feature
- Owner: Codex
- Created: 2026-08-09

## Goal and player/project outcome

玩家可在皇宫、水师驻地和海上大地图的自由探索阶段从系统菜单保存当前进度，并在之后读取同一存档，回到正确场景、任务阶段与角色位置。

## Scope

- 新增常驻 `GameState`，负责版本化单槽 JSON 存档、校验、原子替换和待恢复场景快照。
- 将系统菜单“保存进度”和“读取进度”从占位提示改为真实操作，并保留明确的成功/失败反馈。
- 皇宫保存稳定剧情阶段、玩家位置和内侍位置。
- 水师驻地保存巡视任务阶段、已完成士兵汇报、玩家位置和朝向。
- 海上大地图保存玩家位置、朝向、探索引导阶段与月相日数。
- 读取时切换或重载存档记录的场景，由目标场景消费一次性恢复快照。
- 增加存档格式、菜单信号和三场景恢复的自动验证。

## Non-goals

- 不保存正在播放的对白、选项、章节过场、加载过场或操练覆盖层的中间帧。
- 不实现多存档槽、自动存档、云存档、新游戏确认或返回标题。
- 不保存战斗状态、舰船属性、伤害数值、装备或经济平衡数据。
- 不合并独立 `OfficialCampaignState` 的旧军饷、付费维修和固定两船规则。

## Acceptance checks

- [x] 系统菜单“保存进度”写入 `user://main_flow_save.json`，成功与失败均有可见反馈。
- [x] 系统菜单“读取进度”校验存档并回到记录场景；缺失、损坏或版本不兼容时不破坏当前进度。
- [x] 皇宫自由探索状态读取后保留剧情门控和玩家位置。
- [x] 水师驻地读取后保留士兵汇报去重、任务阶段、玩家位置和朝向。
- [x] 海上大地图读取后保留玩家位置、朝向、探索阶段和月相。
- [x] 菜单打开期间继续阻止移动和场景交互。
- [x] 既有场景串联、大地图往返和 HUD 测试继续通过。

## Documentation impact

- `docs/tech/architecture.md`：新增正式主流程存档格式、生命周期和场景快照边界。
- `docs/design/scene-flow.md`：补充系统菜单保存/读取流程。
- `docs/qa/playtest.md`：补充存档验收场景与验证证据。
- `docs/production/backlog.md`：记录正式主流程存档工作。
- Decisions/ADRs: none

## Implementation notes

- Likely files/modules: `project.godot`, `scripts/core/game_state.gd`, `scripts/exploration_hud.gd`, `scripts/palace_demo.gd`, `scripts/scene_2.gd`, `scripts/sea_overworld.gd`, `scripts/sea_overworld_player.gd`, `tests/test_main_flow_save.gd`。
- Constraints and risks: 场景脚本当前使用局部状态机和根节点临时元数据；恢复必须只发生一次，且不得把读取动作误判为章节首次进入或海图往返。

## Verification evidence

- Automated: `tests/verify_merged_project.ps1`、`tests/test_main_flow_save.gd`、`tests/test_exploration_hud.gd`、`tests/test_scene_transition.gd`、`tests/test_scene_two_dialogue_patrol.gd`、`tests/test_scene_two_sea_link.gd`、`tests/test_sea_overworld.gd` 全部通过。
- Manual/in-engine: Godot 4.7.1 完成项目导入并可启动主项目；无界面运行验证了三场景菜单按钮连接、单槽写入、读取恢复和无效存档保护。

## Final reconciliation

- Files changed: 新增 `scripts/core/game_state.gd`、`tests/test_main_flow_save.gd` 和本变更记录；修改项目自动加载、HUD、皇宫、水师驻地、海上大地图相关脚本与对应测试、设计、架构、QA、待办文档。
- Documented limitations/follow-ups: 仅保存稳定自由探索状态；不覆盖对白/过场中间帧、战斗、船只数值、装备经济、多槽、自动/云存档与返回标题。
