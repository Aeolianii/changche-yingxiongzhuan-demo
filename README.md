# 厂车英雄传 Demo：序章至南疆

这是一个 Godot 4.7.1 .NET 连续可玩项目：

1. 从标题界面进入场景一“皇帝召见水师主帅”。
2. 场景一完成后自动淡出并进入场景二“南疆水师”。
3. 场景二完成县衙剧情后可进入已接入的“水师操演”海战模块，并在操演结束后返回场景二。

## 运行环境

- Godot 4.7.1 .NET
- .NET 9 SDK
- Windows

工程同时使用 GDScript 与 C#。必须使用 Godot .NET 版打开、构建和运行；标准版 Godot 无法编译水师操演模块。

## 下载与运行

1. 克隆仓库，或在 GitHub 点击 **Code → Download ZIP** 并完整解压。
2. 用 Godot 4.7.1 .NET 导入根目录的 `project.godot`。
3. 等待首次资源导入和 C# 构建完成。
4. 按 F5，从项目主场景开始。

场景一完成旁白出现后，会在 2.5 秒后自动进入场景二。点击“立即启程”可以跳过等待。

## 操作

- WASD 或方向键：移动。
- E、空格或回车：继续对话或交互。
- 鼠标：点击画面中的交互按钮；在水师操演中选择关卡、布阵和下达战斗指令。

## 水师操演海战

当前唯一保留的海战实现位于：

| 路径 | 内容 |
|---|---|
| `res://scenes/naval/LevelSelect.tscn` | 关卡选择与剧情返回入口 |
| `res://scenes/naval/NavalDeployment.tscn` | 舰队布阵 |
| `res://scenes/naval/NavalDemo.tscn` | 正式操演战斗 |
| `res://scripts/naval/` | C# 战斗与界面逻辑 |
| `res://data/naval/` | 关卡、船只与技能数据 |
| `res://assets/naval/` | 操演专用素材 |

推荐从主流程进入操演；调试时也可以在编辑器中打开 `LevelSelect.tscn` 并按 F6。

核心玩法规则见 `docs/design/naval-tactics-gameplay.md`，架构与剧情往返约定见 `docs/tech/architecture.md`。

## 验证

```powershell
dotnet build .\ChangcheHeroes.csproj --nologo
godot --headless --path . --script res://tests/test_naval_scene_smoke.gd
godot --headless --path . --script res://tests/test_scene_two_dialogue_patrol.gd
powershell -ExecutionPolicy Bypass -File .\tests\verify_merged_project.ps1
```

设计、架构、变更记录和手动验收项见 `docs/index.md`。
