# 厂车英雄传 Demo：序章至南疆

这是由两个 Godot 4.7 原型合并而成的连续可玩项目：

1. 场景一“皇帝召见水师主帅”使用 GDScript。
2. 场景一完成后自动淡出并进入场景二“南疆水师”。
3. 场景二使用 C#，保留原有移动、NPC 对话和水师操练内容。

仓库同时收录了**南疆战棋海战**玩法模块（见下文“新增：南疆战棋海战”），作为独立可玩场景运行，不影响主线流程。

## 运行环境

- Godot .NET 4.7.1
- .NET SDK 9
- Windows

必须使用 Godot 的 .NET 版本打开；普通版本不能编译 `scripts/Scene2.cs`。

## 下载与运行

1. 克隆仓库，或在 GitHub 点击 **Code → Download ZIP** 并完整解压。
2. 用 Godot .NET 4.7.1 导入根目录的 `project.godot`。
3. 等待首次资源导入和 C# 构建完成。
4. 按 F5，从 `res://scenes/palace/palace_demo.tscn` 开始。

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

自动切换运行测试：

```powershell
godot --headless --path . --script res://tests/test_scene_transition.gd
```

设计、架构、变更记录和手动验收项见 `docs/index.md`。

---

## 新增：南疆战棋海战（Naval Tactics）

独立的方格海战战棋玩法模块，源自《岭南舰影》项目，纯 GDScript、无 3D 依赖。规则模型为纯 `RefCounted` 模拟（可 headless 验证），表现层与规则层分离。

### 三个场景

| 场景 | 内容 |
|---|---|
| `res://scenes/official_campaign.tscn` | **官船生涯**（推荐入口）：水营成长系统（军饷/军功/修船/升级）+ 内置 V2.6 战棋战斗 |
| `res://scenes/naval_tactics.tscn` | **V2.6 战棋**：独立选关的方格海战（2v2 双行动点规则，含 AI） |
| `res://scenes/naval_tactics_v3.tscn` | **V3 目标规则原型**：3v3 单船交替激活 + 机动令/战斗令 + 航标压制（内部试玩版） |

### 运行方式

战棋海战场景与主线是**并列的独立场景**，不改动主场景 `palace_demo.tscn`。运行方法：

1. 在编辑器打开 `project.godot`。
2. 双击对应 `.tscn` 场景文件，按 **F6**（运行当前场景）。
3. 或在命令行直接指定场景：

```bash
godot --path . res://scenes/official_campaign.tscn
```

### 操作

- 鼠标左键：选中船只、选择机动令 / 战斗令、点击目标格。
- `R`：战斗结算后重开本局（`naval_restart` 输入动作，已在 `project.godot` 注册）。

### 设计文档

- 核心玩法规则：`docs/design/naval-tactics-gameplay.md`
- 海水棋盘表现：`docs/design/naval-tactics-water-surface.md`

### 验证与测试

Godot headless 回归（任选其一，均要求 `VERIFY_FAILURES=0`）：

```bash
godot --headless --path . --script res://tools/verify_naval_tactics.gd
godot --headless --path . --script res://tools/verify_official_campaign.gd
godot --headless --path . --script res://tools/verify_target_tactics_v3.gd
```

> 注意：`verify_official_campaign.gd` 中的 “official campaign is startup scene” 一项断言官船生涯是**项目主场景**。在本仓库中主场景是 `palace_demo.tscn`，该单项不适用；在把 `official_campaign.tscn` 设为主场景的独立项目里它应通过。其余项目全部为通过标准。

V3 规则 Python 模拟器（需 Python 3，独立 QA 工具）：

```bash
python tools/tactics_sim/test_naval_tactics_sim.py
```

第三方素材许可见 `assets/THIRD_PARTY.md`。
