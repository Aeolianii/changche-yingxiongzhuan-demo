# CHG-20260818 海图连续水墨迷雾

- Status: done
- Type: content
- Owner: Codex
- Created: 2026-08-18

## Goal and player/project outcome

消除完整海图未知区域中规则重复的蓝色空隙与分块感，让探索迷雾表现为一整片连续、自然起伏的白色像素水墨云海；海上大地图同步直接复用海战素材，维持统一视觉。

## Scope

- 大地图与完整海图直接复用海战 `white_ink_mist_v1.png`。
- 将海战“大范围透明干笔雾纹交叠成连续云墙”的表现方式移植为探索 Shader 的六层低频、多尺度、错位/镜像采样，消除规律间隔。
- 加宽并纹理化完整海图的探索过渡带，减少生硬直角边界。
- 保留原探索边缘柔化、永久揭示、地点名称显隐、玩家标记和存档规则。

## Non-goals

- 不修改海战现有 `white_ink_mist_v1.png` 及其绘制逻辑，也不引入新的正式迷雾素材。
- 不修改探索位图、揭示范围、初始已知区域、地点数据或存档版本。
- 不改变完整海图框、地图底图或标签排版。

## Acceptance checks

- [x] 完整海图未知区域不再出现规律、重复的大块蓝色间隔或可辨认的贴图分块。
- [x] 白雾在大范围未知海域内连续覆盖，局部仍保留自然疏密与水墨飞白。
- [x] 探索边缘没有生硬直角墙，雾纹以自然云气过渡到已揭示区域。
- [x] 大地图和完整海图直接引用海战 `white_ink_mist_v1.png`；海战素材和绘制逻辑保持不变。
- [x] 地点显隐、玩家标记、揭示与跨场景恢复测试通过。

## Documentation impact

- Canonical documents to update before implementation: `docs/design/sea-overworld-design.md`, `docs/design/art-direction.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`
- Decisions/ADRs: 直接复用海战素材，但不能高频规则平铺；探索 Shader 复现海战的大笔触交叠覆盖原则。

## Implementation notes

- Likely files/modules: 两个探索迷雾脚本与 Shader、`tests/test_sea_fog_of_war.gd`
- Constraints and risks: 海战使用 C# `DrawTextureRect` 在格子空间布置笔触，海图使用 GDScript + Shader 裁切连续探索位图；不能直接调用同一绘制函数，只复用素材和大笔触交叠算法。

## Verification evidence

- Automated: Godot 4.7.1 .NET 资源与 Shader 解析退出 0；`tests/test_sea_fog_of_war.gd` headless 退出 0，断言大地图与完整海图都直接引用 `assets/naval/ui/fog/white_ink_mist_v1.png`，海图使用六层大笔触，并覆盖地点显隐、揭示与跨场景恢复。
- Manual/in-engine: Godot 4.7.1 OpenGL Compatibility 以 `1344×896` 连续三次运行专项场景退出 0；最终 `.godot/sea_fog_map_preview.png` 检查确认未知区域形成连续浅灰青白雾幕，无规律蓝色间隔或贴图行列，岛屿只保留符合战斗效果的低对比轮廓。

## Final reconciliation

- Files changed: `scripts/sea_fog_of_war.gd`, `scripts/sea_map_screen.gd`, `shaders/sea_world_fog_edge.gdshader`, `shaders/sea_map_fog_soft_edge.gdshader`, `tests/test_sea_fog_of_war.gd`，以及本记录和四份规范/验收文档。
- Documented limitations/follow-ups: 海战与海图的数据结构和坐标系不同，因此不能直接调用 C# `DrawFog()`；本次直接复用其素材，并在海图 Shader 中复现大笔触交叠原则。ImageGen 曾生成透明探索雾草稿，但用户确认应直接复用战斗素材后已从项目目录移除，未进入正式资源。
