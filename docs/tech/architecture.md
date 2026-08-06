# Technical architecture

- Status: approved
- Engine/version: Godot .NET 4.7.1
- Target platform: Windows
- Canonical project root: `combined-project/`

## Runtime map

项目入口为 GDScript 场景 `PalaceDemo`，第二场景为 C# 场景 `Scene2`。Godot .NET 项目同时承载两种官方脚本语言。

`PalaceDemo` 包含 Background、WorldCollisions、YSortedCharacters、InteractionPoints、Camera2D 和 UI。

`Scene2` 包含 World、运行时角色与环境构建、Camera2D、NPC 交互、对话 UI 和操练覆盖层。

`ExplorationHUD` 是由 `scenes/ui/exploration_hud.tscn` 和 `scripts/exploration_hud.gd` 组成的共享 Canvas UI 组件。两个主场景各实例化一次，通过 `set_exploration_visible(bool)` 接口投射当前场景状态。组件处理角落 HUD、系统菜单、短时提示和退出请求；菜单使用 `shaders/menu_blur.gdshader` 采样屏幕纹理，模糊层之后再绘制清晰的中央面板。

Scene2 的 `FullWidthPaperDialogueBox` 继续作为正文和选项的布局容器，其 `panel` 样式直接拉伸用户重新裁剪的 512×144 `BackgroundBar.png`；黑色描边外侧像素使用 Alpha 透明显示游戏背景，纹理样式保留原有内容边距，因此只改变底板绘制，不改变容器树和交互节点。

角色为 `CharacterBody2D`，脚底小矩形碰撞，`AnimatedSprite2D` 使用独立帧构建 `SpriteFrames`。主角负责输入和相机目标，NPC 复用同一角色动画接口。

## Data flow

输入动作进入 Player，Player 更新速度与动画。场景脚本以显式剧情状态机驱动旁白、太监自身移动、距离触发交互按钮、任务指引、觐见对白和圣旨收尾。主帅位置只由玩家输入和物理碰撞决定，不由剧情脚本写入。无持久化数据。

`interact` 动作同时绑定空格和 E。场景脚本只在按键按下的单帧根据 UI 状态分发：对话框可见时推进文本，交互按钮可见时触发当前交互，避免同一次按键连续跨越两个剧情状态。

太监和皇帝交互使用世界坐标距离检查。交互按钮只在当前剧情状态正确且主角处于交互半径内时可见；玩家离开半径后立即隐藏。任务指引是场景状态的只读 UI 投影，不负责寻路。

场景一对话 UI 将纯文字显示与角色对白显示分开：纯文字入口会隐藏立绘，角色对白入口显式接收人物名、纹理、左右站位和可选占位字。场景节点只持有一个可切换左右位置的立绘容器，避免为每名角色复制 UI；关闭对话时统一清除可见状态。

场景一完成后由本场景脚本启动一次性计时器和淡出层，再调用 `SceneTree.change_scene_to_file()` 切换到 `res://scenes/Scene2.tscn`。切换失败时恢复完成态 UI，允许玩家重试。

## Directory ownership

| Path | Responsibility |
|---|---|
| `assets/backgrounds/` | 生成或画师替换的场景底图 |
| `assets/characters/` | 首版角色帧、元数据与授权 |
| `scenes/characters/` | Player 和 NPC 可复用场景 |
| `scenes/palace/` | 皇宫可玩场景和手工碰撞 |
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
- Scene2 对话底板固定为 1344×190；更换底板不得改变立绘、名牌、正文和选项节点的现有布局。
- 探索 HUD 使用 `set_exploration_visible(bool)` 接收场景可见性，并通过 `menu_visibility_changed(bool)` 通知场景菜单暂停状态；场景一切换 `player.controls_enabled`，场景二在物理与交互分发前查询 `is_menu_open()`，HUD 不直接持有场景角色引用。
- `set_exploration_visible(false)` 必须同步关闭菜单；关闭事件由场景结合剧情、对白和过场状态决定是否恢复输入，避免错误解锁。
- 探索 HUD 使用全屏锚点和角落容器适配窗口；底部中央交互区和底部对话区必须保持无遮挡。

## Persistence

首版无存档。

## Dependencies and tools

| Dependency | Purpose | Version/policy |
|---|---|---|
| Godot | 2D 运行与编辑 | .NET 4.7.1 stable |
| Godot .NET SDK | 编译场景二 C# 脚本 | 4.7.1 / .NET 9 |

## Known debt and risks

- 生成背景可能与角色像素密度不一致，必须先做角色叠放检查。
- 单张背景不可像 TileMap 一样局部重绘，但便于原型快速替换。
- 场景一原设计分辨率为 1280×720，场景二为 1344×896；合并项目统一采用 1344×896，并须回归检查场景一相机与 UI。
- 混合语言项目必须使用 Godot .NET 编辑器；普通 Godot 编辑器无法编译场景二。
- 两个源项目包含内容相同但路径不同的角色素材，其历史 `.import`/`.translation` 产物可能携带重复 UID。合并仓库只保留原始图片、CSV 和授权元数据，导入产物由合并项目重新生成，禁止直接沿用冲突 UID。
