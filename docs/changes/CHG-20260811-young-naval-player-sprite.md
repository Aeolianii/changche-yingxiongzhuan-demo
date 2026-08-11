# CHG-20260811-young-naval-player-sprite: 年轻水师主角像素素材

- Status: done
- Date: 2026-08-11

## Goal

生成一套与项目现有 64×64 LPC 世界角色比例直接兼容的年轻中国水师将领主角候选素材。

## Player-visible outcome

主角在俯视场景中具有清晰的中国水师将领身份，并具备上下左右四方向待机与行走动画。

## Scope

- 生成待机与行走两组四方向动画，每个方向 4 帧。
- 交付帧为 64×64 RGBA PNG，人物可见高度约 48–50 像素，脚底统一落在 y=61–63。
- 角色为年轻、无须、黑色束发，穿蓝灰轻甲、朱红短披肩，腰佩中式雁翎刀。
- 先生成独立候选素材；用户确认后，将 32 帧直接替换到现有 `assets/characters/protagonist/standard/{idle,walk}`。
- 替换后每个动作方向只保留 4 帧，避免第二幕最多读取 9 帧时混入旧 LPC 行走帧。

## Non-goals

- 除把第二幕主角待机/行走读取数量统一为 4/4 外，不修改 Godot 场景、角色逻辑、碰撞、运行时缩放或对话立绘。
- 不生成攻击、受伤、施法或立绘。
- 不声称复原特定历史人物或朝代服制。

## Acceptance checks

- [x] 共 32 张 64×64 RGBA 帧，目录和方向顺序明确。
- [x] 每帧背景透明，无洋红残边，无画布边缘截断。
- [x] 人物高度和脚底锚点与现有主角比例一致。
- [x] 待机与行走角色身份、服装、配色一致，左右方向正确。
- [x] GIF 和透明合成预览可用于快速确认动画。
- [x] 正式 `protagonist` 的待机和行走四方向均只包含新角色 4 帧。
- [x] 第一幕和第二幕现有资源加载逻辑能读取新角色且不混入旧帧。
- [x] 第二幕完整播放每方向 4 帧待机和 4 帧行走。

## Documentation impact

- 更新 `docs/assets/character-assets.md` 记录候选素材合同。
- 设计细节见 `docs/superpowers/specs/2026-08-11-young-naval-player-sprite-design.md`。

## Likely files

- `assets/characters/protagonist_candidate/`
- `assets/characters/protagonist/standard/{idle,walk}/`
- `tests/test_protagonist_sprite_replacement.ps1`
- `tests/test_protagonist_sprite_visual.gd`
- `tests/test_protagonist_scene_two_frames.gd`
- `scripts/scene_2.gd`
- `docs/assets/character-assets.md`
- `docs/superpowers/specs/2026-08-11-young-naval-player-sprite-design.md`
- 本变更记录

## Verification evidence

- Automated image inspection: 32/32 frames are 64×64 RGBA; visible height range 46–50 px, mean 48.81 px; every frame ends at foot y=63; zero clipped frames, zero nontransparent corner frames, and zero visible chroma-magenta pixels at alpha ≥ 16.
- Processor strict QC: both action sheets contain 16 valid non-empty frames with no output-edge contact or paste clamping. The visually reviewed raw-sheet boundary color variation was allowed only at source cleanup; it does not appear in final frames.
- Manual visual inspection: down/left/right/up rows are readable and consistent; the same young, clean-shaven, topknotted commander wears blue-gray armor and a vermilion short cape in both idle and walk sheets.
- Files generated: `assets/characters/protagonist_candidate/standard/`, transparent sheets, previews, raw sheets, processor metadata, scale profile, and `alignment-qc.json` under `generation/`.
- Replacement test followed red/green: before copying, it failed because active `idle/down` contained only old `1.png, 2.png`; after replacement it passed with exactly 32 approved frames and matching SHA-256 hashes.
- Second-scene frame-count test followed red/green: it first failed on the old 2-frame idle limit, then passed after `scene_2.gd` was changed to load 4 idle and 4 walk frames per direction.
- Godot 4.7.1 focused tests passed: `test_protagonist_sprite_visual.gd`, `test_protagonist_scene_two_frames.gd`, `test_click_to_move.gd`, and `test_scene_two_dialogue_patrol.gd`.
- Vulkan runtime preview saved to `.godot/protagonist_sprite_preview.png`; the new protagonist is visible at native 1.0 scale in the palace, aligned to the existing foot anchor with sharp nearest-neighbor pixels.
- Integration files changed: replaced `assets/characters/protagonist/standard/{idle,walk}` with the 32 approved frames, removed obsolete walk frames 5–9 and their import metadata, regenerated import metadata for active frames, updated the two Scene 2 frame limits, and added focused tests.
