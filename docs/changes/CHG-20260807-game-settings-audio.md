# CHG-20260807-game-settings-audio: 游戏音频设置界面

- Status: done
- Type: feature
- Owner: Codex
- Created: 2026-08-07

## Goal and player/project outcome

玩家可以从系统菜单进入与现有古风像素 UI 一致的游戏设置界面，并分别调节音乐与音效音量；返回后继续停留在系统菜单层级。

## Scope

- 将系统菜单“游戏设置”条目从占位提示改为实际入口。
- 设置界面沿用系统菜单的墨绿、宣纸、旧金描边和像素边缘语言。
- 提供“音乐音量”和“音效音量”两条 0–100 滑动条及实时百分比。
- 运行时确保 `Music` 与 `SFX` 音频总线存在，滑动时立即写入对应总线音量。
- 现有海战音效播放器改用 `SFX` 总线。
- 设置界面的返回按钮只返回系统菜单，不关闭整个菜单覆盖层。

## Non-goals

- 不增加画面、分辨率、按键、语言或其他设置。
- 不持久化音量设置，不新增设置文件或存档格式。
- 不新增背景音乐资源。
- 不重新生成已经完成的系统菜单美术素材。

## Acceptance checks

- [x] 点击系统菜单“游戏设置”后隐藏系统菜单主框并显示设置界面。
- [x] 设置界面只有音乐、音效两项，视觉风格与现有系统菜单一致。
- [x] 两条滑动条均可在 0–100 范围拖动，百分比文本同步变化。
- [x] 音乐滑杆实时修改 `Music` 总线，音效滑杆实时修改 `SFX` 总线。
- [x] 点击“返回”恢复系统菜单主框，菜单覆盖层和游戏暂停状态保持不变。
- [x] 场景一和场景二均可使用同一设置界面，1344×896 下无裁切。

## Documentation impact

- `docs/design/art-direction.md`：补充设置界面的视觉与信息范围。
- `docs/design/scene-flow.md`：补充系统菜单与设置子面板之间的往返流程。
- `docs/tech/architecture.md`：补充设置子面板和音频总线约定。
- `docs/qa/playtest.md`：增加设置入口、返回与音量联动验收。
- Decisions/ADRs: none

## Implementation notes

- Likely files/modules: `default_bus_layout.tres`, `scripts/exploration_hud.gd`, `scripts/tactics/naval_combat_presentation.gd`, `tests/test_exploration_hud.gd`。
- Constraints and risks: 当前没有音乐播放器；`Music` 总线作为后续音乐接入契约，本次只验证总线音量响应。

## Verification evidence

- Automated: Godot 4.7.1 headless 导入通过；`tests/test_exploration_hud.gd` 通过，覆盖设置入口、双滑杆范围、百分比、Music/SFX 总线写入、返回层级及场景一/场景二暂停；`tests/test_system_menu_exit.gd` 通过。
- Manual/in-engine: 1344×896 OpenGL 兼容模式渲染通过，`.godot/settings_screen_preview.png` 确认主框、题签、返回纹章、双滑杆和百分比无裁切且像素风统一。

## Final reconciliation

- Files changed: `default_bus_layout.tres`, `scripts/exploration_hud.gd`, `scripts/tactics/naval_combat_presentation.gd`, `tests/test_exploration_hud.gd`, `docs/design/art-direction.md`, `docs/design/scene-flow.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`, 本变更记录。
- Documented limitations/follow-ups: 音量只在当前运行周期生效；项目仍未提供背景音乐资源。
