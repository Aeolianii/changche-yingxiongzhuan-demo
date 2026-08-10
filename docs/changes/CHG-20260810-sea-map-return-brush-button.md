# CHG-20260810 岭南海图返回笔触按钮

- 状态：done
- 类型：海图 UI / 生成式资源
- 日期：2026-08-10

## 目标

把岭南海图右上角的程序化长方形返回按钮替换为像素水墨笔触组件，使其与展开海图卷轴和现有探索 HUD 的美术语言一致。

## 范围

- 使用生图工具生成深墨色横向笔触底板，输出为透明 PNG 并保存到海图 UI 资源目录。
- Godot 在笔触上叠加“返回”二字，保证中文字形准确、清晰。
- 按钮继续位于卷轴右上角，保留原点击关闭、Esc 与 E 键关闭行为。
- 不调整地图视口、标题、迷雾、地点标签或卷轴主体。

## 验收检查

1. 返回按钮背景不再显示规则长方形金边，而是边缘自然的像素水墨横笔触。
2. 笔触上完整显示“返回”二字，文字居中且有足够安全边距。
3. 鼠标点击按钮、Esc 和 E 键都能正常关闭岭南海图。
4. 透明边缘无色底、白边或明显锯齿，原始分辨率渲染中不与卷轴或标题冲突。

## 预计文件

- `assets/ui/sea_overworld/sea_map_return_brush_v1.png`
- `scripts/sea_map_screen.gd`
- `tests/test_sea_fog_of_war.gd`
- `docs/design/sea-overworld-design.md`
- `docs/qa/playtest.md`

## 验证证据

- 透明资源检查：最终 PNG 为 `384×144` RGBA，四角 Alpha 均为 `0`，无可见绿色色键边缘。
- 自动验证：`tests/test_sea_fog_of_war.gd` 在 Godot 4.7.1 headless 与 OpenGL Compatibility 模式均退出 0；覆盖资源绑定、按钮尺寸、准确文字和点击关闭。
- 视觉验证：`.godot/sea_fog_map_preview.png` 原始分辨率复核确认右上按钮为深墨横笔触，“返回”二字居中清晰，未与卷轴和标题冲突。
