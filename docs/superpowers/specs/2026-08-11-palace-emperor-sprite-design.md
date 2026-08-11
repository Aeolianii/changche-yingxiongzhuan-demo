# 第一幕皇帝世界角色替换设计

- Status: approved by project owner on 2026-08-11
- Target: `PalaceDemo/YSortedCharacters/Emperor`

## Intent

标题界面“开始新游戏”后，第一幕皇宫红毯上方当前使用县令 LPC 素材暂代皇帝。将其替换为已经由 `agent-sprite-forge` / `generate2dsprite` 流程生成并通过透明边缘、脚底对齐和帧完整性检查的虚构皇帝像素角色，使开幕画面的核心叙事人物一眼可辨。

## Selected approach

复用共享 `NPC` / `CharacterActor` 角色框架，而不是为皇帝增加一套剧情脚本或独立场景。皇帝资源按现有目录约定存放为：

```text
assets/characters/emperor/standard/
  idle/{up,left,down,right}/1.png..4.png
  walk/{up,left,down,right}/1.png..4.png
```

`CharacterActor` 的角色键加入 `emperor`，继续按既有规则构造 `idle_<direction>` 和 `walk_<direction>` 动画：待机 4 FPS，行走 8 FPS，循环播放。宫殿皇帝实例将 `character_key` 从 `magistrate` 改为 `emperor`，默认 `facing = "down"`。

## Presentation and anchoring

新皇帝帧画布为 128×128，实测非透明人物高度为 88–91 像素、脚底位于源图 `y=121..123`；旧县令待机朝下帧的非透明人物高度约为 49 像素、脚底位于 `y=63`。不得对源 PNG 做模糊重采样；宫殿皇帝实例的 `AnimatedSprite2D` 使用最近邻过滤并从 `scale = Vector2(0.55, 0.55)` 开始，使人物高度约为 48–50 像素。保持现有视觉子节点约 `y=-25` 的偏移时，两套素材的脚底都落在角色根节点下方约 6 像素，因此根节点 `(768, 270)`、碰撞体和交互距离不需要移动。1344×896 运行复核只有在出现明显视觉偏差时才允许小幅调整皇帝视觉子节点，不能改根节点或用模糊缩放掩盖问题。

皇帝在当前第一幕不执行剧情移动，因此开幕和觐见阶段使用 `idle_down`。四方向行走帧仍完整接入，以保持共享角色接口完备，并为后续剧情移动留出能力，但本次不新增皇帝移动行为。

## Preserved behavior

- 皇帝根节点位置、脚底碰撞、Y 排序和觐见距离保持不变。
- `PalaceDemo` 的急报、内侍传召、自由入殿、君臣对白、圣旨和章节切换状态机保持不变。
- 下方水师主帅、内侍、宫殿背景、相机、探索 HUD 和水墨对话框保持不变。
- 皇帝对白右侧的暗红金边“帝”字占位卡不在本次替换范围内。

## Verification design

静态检查确认皇帝角色键合法、32 张方向帧路径完整、每个动画恰有 4 帧，并确认宫殿场景只对皇帝实例覆盖显示参数。缺少目录、方向或帧时测试必须失败，不能依靠共享加载器静默跳过后继续交付。运行检查从标题界面进入新游戏，确认新皇帝显示并播放面朝下待机，脚底稳定且无透明背景问题；随后推进至“觐见”和皇帝对白，确认交互、碰撞、剧情和“帝”字对话占位卡没有回归。
