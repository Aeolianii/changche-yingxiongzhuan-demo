# CHG-20260815-inventory-ui-art-kit: 水师大仓素材化美术升级

- Status: rolled-back
- Date: 2026-08-15

## Goal

把结构正确但仍像代码原型的水师大仓 V2，升级为由像素国风背景、标题牌和专用 UI 组件共同构成的正式游戏界面，消除“一个个普通小方框”的廉价感，同时保留已经验证的 6×2 网格、真实类型、左对齐详情和连续底栏。

## Player-visible outcome

- 打开物品栏时先看到一张具有岭南水师仓廒、木构、船具与海贸气息的暗色像素背景，而不是纯色面板。
- “水师大仓”使用独立牌匾、书法化字形、金色描边和墨影，不再是普通系统字体直接摆放。
- 分类页签、物品槽、选中槽、详情纸面、连续底栏和边角纹样使用同一套生成的像素国风组件。
- 所有正文仍由 Godot 准确渲染；生成图片不画死物品名称、数量、类别、详情或资源数值。

## Scope

- 使用内置图像生成模型制作无文字背景、透明组件图集和标题牌。
- 对组件图集进行色键去底、裁切、缩放和透明边缘检查，输出项目内独立 PNG。
- Godot 使用 `TextureRect` / `NinePatchRect` / `StyleBoxTexture` 组合组件；内容节点与交互逻辑保持动态。
- 生成正常、悬停/选中所需的页签与物品槽视觉状态；选中态仍为深色主体配暖金强调，不使用整块浅米色。
- 标题图片必须逐字核对“水师大仓”；若任何字形错误，图片只承担牌匾装饰，准确文字由 Godot 叠加。

## Non-goals

- 不修改物品数据、经济规则、分类映射、排序、仓库容量、图纸、造船或存档。
- 不重做月环商港交易界面、场景地图、任务栏或其他全局 UI。
- 不把页签文字、物品图标、物品数量、正文或资源数字烘焙进背景。
- 不复制或提交系统商业字体。

## Acceptance checks

- 1344×896 截图中背景、标题、页签、仓格、详情纸面和底栏至少使用五类项目内位图素材，不再由纯色 `StyleBoxFlat` 主导画面。
- 背景没有烘焙文字、物品、12 个槽位、详情分段或资源数字；替换数据后布局仍成立。
- “水师大仓”四字准确、清晰、有独立牌匾和书法化表现；不得出现错字或额外文字。
- 12 个仓格保持完整可读，空槽低对比，选中槽具有独立纹理/金色状态，不能退回普通矩形填色。
- 五个页签文字准确，当前分类一眼可辨；详情正文、资源数值和关闭按钮仍清晰可读。
- 物品栏现有自动化契约、五项相关 Godot 回归、静态检查和 C# 构建继续通过。
- 精确运行月环商港场景，截图无控件拉伸破损、透明色边、文字压线或内容溢出；最终保持场景运行供用户验收。

## Documentation impact

- `docs/design/economy-merchant-harbor.md`：补充水师大仓的分层素材架构和文字准确性边界。
- `docs/qa/playtest.md`：补充素材化视觉、透明边缘、九宫格拉伸和标题验收。

## Likely files

- `assets/ui/inventory/v3/`
- `scripts/ui/inventory_screen.gd`
- `tests/test_inventory_screen.gd`
- `tests/capture_inventory_screen.gd`
- `docs/design/economy-merchant-harbor.md`
- `docs/qa/playtest.md`
- `docs/changes/CHG-20260815-inventory-ui-art-kit.md`
- `docs/superpowers/plans/2026-08-15-inventory-ui-art-kit.md`

## Verification evidence

- 生成并人工检查 1344×896 水师仓廒环境图；图中不含烘焙文字、物品、页签或动态数值。
- 生成纯洋红色键背景组件图集，经色键去底、独立裁切与 alpha 检查后输出标题牌、页签、物品槽、详情纸框、连续底栏和边角纹样；所有透明组件 alpha 范围均为 `0–255`。
- “水师大仓”题字逐字核对正确，黑底已去除；运行截图确认其与标题牌组合后清晰、无额外文字。
- RED：V2 在新增素材化契约下报告 9 项预期失败，覆盖环境、题字、详情、底栏、页签和物品槽。
- GREEN：`test_inventory_screen.gd` 输出 `Inventory screen verification passed.`。
- 回归：`test_exploration_hud.gd`、`test_global_exploration_ui.gd`、`test_yuehuan_merchant_island.gd`、`test_yuehuan_harbor.gd` 全部退出码 0。
- 静态验证：`tests/verify_merged_project.ps1` 输出 `Merged project static verification passed.`。
- C#：`dotnet build ChangcheHeroes.csproj --no-restore` 成功，0 警告、0 错误。
- 视觉：`tests/capture_inventory_screen.gd` 使用 Vulkan 运行截图成功；二次迭代修正了页签混入图集碎片、槽框装饰过大、详情正文越过纸框与舰队数压住浪纹的问题。
- 生成提示方向：像素国风、明代岭南水师仓廒、深墨绿木构、暖金铜饰、窗外港湾帆影；组件要求无文字、彼此分离、纯洋红键背景，包含标题牌、页签、物品槽、详情卷轴、连续底栏与海浪边角。

## Files changed

- `assets/ui/inventory/v3/*.png`
- `scripts/ui/inventory_screen.gd`
- `tests/test_inventory_screen.gd`
- `tests/capture_inventory_screen.gd`
- `docs/design/economy-merchant-harbor.md`
- `docs/qa/playtest.md`
- `docs/changes/CHG-20260815-inventory-ui-art-kit.md`
- `docs/superpowers/plans/2026-08-15-inventory-ui-art-kit.md`

## Final behavior

水师大仓现由可辨识的水师仓廒环境、独立金色题字、海浪船舵标题牌、木雕页签与槽位、旧纸详情框和连续港务底栏共同构成。动态名称、数量、类别、说明、来源、军饷和舰队数据仍由 Godot 渲染，原有分类、排序、选择、关闭和移动锁逻辑不变。
