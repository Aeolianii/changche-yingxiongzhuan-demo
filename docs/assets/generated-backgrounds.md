# 生成背景记录

## `palace_cutaway_v2.png`

- 生成方式：Codex 内置 `image_gen`
- 用途：场景一“皇帝召见水师主帅”
- 尺寸：1536×1024
- 项目路径：`res://assets/backgrounds/palace_cutaway_v2.png`

最终提示词：

> A production-ready single-plane cutaway Chinese imperial audience hall plus exterior courtyard for a Godot narrative RPG. Upper half: roof-removed Ming-inspired audience hall with throne, red columns and broad central aisle. Lower half: gray-stone exterior courtyard. One wide central doorway connects interior and exterior without stairs or elevation change. Polished crisp pixel art compatible with native 64×64 LPC four-direction characters; vermilion, dark teal, muted gold and warm gray. Wide 1536×1024-style 3/4 top-down orthographic map, not isometric. No characters, text, UI, watermark, second floor, cliff, raised platform, closed door, roof occlusion, photorealism, painterly blur or perspective distortion. One continuous physical ground plane; walls and collision boundaries visually unambiguous.

`palace_courtyard_v1.png` 是早期纯室外参考图，不用于当前可玩场景。

## `lingnan_command_dawn_v1.png`

- 生成方式：Codex 内置 `image_gen`
- 用途：游戏启动标题界面原创主视觉
- 尺寸：1536×1024（3:2）
- 项目路径：`res://assets/ui/title_screen/lingnan_command_dawn_v1.png`
- 视觉验收：通过 Godot 4.7.1 Vulkan 实际渲染截图检查；背景无文字、水印或第三方标识，左侧菜单安全区与右侧楼船焦点均清晰。

最终提示词：

> Use case: stylized-concept
> Asset type: game title-screen background, production asset for a Godot 2D narrative RPG
> Primary request: an original cinematic opening image for a Chinese historical-fantasy naval exploration game set on the Lingnan coast; a naval commander seen from behind stands on the deck of a large Ming-inspired war junk, looking across a misty harbor toward distant mountain islands and a few small fleet silhouettes
> Scene/backdrop: dawn over the South China coast, layered ink-wash mountains, quiet dark-teal sea, drifting low mist, subtle harbor watchfires and one muted vermilion command banner
> Style/medium: crisp high-detail pixel art fused with restrained Chinese ink-wash texture, matching a serious historical narrative RPG; clearly pixel-rendered edges, not photorealistic and not soft painterly concept art
> Composition/framing: exact 3:2 landscape composition suitable for 1536x1024; ship deck, commander silhouette and command banner concentrated on the right half; left 42 percent is calm low-contrast mist, sea and aged-paper sky with generous clean negative space for a separate title and vertical menu; cinematic depth without copying any existing game
> Lighting/mood: solemn early dawn, quiet before a long expedition, dark indigo and ink black with old-paper beige, muted bronze-gold highlights and restrained vermilion accents
> Constraints: fully original design; no text, no letters, no calligraphy, no title, no UI, no buttons, no logos, no watermark, no borders; no recognizable characters or assets from existing games; no modern objects; no fantasy monsters; do not place high-contrast details in the left menu safe area; maintain clear pixel edges and readable silhouettes

## `title_calligraphy_v1.png`

- 生成方式：Codex 内置 `image_gen`，绿色色键背景经技能内置 `remove_chroma_key.py` 去除并按 Alpha 主体裁切
- 用途：标题界面独立“厂车英雄传”书法标题
- 尺寸：1724×503，透明 PNG
- 项目路径：`res://assets/ui/title_screen/title_calligraphy_v1.png`

最终提示词：

> Use case: logo-brand
> Asset type: standalone game title calligraphy artwork for a Chinese historical naval narrative RPG
> Primary request: create only the exact five Chinese characters "厂车英雄传" as one balanced horizontal title, readable from left to right
> Text (verbatim): "厂车英雄传"
> Style/medium: bold hand-brushed Chinese ink calligraphy rendered with crisp pixel-art edges; charcoal black ink body with restrained aged-bronze highlights and a few dry-brush edge flecks; solemn, heroic, historical, not modern
> Composition/framing: centered single horizontal title, large characters with even visual rhythm, generous padding around the entire title, no subtitle and no separate emblem
> Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local background removal
> Constraints: render exactly "厂车英雄传" once and only once; five characters in this exact order; no extra Chinese characters, no English, no punctuation, no seal text, no icon, no border, no watermark; background must be one uniform #00ff00 color with no shadows, gradients, texture, reflections, floor plane, or lighting variation; crisp isolated silhouette; do not use #00ff00 inside the title

## `menu_button_ink_v1.png`

- 生成方式：Codex 内置 `image_gen`，绿色色键背景经技能内置 `remove_chroma_key.py` 去除并按 Alpha 主体裁切
- 用途：标题界面四项主菜单与设置返回按钮的可复用生成式底板
- 尺寸：1786×385，透明 PNG
- 项目路径：`res://assets/ui/title_screen/menu_button_ink_v1.png`

最终提示词：

> Use case: stylized-concept
> Asset type: reusable game main-menu button background for a Chinese historical naval RPG
> Primary request: create one single horizontal menu button backing plate with no text and no icon
> Subject: a long restrained ink-brush bar, approximately 4.5:1 width-to-height; deep charcoal and dark teal ink core, irregular dry-brush feathered ends, a thin muted antique-gold vertical accent near the left edge, and a very subtle aged-paper inner highlight
> Style/medium: crisp high-detail pixel art fused with Chinese ink-wash brush texture, solemn and powerful, minimal rather than ornate
> Composition/framing: exactly one centered horizontal button plate, straight readable middle area for overlaid Chinese text, generous empty padding around the plate, fully isolated
> Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local background removal
> Constraints: no text, no letters, no Chinese characters, no symbols, no icons, no logo, no watermark, no extra button variants; the background must be one uniform #00ff00 color with no shadows, gradients, texture, reflections, floor plane, or lighting variation; crisp isolated silhouette; no cast shadow outside the plate; do not use #00ff00 inside the button

## `yuehuan_merchant_island_v2.png`

- 生成方式：Codex 内置 `image_gen`，以伏波古岭完整背景作为项目风格参考。
- 用途：月环商岛可探索商城正式背景候选。
- 尺寸：1536×1024。
- 项目路径：`res://assets/yuehuan_merchant_island/backgrounds/yuehuan_merchant_island_v2.png`。
- 选择原因：连续石板商街、六组以上铺面/货棚、货栈、船行、摊台、仓储货堆和码头卸货区形成明确商港密度；中央与码头主路保持可走。
- 被拒绝版本：`yuehuan_merchant_island_v1.png` 仅保留为生成过程记录，不用于场景；其两栋孤立建筑和大面积空地更像荒岛据点，不满足商城识别度。
- 视觉验收：Godot 4.7 Vulkan 1344×896 实际渲染已检查，截图为 `.godot/yuehuan_merchant_island_exploration.png`。

> 2026-08-12 后续验收结论：V2 虽有商港密度，但商铺、摊位与货物过杂，主路狭窄且需要大量小碰撞，已被 V3 取代，不再被正式场景引用。

## `yuehuan_merchant_island_v3.png`

- 生成方式：Codex 内置 `image_gen`，以伏波古岭完整背景作为风格与空间组织参考。
- 用途：月环商岛正式探索背景。
- 尺寸：1536×1024。
- 项目路径：`res://assets/yuehuan_merchant_island/backgrounds/yuehuan_merchant_island_v3.png`。
- 布局：仅下方一侧海岸和一个码头；陆地向上、左、右延伸；中央为宽阔连续主路/空场；左右各一栋独立货栈与船行，装饰退到建筑墙边和外围。
- 选择原因：参考伏波古岭的大块干净可走地面与自然边界，码头到两名商人的路线一眼可读；正式碰撞仅使用一个边界体、两栋建筑体和六个大边界形状，无逐摊位/逐货箱碰撞。
- 视觉验收：Godot 4.7 Vulkan 1344×896 实际渲染检查通过，截图为 `.godot/yuehuan_merchant_island_exploration.png`、`.godot/yuehuan_merchant_island_goods.png`、`.godot/yuehuan_merchant_island_shipyard.png`。

> 2026-08-12 最终用户验收结论：V3 即使加装独立大招牌，建筑仍像两间不知名路边小店，已被 V4 总埠背景取代；V3 和招牌素材不再被正式场景引用。

## `yuehuan_merchant_island_v4.png`

- 生成方式：Codex 内置 `image_gen`，直接引用伏波古岭完整背景作为项目像素密度、比例、3/4 俯视角、明亮岭南配色与宽松可走空间参考。
- 用途：月环商岛正式“商港总埠”探索背景。
- 尺寸：1536×1024。
- 项目路径：`res://assets/yuehuan_merchant_island/backgrounds/yuehuan_merchant_island_v4.png`。
- 构图：下方单侧海岸与中央宽石码头；码头轴线进入大型交易前庭；左侧为主仓、侧仓、装卸棚、院墙和木铁货堆构成的围合货栈院；右侧为宽体工坊、材料棚、船架和半成品木船构成的船行作场；上方商号公堂收束轴线。
- 选择原因：业务身份由建筑群体量、仓储和造船生产语义直接表达，不再依赖漂浮超大招牌；中央道路和两处门前空场完整，碰撞仍可用少量大型形状覆盖。
- 视觉验收：Godot 4.7 OpenGL / NVIDIA GeForce RTX 5060 在 1344×896 重新生成探索、货栈、船行三张截图；梁货郎与 V4 宽石码头碰撞已按实机画面二次校准。

## 月环商岛 Q 版商人

- 生成方式：Codex 内置 `image_gen` 洋红色键背景，使用技能内置 `remove_chroma_key.py` 去背。
- 正式资产：`res://assets/yuehuan_merchant_island/characters/liang_trader_v2.png`、`res://assets/yuehuan_merchant_island/characters/shen_shipwright_v2.png`。
- 角色约束：约 2.5～3 头身的大头短身 Q 版像素地图小人；梁货郎以账册/算盘识别，沈船师以图纸/木尺识别。
- 被拒绝版本：两张 `v1` 商人采用偏写实成人比例，仅保留生成过程记录，不得用于地图角色。
- 视觉验收：两名商人与现有 64×64 主角在商岛运行截图中并排检查，比例协调、轮廓和职业可辨。

## 月环商岛店铺招牌

- 生成方式：Codex 内置 `image_gen` 使用洋红色键背景，之后通过 `remove_chroma_key.py` 去背；中文不烘焙进图像，由 Godot `Label` 叠加。
- 正式资产：`res://assets/yuehuan_merchant_island/signs/goods_sign_v1.png`、`res://assets/yuehuan_merchant_island/signs/shipyard_sign_v1.png`。
- 设计：同系列旧木悬挂门牌与铜金包角；货栈以木材/铁锭图标识别，船行以船模/图纸图标识别，中央保留店名区域。
- 视觉验收：1344×896 初始码头镜头可同时看见“货栈”“船行”；货栈牌已避开左侧共享 HUD，两个招牌均不遮挡商人、门洞或道路，也没有碰撞节点。

> 该方案在最终用户验收中被否决：超大独立招牌不能弥补小店式建筑体量，且呈现突兀。两张素材保留为过程记录，正式 V4 场景已移除全部独立招牌节点。

## 月环商城商品图标

- 生成方式：Codex 内置 `image_gen` 生成 3×3 洋红键背景像素道具图集，包含 8 种商品与一个刻意空格；使用 `generate2dsprite.py` 清理洋红背景、按格拆分并统一缩放。
- 正式资产目录：`res://assets/ui/merchant_shop/items/icons/`。
- 正式图标：`wood.png`、`ironstone.png`、`yellow_croaker.png`、`grouper.png`、`green_crab.png`、`old_boot.png`、`longjing_tea.png`、`private_salt.png`。
- 视觉约束：统一 3/4 俯视像素风、透明背景、一致光源与尺度；两种鱼体型/配色明确区分，材料、海货、杂物可在货架和货舱小格中辨认。
- 视觉验收：Godot 4.7 OpenGL 1344×896 货栈截图确认卡片、大图和库存格均正确显示。

## 月环船行舰艇展示图

- 来源：用户指定 `C:\Users\wangk\Desktop\美术组素材\游戏像素风\游戏像素风\舰艇1.png`、`舰艇2.png`、`舰艇3.png`，不是生图资产。
- 处理：保存原图到 `res://assets/ui/merchant_shop/ships/source/`，去白底后以最大主体连通域提取单艘舰艇，避免相邻船只残片；未重绘或改变原像素风格。
- 正式资产：`res://assets/ui/merchant_shop/ships/patrol_boat.png`、`cannon_warship.png`、`escort_junk.png`。
- 视觉验收：船行货架三张卡与中央大图显示三种不同舰艇，透明边缘干净，1344×896 无裁切和溢出。
