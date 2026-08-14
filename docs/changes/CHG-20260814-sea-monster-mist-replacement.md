# CHG-20260814：替换海怪雾影并增加动态雾效

- Status: done
- Date: 2026-08-14
- Owner: Codex

## Goal

用用户完成透明抠图的三张“海怪雾影”替换旧生成素材，并让海图上的白雾产生自然、缓慢的动态流动。

## Scope

- 删除旧 `sea_monster_mist_{1,2,3}_v1.png` 素材及导入记录。
- 统一使用 `海怪雾影1.png`、`海怪雾影2.png`、`海怪雾影3.png`。
- 更新海怪随机事件的三种贴图映射与测试断言。
- 扩展海怪雾影材质：亮色雾层缓慢漂移并产生轻微明暗呼吸；暗色剪影保持稳定。
- 保留现有边缘透明衰减、三种海怪与立绘的一一映射、事件选项和奖励。

## Non-goals

- 不重新生成或改画用户提供的三张透明 PNG。
- 不改变海怪事件概率、刷新规则、触发范围、对话或奖励。
- 不让海怪剪影本身位移、扭曲或闪烁。

## Acceptance checks

- 运行时只引用三张中文命名的新雾影素材，旧素材不再存在。
- 三种海怪事件分别显示对应的新雾影与既有立绘。
- 雾影材质使用时间驱动的低速流动，动态只主要作用于高亮白雾区域。
- 边缘保持透明融合，不重新出现深色矩形海水块。
- Godot 资源导入、shader 编译与海怪随机事件测试通过。

## Documentation impact

- `docs/design/sea-overworld-design.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- 本变更记录。

## Likely files

- `assets/sprites/sea_overworld/random_events/海怪雾影{1,2,3}.png`
- `scripts/sea_overworld.gd`
- `shaders/sea_event_vignette.gdshader`
- `tests/test_sea_overworld_sea_monster_event.gd`
- 上述受影响文档。

## Verification evidence

- 三张新 PNG 已逐张目视检查：白雾与淡黑剪影完整，外圈为真实透明背景。
- Godot 4.7.1 .NET headless 资源扫描与导入：通过；`海怪雾影3.png.import` 已按统一文件名重新生成。
- `tests/test_sea_overworld_sea_monster_event.gd` headless：通过；覆盖三张新路径、四角透明像素、动态 shader 参数、三种立绘映射、绕行与默认胜利奖励。
- `tests/test_sea_overworld_random_event_refresh.gd`：通过；随机事件双槽与补位逻辑未回归。
- `tests/test_sea_overworld_sea_monster_event.gd` Vulkan Forward+：通过，shader 编译无错误。
- Vulkan 实景截图 `res://.godot/sea_overworld_monster_mist_preview.png` 已人工检查：雾影周围海水不再出现深色矩形，边缘自然融入海面。
- 运行时代码、测试和现行文档已无旧英文雾影路径或“海怪剪影”命名。

## Actual changed files

- 删除 `assets/sprites/sea_overworld/random_events/sea_monster_mist_{1,2,3}_v1.png` 及其导入记录。
- 新增 `assets/sprites/sea_overworld/random_events/海怪雾影{1,2,3}.png` 及其导入记录。
- 更新 `scripts/sea_overworld.gd`、`shaders/sea_event_vignette.gdshader`。
- 更新 `tests/test_sea_overworld_sea_monster_event.gd`。
- 更新 `docs/design/sea-overworld-design.md`、`docs/tech/architecture.md`、`docs/qa/playtest.md` 与本变更记录。
