# CHG-20260817：布阵台卷轴底板

- 状态：`done`
- 日期：2026-08-17

## 目标

移除布阵台现有褐色军令案背景，改用用户指定 UI 图集中右侧的大型卷轴，并让卷轴底板完整承托现有布阵按钮。

## 范围

- 从 `assets/战斗界面ui/exec-cc37cec0-2d2d-464d-a3e5-027f44fa2a0b.png` 提取右侧卷轴为透明独立素材。
- 删除不再引用的 `assets/naval/ui/deployment_command_desk.png` 及其导入记录。
- 替换 `NavalDeployment.tscn` 的布阵台背景资源与拉伸方式。
- 调整卷轴底板尺寸、九宫格边距和内容安全区，使现有按钮完整落在卷轴内部。

## 非目标

- 不修改按钮节点、尺寸、文字、排列、交互或主题样式。
- 不修改布阵规则、舰船状态、装备面板、舰队面板或战斗流程。
- 不改动本任务开始前已有的用户工作树修改。

## 验收检查

- 布阵台不再引用 `deployment_command_desk.png`。
- 新卷轴素材能被 Godot 4.7.1 .NET 导入并加载。
- 布阵台按钮节点及其 `custom_minimum_size`、文字保持不变。
- 卷轴长度和高度覆盖全部按钮，并保留左右卷轴轴头与内侧留白。
- 海战场景 smoke test 通过，并渲染截图检查布局。

## 文档影响

- 更新 `docs/design/naval-tactics-gameplay.md` 的布阵界面视觉约束。
- 本记录完成后补充最终文件与验证证据。

## 预计文件

- `assets/naval/ui/deployment_scroll_backdrop_v1.png`
- `assets/naval/ui/deployment_scroll_backdrop_v1.png.import`
- 删除 `assets/naval/ui/deployment_command_desk.png` 与对应 `.import`
- `scenes/naval/NavalDeployment.tscn`
- `docs/design/naval-tactics-gameplay.md`
- 本变更记录

## 验证证据

- 使用内置 `imagegen` 的 `precise-object-edit` 与 `background-extraction` 流程，从用户指定图集提取右侧大型卷轴并移除背景；最终文件为 `1672×941` RGBA，透明角点 `(0,0,0,0)`，Alpha 主体边界为 `(44,36)-(1626,941)`。
- 最终提示约束：只保留右侧大型米色横卷轴、深绿卷轴杆和金色轴头；移除其余 UI 与洋红/棋盘背景；输出真实透明 Alpha；不添加文字、按钮、图标或新装饰，不改变卷轴配色与像素轮廓。
- 布阵底板由 `1120×304` 调整为 `1240×346`，内容安全边距由左右 `52` / 上 `52` / 下 `18` 调整为左右 `92` / 上 `64` / 下 `24`；按钮节点、文字、排列和 `custom_minimum_size` 未修改。
- Godot 4.7.1 .NET headless editor 资源扫描与导入：退出码 0。
- `tests/test_naval_scene_smoke.gd`：通过，输出 `PASS: naval demo scene smoke`。
- Godot 4.7.1 .NET OpenGL Compatibility 以 `1344×896` 渲染 `.godot/naval_deployment_scroll_preview.png`：卷轴与轴头完整、按钮全部位于纸面安全区、棋盘主要区域未被遮挡。
