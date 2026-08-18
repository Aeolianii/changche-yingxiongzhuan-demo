# CHG-20260807 像素水墨对话界面

- Status: done
- Owner: Codex
- Updated: 2026-08-07

## 目标

参照用户提供的对话界面层级，将第一章和第二章现有纸张/卡片式对话框统一改为底部半透明像素水墨笔触：人物立绘紧邻对话区域，主角固定在左，NPC 固定在右，文字直接铺在墨色留白区上。

## 范围

- 生图生成完整横向水墨对话底板和独立姓名笔触组件，不使用多张程序卡片拼接视觉主体。
- 第一章、第二章共用同一套生成组件、色彩和像素密度。
- 第一章底板覆盖完整底部文字区；第二章底板额外加高并横向越出屏幕，使正文与两项剧情选项都落在厚实墨迹内。
- 继续使用现有人物立绘；主角在左、内侍/皇帝/士兵/军官/县令在右。
- 保留点击继续、选项按钮和空格推进逻辑。
- 旁白与圣旨无说话对象时只显示水墨底板和正文，不残留人物立绘或姓名。

## 非目标

- 不增加自动播放、长按跳过、语音、打字机动画或对话历史。
- 不重绘人物立绘。
- 不修改剧情内容和任务状态机。

## 验收标准

1. 对话底部使用生成式墨色笔触 PNG，四周透明，整体略微透出游戏场景。
2. 主角对白显示左侧立绘与左侧姓名笔触；NPC 对白显示右侧立绘与右侧姓名笔触。
3. 对话正文位于人物立绘之间的稳定安全区，不与立绘或继续按钮重叠。
4. 第一章和第二章使用相同的底板与姓名笔触资源。
5. 生成素材不烘焙中文、人物、按钮或游戏背景。
6. 不出现自动播放或长按跳过控件。

## 预计改动

- 新增 `assets/ui/dialogue/` 生成素材。
- 调整 `scenes/palace/palace_demo.tscn` 与 `scripts/palace_demo.gd`。
- 调整 `scenes/Scene2.tscn` 与 `scripts/Scene2.cs`。
- 更新对话 UI 运行时与视觉测试。

## 验证证据

- 内置 imagegen 生成两张洋红键控素材，经 `remove_chroma_key.py` 本地去色后得到透明 PNG；四角 Alpha 均为 0。
- `ink_dialogue_backdrop.png`：1491×354；`ink_speaker_nameplate.png`：1639×295。
- `tests/test_scene_portraits.gd`：第一章主角左侧、NPC 右侧、旁白隐藏立绘及共享资源断言通过；Vulkan 截图为 `.godot/ink_dialogue_scene1_preview.png`。
- `tests/test_scene_two_dialogue_background.gd`：第二章水墨底板、透明度、姓名笔触、人物安全边距与共享资源断言通过；Vulkan 截图为 `.godot/ink_dialogue_scene2_preview.png`。
- `tests/test_scene_two_dialogue_patrol.gd` 与 `tests/test_scene_transition.gd`：剧情推进和章节串联回归通过。
- `dotnet build NanjiangFleet.csproj --no-restore`：0 warnings / 0 errors。
- `tests/verify_merged_project.ps1`：静态资源与引用验证通过。
- 2026-08-07 布局修正：第一章底板调整为 1344×300；第二章调整为 1664×360，正文与选项整体下移约 30 像素进入墨迹中段。
- 2026-08-07 文字微调：第一章三种文字安全区右移、上移并收窄行宽；第二章正文与选项组上移 40 像素，使底部选项完整落在墨迹内。
- 2026-08-07 两幕统一：第二章底板缩至与第一章一致的 1344×300，正文统一为 24px、选项与继续文字统一为 20px，单行宽度收窄至约 630–650px。
