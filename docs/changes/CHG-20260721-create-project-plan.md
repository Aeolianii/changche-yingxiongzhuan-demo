# CHG-20260721-create-project-plan: 建立混合 2.5D 项目计划书

- Status: done
- Type: docs-only
- Owner: TSOC
- Created: 2026-07-21

## Goal and player/project outcome

将现有“皇宫受命至南疆水师”原型放入清晰的长期产品框架，记录已确认的“2D 手绘背景 + 低模 3D 人物 + Godot 正交 3D”目标技术路线，并给出美术需求、最小技术验证、阶段边界和验收标准，避免在核心战斗与渲染管线未经验证前批量制作资产。

## Scope

- 新增一份可独立阅读的项目计划书。
- 说明项目定位、参考边界、核心循环与首个公开 Demo 范围。
- 区分当前纯 2D 原型架构与目标混合 2.5D 生产架构。
- 记录 Godot 技术栈、场景分层、数据层、战斗层、存档与工具链方向。
- 给出按阶段交付的美术需求与资产规格。
- 给出最小验证计划、通过门槛、停止条件和后续里程碑。
- 将计划书加入项目文档索引。

## Non-goals

- 不修改当前游戏代码、场景、资源、配置或运行入口。
- 不在本变更中把现有 2D 角色替换为 3D 模型。
- 不承诺正式版全部内容、商业排期或预算。
- 不启动批量 3D 建模、动画和地图生产。

## Acceptance checks

- [x] 计划书明确回答技术路线、Godot 技术栈、美术需求和最小验证计划。
- [x] 计划书明确区分当前原型与目标架构，且不声称尚未实现的系统已经存在。
- [x] 最小验证具备可测量的通过标准和失败后的收缩方案。
- [x] 美术需求按验证资产、Demo 资产和正式版资产分级。
- [x] `docs/index.md` 可以直接访问计划书。
- [x] 本变更不包含 `scenes/Scene2.tscn` 的现有用户修改。

## Documentation impact

- Canonical documents to update before implementation: `docs/product/project-plan.md`、`docs/index.md`
- Decisions/ADRs: 若最小验证通过并进入实现阶段，再单独新增混合 2.5D 架构 ADR；本次仅记录目标路线和验证门槛。

## Implementation notes

- Likely files/modules: `docs/product/project-plan.md`、`docs/index.md`
- Constraints and risks: 当前运行时仍为纯 2D 且同时使用 GDScript/C#；计划书必须避免将目标技术栈描述为当前完成状态。

## Verification evidence

- Automated: `rg` 检查必需章节与关键技术词全部命中；项目计划书、变更记录和索引无行尾空白；计划书无 `TBD`、`TODO`、`FIXME` 或“待定”残留；`git diff --check` 通过。
- Manual/in-engine: 已检查 42 个标题构成的文档大纲、索引目标存在、当前/目标架构边界、V0 与 Demo 美术分级、两周验证步骤、通过门槛和回退条件。文档变更不需要引擎运行验证。

## Final reconciliation

- Files changed: `docs/product/project-plan.md`、`docs/index.md`、`docs/changes/CHG-20260721-create-project-plan.md`
- Documented limitations/follow-ups: 本次仅形成计划，不修改运行时；下一步需由用户评审第 12 节五项决策，批准后为 M0 建立独立 change record、worktree 和实施计划。
