# 伏波古岭生成素材清单

- Status: integrated
- Last updated: 2026-08-10

## Shared specification

- 视角：俯视偏正面 3/4 像素 RPG，与 64×64 四方向角色兼容。
- 像素密度：地表以约 32×32 模块为基准，建筑和树木按整数像素缩放使用。
- 色彩：南海青蓝、岭南湿润草绿、灰砖黛瓦、旧木赭色、少量朱红和铜金。
- 禁止：写实照片、等距 3D、柔焦、平滑矢量边缘、现代物件、人物、文字、Logo、水印。
- 透明模块先在纯色键背景生成，再移除背景；Godot 导入统一使用最近邻过滤。

## Planned modules

- Ground: grass/earth texture and coastal ground treatment.
- Paths: packed-earth road, stone courtyard and coastal landing modules.
- Architecture: Lingnan guard house and small granary.
- Nature: banyan/lychee-like trees, shrubs and weathered rocks.
- Canal: three-way sluice, stone water basin and channel decorations.
- Training/viewpoint: war drum, three plain signal flags, wooden barriers and weathered stele.

## Runtime rules

- Ground and paths remain below the player.
- Buildings, trees and tall props use their wall base, trunk or pole base as Y-sort anchor.
- Water effects remain independent Godot nodes so gameplay state can animate them.
- Collision and triggers remain authored in the scene and are never inferred from generated pixels.

## Final prompts and files

All four sheets were generated with the built-in image generation tool. The project keeps both chroma-key sources, alpha sheets and cropped runtime modules under `assets/fubo_guling/generated/`.

### Architecture sheet

- Prompt: strict 2×2 top-down three-quarter pixel sprite sheet containing a grey-brick Lingnan guard house, small granary, roofed mountain gate and open sea-view pavilion; uniform `#ff00ff` background; clear wall-base anchors; charcoal tiles, damp grey brick, old timber, restrained vermilion/teal/gold; no people, labels, shadows, UI or watermark.
- Runtime files: `guard_house.png`, `granary.png`, `mountain_gate.png`, `view_pavilion.png`.

### Nature sheet

- Prompt: strict 3×2 pixel sprite sheet containing an old banyan, lychee tree, coastal palm, low shrub, sea-weathered rock cluster and mossy boulder; uniform `#ff00ff` background; visible trunk/base anchors; humid greens and blue-grey stone; no scenery baked around modules.
- Runtime files: `banyan_tree.png`, `lychee_tree.png`, `coastal_palm.png`, `shrub_cluster.png`, `coastal_rocks.png`, `mossy_boulder.png`.

### Gameplay-prop sheet

- Prompt: strict 3×2 pixel sprite sheet containing a three-direction stone/wood sluice, open stone basin, military drum, three plain signal flags, crossed timber barrier and blank stone stele; uniform `#ff00ff` background; clear base anchors; no flag writing, labels or effects.
- Runtime files: `sluice_mechanism.png`, `stone_basin.png`, `war_drum.png`, `signal_flag_yellow.png`, `signal_flag_red.png`, `signal_flag_blue.png`, `road_barrier.png`, `blank_stele.png`.

### Terrain sheet

- Prompt: strict 3×2 flat pixel terrain sheet containing humid grass, straight packed-earth road, 90-degree road corner, damp stone courtyard, sandy coastal landing and stone stairs; uniform `#ff00ff` background; broad low-profile overlapping decals; no horizon or vertical props.
- Runtime files: `grass_patch.png`, `earth_road_straight.png`, `earth_road_corner.png`, `stone_courtyard.png`, `coastal_landing.png`, `stone_stairs.png`.

### Processing

- Chroma-key removal used the installed image-generation helper with `#ff00ff`, soft matte thresholds `8/90` and despill.
- Sheets were split by their documented grids, trimmed by alpha and resized with nearest-neighbor sampling.
- The flag cell was separated by connected opaque components so adjacent flag fragments do not leak into individual textures.

## 2026-08-10 medium-map coarse-pixel pass

This pass replaces the dense realistic-pixel collage with four local camera plates and ten sparse foreground modules. It used the built-in image generation tool. The visual target was explicitly corrected to a native `384×256`-like image enlarged 4× with nearest-neighbor sampling: hard square pixels, no antialiasing, 24–32 colors, broad readable clusters and fewer tiny foliage marks.

### Local background plates

- `backgrounds/fubo_plate_sw.png`: southwest landing and guard-house approach; broad pale-ochre road, turquoise lower coast, small Lingnan grey-brick/blue-tile compound, fresh spring-green slopes. Prompt constraints: one camera neighborhood on a larger island; road and land continue beyond frame; no full island, overview, character, UI, flags, drum, sluice or giant building.
- `backgrounds/fubo_plate_se.png`: central/southeast three-branch canal clearing; broad empty road, modest stone-lined turquoise channels and baked inaccessible vegetation. Prompt constraints: exact SW pixel scale/palette/light; no giant machinery or landmark.
- `backgrounds/fubo_plate_nw.png`: northwest garrison training court; mostly empty packed-earth field, low grey walls and a tiny distant blue-grey tiled shelter. Prompt constraints: no troops, weapons, flags, drum, palace or giant gate.
- `backgrounds/fubo_plate_ne.png`: northeast summit lookout; ascending road, small open terrace and partial turquoise sea view. Prompt constraints: no complete island, diorama, huge pavilion or overview composition.

All four prompts included: `native 384x256 artwork enlarged exactly 4x nearest-neighbor; conspicuous hard square pixels; no antialiasing; large clean clusters; limited 24-32 color palette; simplified tile-like forms; classic 16-bit/32-bit RPG background; fresh Chinese/Lingnan coastal; top-down 3/4 orthographic; clear spring morning; avoid smooth gradients, painterly rendering, dark realism, Japanese shrine and Southeast Asian temple.`

Source guides are `generated/unified/guide_sw.png`, `guide_se.png`, `guide_nw.png`, and `guide_ne.png`. They preserve graybox corridor and clearing placement; gameplay collision remains authored independently in Godot.

### Sparse modular sheet

- Source: `generated/modular_sheet_source.png`.
- Prompt: exact 5×2 contact sheet on flat `#FF00FF`; top row guard house, grain store, banyan, lychee and wind-bent coastal tree; bottom row canal marker, Chinese barrel drum, yellow flag, red flag and blue flag. Match the four plates' coarse pixel density and top-down 3/4 perspective; each object isolated with padding; no labels, grid lines, cast shadows, scenery or extra objects.
- Runtime alpha files: `generated/modular/guard_house.png`, `grain_store.png`, `banyan_tree.png`, `lychee_tree.png`, `coastal_tree.png`, `canal_marker.png`, `drum.png`, `flag_yellow.png`, `flag_red.png`, `flag_blue.png`.
- Processing: connected-component crop using `tools/crop_fubo_modular_sheet.py`, then the installed `remove_chroma_key.py` helper with border auto-key, soft matte, thresholds `12/220`, and despill.
- Collision: buildings and three tree trunks retain small authored foot collisions; canal marker, drum and flags are visual/trigger landmarks only.
