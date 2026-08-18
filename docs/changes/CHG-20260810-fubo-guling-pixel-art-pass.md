# CHG-20260810-fubo-guling-pixel-art-pass

- Status: done
- Type: art / scene presentation
- Owner: Project owner
- Created: 2026-08-10

## Goal and player-visible outcome

把伏波古岭现有程序化灰盒替换为可拼装的岭南像素场景。保留已经试玩确认的地图动线、碰撞、触发和两项小游戏，让玩家看到海岛山岭、岭南守备院、古渠、校场与观景台的完整美术氛围。

## Scope

- 以现有 64×64 主角为比例基准，采用约 32×32 的地表模块密度。
- 使用生图模型制作项目专属像素素材，参考 `C:\Users\wangk\Desktop\美术组素材` 的清晰像素边缘、饱和海色和古代海疆建筑色彩。
- 素材按地表、道路/院落、岭南建筑、植被/岩石、水渠机关、校场/观景台装饰分组，不生成一张承担碰撞与遮挡的整幅背景。
- 建筑、树木和交互物继续以脚点 Y 排序；Godot 手工碰撞与剧情触发保持独立。
- 通过 Godot MCP 导入、设置最近邻过滤、搭建表现节点并运行截图检查。
- 修正完成界面按互动键重开时，场景卸载后再次获取 Viewport 导致的空引用。

## Non-goals

- 不改变水渠、听鼓、剧情阶段或地图任务锚点。
- 不接入标题、海图、存档或主流程。
- 不自动从图片 Alpha 生成碰撞。
- 不要求本轮产出完整通用 TileSet 编辑器资源；先形成可重复摆放的场景模块。

## Acceptance checks

- [x] 开局镜头不再以纯程序化色块为主要视觉，码头、守备院和海岸具有统一像素风格。
- [x] 五个区域均至少使用一组独立美术模块，玩家仍能沿原路线完成全流程。
- [x] 守备所、粮仓、树木、水闸、水池、军鼓、号旗、路障和石碑可独立替换或复用。
- [x] 建筑/树冠后方隐藏、前方显示的 Y 排序关系保持正确。
- [x] 现有 17 个碰撞/触发调试形状与新素材脚点大致对齐。
- [x] 所有新增纹理使用最近邻过滤，不出现模糊缩放、照片质感、文字或水印。
- [x] 伏波古岭专项测试和项目既有测试继续通过，Godot 运行日志无阻断错误。
- [x] 完成界面按互动键可以无错误重开伏波古岭。

## Documentation impact

- Updated: `docs/design/fubo-guling-slice.md`, `docs/design/art-direction.md`
- Added: this change record and generated-asset manifest

## Likely files

- `assets/fubo_guling/generated/`
- `scenes/fubo_guling/fubo_guling.tscn`
- `scripts/fubo_guling/fubo_placeholder_world.gd`
- `scripts/fubo_guling/fubo_world_prop.gd`
- `docs/assets/fubo-guling-generated-assets.md`

## Risks

- 生图素材可能无法严格形成无缝 TileSet，因此首轮优先使用带透明边缘的独立模块和可重复地表纹理。
- 生成图不能代替 Godot 的分层、排序锚点和碰撞校准。
- 仓库存在大量与本任务无关的素材导入改动，全部保留且不整理。

## Verification evidence

- Built-in image generation produced four source sheets: architecture, nature, gameplay props and terrain. Chroma-key removal produced transparent alpha sheets and 25 cropped runtime PNG modules; eight source/chroma/alpha sheets remain available for recropping.
- Godot MCP session `v3@2ce2` imported and assigned all textures, created 18 terrain decal nodes and nine additional Y-sorted decoration modules, saved the scene and ran the exact custom scene.
- Runtime screenshots checked the dock/guard-house opening view, canal, training yard, summit pavilion, water feedback, highlight marker and collision debug overlay.
- House collision test stopped the player at approximately `y=1183` with one slide collision; the red debug footprint aligns with the generated guard-house wall base. Debug mode still reports 17 authored collision/trigger shapes.
- Y-sort check placed the player at `y=1080` behind the guard house anchored at `y=1145`; the player was hidden by the building while the keeper in front remained visible.
- Completion restart regression: forced `COMPLETE`, sent an actual `E` key event, and confirmed the scene reloaded to phase `0`, player position `(430,1285)`, live MCP helper and a clean game log.
- `test_fubo_guling.gd` passed and now verifies the guard house, canal gate, tree textures and modular terrain node count.
- All 13 project headless tests passed after the final art and input changes.

## Final reconciliation

- Added `assets/fubo_guling/generated/` with 25 reusable runtime modules and eight retained source sheets.
- Updated the existing presentation scripts to draw generated textures at bottom-center foot anchors while preserving state overlays, highlights and existing gameplay methods.
- Added terrain decals and landmark/nature modules through Godot MCP without moving gameplay anchors or changing collision shapes.
- Kept the default title main scene, six-stage flow, canal truth table and random drum rules unchanged.
- Remaining art follow-up is optional hand-pixel cleanup or conversion of repeated terrain decals into a formal TileSet; it is not required for the current playable scene.
- Unrelated repository and import changes were preserved and not staged or committed.
