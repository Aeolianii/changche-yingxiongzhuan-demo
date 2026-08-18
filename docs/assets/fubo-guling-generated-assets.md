# 伏波古岭生成素材清单

- Status: single-background selected; Godot integration pending
- Last updated: 2026-08-10

## Shared specification

- 视角：俯视偏正面 3/4 像素 RPG，与 64×64 四方向角色兼容。
- 像素密度：以现有 64×64 角色叠放效果为基准；背景保持清楚的像素簇与稳定比例，不靠运行时缩放修正巨型物件。
- 色彩：南海青蓝、岭南湿润草绿、红褐岭南土壤、灰砖黛瓦、旧木赭色、少量朱红和铜金。
- 禁止：写实照片、等距 3D、柔焦、平滑矢量边缘、现代物件、人物、文字、Logo、水印。
- Godot 导入统一使用最近邻过滤；主背景保持不透明完整画面，只有后续确需动态表现的少量效果才使用透明素材。

## Drum minigame audio source

- Selected source recording: `TAIKO DRUM 001.wav` by Freesound user `sandyrb`, performed by Tyson Goodyear. The source is a clean 2.438-second mono taiko-style single hit made from a slowed floor-tom strike.
- Source page: `https://freesound.org/people/sandyrb/sounds/82712/`.
- Project source copy: `assets/audio/fubo_guling/sources/taiko_drum_001_hq.mp3`, downloaded from Freesound's public high-quality preview CDN because the original WAV download requires an account.
- License: Creative Commons Attribution 4.0, confirmed on the Freesound sound page on 2026-08-11. Required credit: `TAIKO DRUM 001.wav` by sandyrb, played by Tyson Goodyear, licensed under CC BY 4.0.
- Runtime derivatives: `drum_low.wav`, `drum_mid.wav`, `drum_rim.wav`; each is a mono single-hit derivative with different pitch/filter/envelope treatment for low drumhead, medium drumhead and sharp rim roles.
- `drum_fail.wav` is also derived from the same licensed source as a short, quieter, high-passed wooden-stick cue. It must remain below 0.3 seconds and quieter than the three playable drums; it is feedback, not an alarm.
- Source SHA-256: `B45B21F9D5C382C2376C67ED26B5815585F5A0727D8FACCAE75B4A392F99B797`. Derivative SHA-256 values: low `BFE0832EEA4A07843C2679F802267E230F3328577DAC7CC4CB9532D04572403B`, mid `C9C355E10A9CCA302D1513450D20B03ECBA36C85F8266378767CD0152A53BE87`, rim `5D1106479CBBD980D079F5007E0361F341D41F97A6690C186B715E3E5CCCF68B`, fail `BBE385E80828E1B0F86BF5D48847303D8CD19195289487C14E1A94E9EA11FDCE` (0.23 seconds, measured peak `-7.3 dB`).
- Research-only rejected source: Wikimedia Commons `02 Taiko2 (short).oga` is CC0 but contains continuous ensemble performance and overlapping hits, so it is not stored or used at runtime.

## Active production target: one complete background

- Active runtime target: `assets/fubo_guling/backgrounds/fubo_guling_complete.png`.
- Target source size: approximately 1536×1024, matching the first-act palace background method and the image model's stable 3:2 landscape output. Use one generation result with proportion-preserving crop only; do not stitch, outpaint or assemble multiple plates.
- The image contains all low lateritic hills, one continuous low-noise light red-brown critical path, coast, guard compound, trees, canal exterior, training yard, lookout and distant blocked scenery. It contains no characters, text, UI, interaction markers, decorative timber fencing or watermarks.
- Godot keeps only Player, Keeper, story blockers, optional water highlight and the Canal/School/Viewpoint `Area2D` triggers as separate scene content.
- Collision is manually authored as 6–9 broad `CollisionPolygon2D` regions. Buildings, roofs, large trees, forest, sea and cliffs are wholly inaccessible; no collision is inferred from pixels.
- Existing 64×64 characters are composited over the generated draft before approval. Reject the image if buildings or trees dominate half the camera, roads cannot fit two characters, or a complete island silhouette is visible.

### Selected production asset

- Owner selection date: 2026-08-10.
- Selection source: user-provided review image `C:\Users\wangk\AppData\Local\Temp\codex-clipboard-e2fe3b8a-77a6-4ff7-ba99-a7663d66a0d0.png`.
- Project destination: `assets/fubo_guling/backgrounds/fubo_guling_complete.png`.
- File properties: 1536×1024 PNG, 3,442,520 bytes, SHA-256 `1BD476F6FC176F93779BE6B42B040099DF0AE839D9976840F78539A82B8407DA`.
- Decision: use this image unchanged as the single map background; stop and discard the unselected style-variant generation run.
- Approved qualities: clear red-earth critical path, humid Lingnan vegetation, sparse functional stonework, modest grey-brick/blue-tile buildings, readable canal and training-yard landmarks, no decorative fence clutter.
- Integration status: selected for production, not yet assigned to the Godot scene and not yet collision-tested with the 64×64 player.

### Active generation prompt contract

The production prompt must preserve the following meaning:

> One complete 3:2 top-down three-quarter pixel-art RPG background for an ancient Chinese Lingnan coastal garrison, bright fresh and polished, crisp clustered pixels, clear turquoise South China Sea only at the landing edge, vegetation-covered low rolling lateritic hills, visible red-brown earth cuts, and one continuous lighter compacted red-earth critical path from dock to guard house, canal, training yard and lookout. The path stays about 144–192 pixels wide, smooth, low-noise and visibly brighter than blocked terrain; every local view reveals its continuation or the next landmark. Use light grey brick, blue-grey tiled roofs, small wok-ear or plain hard-gable houses, banyan, lychee and bamboo, a narrow stone-lined canal embedded in a red-soil slope, open red-earth military training yard with Chinese drum and plain flags, and a low sea-view beacon terrace. Stone is sparse and functional, limited to the dock, canal lining, foundations and a few natural outcrops. Shape boundaries with dark grass edges, low earth banks, tree masses and occasional building walls, never decorative timber fencing. Keep path centers and interaction clearings free of crates, rocks, posts, flowers and crossing lines. A local walkable scene, not a whole-island overview; land and winding roads continue toward the image edges. Spacious clean walkable ground sized for a 64×64 character, small-to-medium architecture, stable orthographic perspective, short soft shadows, refined but uncluttered detail. No characters, text, UI, logo, watermark, full island silhouette, ocean ring, giant buildings, generic Jiangnan garden compound, ornate sweeping eaves, tall stone tower, grey cliffs, rock forest, continuous stone ramparts, decorative timber fences, scattered rubble, cluttered path, Japanese shrine, Southeast Asian temple, northern imperial palace, tropical resort, isometric 3D, dark realistic rendering, painterly blur or antialiasing.

## 2026-08-12 钓鱼小游戏素材

- 生成方式：Codex 内置生图；精灵先生成在纯色洋红抠图底上，再使用 imagegen 技能附带的 `remove_chroma_key.py` 做软边透明化、收边与去色溢，最后以最近邻方式规整尺寸。
- 背景：`assets/fubo_guling/minigames/fishing/fishing_background_v1.png`，840×520。岭南海岛浅滩、顶部中央木码头、由浅玉色过渡至深青色海水；中央约七成水域留空，边缘仅保留克制的水草、礁石和水流纹理；无鱼获、人物、钩线、文字和 UI。
- 移动精灵：`small_yellow_croaker_v1.png`（黄花鱼）、`large_grouper_v1.png`（大石斑）、`blue_green_crab_v1.png`（青蟹）、`sea_rock_v1.png`（低价值岩石）。四者均为独立透明 PNG，使用清晰深墨轮廓与成组像素块，不烘焙水面、阴影和场景。
- 鱼钩：`fishing_hook_v1.png`，传统锻铁鱼钩与短麻绳结的独立透明精灵；使用深墨铁色、暖灰高光和清晰倒刺，替换原先的程序绘制白色弧线钩。
- 运行规则：背景和精灵只负责美术表现；生成素材不决定碰撞、分值或移动参数。鱼、蟹和岩石的速度、负重、命中半径继续由 `FuboFishingGame` 统一配置。
- 界面复用：右上“暂时离开”使用既有 `assets/ui/sea_overworld/sea_map_return_brush_v1.png`，不重复生成同功能笔触。

### 生图提示词约束

- 背景：古代岭南伏波岛海岸钓鱼小游戏；水墨像素 RPG 风；横向侧视玩法区域；顶部中央旧木码头；浅玉色、青绿、深蓝绿分层海水；中央开放、边缘少量水下石块与水草；禁止鱼获、钩线、人物、文字、UI、现代物件和水印。
- 黄花鱼：单条小型黄花鱼、朝右完整侧身、赭金鳞片、深墨轮廓、纯洋红背景；禁止水、气泡、额外鱼和阴影。
- 大石斑：单条粗壮贵重石斑、朝右完整侧身、朱红与焦橙鳞片、米白腹部、深墨轮廓、纯洋红背景；禁止场景和额外物件。
- 青蟹：单只完整青蟹、略俯视的游戏视角、双螯八足、青玉与蓝绿色甲壳、纯洋红背景；禁止水、植物和额外生物。
- 岩石：单块可钩取的沉重海底岩石、深灰绿色、赭色矿脉和少量藤壶、纯洋红背景；禁止沙地、水草、额外石块和阴影。
- 鱼钩：单枚竖向手工锻铁鱼钩，顶部连接一小段打结旧麻绳，倒刺向右上方，水墨像素风、纯洋红背景；禁止鱼竿、鱼饵、浮漂、水花、岸景、文字和额外鱼钩。

## 2026-08-12 敲鼓小游戏背景

- 生成方式：Codex 内置生图；生成完整不透明环境图后，按鼓台实际尺寸机械裁切并以最近邻缩放为 1020×356。
- 运行文件：`assets/fubo_guling/minigames/drum/drum_training_yard_background_v1.png`。
- 提示词约束：空旷的古代岭南海防校场，前中景为平整红土训练场，后方低矮灰砖垛墙，远处为湿润青绿山岭、榕竹与少量浅青海湾；水墨像素 RPG 风；视平线集中在上方、中央下方留空用于叠放三面鼓；只生成环境，禁止鼓、鼓架、人物、兵器、靶子、按键牌、进度条、UI、文字、标志和水印。
- 运行边界：背景不包含三面鼓和任何 UI；鼓、鼓架、点击范围与敲击反馈继续由 Godot 独立绘制，以便后续微调。

## Legacy modular plan (superseded)

The module lists and generated sheets below record previous prototypes only. They are not the active composition plan and must not be assembled into the next map. The replacement background passed review; on 2026-08-17 the unused sheets, plates, cropped modules and processing sources were removed from the working tree. Git history remains the recovery path.

## 2026-08-12 completion transition CG

- Runtime file: `assets/fubo_guling/cutscenes/fubo_completion_cg_v1.png` (1536×1024, 3:2).
- Generation path: built-in ImageGen, using the approved protagonist front/side/back pixel references and the existing bright Lingnan sea transition as visual references.
- Runtime treatment: Godot overlays the exact title `伏波古岭` and subtitle `渔获满舱，鼓令已成`; the bitmap intentionally contains no generated text. `FuboCompletionCutscene` plays the image for four seconds with a slow 1.045× to 1.0× push, staggered caption fade-in and full fade-out.
- Final prompt: `Preserve the approved first CG's bright late-afternoon Fubo Ancient Ridge environment, panoramic turquoise sea, layered green coves, bamboo framing, red-earth stone lookout, distant junk, basket, drumsticks, camera angle and right-side figure placement. Replace only the old warrior with the referenced chibi design translated into a handsome clean-shaven young adult of believable seven-head proportions: dark hair in the same round high bun, small gold-black crown, black-and-gold long court robe, gold bracers and deep-red cloak. Preserve the commanding rear three-quarter pose with both hands planted on the hips and elbows outward, facing the sea and sunset. Keep the open, bright polished Chinese pixel-art cinematic style and clean upper-center sky for engine text. No text, UI, city, dark border, chibi body, beard, helmet, gray hair, other people, photorealism or 3D.`

## Historical planned modules

- Ground: grass/earth texture and coastal ground treatment.
- Paths: packed-earth road, stone courtyard and coastal landing modules.
- Architecture: Lingnan guard house and small granary.
- Nature: banyan/lychee-like trees, shrubs and weathered rocks.
- Canal: three-way sluice, stone water basin and channel decorations.
- Training/viewpoint: war drum, three plain signal flags, wooden barriers and weathered stele.

## Legacy runtime rules

- Ground and paths remain below the player.
- Buildings, trees and tall props use their wall base, trunk or pole base as Y-sort anchor.
- Water effects remain independent Godot nodes so gameplay state can animate them.
- Collision and triggers remain authored in the scene and are never inferred from generated pixels.

## Historical prompts and files (superseded)

All four sheets were generated with the built-in image generation tool. Their chroma-key sources, alpha sheets and unused cropped modules were removed on 2026-08-17; only the assets still loaded by the current game remain under `assets/fubo_guling/generated/`.

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

## Historical 2026-08-10 four-plate coarse-pixel pass (superseded)

This pass replaced the dense realistic-pixel collage with four local camera plates and ten sparse foreground modules. Its specification is retained here as provenance, but the files were removed from the working tree on 2026-08-17 because the result remained visually fragmented and more complex than the accepted first-act single-background method.

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
- Historical runtime alpha files: `generated/modular/guard_house.png`, `grain_store.png`, `banyan_tree.png`, `lychee_tree.png`, `coastal_tree.png`, `canal_marker.png`, `drum.png`, `flag_yellow.png`, `flag_red.png`, `flag_blue.png`. Cleanup retains only `generated/modular/drum.png`, which the current drum minigame still loads.
- Processing: connected-component crop using `tools/crop_fubo_modular_sheet.py`, then the installed `remove_chroma_key.py` helper with border auto-key, soft matte, thresholds `12/220`, and despill.
- Collision: buildings and three tree trunks retain small authored foot collisions; canal marker, drum and flags are visual/trigger landmarks only.
