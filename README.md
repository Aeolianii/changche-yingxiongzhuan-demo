# 厂东英雄传：序章至南疆

这是由两个 Godot 4.7 原型合并而成的连续可玩项目：

1. 场景一“皇帝召见水师主帅”使用 GDScript。
2. 场景一完成后自动淡出并进入场景二“南疆水师”。
3. 场景二使用 C#，保留原有移动、NPC 对话和水师操练内容。

## 运行环境

- Godot .NET 4.7.1
- .NET SDK 9
- Windows

必须使用 Godot 的 .NET 版本打开；普通版本不能编译 `scripts/Scene2.cs`。

## 运行

1. 用 Godot .NET 4.7.1 打开根目录的 `project.godot`。
2. 等待资源导入和 C# 构建完成。
3. 按 F5，从 `res://scenes/palace/palace_demo.tscn` 开始。

场景一完成旁白出现后，会在 2.5 秒后自动进入场景二。点击“立即启程”可以跳过等待。

## 操作

- WASD 或方向键：移动。
- E、空格或回车：继续对话或交互。
- 鼠标：点击画面中的交互按钮。

## 验证

静态检查：

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\verify_merged_project.ps1
```

C# 构建：

```powershell
dotnet build .\NanjiangFleet.csproj
```

设计、架构、变更记录和手动验收项见 `docs/index.md`。
