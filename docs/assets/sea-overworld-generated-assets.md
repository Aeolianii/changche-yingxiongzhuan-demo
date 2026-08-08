# 海上大地图生成素材清单

- 生成方式：Codex 内置生图工具
- 用途：海上大地图初版原型
- 风格基准：项目现有俯视像素风、主角立绘、LPC角色比例及现有舰船素材
- 生成日期：2026-08-08

## 1. 素材文件

| 素材 | 文件 | 尺寸 | 布局 |
|---|---|---:|---|
| 广东海岸原型海上地图（高清版） | `assets/backgrounds/sea_overworld/guangdong_sea_map_v2_hd.png` | 3344×1882 | 单张16:9背景；场景内以0.75倍显示，地图范围不变 |
| B 区东部海域扩展 | `assets/backgrounds/sea_overworld/guangdong_east_sea_expansion_v1.png` | 3344×1882 | 三个大型地标岛；西侧纯海水衔接；场景内以0.75倍显示 |
| C 区南部海域扩展 | `assets/backgrounds/sea_overworld/guangdong_sea_zone_c_v1.png` | 3344×1882 | 四个大型地标岛不规则疏散分布；顶部纯海水衔接 A；右侧预留 D；场景内以0.75倍显示 |
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

## 5. 当前使用边界

这些素材服务于初版移动、地点提示和占位触发验证。当前不要求真实进入岛屿、播放海战或实现拟真航海环境；地图文字、地点名称、“进入 · E”和“开发中”提示继续由Godot界面控件绘制，不烘焙进图片。
