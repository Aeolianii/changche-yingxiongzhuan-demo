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
