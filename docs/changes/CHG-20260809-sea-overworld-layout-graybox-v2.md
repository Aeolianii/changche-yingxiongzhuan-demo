# CHG-20260809-sea-overworld-layout-graybox-v2: B/D 区域职责互换灰模

- Status: done
- Type: content
- Owner: Codex
- Created: 2026-08-09

## Goal and player/project outcome

在阶段一灰模基础上交换 B/D 的区域职责：B 右上改为群岛水战区，D 右下改为敌方核心海域。A/C 保持既有构图关系，两条征战路线最终在右下 D 区汇合。

## Scope

- 以阶段一 v1 灰模为编辑目标生成 v2，不覆盖旧图。
- B 区使用五组碎岛与三条航道，承担群岛水战空间。
- D 区使用三层斜向防御纵深，承担敌方核心海域和终局地标。
- 将 B/D 现有地点名称、视觉层级和坐标草案随区域职责交换。
- 同步海上大地图设计文档、阶段一布局文档和生成素材记录。

## Non-goals

- 不替换游戏运行时四张生产背景。
- 不修改地点触发、碰撞、海图 UI、事件、船只和测试代码。
- 不精修岛屿建筑、植被、海浪、材质和光影。

## Acceptance checks

- [x] A、C 的宏观体量和位置关系与 v1 一致。
- [x] B 右上由五组不同轮廓岛群构成，并可辨识三条水道。
- [x] D 右下由前置卫所、过渡岛和最大核心港构成斜向推进关系。
- [x] 北线经 B、南线经 C，两线均在 D 汇合。
- [x] B/D、C/D 接缝均自然指向 D 核心海域，不形成纯海断层。
- [x] 16 个地点坐标草案已更新且没有遗漏。
- [x] v2 图像保存到项目目录并完成视觉检查。

## Documentation impact

- Canonical documents to update before implementation: `docs/design/sea-overworld-design.md`
- Supporting documents: `docs/assets/sea-overworld-stage1-layout.md`, `docs/assets/sea-overworld-generated-assets.md`
- Decisions/ADRs: none

## Implementation notes

- Likely files/modules: `assets/backgrounds/sea_overworld/concepts/sea_overworld_stage1_graybox_v2.png` and the documents listed above.
- Constraints and risks: 生图可能改变 A/C 的局部细节；验收只要求其宏观体量和位置关系保持，不把生成建筑细节视为生产设计。

## Verification evidence

- Automated: 内容校验通过；坐标表共 16 行，其中 B 区 5 行、D 区 3 行；Markdown 围栏成对；`git diff --check` 无错误。PNG 为 1672×941、24-bit RGB，SHA-256 为 `CB754732E3AF1575227106BEB4973E8BE238066FC67D4E06DE1A979F7034C797`。
- Manual/in-engine: 已按原始分辨率检查 v2。A/C 宏观体量保持；B 可辨识五组岛群与多条水道；D 可辨识前置要塞、中央秘岛和右下最大核心港。概念图未接入引擎，符合非目标约束。

## Final reconciliation

- Files changed: `assets/backgrounds/sea_overworld/concepts/sea_overworld_stage1_graybox_v2.png`, `docs/assets/sea-overworld-stage1-layout.md`, `docs/assets/sea-overworld-generated-assets.md`, `docs/design/sea-overworld-design.md`, 本变更记录。
- Documented limitations/follow-ups: v2 只锁定岛屿体量、位置和区域职责；下一阶段需要将构图拆回四张生产分块，并重新校准地点、碰撞、海图标记和测试。
