# CHG-20260809-scene2-space-dialogue: 第二幕空格推进对话

- Status: done
- Type: usability
- Owner: Codex
- Created: 2026-08-09

## Goal and player/project outcome

第二幕的线性对白与第一幕保持一致：对白框显示“继续/结束/开始巡视”按钮时，玩家可以按空格推进，不必每句都点击按钮。

## Scope

- 第二幕收到 `interact` 输入时，若线性对白推进按钮可见，则调用现有对话推进函数。
- 空格、E 和回车继续复用项目统一的 `interact` 动作。
- 忽略键盘长按产生的重复事件，避免一次跳过多句。
- 选项式对话仍要求玩家明确点击选项，不用空格自动代选。
- 补充运行时与静态回归验证。

## Non-goals

- 不修改对白文本、任务阶段或 NPC 交互距离。
- 不新增自动播放、打字机效果或手柄映射。
- 不改变存档格式，也不自动读取正式存档。
- 不实现标题界面的“继续游戏”。

## Acceptance checks

- [x] 第二幕章节抵达对白可按空格逐句推进并在末句开始巡视。
- [x] 士兵、军官和县令的线性汇报对白可按空格逐句推进并正常触发完成回调。
- [x] 选项式 NPC 对话不会因空格自动选择某一项。
- [x] 键盘重复事件不会连续跳过多句。
- [x] 既有点击按钮推进、点击移动、存档和场景串联测试继续通过。
- [x] 正式存档在测试和项目重启前后保持不变。

## Documentation impact

- `docs/design/scene-flow.md`：记录第二幕线性对白的统一推进操作和启动读取边界。
- `docs/tech/architecture.md`：记录对话输入优先级与存档测试隔离。
- `docs/qa/playtest.md`：新增第二幕空格推进验收。
- `docs/production/backlog.md`：记录本次工作。
- Decisions/ADRs: none

## Implementation notes

- Likely files/modules: `scripts/scene_2.gd`、`tests/test_scene_two_dialogue_patrol.gd`、`tests/verify_merged_project.ps1`。
- Constraints and risks: 第二幕同时存在选项式对话和线性对白，只有 `_next_dialogue_button.visible` 时才能用 `interact` 推进。

## Verification evidence

- Automated: 静态验证、第二幕巡视对白、章节切换、点击移动、正式存档、HUD、海图往返和海图运行测试全部通过。
- Manual/in-engine: Godot 4.7.1 无界面运行验证了章节迎接与任务线性对白的空格逐句推进、键盘 echo 保护和选项保护。

## Final reconciliation

- Files changed: 修改 `scripts/scene_2.gd`、第二幕对白与章节切换测试、静态验证；新增本变更记录并同步流程、架构、QA 与待办文档。
- Documented limitations/follow-ups: 启动仍固定进入皇宫且不自动读取存档；正式存档文件经测试前后 SHA-256 校验保持 `0CE159B0118C790BC929C49F35A721D5A08422C5C0F8A990413A799F5B5739D5`，标题界面继续游戏留待后续。
