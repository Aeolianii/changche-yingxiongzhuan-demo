# 月环商城复用既有黑金 UI 素材

- Status: done
- Date: 2026-08-15

## Goal

按用户提供的项目内既有按钮参考，美化月环商城交易界面，使商城按钮与海图进入提示、人物交互提示保持同一套黑金水墨语言。

## Player-visible outcome

商城的主交易按钮、页签、数量快捷按钮和关闭入口不再表现为通用纯色方框；按钮使用项目现有黑金水墨框的正常态与按下态，文字保持旧纸白/暖金层级，并保留清晰的悬浮、按下和禁用反馈。

## Scope

- 复用 `assets/ui/sea_overworld/interaction_button_ink_v1.png`。
- 复用 `assets/ui/sea_overworld/interaction_button_ink_active_v1.png`。
- 为商城主操作、次操作、页签、数量快捷操作和关闭按钮建立统一的纹理按钮样式。
- 保留当前 4:6 布局、商品行、交易逻辑、快捷数量逻辑和底部资源栏。
- 增加自动化样式契约并进行 1344×896 运行时视觉验证。
- 将默认 `SpinBox` 窄箭头替换为输入框两侧的大号减号/加号按钮，数字居中，并支持点击输入框后直接键盘录入数量。
- 将月环商港自由探索时的底部交互提示从无样式半透明面板改为与伏波岛完全相同的黑金水墨纹理提示框。

## Non-goals

- 不生成新的 UI 图片。
- 不修改商品、价格、库存、图纸或造船规则。
- 不重排商城信息架构，也不修改商岛地图和碰撞。
- 不重做全局物品栏或其他菜单。

## Acceptance checks

- 商城按钮样式实际引用项目既有黑金水墨按钮纹理，而非仅模仿其颜色。
- 正常、悬浮/聚焦、按下和禁用态可辨；禁用态仍使用既有素材但降低亮度和透明度。
- 主交易按钮视觉权重最高，页签与数量快捷按钮保持紧凑，不重新堆出大量方框。
- `test_yuehuan_merchant_island.gd` 在修改前因缺少纹理样式而失败，修改后通过。
- 月环商港返航与合并项目静态验证不回归。
- 1344×896 运行画面中按钮文字居中、无裁切、无明显拉伸破损。
- 数量区显示为大号 `−`、居中数字输入框和大号 `+`；两侧按钮点击热区不小于 52×48，键盘输入并确认后立即更新数量与交易预览。
- 数字输入框宽度控制在 96 像素以内，数字字号不小于 22，避免单个数字周围出现明显无效留白。
- `PromptPanel` 使用 `TextureButton`，正常态与按下态分别直接引用 `interaction_button_ink_v1.png` 和 `interaction_button_ink_active_v1.png`；文字使用系统提示的暖金色与阴影，不再出现简单黑色矩形反馈。

## Documentation impact

- `docs/design/economy-merchant-harbor.md`：补充既有素材复用原则。
- `docs/qa/playtest.md`：补充纹理来源和状态验收。

## Likely files

- `docs/changes/CHG-20260815-merchant-ui-existing-assets.md`
- `docs/design/economy-merchant-harbor.md`
- `docs/qa/playtest.md`
- `tests/test_yuehuan_merchant_island.gd`
- `scripts/yuehuan_merchant/merchant_shop_overlay.gd`

## Verification evidence

- RED：首次运行 `tests/test_yuehuan_merchant_island.gd` 时，关闭、页签、`+10` 与主购买按钮共 8 条纹理来源断言按预期失败，证明旧实现仍使用纯色 `StyleBoxFlat`。
- GREEN：商城统一应用既有黑金水墨正常态/按下态后，同一测试退出码 0，输出 `Yuehuan merchant island verification passed.`。
- Visual：使用 Godot 4.7 Mono/OpenGL 在 1344×896 离线渲染货栈商城并检查 `.godot/merchant_shop_existing_assets.png`。首轮九宫格切分造成边角碎片，随后改为与项目现有 `TextureButton` 一致的整张纹理缩放；最终页签、关闭、四个数量快捷键和主交易按钮边框完整，文字居中无裁切，数量输入改为旧纸色并与详情纸面融合。
- Regression：`tests/test_yuehuan_harbor.gd` 退出码 0，输出 `Yuehuan harbor verification passed.`。
- Static：`tests/verify_merged_project.ps1` 退出码 0，输出 `Merged project static verification passed.`。
- C#：`dotnet build ChangcheHeroes.csproj --nologo --no-restore` 成功，0 警告、0 错误。
- 数量输入 RED：扩展 `tests/test_yuehuan_merchant_island.gd` 后首次运行退出码 1，明确报告缺少独立增减按钮、数字未居中、未启用聚焦全选/即时文本更新，输入 `25` 后数量未同步。
- 数量输入 GREEN：加入 56×52 黑金 `−` / `+` 按钮、居中可编辑输入框和 `update_on_text_changed` 后，同一测试退出码 0；模拟键盘输入 `25` 后 `SpinBox.value == 25`。
- 数量输入 Visual：Godot 4.7 Mono/OpenGL 以 1344×896 离线渲染 `.godot/yuehuan_merchant_island_goods.png`；默认窄箭头已隐藏，大号 `−` / `+` 与数字框完整对齐，快捷按钮和主购买按钮无挤压、裁切或纹理破损。
- 数量输入 Regression：再次运行 `tests/test_yuehuan_merchant_island.gd`、`tests/test_yuehuan_harbor.gd`、`tests/verify_merged_project.ps1` 均退出码 0；`dotnet build ChangcheHeroes.csproj --nologo --no-restore` 为 0 警告、0 错误；`git diff --check` 退出码 0。
- 数字密度修订 RED/GREEN：新增“输入框宽度不超过 96、字号不小于 22”契约后，旧版 112 宽/17 号字按预期失败；改为 88 宽/22 号字后 `test_yuehuan_merchant_island.gd` 退出码 0。
- 数字密度 Visual：重新以 1344×896 渲染 `.godot/yuehuan_merchant_island_goods.png`，单个数字周围留白明显减少，数字与左右黑金按钮视觉重量均衡，多位数输入空间仍充足。
- 商港提示 RED/GREEN：新增 `PromptPanel` 必须为系统 `TextureButton` 且引用正常/激活纹理的契约后，旧 `PanelContainer` 按预期失败；迁移为与伏波岛相同结构后 `test_yuehuan_merchant_island.gd` 退出码 0。
- 商港提示 Visual：1344×896 离线渲染 `.godot/yuehuan_merchant_island_exploration.png`，码头返航提示显示为完整黑金水墨框，暖金文字居中且带阴影，无旧版半透明黑色长方框。
- 商港提示 Regression：`test_yuehuan_harbor.gd` 与 `verify_merged_project.ps1` 退出码 0；C# 构建 0 警告、0 错误。

## Files changed

- `docs/changes/CHG-20260815-merchant-ui-existing-assets.md`
- `docs/design/economy-merchant-harbor.md`
- `docs/qa/playtest.md`
- `scripts/yuehuan_merchant/merchant_shop_overlay.gd`
- `tests/test_yuehuan_merchant_island.gd`

## Final behavior

货栈与船行共用的商城覆盖层现在真实复用海图/人物交互所用黑金水墨按钮素材。正常态使用深绿黑金框，悬浮、聚焦和按下态使用亮色素材，禁用态降低亮度和透明度；关闭、页签、数量快捷操作、购买、出售、全部出售、图纸购买和造船均沿用同一规则。数量区使用独立的大号 `−` / `+`，数字在 88 像素宽的旧纸框中以 22 号字居中；玩家点击数字即可键盘输入，新值即时刷新合计与交易后预览。自由探索时靠近商人或返航点出现的底部提示也已改为伏波岛同款黑金水墨 `TextureButton`，不再使用简单黑色面板。商品行与当前 4:6 信息布局保持不变。
