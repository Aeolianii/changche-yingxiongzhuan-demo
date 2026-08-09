# CHG-20260809-sea-overworld-layout-graybox: 海上大地图阶段一构图灰模

- Status: done
- Type: content
- Owner: Codex
- Created: 2026-08-09

## Goal and player/project outcome

在不改动海上大地图玩法系统的前提下，产出一张 A/B/C/D 四区拼接的低精度构图灰模，让全图具备“由左上军港出征、北南双线推进、右上核心港汇合”的明确方向，并为下一阶段高清背景重排提供位置依据。

## Scope

- 生成一张四区拼接的低精度海域构图图，只确认岛屿体量、位置、密度和航线关系。
- 保留当前 2×2 分块结构、地图总范围、16 个地点名称和现有交互职责。
- 给出 16 个地点的建议世界坐标与大/中/小视觉层级。
- 明确 A/B/C/D 接缝的岛链、礁石或航道连续关系。
- 将构图决策同步到海上大地图设计文档和生成素材清单。

## Non-goals

- 不替换当前游戏内四张生产背景。
- 不修改地点触发、碰撞、船只、事件、海图 UI 或测试代码。
- 不精修建筑、植被、海浪、光影、材质和单个岛屿轮廓。
- 不新增拟真航海、暗礁伤害、补给或潮汐玩法。

## Acceptance checks

- [x] 灰模能从左上出征区自然引导至右上核心港。
- [x] 北线与南线均连续，南线可从 D 区重新汇入 B 区终点。
- [x] A/B、A/C、B/D、C/D 四条接缝均有跨区视觉关系。
- [x] C 区以 2 个主要地标和 2 个低体量地点形成危险外海，而非四个等大圆岛。
- [x] D 区岛群被打散，并形成至少三条可辨识航道。
- [x] 16 个地点坐标草案均位于可航行、可接近的位置。
- [x] 产物已保存到项目目录并完成视觉检查。

## Documentation impact

- Canonical documents to update before implementation: `docs/design/sea-overworld-design.md`
- Supporting asset record: `docs/assets/sea-overworld-generated-assets.md`
- Decisions/ADRs: none

## Implementation notes

- Likely files/modules: `docs/design/sea-overworld-design.md`, `docs/assets/sea-overworld-generated-assets.md`, `docs/assets/sea-overworld-stage1-layout.md`, `assets/backgrounds/sea_overworld/concepts/sea_overworld_stage1_graybox_v1.png`
- Constraints and risks: 生图只作为构图草案，不能直接替代可碰撞、可交互的生产底图；生成图中的岛屿数量与细节可能存在轻微漂移，最终坐标以文档表格为准。

## Verification evidence

- Automated: 未运行游戏测试；本次只新增文档与非生产概念图。已验证 PNG 为 1672×941、24-bit RGB，SHA-256 为 `776541BE9775F99D4FBEF12D832FF17C9F3D47E42E20A05A6E85697333491259`。
- Manual/in-engine: 已按原始分辨率检查概念图；左上起点、北南双线、中央跨区岛链、C 区疏险关系、D 区碎岛航道和右上终点均可辨识。未接入引擎，符合非目标约束。

## Final reconciliation

- Files changed: `assets/backgrounds/sea_overworld/concepts/sea_overworld_stage1_graybox_v1.png`, `docs/assets/sea-overworld-stage1-layout.md`, `docs/assets/sea-overworld-generated-assets.md`, `docs/design/sea-overworld-design.md`, `docs/index.md`, 本变更记录。
- Documented limitations/follow-ups: 生图中的建筑和小礁数量不作为最终设计；下一阶段按坐标草案重排四张生产背景，再同步地点、碰撞、海图标记和针对性测试。
