# CHG-20260809-sea-overworld-layout-graybox-v3: 海域气质与功能岛差异化灰模

- Status: done
- Type: content
- Owner: Codex
- Created: 2026-08-09

## Goal and player/project outcome

在 v2 的 A/B/C/D 宏观布局与 B/D 职责基础上生成 v3 灰模，不增加主要岛屿数量，重点解决城市岛底盘重复、南北海域气质不清、岛链关卡线感、中央空洞和 B 区杂乱问题。

## Scope

- 保留 v1、v2 历史图，新增 `sea_overworld_stage1_graybox_v3.png`。
- 保留 16 个地点及 A4、B5、C4、D3 的区域分配。
- 北部 A/B 改为繁华贸易海域：港池、仓栈、多码头、人口密集、岛礁较少、航路开阔。
- 南部 C/D 改为蛮荒危险海域：高山岛、破碎海岸、军事堡垒、海盗据点、礁群与曲折航线。
- 将主要地点分别设计为港城、军事堡垒、小渔村、无人山岛四种功能造型，不再统一使用“岩石底座—城墙—中式建筑—木码头”。
- 岛链节奏改为“密—疏—空—密”，取消等间距串珠式路径。
- 中央海域只增加 3～5 个极小礁石和一艘沉船，用作视觉信息，不作为地点或连续路径。
- B 区删除约一半装饰礁点，形成至少一条宽阔、干净、容易辨认的航运通道。

## Non-goals

- 不替换游戏运行时四张生产背景。
- 不修改地点坐标、触发、碰撞、海图 UI、事件和测试代码。
- 不新增可进入地点、主要岛屿或玩法系统。
- 不精修建筑、植被、海浪、光影和材质。

## Acceptance checks

- [x] v1、v2 文件保持不变，v3 使用独立文件名。
- [x] A/B 北部明显比 C/D 南部繁华，拥有更多港口设施和更清楚的开阔航路。
- [x] C/D 南部明显更蛮荒、军事化，山岛更多、海岸更破碎、城市更少。
- [x] 港城、军事堡垒、小渔村、无人山岛四类地点在底盘、建筑和码头上均可区分。
- [x] 主要岛屿和地点数量没有增加，仍对应 16 个地点。
- [x] 岛链呈现“密—疏—空—密”，不再像等距路径点。
- [x] 中央海域包含 3～5 个微型礁石和一艘沉船，但仍保留大块可航行水面。
- [x] B 区视觉噪声低于 v2，并保留一条明显的宽航道。
- [x] v3 已保存到项目目录并完成原始分辨率视觉检查。

## Documentation impact

- Canonical documents to update before implementation: `docs/design/sea-overworld-design.md`
- Supporting documents: `docs/assets/sea-overworld-stage1-layout.md`, `docs/assets/sea-overworld-generated-assets.md`
- Decisions/ADRs: none

## Implementation notes

- Edit target: `assets/backgrounds/sea_overworld/concepts/sea_overworld_stage1_graybox_v2.png`
- Output: `assets/backgrounds/sea_overworld/concepts/sea_overworld_stage1_graybox_v3.png`
- Constraints and risks: 生图可能改变现有岛屿的精确轮廓和局部位置；阶段一只验收宏观区域、功能造型、密度节奏和航路留白，不将建筑细节视为生产设计。

## Verification evidence

- Automated: 内容校验通过；坐标表保持 16 行，其中 B 区 5 行、D 区 3 行；Markdown 围栏成对；`git diff --check` 无错误。v1/v2 SHA-256 与历史记录一致。v3 为 1672×941、24-bit RGB，SHA-256 为 `77BB36901D7381FE9D0BDB45C499DE3DB186AEB75BEBAFC6673FAA4C1F94ED0A`。
- Manual/in-engine: 已按原始分辨率检查 v3。北部港贸与南部蛮荒军事差异明确；四种功能轮廓可辨识；A4/B5/C4/D3 地点组完整；中央沉船和微型礁石未形成路径；B 区宽航道保留。概念图未接入引擎，符合非目标约束。

## Final reconciliation

- Files changed: `assets/backgrounds/sea_overworld/concepts/sea_overworld_stage1_graybox_v3.png`, `docs/assets/sea-overworld-stage1-layout.md`, `docs/assets/sea-overworld-generated-assets.md`, `docs/design/sea-overworld-design.md`, 本变更记录。
- Documented limitations/follow-ups: v3 只锁定功能造型、南北气质、密度节奏和中央视觉元素；下一阶段需要将构图拆回四张生产分块，再校准地点、碰撞、海图标记和测试。
