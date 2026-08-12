# 全局探索 UI 与伏波古岭正式存档设计

- Status: implemented and verified
- Date: 2026-08-11
- Owner: Project owner / Codex

## Goal

把现有 `ExplorationHUD` 从皇宫、场景二和海上大地图各自持有的场景组件，迁移为进程内唯一、跨场景常驻的 Autoload UI；伏波古岭接入同一套角色状态、任务、功能入口和系统菜单，并进入正式单槽存档范围。

## Player-visible outcome

- 皇宫、场景二、海图和伏波古岭始终显示同一套水墨像素探索 HUD，不会因切换场景出现样式回退、重复 UI 或残留任务。
- 伏波古岭移除左上深色简单方框，改用共享角色状态、任务栏和右上“任务 / 人物 / 物品栏 / 船只 / 菜单”五个入口。
- 伏波底部交互提示、守岭人对话与完成提示使用项目现有水墨像素底板，不再使用纯色 `ColorRect` 方框。
- 玩家可在伏波稳定探索状态保存和读取；读取后恢复人物位置、朝向、任务阶段与钓鱼/鼓令完成状态，并可从码头返回原海图上下文。

## Selected architecture

新增 `ExplorationUI` Autoload。它是唯一 `ExplorationHUD` 实例的所有者，负责：

1. 启动时实例化 `res://scenes/ui/exploration_hud.tscn`。
2. 通过 `WeakRef` 记录当前场景所有者与任务上下文，不延长场景生命周期。
3. 在场景切换时关闭菜单、任务页、地图页和提示等瞬态 UI，隐藏 HUD，等待新场景接管。
4. 将 HUD 的 `menu_visibility_changed`、`save_requested`、`load_requested`、`return_title_requested` 意图只转发给当前场景。
5. 保证同一 SceneTree 中始终只有一个正式 `ExplorationHUD`。

场景通过稳定接口接入：

```gdscript
var exploration_hud: Control

func _ready() -> void:
	exploration_hud = ExplorationUI.acquire(self, &"fubo_guling")

func _exit_tree() -> void:
	ExplorationUI.release(self)
```

`acquire(owner, context_id)` 必须先重置上一个场景的瞬态 UI，再设置任务上下文并返回 HUD。`release(owner)` 只在 `owner` 仍是当前所有者时生效，避免旧场景延迟退出时隐藏新场景 UI。

## Four-scene migration

- `PalaceDemo`、`Scene2`、`SeaOverworld` 删除各自场景树中的 `ExplorationHUD` 实例和对应 PackedScene 引用。
- 三个场景保留现有任务、存档、菜单暂停和显隐规则，只把 `$UI/ExplorationHUD` 替换为从 `ExplorationUI` 获取的全局实例。
- `FuboGuling` 新增同样的获取、释放和系统菜单信号处理；进入小游戏、对话、加载切场和完成覆盖层时隐藏全局 HUD，返回稳定探索时恢复。
- 标题界面不接管探索 HUD。任何探索场景返回标题前释放当前上下文，全局 HUD 保持隐藏。
- 场景加载失败时，当前场景重新接管并恢复 HUD 与人物控制，不能留下全屏透明输入层。

## Context reset and task projection

`ExplorationHUD.set_quest_context()` 与任务页支持四类上下文：皇宫默认、`scene_two`、`sea_overworld`、`fubo_guling`。每次切换必须重置上一上下文的月相、海图入口、任务数据、提示、菜单和覆盖层状态。

伏波任务投影：

| Phase | 主任务 | 当前目标 |
|---|---|---|
| `ARRIVAL` | 伏波古岭 | 旧存档兼容态，载入后转为可钓鱼 |
| `FISHING_AVAILABLE` | 码头渔获 | 码头旁可随时钓鱼，也可询问守岭人 |
| `DRUM_AVAILABLE` | 古校场鼓令 | 沿山路前往古校场 |
| `VIEWPOINT_OPEN` | 登岭望海 | 登上观景台眺望南海 |
| `COMPLETE` | 伏波古岭 | 行程完成 |

任务页使用 `fubo_guling` 专用任务数据，不显示皇宫、水师驻地或海图任务。人物、物品栏和船只入口沿用当前共享 HUD 行为，不在本次新增伏波专属内容。

## Fubo presentation layer

- 删除伏波 `Interface/HUD/TitlePanel`、`FishingPanel` 与 `DrumPanel` 的简单方框显示；小游戏状态仍由各自全屏场景负责。
- `PromptPanel` 改用 `res://assets/ui/sea_overworld/interaction_button_ink_v1.png` 与对应按下态的横向水墨交互底板，文字由引擎绘制。
- `DialoguePanel` 使用 `res://assets/ui/dialogue/ink_dialogue_backdrop.png`，姓名使用 `res://assets/ui/dialogue/ink_speaker_nameplate.png`，布局与皇宫/场景二的安全文字区一致。
- `Overlay` 的短时解锁提示和完成提示使用水墨像素覆盖层；不得遮挡系统菜单，也不得在全局 HUD 隐藏后继续截获无关输入。
- 两个小游戏内部 UI、规则与音频本次保持不变。

## Formal save contract

`GameState.ALLOWED_SCENES` 增加：

```text
res://scenes/fubo_guling/fubo_guling.tscn
```

现有顶层存档格式不变，`SAVE_VERSION` 保持 1；旧存档继续兼容。伏波稳定快照由 `FuboSaveState` 编解码；坐标和返航船位使用 JSON 可持久化的二元数组，运行时再还原为 `Vector2`。字段包含：

```gdscript
{
	"player_position": [x, y],
	"player_facing": "up|left|down|right",
	"phase": int,
	"fishing_completed": bool,
	"drum_completed": bool,
	"keeper_intro_completed": bool,
	"sea_return_context": Dictionary,
}
```

保存规则：

- 新流程从 `FISHING_AVAILABLE` 开始；`ARRIVAL` 仅保留为旧存档兼容值，载入后立即转为可钓鱼状态。`FISHING_AVAILABLE`、`DRUM_AVAILABLE`、`VIEWPOINT_OPEN` 的自由移动状态可保存。
- 对话、钓鱼/鼓令小游戏、加载切场、完成覆盖层或其他输入锁定状态返回 `unstable_scene`，不覆盖旧存档。
- `fishing_completed` 与 `drum_completed` 必须和 `phase` 一致；写入和读取均校验，矛盾或非法数据返回 `invalid_scene_state`，不部分恢复。
- `keeper_intro_completed` 独立记录玩家是否听过守岭人的首次玩法提示，不影响钓鱼入口；缺少该字段的旧 `FISHING_AVAILABLE` 存档按已听取处理。
- `sea_return_context` 使用 `FuboTravelSession.decode_context()` 校验。有效数据在读取岛屿后重新写回 SceneTree 会话元数据，使码头返航仍恢复原船位；无效或缺失数据允许载入岛屿，但返航使用既有安全海图回退点。
- 读取只重建稳定地图状态，不恢复对话行号、小游戏计时、鼓谱、鱼群、提示计时器或加载动画。

## Signal and lifecycle safety

- `ExplorationUI` 只连接 HUD 内部信号一次；场景接管使用当前所有者校验，不能随场景往返累积重复回调。
- 场景释放时必须停止自己对全局管理器信号的监听。Godot 自动断开已释放对象的 Callable，但仍显式释放所有权以重置 UI。
- 全局 HUD 不保存场景节点的强引用超过场景生命周期；所有者失效时自动隐藏并清空上下文。
- 小游戏宿主隐藏地图 HUD 时不释放场景所有权；退出小游戏后恢复同一任务上下文。

## Error handling

- Autoload 未能实例化 HUD 时输出明确错误，场景继续运行但不创建第二份临时 HUD。
- 保存或读取失败使用全局 HUD toast 显示 `GameState.error_message()`。
- 读取场景失败时清除待恢复快照，保留当前场景、任务和人物控制。
- 场景切换期间所有 HUD 功能入口不可交互；切换失败时统一复位。

## Testing and visual acceptance

- 新增全局 UI 生命周期测试：连续进入皇宫、场景二、海图、伏波和标题，始终只有一个 HUD，且上下文与显隐正确。
- 更新既有测试节点路径，从场景内 `$UI/ExplorationHUD` 改为 `/root/ExplorationUI` 提供的实例。
- 伏波存档测试覆盖四个稳定阶段、位置、朝向、完成标记、返航上下文、非法/矛盾快照和不稳定状态拒绝。
- 运行皇宫剧情、场景二巡视与操练、海图月相和地图、海图—伏波往返、钓鱼、听鼓、标题继续/返回、主流程存档等回归。
- 1344×896 Vulkan 截图检查四个场景的 HUD 一致性，以及伏波交互、对话、任务页、系统菜单和小游戏前后显隐。

## Non-goals

- 不修改两个伏波小游戏内部视觉、规则和音频。
- 不保存进行中的对白、小游戏、过场或加载动画。
- 不新增人物、物品栏或船只系统内容。
- 不修改四个场景的剧情、地图、碰撞或角色移动规则。
