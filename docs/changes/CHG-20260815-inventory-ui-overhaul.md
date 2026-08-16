# 水师大仓物品栏视觉与交互重做

- Status: done
- Date: 2026-08-15

## Goal

将当前大面积留白、纯文字物品和固定“仓库说明”的全局物品栏，重做为适合古风水师项目的高识别度仓库界面，并与月环货栈的黑金水墨视觉和物品数据保持一致。

## Scope

- 采用“顶部分类页签 + 左中部 6 列物品网格 + 右侧动态详情 + 底部资源栏”的经典背包结构。
- 使用代码原生宏观面板承载水师大仓，不让位图底板画死页签、仓格、详情分段或底栏结构。
- 物品格显示现有像素图标、名称、数量角标、类型色边框和选中反馈。
- 默认选中当前分类第一件物品；点击物品格实时刷新大图、名称、类型、描述、来源与用途。
- 分类包含全部、材料、岭南特产、海上货物、造船图纸；增加排序入口。
- 关闭按钮复用黑金水墨状态并支持 `Esc`；底部显示军饷与舰队数量。
- 统一右侧详情的信息轴线和底部资源块对齐：仅保留一个真实类型标签，描述/用途/来源使用同一左边界，军饷与舰队分别位于连续底栏两端。
- 布局使用节点层级、容器和相对边界约束，不再绑定生成图片内部坐标。
- 更新自动化契约、1344×896 运行截图与相关回归测试。

### V2 revision（2026-08-15）

- 停止继续修补带有五个页签框、三段详情框、24 个固定空槽和五段底栏框的 V1 生成底图；V2 使用代码原生的宏观外框、顶部标题、暗色仓格区、单张详情纸面和连续底栏，装饰不再决定内容坐标。
- 首屏保持 6 列，但固定占位缩减为 2 行共 12 格；当前最多 11 种唯一条目可完整容纳，只有条目超过 12 项时才通过滚动区域扩展。
- 右侧只保留一个真实物品类型标签，不显示目录中不存在的“品质”或由分类推导出的“军需 / 珍货 / 永久”等伪品质。
- 详情的大图与名称居中；描述、用途、来源使用统一左边界和左对齐的短标签—正文层级，不再将多行正文强制居中。
- 页签与选中物品保持深色承载面，使用金色下划线、描边和轻微提亮表达状态；禁止使用大块浅米色填充充当选中态。
- 底部改为一条连续状态栏，仅在左侧显示军饷、右侧显示舰队数量，不保留三个空资源框。
- 排序入口与“库藏”标题合并为同一工具栏，不再悬浮在网格上方。

## Non-goals

- 不修改物品产出、售价、图纸解锁、造船、仓库容量或存档结构。
- 全局物品栏保持只读，不在没有使用规则的物品上虚构“使用”操作，也不绕过商港交易规则加入直接出售。
- 本轮不实现拖拽、拆分堆叠、装备穿戴或移动端触控方案。
- 不重做货栈商城、任务栏、人物栏和其他全局菜单。

## Acceptance checks

- 1344×896 下界面不存在固定“仓库说明”与大面积无效留白。
- 顶部五个分类可点击，选中态明确；网格为 6 列，物品图标、名称和数量均可读。
- 打开界面默认选中第一项，右侧详情随点击和分类实时变化。
- 右侧至少展示大图、名称、类型、用途、来源；图纸展示已解锁与造船用途。
- 排序控件可切换“类型优先 / 数量优先 / 名称排序”，并重排当前分类。
- 关闭按钮使用项目黑金素材，`Esc` 可关闭；底部军饷与舰队数据准确。
- 右侧只有一个真实类型标签，描述、用途、来源使用同一左边界并左对齐；底部军饷和舰队在连续状态栏两端完整显示。
- 自动化验证结构、槽位数量、对齐方式与相对边界，不绑定生成图片内部坐标；铁石物品卡名称与卡片中心点一致。
- `test_inventory_screen.gd` 先因旧结构缺失而失败，实施后通过；商港、全局探索 UI 与静态检查不回归。
- V2 首屏恰有 12 个仓格占位，6 列 × 2 行；当前默认库存不再产生 22 个空框。
- V2 不存在 `DetailQuality` 或由分类推导的伪品质文字；木材详情只显示真实类型“造船材料”。
- 描述、用途、来源共享左侧内容边界并左对齐；长来源可正常换行，不得出现单独一行的“购买”。
- 页签与物品选中态保持深色底，使用金色线条/描边反馈；连续底栏中军饷完整位于左侧、舰队完整位于右侧。
- 视觉布局不再依赖 `x=1121`、第五个底框等生成图片内部坐标，自动化改为验证节点层级、数量、对齐方式和边界关系。
- “海上货物”页同时收纳 `cargo` 与 `misc`，确保旧靴子等海上杂物不会只出现在“全部”。
- 图纸详情的真实类型固定为“造船图纸”；永久解锁是规则说明，不作为类型或品质文案。
- 滚动视口必须为纵向滚动条预留宽度，出现第三行后第六列仍完整可见。

## Documentation impact

- `docs/design/economy-merchant-harbor.md`：更新全局物品栏的正式布局与只读边界。
- `docs/qa/playtest.md`：增加物品栏视觉、筛选、排序、详情与键盘验收。

## Likely files

- `docs/changes/CHG-20260815-inventory-ui-overhaul.md`
- `docs/design/economy-merchant-harbor.md`
- `docs/qa/playtest.md`
- `assets/ui/inventory/`
- `scripts/ui/inventory_screen.gd`
- `tests/test_inventory_screen.gd`

## Verification evidence

### V1 historical evidence（已由 V2 废弃，不代表当前行为）

- Research：网络参考确认了成熟 RPG 背包普遍采用“分类 + 网格 + 固定详情”的可识别结构；网格适合大量简单堆叠物，类型/品质色边框可降低逐项阅读成本。本项目只借鉴信息架构，不复刻具体游戏资产。
- Image generation：使用内置 `imagegen` 生成两版无文字水师大仓底板。首版因模型画死 7 列格线而淘汰；第二版移除所有内置格线、压缩顶部景片，保留空白深墨绿承载面、五个页签框、右侧旧纸详情区与底部资源框，最终保存为 `assets/ui/inventory/inventory_backdrop_v1.png`。
- RED：扩展 `test_inventory_screen.gd` 后旧界面退出码 1，共报告 17 项缺口，包括无专用底板、无五类页签、非 6 列、无图标/数量角标、固定仓库说明、无动态详情/排序/黑金关闭与 Esc。
- GREEN：重构后 `test_inventory_screen.gd` 退出码 0，输出 `Inventory screen verification passed.`；默认选中木材、三项排序下拉、图标与数量、详情字段、黑金关闭和 Esc 均通过契约。
- Visual：Godot 4.7 Mono/OpenGL 在 1344×896 生成 `.godot/inventory_screen_preview.png`。首轮发现右侧文字偏浅且用途压线，随后加深墨色并将描述/用途/来源分别落入三个纸面分区；第二轮确认 6 列仓格、24 个可见槽位、图标数量、选中态、详情大图、页签、排序和底部资源完整无裁切。
- Regression：`test_exploration_hud.gd`、`test_global_exploration_ui.gd`、`test_yuehuan_merchant_island.gd`、`test_yuehuan_harbor.gd` 均退出码 0。
- Static/C#：`tests/verify_merged_project.ps1` 退出码 0；`dotnet build ChangcheHeroes.csproj --nologo --no-restore` 成功，0 警告、0 错误；`git diff --check` 退出码 0。
- 文字对齐 RED/GREEN：增加类型/品质等宽同高、三段详情统一边界与居中、底部资源标签禁止横向扩展的契约后，旧布局按预期报告 4 项失败；统一标签尺寸、文本矩形、水平/垂直对齐和资源组尺寸后 `test_inventory_screen.gd` 退出码 0。
- 文字对齐 Visual：重新渲染 1344×896 `.godot/inventory_screen_preview.png`；右侧描述、用途、来源分别在三个纸面区居中且不压装饰线，类型/品质同基线；军饷和舰队的图标、名称、数值组合在各自底框内整体居中。
- 精确坐标 RED/GREEN：新增详情全层必须共用 `x=1121`、铁石卡名必须位于卡片中心、舰队块必须完整处于 `x=970–1190` 的断言后，旧实现报告详情 4 项与舰队 1 项失败；修正后 `test_inventory_screen.gd` 退出码 0。
- 精确坐标 Visual：默认木材截图确认舰队组合完整进入第五个框；专门点击铁石生成 `.godot/inventory_screen_ironstone.png`，确认铁石大图、名称、标签组与三段正文均围绕纸框中心 `x=1121`，铁石物品格名称也位于槽位中心。

### V2 verification（2026-08-15）

- RED：V2 契约首次运行退出码 1，准确报告旧生成底图、24 个固定槽位、伪品质、居中正文、五格底栏和浅色选中态等 10 项旧结构问题。
- GREEN：重建后 `test_inventory_screen.gd` 退出码 0；首屏固定 12 格、单真实类型、左对齐正文、连续底栏、深色选中卡与深色页签均通过。
- Visual：Godot Vulkan 在 1344×896 重新生成 `.godot/inventory_screen_preview.png`。截图确认 V1 复杂底图、顶部景片、详情小框和五段资源格全部退出运行时；右侧来源在扩大正文宽度并将字号调整为 15 后不再把“购买”拆成孤立行。
- 页签状态复核：稳定选中态改为当前分类显式样式，不再依赖持续按下按钮；运行截图像素采样确认选中页签内部为深墨绿 `#1B2B27`，金色只用于边缘和下划线。
- Regression：`test_inventory_screen.gd`、`test_exploration_hud.gd`、`test_global_exploration_ui.gd`、`test_yuehuan_merchant_island.gd`、`test_yuehuan_harbor.gd` 均退出码 0。
- Static/C#：`powershell -ExecutionPolicy Bypass -File tests/verify_merged_project.ps1` 输出 `Merged project static verification passed.`；`dotnet build ChangcheHeroes.csproj --nologo --no-restore` 为 0 警告、0 错误；目标文件 `git diff --check` 通过，仅有仓库既有的 LF/CRLF 提示。
- Editor：Godot AI 会话当前场景为月环商港且 readiness 为 `ready`；编辑器日志没有 `inventory_screen.gd` 新增警告或错误，列出的 5 条均来自既有 `sea_map_screen.gd`、`exploration_ui.gd` 和 `merchant_shop_overlay.gd`。
- Independent review：首轮审查发现 `misc` 无分类入口、图纸类型误写为“永久图纸”、滚动条可能裁切第六列以及 V1 文档未充分标记废弃；四项均经文档修订和 RED/GREEN 测试修复。同一审查代理复核后报告无剩余 Critical 或 Important 问题。
- Review fixes：`cargo` 页包含 `misc`；图纸类型为“造船图纸”；`ItemScroll` 宽 824 像素，相对 806 像素六列内容为滚动条保留 18 像素；V1 证据明确标记为历史且由 V2 废弃。
- Final fresh verification：五个 Godot 测试再次全部退出码 0；合并项目静态检查通过；C# 构建 0 警告、0 错误；Vulkan 截图保存成功。

## Files changed

- `assets/ui/inventory/inventory_backdrop_v1.png`
- `assets/ui/inventory/inventory_backdrop_v1.png.import`
- `scripts/ui/inventory_screen.gd`
- `tests/test_inventory_screen.gd`
- `docs/design/economy-merchant-harbor.md`
- `docs/qa/playtest.md`
- `docs/changes/CHG-20260815-inventory-ui-overhaul.md`
- `docs/superpowers/plans/2026-08-15-inventory-ui-v2.md`

## Final behavior

水师大仓 V2 不再加载带有内置页签、详情分段、24 个槽位和五格底栏的生成底图，而由代码原生宏观面板承载。顶部五类页签支持鼠标和数字键 `1–5`，稳定选中态为深墨绿底配金色下边缘；左侧首屏固定 6 列 × 2 行共 12 格，条目超过 12 项时由滚动区域扩展。真实物品显示像素图标、名称、数量与类型色描边，选中卡保持深色并使用金色边框。右侧只显示大图、名称、一个真实类型、描述、用途和来源，正文统一左对齐，不再显示伪品质。排序与库藏标题共处工具栏；底部为一条连续状态栏，军饷靠左、舰队靠右。全局仓库仍为只读，出售留在月环货栈。
