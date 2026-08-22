# CHG-20260822-character-art-refresh: 8.22 角色素材更新

- Status: done
- Type: content
- Owner: Project owner
- Created: 2026-08-22

## Goal and player/project outcome

把 `assets/8.22素材更新/` 中已交付的角色美术接入现有皇宫、南疆水师与海上大地图流程，使对话立绘、主角/皇帝世界动画和船上主角 Q 版形象保持同一批新设定，同时不改变玩法和场景流程。

## Scope

- 替换海霸天、海盗小兵、皇帝、士兵、主角、茶商、私盐商人、传令太监与县令的对话立绘。
- 皇帝更新第一幕面朝下待机动画，行走动画和剧情移动规则不变。
- 主角更新对话立绘、四方向移动动画、待机动画，以及海上大地图船上 Q 版形象。
- 海盗船接敌对白改成水师士兵先报告、海盗小兵再叫阵，随后显示原有四档难度选项。
- 对源图做透明背景、等比缩放与动画脚底锚点标准化，保持现有对话框和世界角色的视觉尺度。

## Non-goals

- 不修改海盗战难度、遭遇生成、战斗结算、任务状态或经济数值。
- 不修改传令太监、县令、士兵或其他 NPC 的世界动画。
- 不修改皇帝行走动画、位置、碰撞和觐见流程。
- 不修改伏波古岭等任务范围外场景结构和玩法。

## Acceptance checks

- [x] 九类角色在各自现有对话入口显示新立绘；立绘透明、保持宽高比并符合原 `440×520` 对话区域的视觉大小。
- [x] 皇帝第一幕面朝下循环播放新待机帧，世界可见高度与原角色接近。
- [x] 主角在第一、第二幕按新待机/四向移动帧播放，脚底稳定且角色尺寸不跳变。
- [x] 海上大地图船上主角切换为新 Q 版四方向形象，仍固定站在甲板锚点。
- [x] 海盗接敌先出现水师士兵报告，再出现海盗小兵“抄家伙”叫阵及四档难度选项。
- [x] 相关 Godot 资源导入、对话与角色专项检查通过。

## Documentation impact

- Canonical documents to update before implementation: `docs/assets/character-assets.md`, `docs/design/art-direction.md`, `docs/design/palace-scene.md`, `docs/design/sea-overworld-design.md`
- Decisions/ADRs: 保持既有运行时资源路径和 UI 锚点；新源图只做确定性格式/尺度适配，不重绘角色。

## Implementation notes

- Likely files/modules: `assets/characters/*/picture.png`, `assets/characters/{protagonist,emperor}/standard/`, `assets/sea_overworld/portraits/`, `assets/sprites/sea_overworld/protagonist_chibi_4dir_v1.png`, `scripts/palace_demo.gd`, `scripts/scene_2.gd`, `scripts/sea_overworld.gd`, focused tests.
- Constraints and risks: 源立绘多为白底 RGB，须只清除与画布边缘连通的近白背景；动画源画布包含 256/512 两种尺寸，须统一到现有 64/128 像素运行时合同并保持脚底锚点。

## Verification evidence

- Godot 资源导入：Godot 4.7.1 .NET 完整扫描退出码 `0`。
- Headless 专项检查通过：`test_scene_portraits.gd`、`test_palace_emperor_sprite.gd`、`test_protagonist_sprite_visual.gd`、`test_protagonist_scene_two_frames.gd`、`test_sea_overworld_pirate_battle.gd`、`test_wokou_main_quest_flow.gd`、`test_sea_overworld_salt_merchant_event.gd`、`test_scene_two_dialogue_patrol.gd`。
- Vulkan 窗口检查通过：第一幕与第二幕对话框专项脚本均退出码 `0`。
- 实机截图核对：主角、士兵、皇帝和海盗小兵均为透明上半身立绘，左右侧占位与原对话框效果相符；船上主角 Q 版在甲板锚点处尺寸正常。

## Final reconciliation

- Files changed: 角色运行时 PNG 与 Godot 导入文件、皇宫/第二幕/海上大地图脚本、五个专项测试及四份规范文档。
- Documented limitations/follow-ups: 交付素材只有一套主角待机朝向，因此四个停止方向共用这套 16 帧正面待机；皇帝按需求只更新面朝下待机，既有行走与其他方向帧不变。`assets/8.22素材更新/` 保留为未提交源素材，运行时不依赖该目录。
