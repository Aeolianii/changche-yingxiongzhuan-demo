# CHG-20260810-sea-overworld-hd-layered-assets: 海上大地图高清分层资产

- Status: in-progress
- Type: art/content pipeline
- Owner: Codex
- Created: 2026-08-10

## Goal and player/project outcome

把当前海上大地图中与海水烘焙在一起、放大后细节模糊的大陆海岸与岛屿地标，重制为可独立摆放的高清透明 PNG；海水改为独立、可四块拼接的纯背景，使镜头放大时建筑、岩岸与码头仍保持清晰。

## Scope

- 以 `sea_overworld_stage1_graybox_v4.png` 和当前 A/B/C/D v3 生产图为构图、视角、功能造型与画风参考。
- 先制作“月环商港”代表性高清透明样张，锁定统一视角、比例、光照、描边与细节密度；它是完整独立岛，且高密度建筑与朝左月牙港口可同时验证清晰度和入口方向。
- 样张验收后，逐个制作其余活动地点与必要装饰岛礁；每个主体单独输出透明 PNG。
- 海水另行生成四张可拼接背景；不在海水图中烘焙岛屿、建筑、文字、航线或 UI。
- 本阶段先生成和验证美术资产，不接入 Godot 场景，不改碰撞与地点坐标。
- 岛屿底部材质按功能区分，禁止全部使用同一种岩石托盘：渔村、渔链与白沙渔岛以沙滩/浅滩/少量红树林或低岩为主；商港混合低沙岸与人工石码头；军事堡垒、灯塔、古岭和遗迹才使用明显岩基；自然群岛混合岩岸、沙湾与植被。

## Non-goals

- 不改变现有 15 个地点的名称、职责、中心坐标、入口方向和 A4/B5/C4/D2 分布。
- 不重设计大地图航线、碰撞、任务、事件、天气、潮汐或战斗逻辑。
- 不覆盖当前 A/B/C/D v3 运行时图片；新资产使用独立版本化目录和文件名。

## Acceptance checks

- [ ] 月环商港样张保持现有斜俯视角、岭南中式商港轮廓、低而宽的月牙形港池和朝左入口。
- [ ] 样张放大查看时，屋顶、城墙、岩岸、码头边缘清晰，无当前母图中的糊化伪细节。
- [ ] 输出包含有效 Alpha 通道，四角透明，无明显色键残边、文字、水印或海水大背景。
- [ ] 主体周围保留足够透明边距，便于 Godot 独立定位和缩放。
- [ ] 15 个地点不得重复为“圆形岩石底座 + 建筑”；沙滩、浅滩、人工港基、峭壁、山岭和破碎礁群必须按地点职责形成可辨轮廓。
- [ ] 生成提示词、参考图角色和最终文件路径记录在本变更记录中。

## Documentation impact

- Canonical/supporting asset document: `docs/assets/sea-overworld-generated-assets.md`
- Change record: this file
- Runtime design and coordinates remain unchanged in this phase.

## Likely files

- Create: `assets/sprites/sea_overworld/hd_locations/`
- Create: `assets/sprites/sea_overworld/hd_locations/yuehuan_merchant_harbor_hd_v1.png`
- Later create: additional independent location/island PNGs and four ocean background tiles.

## Verification evidence

- Generated the first calibration asset with the built-in image generation tool using `guangdong_sea_zone_b_v3.png` as the subject/style reference and `sea_overworld_stage1_graybox_v4.png` as the camera/layout reference.
- Final asset: `assets/sprites/sea_overworld/hd_locations/yuehuan_merchant_harbor_hd_v1.png`.
- Output inspection: `1254x1254`, RGBA, alpha range `0..255`; `1,141,619` fully transparent pixels, `420,257` fully opaque pixels, `10,640` antialiased partial-alpha pixels; all four corners are fully transparent.
- Visual inspection: the left-facing C-shaped harbor mouth and long leftward pier remain readable; roof ridges, eaves, quay edges, stairs, timber piers and rock planes are materially clearer than the baked v3 map artwork; no sea background, text, UI or watermark is present.
- Chroma-key source is retained only under `.godot/imagegen/` and is not a production asset.
- Pending: user visual acceptance, remaining locations, ocean background tiles, and eventual in-engine scale/composition verification.
- User correction on 2026-08-10: not every island may use a rock base. `chuanshan_fishing_village_hd_v1.png` and `shanwan_fishing_chain_hd_v1.png` remain as draft history and will receive non-destructive sand-beach `v2` revisions.

## Generation prompt: Yuehuan Merchant Harbor v1

```text
Use case: stylized-concept
Asset type: production-ready independent high-resolution 2D game-map location sprite for Godot
Input images: Image 1 is the current production Zone B reference; use only the large C-shaped merchant harbor near the upper center as the subject reference. Image 2 is the approved full-map layout reference; use it only to preserve the same top-down oblique camera, relative landmark scale, and functional silhouette.
Primary request: recreate Yuehuan Merchant Harbor (月环商港) as one isolated, crisp, high-definition location asset. It must clearly be the same low, wide C-shaped populated merchant-harbor island from Image 1, with the enclosed bay and harbor mouth opening to the LEFT toward the map center. Preserve the long primary pier/entrance extending left, the crescent stone quay, the dense curved band of traditional Lingnan/late-imperial Chinese tiled-roof warehouses, inns, market halls and small towers, and the rocky outer rim. Improve real structural clarity rather than merely sharpening: every roof ridge, eave, wall, quay edge, stair, timber pier and rock plane must have coherent clean geometry and readable separation when zoomed in.
Style/medium: polished hand-painted 2D game art matching the references; lightly stylized Chinese coastal RPG world-map art; crisp deliberate contours and controlled painterly texture; NOT photorealistic, NOT 3D-rendered, NOT blurry AI paint, NOT low-resolution pixelation. Keep the reference's dark gray-blue tiled roofs, warm beige stone and timber, restrained mossy green, muted brown-gold trim, and soft neutral daylight from the upper-left.
Composition/framing: one complete isolated landmark centered on a square canvas, same top-down oblique 3/4 camera and same left-facing orientation as Image 1; landscape-wide footprint; generous empty padding on all sides; do not crop any pier, rock or roof. The harbor interior and the opening must remain unobstructed and visibly connected to the left edge of the C-shape.
Scene/backdrop: perfectly flat solid #ff00ff chroma-key background everywhere outside the landmark AND inside the open harbor basin. No sea, water, waves, foam, reflections, floor plane, background scenery, gradient, texture, shadow, or lighting variation in the magenta area. Do not use #ff00ff anywhere in the subject.
Detail hierarchy: merchant harbor, not fortress. Low wide commercial silhouette; many small but coherent roofs and warehouses; continuous stone quays; several functional piers along the inner crescent; no complete defensive wall; no giant palace; no dominant keep.
Constraints: one subject only; no other islands, reefs, boats, ships, people, flags with writing, text, labels, letters, numbers, UI, route lines, compass, border, logo or watermark. No cast shadow or colored glow outside the subject. No cyan/blue water halo around the rocks. Maintain crisp opaque edges suitable for chroma-key removal and transparent PNG compositing.
```
