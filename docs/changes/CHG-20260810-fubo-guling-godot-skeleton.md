# CHG-20260810-fubo-guling-godot-skeleton

- Status: done
- Type: feature / gameplay skeleton
- Owner: Project owner
- Created: 2026-08-10

## Goal and outcome

在最新版 `C:\Users\wangk\Desktop\厂车v3` 中，以 `C:\Users\wangk\fubo-guling` 已确认网页玩法为基准，新增可独立运行的伏波古岭 Godot 骨架。先验证地图动线、分层遮挡、碰撞、剧情门控和两项玩法，正式素材后补。

## Scope

- 2600×1500 程序化占位地图、受限跟随相机、脚底碰撞与 Y 排序遮挡。
- 一名守岭人和三句线性对话。
- 六阶段场景状态机及两个动态剧情障碍。
- 三道三态分流闸、27 种组合、主渠/泄水反馈、操作评级。
- 每局随机的 3/4/5 步听鼓序列、随机轮速、失败重播当前轮。
- 专项模型测试、场景运行、碰撞/遮挡截图和既有回归。
- 安装并启用项目开发期 `godot_ai` 插件，使所有场景节点写入、运行和截图都经目标项目 MCP 验证。

## Non-goals

- 不把伏波古岭接入标题、主流程、海图、存档或经济。
- 不修改现有皇宫、水师驻地、海图和战棋场景。
- 不制作或生成正式素材。
- 不整理或提交当前已有的大量素材 `.import` 变更。

## Acceptance checks

- [x] Godot MCP 会话明确指向 `C:/Users/wangk/Desktop/厂车v3/`，并在写入前确认编辑器未运行游戏和目标场景保存状态。
- [x] `res://scenes/fubo_guling/fubo_guling.tscn` 可独立运行，标题界面仍是默认主入口。
- [x] 程序化骨架包含独立地面、Y 排序对象、遮挡、效果、碰撞、触发和 UI 节点。
- [x] 人物脚底碰撞、相机边界以及建筑/树木前后遮挡通过运行检查。
- [x] 守岭人对话前古渠与校场玩法均不可触发。
- [x] 三向分流古渠 27 种组合只有目标组合完成，任意状态可恢复。
- [x] 听鼓序列每局随机且满足相邻不重复、末轮三色齐全；固定种子可复现。
- [x] 古渠只开放校场；三轮听鼓后才开放观景台。
- [x] MCP 目标场景运行、可见碰撞检查、截图和日志检查完成；既有自动测试没有回退。

## Documentation impact

- Added: `docs/design/fubo-guling-slice.md`
- Updated: `docs/index.md`, `docs/tech/architecture.md`, `docs/design/art-direction.md`, `docs/production/backlog.md`, `docs/qa/playtest.md`

## Likely files

- `addons/godot_ai/`, `project.godot`
- `scenes/fubo_guling/fubo_guling.tscn`
- `scripts/fubo_guling/fubo_guling.gd`, `fubo_world_prop.gd`, `fubo_canal_puzzle.gd`, `fubo_drum_memory.gd`, `fubo_placeholder_world.gd`
- `tests/test_fubo_guling.gd`

## Risks and constraints

- 当前目标仓库已有大量与本任务无关的素材导入改动，全部视为用户变更并保留。
- 厂车v3 当前编辑器没有项目内 `godot_ai` 插件；启用后必须重新确认 MCP 会话路径，不能继续使用旧项目会话。
- 占位图只验证结构和玩法，不得当成最终岭南美术验收。

## Verification evidence

- Godot MCP 会话 `v3@2ce2` 指向 `C:/Users/wangk/Desktop/厂车v3/`；通过 MCP 创建和保存关卡节点、属性、碰撞、触发与 UI，并以 custom scene 模式运行目标场景。
- Godot 4.7 运行日志：目标场景启动后游戏助手在线，当前运行无解析错误、脚本错误或阻断错误；编辑器在修正占位地图常量后无新增错误。
- 运行流程：实际 `E` 键触发守岭人三句对话；初始闸态 `[0,2,1]` 经 6 次交互到 `[2,1,0]`，显示“善治”，只关闭校场障碍。
- 听鼓运行样例生成 `3/4/5` 步序列和 `0.52/0.62/0.72` 档随机轮速；故意错误后输入游标归零、当前序列与速度不变；最终结果顺序为进度、轮完成、最终完成并只关闭观景台障碍。
- 碰撞/遮挡：`G` 调试层显示 17 个碰撞或触发形状；角色向房屋墙基移动产生滑动碰撞并停止；角色 Y 小于房屋脚点时被屋体遮挡，Y 大于脚点时显示在屋体前。
- 自动化：`test_fubo_guling.gd` 验证古渠 27 状态真值表、评级、听鼓随机约束/复现/错误恢复和场景契约，退出码 0。
- 回归：`tests/` 下 13 个 Godot headless 测试逐项运行，全部退出码 0。
- 入口：`project.godot` 的 `run/main_scene` 保持 `res://scenes/ui/title_screen.tscn`。

## Final reconciliation

- 新增 Godot AI 开发插件、伏波古岭设计文档、独立场景、5 个关卡脚本和 1 个专项测试；更新架构、美术、生产与 QA 文档。
- 运行时相机边界由伏波古岭控制器设置，避免修改共享 `player.tscn` 或依赖实例子节点覆盖。
- 正式像素素材、TileSet、最终岭南场景细节、主流程入口和存档接入仍是后续工作；本变更仅完成可试玩骨架。
- 未整理、删除、暂存或提交仓库中既有的素材导入与其他无关改动。
