# CHG-20260818 海域圆角视野揭示

- Status: complete
- Type: visual-behavior
- Owner: Codex
- Created: 2026-08-18

## Goal and player/project outcome

把玩家航行视野的永久开图形状从直角矩形改为圆角矩形，让完整海图和航行边缘形成连续圆润的水墨轮廓，减少矩形裁切感。

## Scope

- 相机视野四边仍按现有 48 世界像素内缩。
- 视野揭示印章的四角改为稳定圆弧，圆角半径随视野短边缩放。
- 玩家移动时继续合并永久揭示印章；现有 Shader 柔边叠加在圆角逻辑轮廓上。

## Non-goals

- 不修改大陆初始揭示多边形、探索存档格式、地点显隐和迷雾美术纹理。
- 不改变视野中心区域或四条边的主要可见范围。

## Acceptance checks

- [x] 单次玩家视野揭示为圆角矩形，靠近直角尖端的单元保持未探索。
- [x] 圆角内部、四边中心和玩家周围仍正常揭示。
- [x] 航行连续开图不产生断层，完整海图无明显直角矩形轮廓。
- [x] 永久探索、地点显隐和跨场景恢复保持正常。
- [x] 专项自动化与 OpenGL 截图验证通过。

## Documentation impact

- Canonical documents: `docs/design/sea-overworld-design.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`

## Verification evidence

- Automated: Godot 4.7.1 .NET `--headless --editor --quit` 解析退出 0；`tests/test_sea_fog_of_war.gd` headless 退出 0，新增断言确认圆角半径至少 160 世界单位、圆弧内部已揭示、旧矩形尖角仍被迷雾覆盖，并继续覆盖地点显隐和跨场景恢复。
- Manual/in-engine: OpenGL Compatibility 1344×896 实际渲染退出 0；检查 `.godot/sea_fog_map_preview.png`，出生开图区域两侧底角呈连续圆弧；连续航线截图无迷雾断层。

## Final reconciliation

- Files changed: `scripts/sea_fog_of_war.gd`, `tests/test_sea_fog_of_war.gd`，以及本记录和三份规范/验收文档。
- Documented limitations/follow-ups: 圆角半径当前为内缩后视野短半轴的 `0.5`；后续若相机视野比例或 48 像素内缩规则变化，半径会按比例自动调整。
