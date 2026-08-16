# 海上大地图点击移动 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为海上大地图船只增加左键点击世界坐标后的直线自动航行，并保持现有输入锁和碰撞规则。

**Architecture:** 点击目标状态归属 `SeaOverworldPlayer`，与键盘速度、`move_and_slide()` 和航行动画共用同一物理循环。场景控制器继续只通过 `controls_enabled` 管理输入锁，因此菜单、对话、商城和转场无需新增平行状态。

**Tech Stack:** Godot 4.7 .NET、GDScript、CharacterBody2D、SceneTree 自动化测试。

## Global Constraints

- 只做直线点击移动，不增加导航网格或自动绕岛。
- 现有碰撞、速度、月相、地点、事件和存档行为保持不变。
- 键盘优先于点击目标；输入锁必须清除目标。

---

### Task 1: 用测试定义海图点击移动契约

**Files:**
- Modify: `tests/test_click_to_move.gd`

**Interfaces:**
- Consumes: `SeaOverworldPlayer.controls_enabled`、`movement_bounds`、`_unhandled_input()`。
- Produces: `request_move_to(Vector2)`、`cancel_move_target()`、`has_move_target()`、`move_target()` 的运行时契约。

- [x] **Step 1: 添加海图船只测试**

实例化 `sea_overworld.tscn`，在无阻挡水面发送左键事件，断言目标坐标、抵达停止、键盘取消、输入锁清除和碰撞阻挡。

- [x] **Step 2: 运行测试确认 RED**

Run: `Godot --headless --path . --script tests/test_click_to_move.gd`

Expected: 海图船只缺少 `has_move_target` / `request_move_to` 契约而失败。

### Task 2: 实现 SeaOverworldPlayer 点击移动

**Files:**
- Modify: `scripts/sea_overworld_player.gd`

**Interfaces:**
- Consumes: 屏幕左键坐标、当前 CanvasTransform、`controls_enabled`、`movement_bounds`。
- Produces: 直线目标方向并继续复用 `move_and_slide()`、朝向、尾浪和 `sailed` 信号。

- [x] **Step 1: 添加点击目标状态与公开方法**

加入停止半径、受阻超时、目标坐标和查询/取消方法；目标坐标先限制在 `movement_bounds` 内。

- [x] **Step 2: 合并键盘与自动航行输入**

键盘输入优先取消目标；无键盘且有目标时使用 `global_position.direction_to(_move_target)`；到达或受阻时清除目标并停船。

- [x] **Step 3: 运行测试确认 GREEN**

Run: `Godot --headless --path . --script tests/test_click_to_move.gd`

Expected: 输出 `Click-to-move runtime verification passed.`。

### Task 3: 回归、运行与文档收口

**Files:**
- Modify: `docs/changes/CHG-20260816-sea-overworld-click-move.md`
- Modify: `docs/superpowers/plans/2026-08-16-sea-overworld-click-move.md`

**Interfaces:**
- Consumes: 完成后的船只移动契约。
- Produces: 可重复验证证据和用户可验收的运行场景。

- [x] **Step 1: 运行海图与关联回归**

运行 `test_click_to_move.gd`、`test_sea_overworld.gd`、`test_global_exploration_ui.gd`、静态验证和 C# 构建。

- [x] **Step 2: 指定运行海上大地图场景**

在 Godot 编辑器中运行 `res://scenes/sea_overworld/sea_overworld.tscn`，检查日志无新增错误并保持窗口开启。

- [x] **Step 3: 写回验证证据**

把测试、构建、运行状态和已知限制写入变更记录，状态改为 `done`，勾选本计划。
