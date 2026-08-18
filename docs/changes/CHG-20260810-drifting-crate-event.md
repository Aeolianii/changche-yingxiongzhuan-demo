# CHG-20260810 漂流木箱随机事件

- 状态：done
- 类型：海图事件 / 对话 / 生成素材
- 日期：2026-08-10

## 目标

把现有“漂流木箱·该事件开发中”占位触发升级为一次性双选项事件，并用新生成的像素水墨木箱素材替代临时菱形与地图文字。

## 范围

- 使用 Codex 内置生图功能制作透明背景的漂流木箱地图素材。
- 木箱继续位于现有海图事件坐标，不显示“漂流木箱”四字标签。
- 玩家接触后复用场景二纸质对话框、士兵立绘、士兵姓名牌和双选项按钮样式。
- 对话内容为士兵报告海上发现漂流木箱，提供“打捞上来”“置之不理”两个选项。
- 打捞后显示金石 `+100`、木材 `+100`、银钱 `+1000`；当前只作对话提示，不写入资源状态。
- 两个分支都关闭对话、恢复航行并移除木箱。
- 为素材、交互锁定、两个分支和一次性移除增加针对性测试。

## 非目标

- 不实现正式资源背包、资源存档、随机掉落表或事件刷新系统。
- 不修改海图碰撞、地点入口、场景二既有对话内容或角色资源。
- 不改变渔船、商船等其他自动触发目标的占位行为。

## 验收检查

1. 海图显示透明背景水墨像素木箱，不显示事件名称大字。
2. 接触木箱后玩家不能继续移动，显示场景二同款士兵对话框和两项选择。
3. “打捞上来”显示三项精确资源增量；确认后木箱消失并恢复航行。
4. “置之不理”立即关闭对话，木箱消失并恢复航行。
5. 任一分支结束后事件节点不可再次触发；其他船只占位事件无回归。

## 文档影响

- `docs/design/sea-overworld-design.md`：记录漂流木箱的一次性双选项流程。
- `docs/assets/sea-overworld-generated-assets.md`：登记生成素材、尺寸、用途与最终提示词。
- 本记录完成时补充最终资源校验、运行测试与截图证据。

## 预计文件

- `assets/sprites/sea_overworld/drifting_supply_crate_v1.png`
- `scenes/ui/field_event_dialogue.tscn`
- `scripts/ui/field_event_dialogue.gd`
- `scripts/sea_overworld.gd`
- `tests/test_sea_overworld_crate_event.gd`
- 上述文档与本变更记录。

## 实际实现

- 通过 Codex 内置 `imagegen` 生成纯绿色键控源图，使用技能自带 `remove_chroma_key.py` 去底，再裁切缩放为 `512×512` 透明 PNG。
- 木箱运行时以 `0.22` 倍最近邻采样显示，地图节点仅包含 `CrateSprite`，不再创建旧菱形占位或“漂流木箱”标签。
- `FieldEventDialogue` 复用场景二的 `ink_dialogue_backdrop.png`、`ink_speaker_nameplate.png`、士兵 `picture.png` 及同样的右侧大立绘、姓名牌和选项按钮布局。
- 接触时关闭事件监测并锁定玩家控制；打捞/忽略任一选择都会设置一次性完成状态并删除事件节点。打捞结果确认或忽略完成后恢复航行。
- 存档快照新增 `crate_event_resolved`，已处理的木箱在载入时保持移除。

## 验证证据

- Asset: 最终 PNG 为 `512×512` RGBA，四角 Alpha 均为 `0`，主体不透明像素 `95576`；SHA-256 为 `D000E49495FFEF5744A268E9A0371BF25FF7BE1129CE379D5C0565471623F037`。
- Automated: `tests/test_sea_overworld_crate_event.gd` 在 headless 和 OpenGL compatibility 两种模式均通过；覆盖无地图文字、Scene2 组件/立绘复用、碰撞锁航、两项选择、精确资源文案、双分支移除、恢复航行和已完成状态载入。
- Regression: `tests/test_sea_overworld_entry_alignment.gd` 与 `tests/test_scene_two_sea_link.gd` 通过。
- Static: Godot 4.7.1 headless 编辑器导入/解析与 `git diff --check` 通过。
- Visual: `.godot/sea_overworld_crate_preview.png` 确认木箱在海面尺度适中、贴身水沫自然且无名称文字；`.godot/sea_overworld_crate_dialogue_preview.png` 确认士兵立绘、纸质对话框、姓名牌及两项选择完整可读、无遮挡。
- Known existing state: 完整 `tests/test_sea_overworld.gd` 仍会因用户正在编辑的 `World/WorldCollision` 与旧 32 节点精确基准不一致而失败；`tests/test_main_flow_save.gd` 的海图恢复点 `(2450,1400)` 也会被当前手工碰撞挤开。两项失败均与本次木箱事件无关，本变更没有修改或回退该碰撞场景。
