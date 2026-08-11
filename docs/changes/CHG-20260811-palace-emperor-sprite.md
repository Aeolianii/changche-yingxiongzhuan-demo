# CHG-20260811-palace-emperor-sprite: 第一幕皇帝世界角色替换

- Status: proposed
- Type: content
- Owner: Project owner
- Created: 2026-08-11

## Goal and player/project outcome

把标题界面“开始新游戏”后第一幕皇宫红毯上方的县令占位皇帝，替换为已通过像素素材试产的虚构岭南朝廷皇帝。玩家在开场急报、自由移动和觐见阶段都能看到身份明确、与宫殿色彩协调的待机角色，同时保留现有剧情、交互、碰撞、位置和场景流程。

## Scope

- 把试产皇帝的四方向待机与行走帧整理到项目既有角色目录约定中。
- 扩展共享角色键，使 `CharacterActor` 能加载 `emperor`。
- 只把 `PalaceDemo/YSortedCharacters/Emperor` 从 `magistrate` 切换到 `emperor`。
- 为该皇帝实例设置约 `0.55` 的最近邻显示缩放并校正脚底锚点；默认面朝下播放四帧待机。
- 增加静态/运行态验证，并在 1344×896 开幕画面中检查实际比例与像素清晰度。

## Non-goals

- 不替换对话框中的暗红金边“帝”字立绘占位卡。
- 不修改水师主帅、内侍、县令或其他场景中的角色素材。
- 不改变皇帝位置、觐见距离、脚底碰撞、剧情状态机、对白、相机、背景或 UI。
- 不把该虚构角色描述为真实历史皇帝复原，也不新增攻击、受击或剧情动作。

## Acceptance checks

- [ ] 从标题界面开始新游戏后，第一幕红毯上方显示新皇帝，不再显示县令占位小人。
- [ ] 皇帝面朝下循环播放四帧待机动画；四方向待机与行走资源均可由共享角色加载器建立动画。
- [ ] 皇帝脚底继续落在原世界坐标 `(768, 270)`；约 `0.55` 缩放后可见高度为 48–50 像素，与原县令占位约 49 像素及宫殿石砖比例协调。
- [ ] 像素纹理保持最近邻、透明边缘无黑底或品红残留，角色没有裁切或明显抖脚。
- [ ] 玩家接近皇帝后“觐见”仍按原距离和剧情状态出现，皇帝碰撞、Y 排序和对白流程不变。
- [ ] 对话中的皇帝立绘继续显示既有“帝”字占位卡。
- [ ] 相关角色/场景测试和项目场景解析通过，运行日志无新增阻断错误。

## Documentation impact

- Canonical documents to update before implementation: `docs/design/palace-scene.md`, `docs/assets/character-assets.md`, `docs/design/art-direction.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`
- Approved design: `docs/superpowers/specs/2026-08-11-palace-emperor-sprite-design.md`
- Decisions/ADRs: none; reuse the existing character-frame directory and shared `CharacterActor` loader.

## Implementation notes

- Likely files/modules: `assets/characters/emperor/`, `scripts/character_actor.gd`, `scenes/palace/palace_demo.tscn`, focused palace/character tests.
- Constraints and risks: source frames use a 128×128 canvas and contain an 88–91 pixel-high figure while the old 64×64 magistrate idle figure is about 49 pixels high; preserve source pixels and start from a `0.55` emperor-instance scale. The target worktree already contains unrelated active changes, including editor-generated `.import` updates and a modified palace scene; edits must remain limited to the emperor-specific lines.

## Verification evidence

- Automated: not run
- Manual/in-engine: not run

## Final reconciliation

- Files changed: TBD
- Documented limitations/follow-ups: the dialogue portrait remains the approved “帝” placeholder until a separate portrait asset is produced.
