# CHG-20260807-generated-settings-controls: 生图设置控件

- Status: done
- Type: content
- Owner: Codex
- Created: 2026-08-07

## Goal and player/project outcome

将游戏设置界面的返回按钮、音量滑轨和音量滑块替换为与既有系统菜单一致的古风像素生图组件，减少程序绘制控件与主框之间的风格差异。

## Scope

- 生成一个无文字、带清晰回转箭头的设置返回按钮透明 PNG。
- 生成一个可横向拉伸的深墨绿旧金音量滑轨透明 PNG。
- 生成一个旧金包边、黛青内芯的菱形音量滑块透明 PNG。
- Godot 设置面板改用三类生成素材，保留现有点击和拖动逻辑。
- 删除返回按钮下方的“返回”提示文字。

## Non-goals

- 不改变音乐、音效两条总线和 0–100 音量映射。
- 不增加设置项，不修改系统菜单主框或游戏场景背景。
- 不在生成图中加入中文、数字、水印或额外装饰文字。

## Acceptance checks

- [x] 返回按钮使用项目内新生成素材，箭头清晰且下方不再显示“返回”。
- [x] 两条音量滑轨使用同一生成式轨道素材，拉伸后边缘无明显变形。
- [x] 两条滑块使用同一生成式菱形素材，拖动与百分比更新保持有效。
- [x] 三类 PNG 四角透明、无色键残边，并使用最近邻采样。
- [x] 1344×896 实机渲染中设置界面与系统菜单保持同一古风像素语言。

## Documentation impact

- `docs/design/art-direction.md`：将设置滑轨、滑块和返回按钮确定为生成式透明 PNG。
- `docs/qa/playtest.md`：新增生图设置控件渲染与交互验收。
- Decisions/ADRs: none

## Implementation notes

- Likely files/modules: `assets/ui/system_menu/settings_return_button.png`, `assets/ui/system_menu/volume_slider_track.png`, `assets/ui/system_menu/volume_slider_knob.png`, `scripts/exploration_hud.gd`, `tests/test_exploration_hud.gd`。
- Constraints and risks: 生图先使用纯洋红色键背景，抠图后需缩放到固定像素画布并检查 Alpha 与居中。

## Verification evidence

- Automated: Godot 4.7.1 导入通过；`tests/test_exploration_hud.gd` 通过，验证三类生成素材可加载、Alpha 四角透明、节点映射、最近邻采样、无返回提示文字以及双滑杆交互。
- Manual/in-engine: 1344×896 OpenGL 兼容模式渲染通过，`.godot/settings_screen_preview.png` 确认返回箭头、金边墨槽和菱形滑块风格统一且无裁切。
- Image processing: 内置 ImageGen 以三组独立提示生成纯洋红色键背景；使用技能自带 `remove_chroma_key.py` 抠图并归一为 196×196、632×64、24×24。三张最终图四角 Alpha 均为 0，检测到的残留洋红像素均为 0。

## Final reconciliation

- Files changed: 三张 `assets/ui/system_menu/` 设置控件 PNG 及导入描述、`scripts/exploration_hud.gd`、`tests/test_exploration_hud.gd`、`docs/design/art-direction.md`、`docs/qa/playtest.md`、本变更记录。
- Documented limitations/follow-ups: 滑轨仅承载轨道外观，实际数值、拖动和百分比仍由 Godot `HSlider` 负责。
