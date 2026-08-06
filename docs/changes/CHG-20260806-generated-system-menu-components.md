# CHG-20260806 生图系统菜单组件

- Status: done
- Date: 2026-08-06

## Goal

使用图像生成能力制作一套与用户示例图气质一致、可直接用于 Godot 的东方武侠系统菜单组件，替换当前主要由简单卡片组合构成的菜单外观。

## Scope

- 以示例图作为布局与材质语言参考，生成无文字的系统菜单框、标题牌区域、横向菜单按钮底板和关闭按钮装饰。
- 组件采用透明 PNG，保留黛青黑、旧铜金、灰白纸石材质、细密中式暗纹与不规则手绘边缘。
- 在 Godot 中使用生成素材承载现有“系统”标题、六个菜单条目和关闭交互，所有中文继续由引擎文字绘制，保证准确性。
- 保留既有背景模糊、菜单暂停、未开放提示和退出游戏行为。
- 1344×896 基准画面下实际渲染并调整拉伸、边距和文字对比度。

## Non-goals

- 不生成或替换游戏背景、人物、角落探索 HUD 与剧情素材。
- 不把示例图中的原始 UI 图像直接复制进项目。
- 不在生成图片中烘焙中文按钮文字，避免生成文字错误。
- 不改变菜单条目、功能范围或交互逻辑。

## Acceptance checks

- 中央菜单框和按钮具有明确的生成式美术纹理，不再呈现为单纯的平面卡片组合。
- 生成素材在项目内保存为透明 PNG，四角透明且无明显色键残边。
- 标题、六个菜单名称和关闭符号仍清晰准确。
- 背景模糊、关闭恢复、五项即将实现提示和退出游戏继续有效。
- 1344×896 下无素材变形、文字裁切或按钮点击区域错位。

## Documentation impact

- `docs/design/art-direction.md`：记录生成式系统菜单组件规范。
- `docs/assets/generated-backgrounds.md`：不适用；本次为 UI 组件，不是背景。
- `docs/qa/playtest.md`：增加生成式菜单组件渲染验收。

## Likely files

- `assets/ui/system_menu/system_menu_frame.png`
- `assets/ui/system_menu/menu_button.png`
- `assets/ui/system_menu/close_button.png`
- `scripts/exploration_hud.gd`
- `tests/test_exploration_hud.gd`
- `tests/verify_merged_project.ps1`

## Verification evidence

- 使用内置 `imagegen`，以用户示例图作为风格与比例参考，分别生成无文字的纵向菜单框、横向按钮底板和关闭按钮；未复制示例图背景、人物或原始组件。
- 三张源图均采用纯绿色色键背景，并通过 `remove_chroma_key.py --auto-key border --soft-matte --despill` 输出透明 PNG。透明像素统计：菜单框 548514/1572951，按钮 1031906/1573116，关闭按钮 964631/1572516；软边像素占比低且无明显绿色残边。
- `tests/test_exploration_hud.gd` 通过：三张纹理均可作为 Godot 资源加载，四角 Alpha 小于 0.05、中心 Alpha 大于 0.95，菜单节点使用正确纹理，原交互契约保持不变。
- 1344×896 OpenGL 兼容模式实际渲染确认：生成菜单框完整覆盖中央面板，顶部标题牌、六个按钮和关闭装饰无裁切；引擎中文清晰，按钮点击区域与画面一致。
- `tests/test_system_menu_exit.gd`、`test_scene_portraits.gd`、`test_scene_two_dialogue_background.gd` 和 `test_scene_transition.gd` 回归通过。
- `tests/verify_merged_project.ps1` 与 `git diff --check` 通过。

## Final prompt set

- 菜单框：以示例图为材质语言参考，生成一个无文字、正视、9:13 纵向框体；暗玉黑织纹中心、旧铜金外框、墨色内框、中式回纹暗纹、装饰角与顶部空标题牌，纯绿色色键背景。
- 按钮底板：生成一个无文字、正视、约 5.2:1 横向底板；灰白旧纸/石材内芯、墨色描边、旧铜包边、左侧空菱形徽章座与中央文字净区，纯绿色色键背景。
- 关闭按钮：生成一个无符号、正视、圆形八边徽章底座；暗玉黑中心、旧铜金和墨色多层边框、四向结饰，纯绿色色键背景。
