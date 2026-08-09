# CHG-20260809-title-screen: 游戏启动与继续游戏界面

- Status: done
- Type: feature
- Owner: Codex
- Created: 2026-08-09

## Goal and player/project outcome

游戏启动后先进入具有独立水师主视觉的标题界面，玩家可直接继续已有存档、开始新游戏、调整基础音量或退出，不再误以为重启后存档消失。

## Scope

- 使用内置生图模型生成原创 3:2 像素水墨海疆主视觉，并保存到项目资源目录。
- 使用已生成的独立“厂车英雄传”书法标题素材，并通过色键移除得到透明 PNG。
- 使用内置生图模型生成可复用的透明水墨菜单按钮底板，四项菜单文字仍由 Godot 精确绘制。
- 标题与菜单作为独立 Godot UI 层，避免把交互文字烘焙进背景。
- 删除章节题签、副标题、版本号和常驻存档说明，只保留标题与四项核心菜单；错误信息按需临时显示。
- 主菜单提供“继续游戏、开始新游戏、游戏设置、退出游戏”。
- “继续游戏”读取正式单槽存档并切换到记录场景；无存档时禁用并明确显示状态。
- “开始新游戏”进入皇宫开场，但不删除既有存档，避免误操作造成进度丢失。
- 设置面板提供音乐与音效音量，并复用项目现有 Audio Bus。
- 将三个自由探索场景的系统菜单“返回标题”从占位提示改为真实切换，返回时不改写存档。
- 添加淡入、缓慢背景漂移和清晰的键鼠焦点反馈。
- 更新项目主场景、存档入口和自动验证。

## Non-goals

- 不复制任何现有游戏的角色、Logo、场景或菜单素材。
- 不实现多存档槽、存档缩略图、删除存档、云同步或账号系统。
- 不自动覆盖、迁移或删除 `user://main_flow_save.json`。
- 不新增战斗、船只数值或剧情内容。

## Acceptance checks

- [x] 启动项目进入标题界面，主视觉在 1344×896 画布及拉伸窗口下无黑边和明显变形。
- [x] 生成式书法标题素材实际显示，“厂车英雄传”字形完整且边缘透明干净。
- [x] 四个选项使用生成式水墨 UI 底板，文字由 Godot 绘制且所有交互区域一致。
- [x] 界面只保留标题和四项核心菜单，不显示章节题签、副标题、版本号或常驻存档小字。
- [x] 正式存档存在时“继续游戏”可读取并进入正确场景；存档缺失时按钮禁用。
- [x] “开始新游戏”进入皇宫且不删除现有正式存档。
- [x] 音乐与音效设置可调节，对应 Audio Bus 状态即时更新。
- [x] 退出按钮正常结束应用，键盘焦点和鼠标悬停均有明确反馈。
- [x] 皇宫、水师驻地和海上大地图可通过系统菜单返回标题，正式存档保持不变。
- [x] 既有场景、空格对白、点击移动、存档、HUD 与海图测试继续通过。
- [x] 正式存档在实现、测试和项目重启前后保持不变。

## Documentation impact

- `docs/index.md`、`docs/product/mvp.md`：启动路径增加标题界面。
- `docs/design/art-direction.md`：新增标题界面构图、色彩和生成素材约束。
- `docs/design/scene-flow.md`：定义继续游戏、新游戏、设置与退出流程。
- `docs/tech/architecture.md`：新增 TitleScreen 场景职责和存档加载契约。
- `docs/assets/generated-backgrounds.md`：记录生成方式、项目路径和最终提示词。
- `docs/qa/playtest.md`、`docs/production/backlog.md`：增加验收与进度记录。

## Implementation notes

- Likely files/modules: `assets/ui/title_screen/`、`scenes/ui/title_screen.tscn`、`scripts/ui/title_screen.gd`、`project.godot`、标题界面运行测试与静态验证。
- Constraints and risks: 生图模型不保证中文文字准确，因此背景禁止文字；标题优先独立生成并人工验证，不合格时用 Godot 原生文字确保准确。

## Verification evidence

- Automated: 静态验证和 12 项 Godot 运行测试全部通过，覆盖标题继续/新游戏、音量、返回标题、存档、HUD、点击移动、章节切换、第二幕对白、海图往返和退出。
- Manual/in-engine: Godot 4.7.1 Vulkan 实际渲染并检查 `.godot/title_screen_preview.png`；确认透明书法标题、四个生成式按钮底板、简化后的信息层级、背景裁切和键盘焦点显示正常。

## Final reconciliation

- Files changed: 新增标题背景、透明书法标题、透明水墨菜单底板、`scenes/ui/title_screen.tscn`、`scripts/ui/title_screen.gd`、`tests/test_title_screen.gd` 和本变更记录；修改项目入口、共享 HUD、三个探索场景、对应测试与权威文档。
- Generated asset prompts: 背景、书法标题与菜单按钮底板均使用内置 `image_gen` 生成，三个最终提示词和色键处理方式完整记录于 `docs/assets/generated-backgrounds.md`。
- Documented limitations/follow-ups: 标题界面不显示存档时间/缩略图，也不提供删除或覆盖确认；无存档时仅将“继续游戏”置灰，读取错误才临时显示必要信息；开始新游戏保留旧存档，直到玩家下一次主动保存。
