# 海上大地图生成素材清单

- 生成方式：Codex 内置生图工具
- 用途：海上大地图原型、生产分块与配套运行时素材
- 风格基准：项目现有俯视像素风、主角立绘、LPC角色比例及现有舰船素材
- 初次生成日期：2026-08-08
- 最近更新：2026-08-10

## 1. 素材文件

| 素材 | 文件 | 尺寸 | 布局 |
|---|---|---:|---|
| 广东海岸原型海上地图（高清版） | `assets/backgrounds/sea_overworld/guangdong_sea_map_v2_hd.png` | 3344×1882 | 单张16:9背景；场景内以0.75倍显示，地图范围不变 |
| B 区东部海域扩展 | `assets/backgrounds/sea_overworld/guangdong_east_sea_expansion_v1.png` | 3344×1882 | 三个大型地标岛；西侧纯海水衔接；场景内以0.75倍显示 |
| C 区南部海域扩展（左侧疏散版） | `assets/backgrounds/sea_overworld/guangdong_sea_zone_c_v2.png` | 3344×1882 | 四个大型地标岛分为左右两组；组间保留宽海峡；顶部衔接 A，最右侧预留 D；场景内以0.75倍显示 |
| D 区东南海域扩展（海色匹配版） | `assets/backgrounds/sea_overworld/guangdong_sea_zone_d_v2.png` | 3344×1882 | 海水匹配 B/C 色域；五个主岛复合体与障碍礁群颜色保持原图；场景内以0.75倍显示 |
| 主角Q版四方向 | `assets/sprites/sea_overworld/protagonist_chibi_4dir_v1.png` | 1776×887 | 4列×1行，每格444×887 |
| 玩家船只方向与状态 | `assets/sprites/sea_overworld/player_ship_4dir_states_v1.png` | 1448×1086 | 4列×2行，每格362×543 |
| 可复用岛屿 | `assets/sprites/sea_overworld/island_locations_atlas_v1.png` | 1920×820 | 4列×1行，每格480×820 |
| 海上事件船只（清理版） | `assets/sprites/sea_overworld/event_ships_atlas_v2.png` | 1560×1008 | 4列×1行，每格390×1008；已移除商船右侧残留线条 |
| 船尾航迹与侧浪 | `assets/sprites/sea_overworld/ship_wake_fx_atlas_v1.png` | 1448×1086 | 4列×2行，每格362×543 |
| 水墨像素交互按钮（普通态） | `assets/ui/sea_overworld/interaction_button_ink_v1.png` | 720×176 | 无文字透明PNG；场景内以360×88显示 |
| 水墨像素交互按钮（按下态） | `assets/ui/sea_overworld/interaction_button_ink_active_v1.png` | 720×176 | 同轮廓亮色反馈；场景内以360×88显示 |
| 水墨像素海图图标 | `assets/ui/icons/hud_map_v1.png` | 128×128 | 透明PNG；放置于原人物头像的菱形框中 |
| 岭南海域双向加载图 | `assets/ui/loading/lingnan_sea_loading_v1.png` | 1536×1024 | 3:2全屏背景；文字由 Godot 叠加，可复用于进入大地图与返回南海军港 |
| 水墨像素月面 | `assets/ui/sea_overworld/moon_clock_moon.png` | 256×256 | 透明PNG；作为左上月相时钟的着色器纹理，不包含外框或文字 |
| 大地图阶段一构图灰模 v1 | `assets/backgrounds/sea_overworld/concepts/sea_overworld_stage1_graybox_v1.png` | 1672×941 | 历史构图；B 为敌方核心、D 为群岛水战区，不接入游戏 |
| 大地图阶段一构图灰模 v2 | `assets/backgrounds/sea_overworld/concepts/sea_overworld_stage1_graybox_v2.png` | 1672×941 | 历史构图；B 右上为群岛水战区、D 右下为敌方核心海域，不接入游戏 |
| 大地图阶段一构图灰模 v3 | `assets/backgrounds/sea_overworld/concepts/sea_overworld_stage1_graybox_v3.png` | 1672×941 | 历史构图；强化北部港贸、南部蛮荒军事和四类功能岛差异，不接入游戏 |
| 大地图阶段一构图灰模 v4 | `assets/backgrounds/sea_overworld/concepts/sea_overworld_stage1_graybox_v4.png` | 1672×941 | 当前构图；将 B 区海防堡垒迁入中央偏右，缓解中央留白与右上地标竞争，不接入游戏 |

### 1.1 v4 生产运行时分块

四张分块以 v4 灰模为唯一构图参考，通过内置生图工具的 `sketch-to-render` 模式生成统一生产画面，再合成为仓库外的 `6528×3604` RGB 母图，并由 `tools/slice_sea_overworld_map.py` 按 `160` 源像素重叠带确定性裁切。母图与生成中间稿保存在 `D:\厂车英雄传DEMO\artwork\sea_overworld\`，不提交仓库。

| 分块 | 文件 | 尺寸 | 用途 | 生成方式 | SHA-256 |
|---|---|---:|---|---|---|
| A | `assets/backgrounds/sea_overworld/guangdong_sea_zone_a_v3.png` | 3344×1882 | 左上繁华海岸、南海军港与出征起点 | v4 生图母图裁切 `(0,0,3344,1882)` | `ACBB0B091D5F1D9B75EB712C5F048D96DF60A7CC39D520D5AEF98F8049CF03D6` |
| B | `assets/backgrounds/sea_overworld/guangdong_sea_zone_b_v3.png` | 3344×1882 | 右上群岛水战区与北线航道 | v4 生图母图裁切 `(3184,0,3344,1882)` | `BDA3BD4A2749A39C611F85C48F60358F3DB118DE7257CE6AB4364B35668468D8` |
| C | `assets/backgrounds/sea_overworld/guangdong_sea_zone_c_v3.png` | 3344×1882 | 左下蛮荒危险海域与南线航道 | v4 生图母图裁切 `(0,1722,3344,1882)` | `04974B2D0FCF139DA6E52C5D62CEE239F2DED9AB98F38265E32786E14EFFC64C` |
| D | `assets/backgrounds/sea_overworld/guangdong_sea_zone_d_v3.png` | 3344×1882 | 右下敌方核心海域与终局商港 | v4 生图母图裁切 `(3184,1722,3344,1882)` | `780A6024EE560850D43A31B579751058B93734D980AFA6C841480F1CA95D84A4` |

除地图底图和全屏加载图外，其余素材均已去除对应色键背景并保存为带Alpha通道的PNG；四角透明度已验证为0。

## 2. 图集顺序

### 2.1 主角Q版

从左到右：向下、向左、向右、向上。

### 2.2 玩家船只

- 第一行：静止状态，方向依次为向下、向左、向右、向上。
- 第二行：航行状态，方向依次为向下、向左、向右、向上。

### 2.3 岛屿

从左到右：港口城镇、渔村、海防军寨、荒岛秘境。

### 2.4 海上事件船只

从左到右：渔船、商船、水师巡逻船、海盗船。

### 2.5 航迹特效

- 第一行：4帧V形船尾航迹循环。
- 第二行：4帧船体两侧水花循环。

## 3. 初版移动感使用建议

1. 船只无输入时使用第一行静止状态；检测到移动输入后切换第二行航行状态。
2. 航行时在船体下层播放航迹第一行的4帧循环，建议8～10 FPS。
3. 两侧水花作为较弱的第二层循环，可以与主航迹错开一帧，避免机械同步。
4. 船只和航迹共同根据当前四方向切换或旋转，航迹始终位于船尾。
5. 船只航行时可增加1～2像素的轻微上下浮动；停止时隐藏独立航迹和水花。
6. 镜头跟随船只移动，静态地图产生相对位移，配合尾浪即可形成明确速度感，无需风向、洋流或加减速系统。

## 4. 最终生图提示词

### 4.1 海上地图

```text
Use case: stylized-concept
Asset type: production-ready pixel-art game overworld background
Primary request: create a light-weight sea overworld background inspired by the coastline of Guangdong, China, compressed and fictionalized for an RPG travel map. It must support a Q-version player ship moving freely between islands and locations.
Scene/backdrop: calm blue-green coastal sea with a broad west-to-east coast, several distinct island groups, one narrow strait, one optional tidal passage, a central harbor island, fishing-village island, fortified island and wilderness island.
Style/medium: crisp hand-painted pixel art, classic Chinese wuxia RPG overworld, top-down with slight front-facing elevation, nearest-neighbor-looking edges and restrained ink-wash influence.
Composition/framing: 16:9 landscape, at least 65 percent navigable water, broad central route and looping side routes.
Constraints: no text, labels, UI, icons, player, ships, people, title, border, watermark, wind arrows, fog, storms, currents, hazard reefs, route lines, grids or modern map symbols.
```

#### 高清化编辑

内置生图模式：图像编辑。以原地图为编辑目标，生成后等比高清化到3344×1882并进行轻度锐化。

```text
Use case: precise-object-edit
Asset type: high-resolution production background for the existing Godot sea overworld
Primary request: upscale and refine the supplied sea map into a much sharper high-resolution version suitable for camera zoom. Increase pixel/detail density and crispness while preserving the exact existing map layout.
Style/medium: polished high-resolution pixel art; retain the same Chinese wuxia RPG overworld look, palette, top-down perspective, lighting and calm sea.
Composition/framing: preserve the exact 16:9 framing and every landmass position and silhouette, including all four main locations, docks, rocks, island groups, straits and open-water routes.
Constraints: change only resolution, sharpness and fine texture detail. No moving, adding, removing, resizing or redesigning locations or landforms. No text, labels, UI, icons, player, ships, characters, routes, grid, border, watermark, blur, haze or crop.
```

### 4.2 主角Q版

```text
Use case: stylized-concept
Asset type: pixel-art game character sprite sheet
Primary request: create the same protagonist as a Q-version older Chinese naval commander, preserving his gray beard, bronze helmet and armor, dark red cloak and muted teal sleeves.
Style/medium: crisp chibi pixel art matching the project LPC scale, nearest-neighbor edges and no blur.
Composition/framing: one row of four equal cells: facing down, left, right and up; neutral standing pose suitable for a ship deck.
Scene/backdrop: perfectly flat #ff00ff chroma-key background.
Constraints: uniform background, no shadows, grid lines, labels, text, UI, weapons, ship, extra characters or watermark; preserve identity and outfit across directions.
```

### 4.3 玩家船只

```text
Use case: stylized-concept
Asset type: pixel-art player ship sprite sheet
Primary request: create a compact ancient Chinese player war junk with blue-gray sail, original white wave emblem, dark wood hull, bronze trim and small red command pennant.
Style/medium: crisp pixel art matching the generated map, top-down with slight front-facing elevation.
Composition/framing: two rows and four columns; columns are down, left, right and up; first row idle without wake, second row moving with short V-shaped wake and side splashes.
Scene/backdrop: perfectly flat #ff00ff chroma-key background.
Constraints: no grid lines, labels, text, UI, ocean background, people, extra ships, weapon effects or watermark; design and scale remain consistent in every cell.
```

### 4.4 岛屿与事件船只

```text
Use case: stylized-concept
Asset type: reusable pixel-art island and event-ship atlases
Primary request: generate four isolated islands—harbor town, fishing village, naval fortress and wilderness cave island—and four event ships—fishing boat, merchant junk, naval patrol ship and pirate junk.
Style/medium: match the generated sea map's crisp pixel art, palette and top-down perspective.
Composition/framing: four equal horizontal cells per atlas, generous separation and clear silhouettes.
Scene/backdrop: perfectly flat #ff00ff chroma-key background.
Constraints: no grid lines, labels, text, UI, people, modern structures or watermark.
```

### 4.5 航迹特效

```text
Use case: stylized-concept
Asset type: pixel-art animated ship wake and water-motion FX sprite sheet
Primary request: create a four-frame looping V-shaped stern wake and four small paired side-splash frames that clearly communicate forward motion at normal RPG overworld speed.
Style/medium: crisp opaque pixel clusters using white, pale cyan and medium blue, matching the player ship and map.
Composition/framing: top row four stern-wake frames; bottom row four side-splash frames; equal cells and consistent alignment.
Scene/backdrop: perfectly flat #ff00ff chroma-key background.
Constraints: no ships, islands, grid lines, labels, text, UI or watermark; no realistic translucency or blur.
```

### 4.6 商船素材清理

内置生图模式：图像编辑（以原事件船只图集和问题截图为参考），生成后进行洋红键控去底，并按 Alpha 连通区域移除商船右侧孤立竖线。

```text
Precisely edit this four-ship pixel-art atlas. Preserve the four ship designs, their order, scale, top-down perspective, crisp pixel-art rendering, spacing, and all legitimate masts, rigging, flags, sails, hull details, and cargo. In the second cell (merchant junk), remove only the isolated thin vertical stray line floating to the right of the ship; it is a cutout artifact and is not connected to the ship. Clean every ship silhouette so there are no detached accidental pixels or remnant marks outside the intended art. Use a perfectly uniform #ff00ff chroma-key background across the full canvas. No grid, labels, text, UI, shadows, ocean, extra objects, watermark, or redesign.
```

### 4.7 水墨像素交互按钮

内置生图模式：图像生成（普通态）与图像编辑（按下态）。两态生成后使用洋红键控去底，裁切并统一为720×176透明PNG；地点名和“进入 · E”继续由Godot文字层绘制。

普通态：

```text
Use case: stylized-concept
Asset type: production game UI interaction button, normal/idle state
Primary request: create exactly one isolated wide horizontal interaction-button frame for a Chinese wuxia sea-overworld game's enter-location prompt.
Style/medium: crisp water-ink pixel art matching the existing exploration HUD; dark black-green ink wash, muted jade center, restrained weathered antique-gold double-line outlines and stair-stepped pixel edges.
Composition: one centered symmetrical banner with a broad unobstructed text-safe area and subtle ink-brush tails at both ends.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background.
Constraints: no text, letters, Chinese characters, numbers, symbols, icons, characters, boats, scenery, extra UI, watermark or outside cast shadow; avoid vivid green.
```

按下态：

```text
Use case: precise-object-edit
Asset type: production game UI interaction button, pressed/active state
Primary request: preserve the exact normal-state silhouette, proportions, ornament positions and framing; change only the interaction state.
State change: make the dark-jade center subtly lighter, brighten the antique-gold inner line and add a restrained inward highlight while retaining the dark ink-wash mood.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background.
Constraints: no redesign, reshape, crop, rotation, movement, text, symbols, icons, extra UI or watermark.
```

### 4.8 水墨像素海图图标

内置生图模式：图像生成。生成后使用洋红键控去底，裁切并等比缩放到128×128透明PNG。

```text
Use case: stylized-concept
Asset type: production game UI icon for a Chinese wuxia sea-overworld map button
Primary request: create exactly one isolated folded maritime parchment chart with a simplified curving Guangdong-like coastline and one tiny restrained compass-point mark; it will sit inside an existing diamond frame.
Style/medium: crisp hand-painted pixel art with Chinese ink-wash influence and stair-stepped edges, readable at 72 pixels.
Color palette: aged ivory parchment, near-black ink coastline, muted antique gold bindings and restrained desaturated teal sea marks.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background.
Constraints: no text, labels, outer frame, diamond, scenery, characters, boats, UI panel, watermark or outside drop shadow.
```

### 4.9 岭南海域双向加载图

内置生图模式：图像生成。画面本身不烘焙文字，加载说明由 Godot 根据切换方向显示“正在进入大地图”或“正在进入南海军港”。

```text
Use case: stylized-concept
Asset type: production full-screen loading background for a Chinese wuxia pixel-art RPG.
Primary request: Create one atmospheric maritime journey loading illustration showing a single small ancient Chinese command junk sailing between a fortified coastal harbor and open island-dotted sea, representing travel between South Sea Harbor and the Lingnan sea overworld.
Input images: southbound_journey.png is the project's chapter-transition style reference for dense black ink-brush borders, antique parchment mood, and crisp pixel treatment; guangdong_sea_map_v2_hd.png is the subject and palette reference for the Lingnan coast, blue-green sea, islands, ancient harbor architecture, and ship scale. Do not copy the exact map layout.
Style/medium: polished hand-painted pixel art with Chinese ink-wash influence, crisp stair-stepped edges, dark ink feathering around the frame, antique gold accents, muted blue-jade water, slightly dramatic but calm.
Composition/framing: 3:2 landscape full-screen image; coastal harbor on the left-middle distance, open sea and small islands to the right, one command junk traveling along a subtle wake through the central third; keep a quiet darkened text-safe band across the lower center for engine-rendered loading text.
Lighting/mood: late-afternoon coastal light, contemplative departure and return, readable silhouettes.
Constraints: no words, no Chinese characters, no letters, no numbers, no UI, no logos, no loading bar, no player portrait, no multiple ships, no combat, no storm, no fog wall, no watermark. Fill the entire rectangular canvas with artwork; no transparency and no chroma-key background.
```

### 4.10 水墨像素月面

内置生图模式：图像生成。`function_button.png` 与 `player_status_frame.png` 仅作为视觉风格参考；生成图使用绿色键控去底并以最近邻方式缩小到 256×256 透明 PNG。月相明暗由 Godot 着色器连续绘制。

```text
Use case: stylized-concept
Asset type: game UI icon texture, intended for a lunar-phase clock inside the project's existing diamond HUD frame
Input images: Image 1 and Image 2 are style references only; match their ink-wash pixel-art rendering, dry brush texture, dark blue-black ink, aged parchment cream, and restrained antique-gold accents; do not copy their shapes or frame
Primary request: one centered full moon disc, perfectly circular, with subtle hand-painted lunar mottling and sparse Chinese ink-brush texture
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local background removal
Style/medium: ancient Chinese ink-wash pixel art UI asset, crisp nearest-neighbor pixel edges, readable at 96x96 pixels, solemn and elegant
Composition/framing: single moon disc centered, fills about 72% of the square canvas, generous even padding, no frame, no clouds
Color palette: warm parchment-white moon, muted gray ink mottling, thin dark ink outer contour; no bright white, no neon
Constraints: one moon only; background must be one uniform #00ff00 with no shadows, gradients, texture, reflections, floor plane, or lighting variation; crisp silhouette; no cast shadow; no glow outside the disc; do not use #00ff00 anywhere in the moon; no text, no face, no rabbit, no buildings, no stars, no clouds, no border, no logo, no watermark
Avoid: photorealism, smooth vector art, modern UI, ornate frame, extra objects
```

### 4.11 B 区东部海域扩展

内置生图模式：图像编辑。第一张输入为五岛东部扩展初稿，第二张输入为项目现有高清海图的风格和接缝参考。生成后以最近邻采样统一为 3344×1882 PNG。

```text
Use case: precise-object-edit for a production-ready 2D game world-map background tile
Input images: Image 1 is the edit target (the generated B East Sea expansion). Image 2 is a strict visual/style and western-edge water seam reference.
Primary request: simplify Image 1 into a sparse eastern sea zone containing exactly THREE playable islands total. Keep only: (1) the upper-left fortified island outpost, (2) the upper-right large merchant-port island, and (3) the lower-right mysterious forest/cave island. Remove the central pearl-farming island, remove the lower-left fishing-village island, and remove every other detached decorative rock, reef, tiny islet, island, or landmark throughout the ocean.
Replacement: replace every removed object and all its surf/wake/shadow traces with continuous clean cyan ocean that matches surrounding water perfectly. The result must feel spacious and sparse, with very broad uninterrupted sailing routes and long sea distances between the three remaining islands.
Seam invariant: the western 15% of the entire canvas must be completely uninterrupted open water matching Image 2's right-edge water—no land, rocks, reef, surf rings, shadows, objects, color bands, borders, or gradients.
Preserve: keep the same 16:9 framing, exact crisp pixel-art scale, top-down isometric-oblique camera, lighting, water hue and texture, three remaining island designs and their approximate positions. Keep all three islands fully inside safe margins and clearly separated.
Constraints: exactly three island landmasses in the whole image; shoreline rocks physically attached to those three landmasses are allowed, but no detached rocks/islets. No text, labels, borders, UI, compass, ships, people, monsters, logos, or watermark. No painterly blur and no photorealism.
```

### 4.12 C 区南部海域扩展

内置生图模式：图像编辑。以当前 C 区草稿为编辑目标，以 A 区底边为北侧接缝与水面风格参考；生成后使用最近邻采样统一为 3344×1882 PNG。

```text
Use case: precise-object-edit for a production-ready 2D game world-map background tile
Input images: Image 1 is the current south C-zone edit target. Image 2 is the A-zone reference directly above C and the north seam-water reference.
Primary request: keep C south of A and keep exactly the same four recognizable island designs, but spread the islands farther apart because the current layout feels crowded. Preserve a natural irregular archipelago with unequal distances, not a grid or four-corner rectangle.
New approximate positions: move lighthouse island toward upper-left, centered around 19% canvas width / 29% height; move fortified sea-gate island farther right and slightly upward, centered around 55% width / 34% height; keep fishing-village island left-lower, centered around 27% width / 65% height; move ancient forest/cave island farther right and slightly upward, centered around 59% width / 78% height. These are approximate organic placements. Make all visible ocean gaps clearly wider than before; the closest pair must still have at least one-third of a medium island's width of uninterrupted water between their surf lines. No two centers align horizontally or vertically.
North seam invariant: the TOP 15% of the canvas remains completely uninterrupted open sea matching Image 2's bottom-edge water—same cyan hue, brightness, texture, and lighting. No land, rock, reef, surf, shadow, wake, object, band, border, or gradient may enter it.
Future-D invariant: retain at least the RIGHTMOST 25% as uninterrupted open ocean for the future D zone. C has no neighbor on its left, so islands may sit near the left while staying fully inside safe margins.
Replacement: replace all vacated island positions, surf, shadows, wakes, seams, and artifacts with perfectly continuous ocean. Rebuild clean natural water around each new island position.
Preserve: exactly four island identities, architecture, relative sizes, crisp high-detail pixel art, isometric-oblique top-down camera, palette, lighting, water texture scale, and Chinese wuxia RPG ink-wash atmosphere.
Constraints: exactly four island landmasses total. No detached rocks, reefs, tiny islets, sandbars, extra landmarks, text, labels, routes, compass, border, UI, ships, people, monsters, logos, or watermark. No islands touch or overlap. No photorealism, painterly blur, or soft 3D rendering.
```

### 4.13 C 区左右岛组间距调整

内置生图模式：图像编辑。第一张输入为 C 区左侧布局草稿，第二张输入为 A 区水面与顶部接缝参考；生成后以最近邻采样统一为 3344×1882 PNG。

```text
Use case: precise-object-edit
Asset type: production-ready 2D Godot sea-overworld background tile for the southern C zone
Input images: Image 1 is the current C-zone edit target. Image 2 is only the project's A-zone water, pixel-art style, scale, lighting, and north-seam reference.
Primary request: change ONLY the horizontal grouping distance. Keep the two LEFT islands—the upper lighthouse island and lower fishing-village island—at their current positions. Move the two RIGHT islands—the fortified sea-gate island and the ancient forest/cave island—farther to the RIGHT so the right pair is clearly separated from the left pair by a broad uninterrupted vertical ocean corridor.
Composition: keep the irregular, non-grid layout and the current unequal vertical positions. Approximate centers after moving: lighthouse around 15% width / 28% height unchanged; fishing village around 21% width / 68% height unchanged; fortified island around 52% width / 38% height; forest/cave island around 56% width / 81% height. The open-water corridor between the surf lines of the left pair and right pair should be visibly wide—at least 12% of the full canvas width. Keep every island and surf fully inside the left 70% of the canvas, leaving the RIGHTMOST 30% completely uninterrupted open ocean for future D-zone adjacency.
North seam invariant: keep the TOP 16% completely uninterrupted open sea matching Image 2's lower-edge cyan water. No island, rock, reef, surf, shadow, wake, band, border, seam, object, or gradient may enter it.
Replacement: erase the old positions of the two moved islands and all leftover surf, wakes, shadows, reefs, seams, or ghost artifacts, replacing them with perfectly continuous matching ocean.
Preserve: exactly the same four island identities, architecture, large readable scale, crisp high-detail pixel art, nearest-neighbor-looking edges, palette, lighting, camera, Chinese wuxia RPG ink-wash atmosphere, and water texture. Preserve the two left islands exactly.
Constraints: exactly FOUR island landmasses total. No detached rocks, reefs, tiny islets, sandbars, extra landmarks, text, labels, routes, compass, border, UI, ships, people, monsters, logos, or watermark. No island touches another. No four-corner rectangle, aligned grid, equal spacing, photorealism, painterly blur, soft 3D rendering, crop, or transparency.
```

### 4.14 D 区东南海域扩展

内置生图模式：图像编辑。以 B 区水面为编辑底图，以 C 区和 A 区作为接缝、岛形、附岛与障碍礁群参考；经过间距与左侧位置修正后，以最近邻采样统一为 3344×1882 PNG。最终修正提示词如下：

```text
Use case: precise-object-edit
Asset type: final production-ready southeast D-zone Godot world-map tile
Input images: Image 1 is the D-zone edit target. Image 2 is the strict west seam-water reference.
Primary request: reposition ONLY the two LEFT playable major island complexes to exact approximate target centers. Put the upper fortified reef-gate complex center at 32% canvas width / 27% canvas height. Put the misty forest/cave archipelago center at 31% canvas width / 55% canvas height. Preserve their current vertical identity/order, exact shapes, sizes, architecture, satellite islets, reef details, mist, and surf.
Safe placement invariant: the leftmost visible surf pixel of either moved complex must be at or after 17% canvas width, while both centers must be no farther right than 33% canvas width. This creates the intended slightly-left placement while retaining the C/D seam.
Fixed invariants: keep the upper-right crescent harbor, middle-right ancient-shrine ridge, bottom chain-shaped fishing/mangrove complex, and every non-playable obstacle cluster exactly fixed pixel-for-pixel.
Seam invariants: the entire LEFTMOST 17% and TOP 16% remain completely uninterrupted cyan ocean with no land, island, rock, reef, satellite islet, surf, mist, shadow, wake, object, seam, band, border, or gradient.
Replacement: erase the two old positions and all residual pixels, replacing them with continuous matching water.
Preserve: exactly five playable major island complexes; current broad central corridor; irregular unequal spacing; non-round silhouettes; crisp high-detail Chinese wuxia pixel art; camera, palette, water texture, and lighting.
Constraints: do not add, remove, resize, redesign, or restyle any island or obstacle. No mainland, text, labels, routes, compass, border, UI, ships, people, monsters, logos, watermark, crop, blur, or transparency.
```

### 4.15 D 区海水颜色匹配

内置生图模式：精确图像编辑。使用 D 区为目标图，以 C/B 区为海水色彩与纹理参考；生成结果用于确认目标色域。为严格保护岛屿，最终生产图从 D 区原图建立仅覆盖海水候选像素的受限蒙版，将海水均值从约 RGB `(1, 181, 244)` 校正为约 RGB `(6, 171, 222)`，蒙版外像素逐字节保持不变。最终提示词如下：

```text
Use case: precise object-preserving raster edit for a production Godot world-map tile.
Input roles: Image 1 is the D-zone target. Images 2 and 3 are water palette and texture references only.
Primary request: change ONLY the open-ocean water color and brightness in Image 1 so it matches the deeper blue-cyan sea of Images 2 and 3, approximately RGB (5, 172, 222). Retain Image 1's existing subtle wave texture and exact pixel-art/watercolor texture.
Strict invariant: every pixel belonging to islands, land, vegetation, buildings, docks, beaches, rocks, reefs, satellite islets, obstacle clusters, surf foam, and mist must remain visually unchanged. Do not move, resize, redraw, recolor, add, or remove any land feature.
Preserve the exact canvas, composition, five island complexes, two non-landable reef obstacle clusters, spacing, scale, and seamless tile edges.
No text, labels, UI, ships, compass, border, frame, new islands, or new objects.
Output should be a faithful water-only color correction, not a reimagining.
```

### 4.16 大地图阶段一构图灰模

内置生图模式：图像生成。A/B/C/D 四张现有生产背景仅作为风格、镜头、岛屿身份与尺度参考；输出是一张新的全图拼接构图概念，不替换生产底图。

```text
Use case: stylized-concept
Asset type: low-fidelity game world-map composition graybox for preproduction, not final art
Input images: Images 1-4 are style, camera, current island identity, and scale references for the existing A/B/C/D sea-map chunks. Create a new single stitched overview; do not reproduce their current disconnected placements.
Primary request: design one coherent 16:9 maritime campaign-map graybox for a Chinese wuxia RPG. Show only island massing, approximate size hierarchy, placement, open-water corridors, and seam-spanning visual relationships. The eye must travel from a dense mainland naval departure area in the upper-left, through two branching sea routes, and finally to one dominant enemy core port landmark in the upper-right.
Scene/backdrop: calm cyan sea covering the full canvas. Treat the canvas as four invisible equal A/B/C/D quadrants: A upper-left, B upper-right, C lower-left, D lower-right.
Composition/framing: wide top-down oblique overworld view matching the reference camera. A: dense northwest mainland coast plus a large naval-port island, one smaller fishing settlement, two secondary islands, and a descending southeast chain of tiny islets aimed toward the center. B: three main islands arranged diagonally rather than horizontally—mid-left fortified outpost, mid-upper secondary port, and a clearly largest dominant core port near the upper-right—connected by sparse stepping-stone reefs with a readable open approach corridor. C: dangerous sparse outer sea with only two major landmarks, one tall lighthouse island and one pirate-fort island; two existing secondary locations become much smaller low sandbar and broken ruin/reef clusters; add scattered thin reef chains and shipwreck-scale marks, leaving broad navigable water. D: fragmented archipelago battle zone spread across the quadrant instead of packed at the right edge; include five distinguishable island complexes with crescent, long-ridge, broken-cluster, fortress, and chain silhouettes; shape three clear corridors: broad central passage, narrow reef channel, and longer safe southern route. Connect C to D and D upward into B using island-chain direction and water openings. Avoid a blank blue hole at the four-quadrant center.
Style/medium: deliberately rough preproduction blockout; simplified painted pixel-art silhouettes; flat muted green-gray land, tan shore, cyan water; minimal placeholder architecture blocks only for scale; low detail, clear masses, no polish.
Size hierarchy: 2-3 extra-large landmarks, 4-5 large islands, 6-8 medium locations, and many tiny islet/reef groups acting as visual glue. Preserve at least 60 percent navigable water.
Constraints: no text, labels, letters, numbers, UI, legend, grid, quadrant divider lines, arrows, route lines, compass, ships, characters, combat, weather, fog, decorative border, logo, or watermark. No photorealism, no final rendering, no dense architectural detail, no four-corner grid placement, no repeated round green islands, and no empty center.
```

### 4.17 大地图阶段一 B/D 互换灰模

内置生图模式：精确图像编辑。第一张输入为阶段一 v1 灰模，第二张为三地标敌方核心海域参考，第三张为五岛群水战区参考。A/C 左半区保持宏观体量不变，仅交换 B/D 的区域职责。

```text
Use case: precise-object-edit
Asset type: revised low-fidelity game world-map composition graybox for preproduction, not final art
Input images: Image 1 is the existing stage-one stitched graybox edit target. Image 2 is the three-landmark enemy-core composition reference. Image 3 is the five-complex archipelago battle-zone composition and silhouette reference.
Primary request: revise Image 1 by swapping ONLY the narrative and compositional roles of the upper-right B quadrant and lower-right D quadrant. B in the upper-right must become the fragmented archipelago naval-battle zone inspired by Image 3. D in the lower-right must become the enemy core sea inspired by Image 2. Preserve the overall 16:9 framing, sea palette, camera, rough graybox treatment, and the macro massing and positions of the entire left half A and C.
B upper-right composition: distribute five clearly distinct island complexes across the quadrant instead of forming one heavy terminal city. Use a small fortified reef-gate near upper-left B, a crescent harbor near upper-middle/right, a broken misty cluster near middle-left, a long ridge island near middle-right, and a low chain archipelago near the lower B/D seam. Organize three readable water corridors: a broad central passage, a narrow reef channel, and a longer outer detour. Keep broad navigable water and avoid a dense pile at the far right.
D lower-right composition: use exactly three main strategic landmarks arranged on a descending diagonal from upper-left D toward the bottom-right corner. First is a medium-large fortified forward outpost near upper-left D; second is a medium mysterious island near central D; third is one unmistakably largest fortified enemy core port near the bottom-right, serving as the final visual destination. Add only sparse stepping-stone reefs connecting the three. The final core port must be visually dominant but remain fully inside safe margins with navigable water around it.
Route structure: the northern route travels from A through B's archipelago and descends across the B/D seam into D. The southern route travels from A through sparse dangerous C and crosses the C/D seam into D. Both routes visually converge on the central D island, then terminate at the bottom-right core port. Use island-chain direction and water openings only; no drawn route lines.
Center and seams: keep the four-quadrant center connected by sparse diagonal islets but retain a broad cross-shaped navigable water gate. B/D and C/D seam relationships must point toward D rather than back toward B.
Style/medium: deliberately rough preproduction blockout; simplified painted pixel-art silhouettes; flat muted green-gray land, tan shore, cyan water; minimal placeholder architecture blocks only for scale; low detail, no refinement.
Invariants: preserve A upper-left as the dense mainland naval departure region. Preserve C lower-left as sparse dangerous outer sea with one lighthouse landmark, one pirate-fort landmark, a small sandbar group, and a broken ruin/reef chain. Do not move or redesign the left-half macro composition.
Constraints: no text, labels, letters, numbers, UI, legend, grid, quadrant divider lines, arrows, route lines, compass, ships, characters, combat, weather, fog, decorative border, logo, or watermark. No photorealism, no final rendering, no empty center, no repeated round-island grid. Do not leave the dominant enemy city in upper-right B; it must be in lower-right D.
```

### 4.18 大地图阶段一功能差异化灰模 v3

内置生图模式：精确图像编辑。以 v2 为编辑目标，先建立功能造型和南北海域差异，再通过两次局部编辑恢复 A4/B5/C4/D3 的地点分配。以下为最终提示词组。

#### 4.18.1 主编辑

```text
Use case: precise-object-edit
Asset type: revised low-fidelity game world-map composition graybox v3 for preproduction, not final art
Input images: Image 1 is the approved v2 stitched graybox edit target. Preserve its 16:9 framing, cyan sea, top-down oblique camera, A/B/C/D quadrant roles, approximate main-location centers, and total count of major playable locations. Do not add any new major island or settlement.
Primary request: redesign the existing islands so every functional type has a distinct silhouette and construction logic, while strengthening the contrast between prosperous northern seas and dangerous southern seas. Fix the repeated formula of round rock base + ring wall + Chinese buildings + wooden docks.
Northern half A and B: portray a prosperous, populated trade-and-shipping sea. Use broad clean shipping lanes, fewer tiny islets, calm open water, active-looking harbors, warehouses, quays, sheltered bays, and more docks only where the function requires them. A mainland city must grow organically from the coastline rather than sit on a circular rock pedestal. A major merchant port should be low and wide around a crescent harbor basin, with stone quays, warehouses, market roofs, several piers, and no complete defensive wall. A small fishing village should be a flat sandbar or mangrove shore with stilt houses and one modest jetty, no wall. In upper-right B keep the same five major location groups but remove roughly half the decorative detached reef dots and eliminate clutter; create one unmistakable broad, clean shipping corridor through the quadrant. Differentiate B's five locations as an angular naval checkpoint, a low crescent merchant harbor, a modest fishing settlement, a long inhabited trade island, and one restrained natural landmark. Do not make all five urban or equally detailed.
Southern half C and D: portray dangerous, wild, militarized and pirate-controlled waters. Use taller mountain islands, caves, bare rock, broken asymmetric coastlines, jagged reefs, narrow crooked passages and fewer cities or docks. The lighthouse island must be a steep narrow peak with only a lighthouse and tiny landing, no town or wall. The pirate stronghold must be an irregular cliff island with timber palisades, crude towers and one rough hidden jetty, not a formal ring-walled city. The low sandbar must remain almost flat and sparsely inhabited. The ruin island must be broken into natural rock shelves with ruins and no working dock. In D, the forward fortress must use angular stone breakwaters, exposed rock, heavy walls and a single military pier. The middle mysterious island must be a tall uninhabited mountain/cave island without a dock. The bottom-right enemy core must remain the largest final destination, but redesign it as a severe cliff citadel with geometric sea walls, fortified harbor mouth and military docks—not another lush circular city island.
Island-chain rhythm: remove evenly spaced pearl-necklace chains and anything that looks like a drawn level path. Arrange small rocks in irregular clustered rhythm: dense group near a coast, then sparse pair, then a broad open-water interval, then another dense hazard cluster. The overall reading must be dense -> sparse -> open -> dense, with large uneven gaps and no continuous dotted line.
Central sea: retain a broad navigable open-water area but relieve the empty-hole feeling with exactly 3 to 5 extremely small irregular reefs plus one partially submerged ancient shipwreck. Scatter them asymmetrically; do not align them, connect them into a route, or make them look enterable. Keep most of the center empty.
Functional silhouette rules: merchant port = low crescent bay, stone quays, warehouses, multiple piers, no full wall; military fortress = angular artificial sea wall, bare rock, dominant fortifications, one military dock; fishing village = flat sandbar or mangrove, stilt huts, one small jetty, no wall; uninhabited mountain island = steep asymmetric peak, cave and broken shore, zero buildings or docks. Every major island must clearly choose one function and not share the same base silhouette.
Style/medium: deliberately rough preproduction blockout; simplified painted pixel-art silhouettes; low detail; flat muted green-gray and tan land against cyan water; enough placeholder architecture to communicate function, no refinement.
Invariants: preserve A upper-left as mainland departure region; B upper-right as northern archipelago shipping/battle zone; C lower-left as sparse dangerous outer sea; D lower-right as enemy core sea; preserve approximate main-landmark positions and existing major-location count; retain v2's bottom-right final destination hierarchy.
Constraints: no text, labels, letters, numbers, UI, legend, grid, quadrant lines, arrows, route lines, compass, moving ships, characters, combat, weather, fog, border, logo, or watermark. The single broken shipwreck in the center is allowed. No photorealism, no final rendering, no extra major islands, no extra cities, no evenly spaced reef chains, no repeated circular green-rock city bases, and no cluttered upper-right.
```

#### 4.18.2 地点数量恢复

```text
Use case: precise-object-edit
Asset type: corrected stage-one world-map graybox v3
Input images: Image 1 is the v3 draft edit target whose functional differentiation, north/south contrast, clean B quadrant, central tiny reefs and single shipwreck must be preserved. Image 2 is the v2 location-count and approximate-placement reference only.
Primary request: make only one correction: restore the THREE existing location groups that Image 1 accidentally merged or omitted, so the composition again represents A4, B5, C4 and D3 location groups. These are not new locations; they existed in Image 2. Keep every other improvement from Image 1 unchanged.
Restore in A upper-left: besides the existing mainland port city and large crescent merchant harbor, restore exactly two modest secondary locations in the open water/nearshore area between A and the central seam. One must be a very small flat fishing-village sandbar with stilt huts and one short jetty, no wall. The other must be a small irregular natural secret-island/outpost with an asymmetric green-rock silhouette, sparse trees or one tiny shrine, and no city wall; it may have only a minimal landing. Keep both clearly smaller than the crescent merchant harbor. Do not clutter A or block its broad shipping lane.
Restore in D lower-right: besides the existing central tall uninhabited cave mountain and the huge bottom-right enemy core citadel, restore exactly one medium forward military fortress near the upper-left edge of D, below the horizontal centerline and right of the vertical centerline. It must use angular bare-rock foundations, geometric breakwaters, dominant fort walls and exactly one military pier. It must not look like a merchant town, circular green city island, or another giant endpoint.
Preserve strictly from Image 1: northern prosperous trade character; southern wild military character; differentiated merchant port, fortress, fishing village and uninhabited mountain silhouettes; reduced upper-right clutter and broad clean B shipping corridor; irregular dense -> sparse -> open -> dense rock rhythm; central area with only 3 to 5 extremely small reefs and one partially submerged shipwreck; bottom-right core citadel hierarchy; rough preproduction pixel-art graybox style, framing, camera and palette.
Location distribution invariant: A upper-left must read as four functional location groups total including the mainland city; B upper-right remains five; C lower-left remains four; D lower-right becomes three. Do not delete, merge, duplicate, or add any other major location group.
Constraints: no text, labels, grid, route lines, arrows, UI, compass, moving ships, characters, border, logo or watermark. Do not add any extra major island beyond the three restored existing groups. Do not recreate evenly spaced pearl-necklace reef chains. Do not change the central shipwreck. Do not redesign or move the existing B, C, D mountain or final citadel groups.
```

#### 4.18.3 B 区小渔村恢复

```text
Use case: precise-object-edit
Asset type: final corrected stage-one world-map graybox v3
Input images: Image 1 is the nearly final v3 edit target. Preserve the entire image exactly except for one small localized correction in upper-right B.
Primary request: restore B's missing fifth functional location by converting ONE existing small decorative reef group in the upper-right B quadrant into a very small, low, modest fishing-village islet. Use the small reef group below and slightly right of B's angular fortress and left of the long inhabited trade island, near the upper-middle-right open water. Keep the same tiny footprint: flat sand or mangrove base, three to five simple stilt huts, fishing racks and exactly one short wooden jetty. No wall, no tower, no large temple, no multi-pier harbor, no tall rock pedestal. It must be much smaller and quieter than the crescent merchant harbor.
Location invariant after this edit: A remains four functional location groups; B must clearly read as exactly five groups—angular fortress, crescent merchant harbor, tiny fishing village, long inhabited trade island, tall natural cave island; C remains four; D remains three. Do not add, remove, merge, resize, move or redesign any other major group.
Strict preservation: keep the mainland city, A crescent port, A sandbar village, A shrine island, all B groups, all southern islands, central 3 to 5 tiny reefs and the single shipwreck, dense -> sparse -> open -> dense rhythm, broad clean B shipping corridor, north/south contrast, bottom-right core citadel, composition, framing, camera, palette and rough graybox style unchanged.
Constraints: change only that one small reef group into the tiny fishing village. No other edits. No text, labels, route lines, arrows, UI, moving ships, characters, border, logo or watermark. Do not create extra rocks or islands. Do not clutter B.
```

### 4.19 大地图阶段一中央留白与地标层级灰模 v4

内置生图模式：精确图像编辑。以 v3 为唯一编辑目标，只迁移 B 区棱角型海防堡垒，其他地点、中央沉船与礁石均锁定。

#### 4.19.1 堡垒迁移

```text
Use case: precise-object-edit
Asset type: revised low-fidelity game world-map composition graybox v4 for preproduction, not final art
Input image: Image 1 is the approved v3 stitched world-map graybox and the edit target.

Primary request: make exactly ONE object relocation. Move the existing angular naval checkpoint fortress in the upper-right B sea—the medium bare-rock rectangular fort with geometric stone walls and one long wooden military pier, currently above-left of the crescent merchant harbor—diagonally down-left into the central-right open sea. Place its center at approximately 56% of canvas width and 43% of canvas height, still above the horizontal map midpoint and still belonging to B. Preserve the fortress's existing size, silhouette, orientation, architecture, rock base, pier, palette, camera and detail level.

Old location cleanup: completely remove the fortress from its old upper-right position and reconstruct that footprint as seamless clean cyan sea matching the surrounding water. Do not leave rocks, foundations, shadows or duplicate fragments there.

Composition intent: the relocated fortress becomes a gateway landmark at the northeast edge of the central navigable water, reducing the oversized central void. Keep at least roughly one-and-a-half fortress widths of open water around it. Maintain clear continuous east-west and north-south passages between it, the central shipwreck, the tall cave mountain to its right/lower-right, and nearby islands. It must not overlap or visually merge with the central shipwreck, tiny reefs, fishing village or natural mountain island.

Upper-right hierarchy after the move: the crescent merchant harbor is the primary upper-right architectural landmark; the long inhabited trade island is the secondary landmark. The tiny fishing village and tall natural cave island remain subdued. The old fortress position becomes open water, so the upper-right no longer presents three equal competing architectural landmarks.

Strict invariants: change only the fortress position and the water at its old footprint. Preserve every other pixel-level composition decision as closely as possible: all other 15 major location groups, A4/B5/C4/D3 distribution, mainland city, crescent ports, fishing villages, shrine island, long trade island, all southern islands, bottom-right enemy core citadel, central single shipwreck and 3 to 5 tiny reefs, north/south visual contrast, dense-to-sparse-to-open-to-dense rhythm, broad B shipping corridor, 16:9 framing, cyan sea, top-down oblique camera and rough painted pixel-art graybox style.

Constraints: do not add, delete, duplicate, resize or redesign any other island, reef, building, dock, shipwreck or landmark. Do not invent new objects. No text, labels, letters, numbers, UI, legend, grid, quadrant lines, arrows, route lines, compass, moving ships, characters, combat, weather, fog, border, logo or watermark. No final-art refinement.
```

#### 4.19.2 月环商港朝向修订

```text
Use case: precise-object-edit
Asset type: localized orientation correction for the stage-one world-map graybox v4
Input image: Image 1 is the current v4 edit target.

Primary request: change ONLY the orientation of the large crescent-shaped merchant harbor in the upper-right corner. It is the populated C-shaped architectural island near the top-right, above the long inhabited trade island. Horizontally mirror/turn the complete crescent harbor landmark in place so its enclosed bay opening faces LEFT toward the map center, and its long primary pier/harbor entrance also extends toward the LEFT. Keep the landmark's center at exactly the same position. Preserve its overall footprint, scale, crescent silhouette, buildings, quay density, palette, camera angle, shadows and rough painted pixel-art graybox detail.

Localized reconstruction: rebuild only the water immediately around the mirrored crescent edges and piers so it blends seamlessly. The result must clearly read as the same merchant harbor facing left, not a redesigned island and not a rotated camera view.

Strict invariants: preserve the relocated angular naval fortress in the central-right sea exactly where it is. Preserve every other island, reef, building, dock, coastline, central shipwreck, tiny reef, sea texture, spacing and composition unchanged. Preserve A4/B5/C4/D3, the reduced central void, clear east-west and north-south passages, the long inhabited trade island as the secondary upper-right landmark, northern trade character, southern dangerous military character, 16:9 framing, top-down oblique camera and rough graybox style.

Constraints: no new objects; no deletions or duplicates; do not move or resize the crescent landmark; do not change the central fortress; do not alter the long trade island; no text, labels, UI, arrows, route lines, compass, characters, moving ships, weather, border, logo or watermark. No final-art refinement.
```

## 5. 当前使用边界

这些素材服务于初版移动、地点提示和占位触发验证。当前不要求真实进入岛屿、播放海战或实现拟真航海环境；地图文字、地点名称、“进入 · E”和“开发中”提示继续由Godot界面控件绘制，不烘焙进图片。
