# QA and playtest

## Build smoke checks

- [x] Project opens without blocking import errors.
- [x] Main playable path starts.
- [x] Player cannot become permanently stuck on the expected path.
- [x] Completion or exit state is reachable.

## Current acceptance scenarios

| Scenario | Setup | Action | Expected | Result/build |
|---|---|---|---|---|
| 主角移动 | 进入皇宫 | 连续按方向输入 | 动画方向一致，相机平滑跟随 | passed / run 4 |
| 场景边界 | 左墙与殿外宫墙前 | 持续向阻挡物移动 | 左墙停在 x≈67；宫墙停在 y≈625 | passed / run 4 |
| 中央门洞 | 御道 x=768, y=700 | 持续向上移动 | 穿过门洞进入 y≈422 的殿内 | passed / run 4 |
| 装饰穿行 | 草木、旗帜和灯笼附近 | 检查场景物理节点 | 装饰无碰撞节点 | passed / run 4 |
| 开场旁白 | 新开游戏 | 点击继续 | 依次显示三份岭南急报 | passed / run 4 |
| 太监传召 | 关闭开场旁白 | 等待太监移动 | 太监从殿内经门洞抵达主帅附近 | passed / run 4 |
| 对话入殿 | 太监接近主帅 | 点击“对话” | 对话后太监与主帅自动进入正殿 | passed / run 4 |
| 觐见 | 主帅接近皇帝 | 点击“觐见” | 完整显示用户提供的两段正式对白 | passed / run 4 |
| 圣旨收尾 | 觐见对白结束 | 点击继续 | 显示圣旨旁白并完成场景 | passed / run 4 |
| 稳定性 | 新开游戏 | 走完整流程 | 当前运行日志无解析或运行时错误 | passed / run 4 |
| 合并项目入口 | 打开合并项目 | 按 F5 | 从皇宫场景开始，不直接进入场景二 | passed / combined run 1 |
| 自动串联 | 完成圣旨并进入场景一完成态 | 等待 2.5 秒 | 画面淡出并自动进入场景二 | passed / runtime transition test |
| 跳过等待 | 场景一完成态 | 点击“立即启程” | 立即淡出并进入场景二，不重复切换 | passed / runtime transition test |
| 场景二启动 | 从场景一完成跳转 | 等待场景二加载 | 南疆水师场景和 C# 脚本成功实例化 | passed / runtime transition test |
| 切换失败恢复 | 场景二加载返回错误 | 触发跳转 | 场景一恢复输入与按钮、显示错误提示并允许重试 | passed / static guard test |
| 内侍立绘 | 进入太监传召对白 | 查看对话框右侧 | 显示士兵 `picture.png`，名牌为“内侍” | passed / portrait runtime + render capture |
| 皇帝占位立绘 | 进入皇帝对白 | 查看对话框右侧 | 显示暗红金边“帝”字占位卡，名牌为“皇帝” | passed / portrait runtime + render capture |
| 主帅立绘 | 推进至主帅回复 | 查看对话框左侧 | 显示将军 `picture.png`，名牌为“水师主帅” | passed / portrait runtime + render capture |
| 无角色文本 | 查看旁白、圣旨和错误提示 | 推进或触发文本 | 立绘及名牌隐藏，不残留上一位说话者 | passed / portrait runtime test |
| Scene2 对话底板 | 与县令或士兵开始对话 | 查看底部对话区域 | `BackgroundBar.png` 覆盖完整底部；黑框外透出游戏背景、框内纸张不透明，且其他 UI 布局不变 | passed / alpha render 1 |
| 探索 HUD 信息 | 进入任一场景自由移动阶段 | 查看屏幕角落 | 左上显示主帅头像；左侧同时显示主线与支线；右上显示四个具名功能按钮 | passed / exploration HUD runtime + render 1 |
| 探索 HUD 显隐 | 依次进入自由移动、对白、自动过场、操练或淡出 | 观察 HUD | 仅自由移动时显示，所有对白与过场阶段隐藏，结束后按状态恢复 | passed / exploration HUD runtime 1 |
| 未开放功能提示 | 自由移动阶段 | 分别点击物品栏、船只、人物 | 每个按钮都出现“功能即将开放”提示，提示自动消失且不阻断移动 | passed / exploration HUD runtime 1 |
| 系统菜单布局 | 自由移动阶段 | 点击右上“菜单” | 世界画面和角落 HUD 模糊压暗，中央显示除“新手教程”外的六个指定条目及关闭按钮 | passed / system menu runtime + render 1 |
| 系统菜单暂停 | 系统菜单已打开 | 持续输入移动与交互按键 | 主角保持静止，不触发 NPC 对话；关闭后恢复探索 | passed / Scene1 + Scene2 runtime 1 |
| 系统菜单占位功能 | 系统菜单已打开 | 点击继续、保存、读取、设置、返回标题 | 分别显示该功能即将实现，不切换场景或写入数据 | passed / system menu runtime 1 |
| 退出游戏 | 系统菜单已打开 | 点击“退出游戏” | 调用场景树退出并结束应用 | passed / isolated exit runtime 1 |
| 生成式菜单组件 | 自由移动阶段 | 打开系统菜单并检查框体、按钮和关闭钮 | 三类生成组件透明边缘干净、风格统一、无生成文字；引擎中文清晰且点击区域对齐 | passed / generated menu render 1 |
| 菜单按钮高度与悬浮 | 系统菜单已打开 | 观察六个按钮并逐个悬浮 | 按钮纵向舒展、文字字号保持 21；悬浮时背景和字体颜色不变化 | passed / system menu button render 3 |

## 手动觐见与任务指引验收

- [x] 开场旁白显示期间主角仍可移动。
- [x] 太监在固定位置等待，玩家远离时没有“对话”按钮。
- [x] 玩家接近太监后出现“对话”，传召结束显示“奉诏入殿”。
- [x] 主角不会被自动带入殿内，必须由玩家自行通过中央门洞。
- [x] 玩家远离皇帝时没有“觐见”，接近后出现。
- [x] 完成觐见和圣旨后任务显示“领旨南下”。

## 安全活动区验收

- [x] 右侧持续移动时停在安全边界，不进入画面边缘。
- [x] 向下持续移动时停在石像上方的安全边界。
- [x] 右下角分别用左、上、左上输入测试，均可立即脱离。
- [x] 从右庭院可回到中央御道和左庭院。
- [x] 中央门洞仍可双向通行。

## 正殿安全活动区验收

- [x] 从殿内向下移动，停在屋顶墙檐之前。
- [x] 向上移动，停在顶部陈设之前。
- [x] 正殿左右边界均不会进入装饰区。
- [x] 正殿四角向中央方向移动均能脱离。
- [x] 中央门洞双向通行且“觐见”仍可触发。

## 输入、UI 与墙体优化验收

- [ ] 对话框缩小并下移，不遮挡画面中央人物。
- [ ] WASD 与方向键移动测试通过。
- [ ] 仅使用空格键可从第一份急报走到场景完成。
- [ ] 外墙、左右殿墙和御座碰撞双侧测试通过。
- [ ] 中央门洞从殿外进入与从殿内离开均可通行。

## Playtest observations

| Date/build | Player | Observation | Evidence | Follow-up |
|---|---|---|---|---|
| 2026-07-18 / run 4 | Codex | 场景一可从急报完整走到圣旨收尾 | 运行截图、状态机结果与坐标检查 | 交付用户试玩 |
| 2026-07-18 / run 10 | Codex | 任务栏、距离交互和全程自由移动通过 | 任务文本、交互可见性、角色坐标与运行日志 | 交付用户试玩 |
| 2026-07-18 / run 12 | Codex | 右下角不再形成死角，安全活动区与用户红线近似一致 | 可见碰撞截图、边界与三方向脱离坐标 | 交付用户试玩 |
| 2026-07-18 / run 16 | Codex | 正殿安全区完成，角色不再站到屋顶墙檐 | 可见碰撞截图、四边停止坐标、四角脱离与觐见检查 | 交付用户试玩 |
| 2026-07-20 / combined run 1 | Codex | 两个项目合并后，资源重新分配唯一 UID；Scene1、Scene2 和两条切换路径均无运行错误 | Godot .NET 4.7.1 headless 导入/启动日志、自动切换测试 | 交付用户试玩 |
| 2026-07-21 / portrait run 1 | Codex | Scene1 内侍、皇帝与主帅立绘按对白和左右站位切换，正式长对白没有溢出 | 1344×896 三角色渲染截图、立绘运行态测试、完整串联回归 | 等待正式皇帝立绘 |
| 2026-07-21 / Scene2 UI run 1 | Codex | Scene2 米黄色程序底板已替换为 `BackgroundBar.png`，其他对话 UI 布局未变化 | 1344×896 渲染截图、节点布局断言、完整串联回归 | 交付用户试玩 |
| 2026-07-21 / Scene2 UI alpha render 1 | Codex | 黑框外侧白底已透明化，甲板和水面能从上缘、左侧尖角及右上凹口透出，框内纸张保持不透明 | 1344×896 OpenGL 截图、PNG Alpha 取样、Scene2 运行态测试与完整串联回归 | 交付用户试玩 |
| 2026-08-06 / exploration HUD render 1 | Codex | 两个场景共用的东方武侠风探索 HUD 已接入；主角头像、主支线任务和四个功能入口信息清楚，对话与过场显隐正确 | 1344×896 OpenGL 截图、HUD 运行态测试、C# 构建与既有剧情回归 | 交付用户试玩 |
| 2026-08-06 / system menu render 1 | Codex | 共享系统菜单已接入；实时模糊覆盖世界与 HUD，六个菜单条目清晰，暂停和关闭恢复在两个场景一致 | 1344×896 OpenGL 截图、HUD/暂停运行态测试、隔离退出测试与既有剧情回归 | 交付用户试玩 |
| 2026-08-06 / generated menu render 1 | Codex | 简单卡片菜单已替换为生成式暗玉织纹、旧铜包边和灰白纸石按钮组件；所有中文继续由引擎绘制 | 1344×896 OpenGL 截图、PNG Alpha 断言、HUD/退出/剧情回归 | 交付用户试玩 |
| 2026-08-06 / ink-wash exploration HUD render 1 | Codex | 探索主界面的简单卡片和几何底板已替换为水墨状态框、透空任务卷和水墨菱形入口；菜单顺序、任务透明卡片及显隐行为保持不变 | 1344×896 OpenGL 截图、三类 PNG Alpha 断言、HUD/退出/场景切换回归 | 交付用户试玩 |
| 2026-08-06 / ink-wash system menu render 1 | Codex | 系统菜单主框、加高按钮底框和关闭按钮已统一为水墨宣纸风；标题落在顶部题签内，模糊背景、六项菜单和原有功能规则保持不变 | 1344×896 OpenGL 截图、三类 PNG Alpha 断言、HUD/退出/静态回归 | 交付用户试玩 |
| 2026-08-06 / HUD legibility layout render 1 | Codex | 左上角色栏放大 50%并移除“帅”字，任务卡改为不透明深灰底；探索功能符号下移、系统菜单徽章字左移后均落在底框中心 | 1344×896 探索 HUD 与系统菜单截图、布局断言、HUD/退出/静态回归 | 交付用户试玩 |
| 2026-08-06 / HUD alignment follow-up render 1 | Codex | 系统菜单六个菱形拉开且未越界；任务栏改为统一灰底、透明任务项和上移标题；头像与“水师元帅”两级文字均进入状态框对应区域 | 1344×896 探索 HUD 与系统菜单截图、层级/位置断言、HUD/退出/静态回归 | 交付用户试玩 |
| 2026-08-06 / system frame and quest polish render 1 | Codex | 系统菜单外框扩展后底部按钮留白充足；角色两级文字下移；任务栏灰底连续延伸至题签后方，并用单条分隔线代替任务卡矩形框 | 1344×896 探索 HUD 与系统菜单截图、边界/层级断言、HUD/退出/静态回归 | 交付用户试玩 |
| 2026-08-06 / generated filled quest frame render 1 | Codex | 透明任务框与程序灰底组合已替换为一张自带深灰黛青底色、顶部题签和墨锋外沿的完整生成式任务框，主支线内容直接叠加其上 | 1344×896 OpenGL 截图、PNG 内外 Alpha 断言、HUD/退出/静态回归 | 交付用户试玩 |
| 2026-08-06 / text-only quest entries render 1 | Codex | 主支线任务的“帅”“商”人物徽章已移除，每项仅保留分类、任务名称和简短描述，并利用释放空间统一左对齐 | 1344×896 OpenGL 截图、节点与文字位置断言、HUD/静态回归 | 交付用户试玩 |

## Known issues

- 皇帝世界小人暂用县令素材，对话立绘暂用“帝”字卡；太监世界小人与对话立绘暂用士兵素材。
- 圣旨正文为原型占位，等待策划提供正式版本。
