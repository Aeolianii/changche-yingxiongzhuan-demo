# Technical architecture

- Status: approved
- Engine/version: Godot 4.7.1
- Target platform: Windows
- Canonical project root: `combined-project/`

## Runtime map

项目入口 `PalaceDemo` 与第二场景 `Scene2` 均使用 GDScript，标准版与 .NET 版 Godot 均可运行。

`PalaceDemo` 包含 Background、WorldCollisions、YSortedCharacters、InteractionPoints、Camera2D 和 UI。

`Scene2` 包含 World、运行时角色与环境构建、Camera2D、NPC 交互、对话 UI 和操练覆盖层。

`SeaOverworld` 是独立运行的海上大地图初版，场景位于 `scenes/sea_overworld/sea_overworld.tscn`。它使用单张放大的广东海岸原型背景、手工岛屿碰撞、`CharacterBody2D` 船只、地点 `Area2D` 和独立 Canvas UI；当前不接入正式章节切换。

`ExplorationHUD` 是由 `scenes/ui/exploration_hud.tscn` 和 `scripts/exploration_hud.gd` 组成的共享 Canvas UI 组件。两个主场景各实例化一次，通过 `set_exploration_visible(bool)` 接口投射当前场景状态。组件处理角落 HUD、系统菜单、短时提示和退出请求；菜单使用 `shaders/menu_blur.gdshader` 采样屏幕纹理，模糊层之后再绘制清晰的中央面板。

Scene2 的 `FullWidthPaperDialogueBox` 继续作为正文和选项的布局容器，但其 `panel` 样式改为拉伸共享的生成式像素水墨对话底板；姓名容器使用共享姓名笔触。Scene1 直接引用同一资源。两处保留各自既有状态机，只统一底板、人物左右站位和正文安全边距。

角色为 `CharacterBody2D`，脚底小矩形碰撞，`AnimatedSprite2D` 使用独立帧构建 `SpriteFrames`。主角负责输入和相机目标，NPC 复用同一角色动画接口。

## Data flow

输入动作进入 Player，Player 更新速度与动画。场景脚本以显式剧情状态机驱动旁白、太监自身移动、距离触发交互按钮、任务指引、觐见对白和圣旨收尾。主帅位置只由玩家输入和物理碰撞决定，不由剧情脚本写入。无持久化数据。

海上大地图继续复用 `move_up/down/left/right`，但地点进入不复用同时包含空格和回车的通用 `interact` 动作，而是只接收物理键E或鼠标点击“进入”按钮。船只进入地点 `Area2D` 后显示地点名称和底部操作条，不绘制岛屿轮廓；进入海上事件或事件船只的 `Area2D` 时自动显示一次占位提示。

`interact` 动作同时绑定空格和 E。场景脚本只在按键按下的单帧根据 UI 状态分发：对话框可见时推进文本，交互按钮可见时触发当前交互，避免同一次按键连续跨越两个剧情状态。

太监和皇帝交互使用世界坐标距离检查。交互按钮只在当前剧情状态正确且主角处于交互半径内时可见；玩家离开半径后立即隐藏。任务指引是场景状态的只读 UI 投影，不负责寻路。

场景一对话 UI 将纯文字显示与角色对白显示分开：纯文字入口会隐藏立绘，角色对白入口显式接收人物名、纹理、左右站位和可选占位字。场景节点只持有一个可切换左右位置的立绘容器，避免为每名角色复制 UI；关闭对话时统一清除可见状态。

场景一完成后由本场景脚本启动一次性计时器，并调用独立的 `ChapterTransition` Canvas UI 播放南下行程。过场完成时在场景树根节点写入一次性入口标记，再调用 `SceneTree.change_scene_to_file()` 切换到 `res://scenes/Scene2.tscn`。切换失败时移除标记、关闭过场并恢复完成态 UI，允许玩家重试。

`Scene2` 只在检测到该入口标记时消费并删除它，随后复用既有对话框播放水师副将迎接对白。对白期间移动、交互和探索 HUD 均锁定；对白结束后才调用共享 HUD 的 `set_main_task("巡视水师驻地")` 并恢复自由探索。直接运行 `Scene2.tscn` 时不触发入口对白，便于独立调试。

第二章巡视使用场景内轻量任务状态机，不通过环境节点触发：两名值守士兵以稳定角色标识分别登记一次汇报，收齐后开放中军军官复命；军官复命完成后开放广州县令会谈，县令会谈完成回调既有操练覆盖层。共享 HUD 接收任务标题、当前目标和步骤阶段，只负责投影，不反向控制 Scene2 剧情。

## Directory ownership

| Path | Responsibility |
|---|---|
| `assets/backgrounds/` | 生成或画师替换的场景底图 |
| `assets/characters/` | 首版角色帧、元数据与授权 |
| `scenes/characters/` | Player 和 NPC 可复用场景 |
| `scenes/palace/` | 皇宫可玩场景和手工碰撞 |
| `scenes/sea_overworld/` | 海上大地图场景、地点触发与船只原型 |
| `scripts/` | 移动、动画、交互与 UI 行为 |
| `assets/` | 统一管理背景、角色、UI 与场景素材 |
| `shaders/` | 场景二水面等视觉效果着色器 |
| `tests/` | 合并项目静态验收与资源引用检查 |

## Interfaces and invariants

- 2D 单平面，不实现高度系统。
- 像素纹理使用最近邻过滤，角色保持原始 64×64 比例。
- 一次性边界只用编辑器可见、可拖动的 `CollisionPolygon2D`。
- 原型庭院采用少量连续矩形边界定义安全活动区，边界与花坛、石像和画面边缘保持视觉余量；优先避免窄缝与凹角，不逐个包围装饰物。
- 正殿边界使用独立的左右矩形和连续上下边界：上半部比庭院更窄，下半部仍保持庭院宽度；不使用凹多边形拼接两种宽度，避免物理引擎分解出斜向三角碰撞。
- 不从生成图片自动识别碰撞，不使用程序生成地形边界。
- 装饰物不碰撞；只有建筑、墙体、栏杆、水体和世界边缘阻挡玩家。
- 宫殿室内外在同一坐标平面；门洞通过手工碰撞缺口表达，不增加高度变量。
- Scene1 与 Scene2 必须引用同一套对话底板和姓名笔触资源；主角站左、NPC 站右，无说话者时隐藏立绘与姓名。
- 对话视觉主体由单张横向水墨笔触构成；代码只负责透明度、拉伸、文字布局和交互状态，不重新拼装矩形外框。
- 探索 HUD 使用 `set_exploration_visible(bool)` 接收场景可见性，并通过 `menu_visibility_changed(bool)` 通知场景菜单暂停状态；场景一切换 `player.controls_enabled`，场景二在物理与交互分发前查询 `is_menu_open()`，HUD 不直接持有场景角色引用。
- `set_exploration_visible(false)` 必须同步关闭菜单；关闭事件由场景结合剧情、对白和过场状态决定是否恢复输入，避免错误解锁。
- 章节入口标记必须是一次性的运行时元数据：Scene2 读取后立即删除，场景加载失败时也必须清理，不能污染再次进入。
- Scene2 的士兵汇报必须按角色标识去重；军官复命和县令操练入口必须由任务阶段约束，不能只依赖玩家点击某个通用选项。
- 探索 HUD 使用全屏锚点和角落容器适配窗口；底部中央交互区和底部对话区必须保持无遮挡。

## Persistence

首版无存档。

## Audio settings

- `ExplorationHUD` 在共享系统菜单覆盖层内管理 `SystemPanel` 与 `SettingsPanel` 两个互斥子面板；进入设置不改变覆盖层可见性，因此场景一和场景二继续使用既有 `menu_visibility_changed(bool)` 暂停契约。
- `default_bus_layout.tres` 声明 `Music` 与 `SFX` 音频总线，父级均为 `Master`；`ExplorationHUD` 仍在运行时检查并补齐缺失总线。设置界面的两条滑动条将 0–100 线性值实时转换为对应总线的分贝值，0 映射为静音下限。
- 背景音乐播放器应使用 `Music`，交互与战斗音效播放器应使用 `SFX`；当前海战演出音效迁移到 `SFX`。
- 首版不持久化音量，重新启动游戏后使用项目或运行时默认值。

## Dependencies and tools

| Dependency | Purpose | Version/policy |
|---|---|---|
| Godot | 2D 运行与编辑 | 4.7.1 stable |

## Known debt and risks

- 生成背景可能与角色像素密度不一致，必须先做角色叠放检查。
- 单张背景不可像 TileMap 一样局部重绘，但便于原型快速替换。
- 场景一原设计分辨率为 1280×720，场景二为 1344×896；合并项目统一采用 1344×896，并须回归检查场景一相机与 UI。
- 场景逻辑已统一为 GDScript，不再依赖 .NET SDK 或 Godot .NET 编辑器。
- 两个源项目包含内容相同但路径不同的角色素材，其历史 `.import`/`.translation` 产物可能携带重复 UID。合并仓库只保留原始图片、CSV 和授权元数据，导入产物由合并项目重新生成，禁止直接沿用冲突 UID。
