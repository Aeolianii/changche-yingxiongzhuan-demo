# CHG-20260720-promote-new-palace-project

- Status: in-progress
- Type: project relocation and cleanup
- Owner: Codex
- Created: 2026-07-20

## 目标

将“单层皇宫原型”确立为《厂东英雄传》的唯一主工程，迁移到固定路径 `C:\Users\wangk\Documents\厂东英雄传`，删除该路径下原有的 Tiny Swords 海岛/皇城旧工程。

## 范围

- 关闭当前新版工程的 Godot 运行进程和编辑器。
- 将旧 `厂东英雄传` 目录临时移走。
- 将 `厂东英雄传-单层皇宫原型` 整体移动到 `厂东英雄传`。
- 验证 `project.godot` 和 `scenes/palace/palace_demo.tscn` 存在且入口指向新版场景。
- 验证成功后永久删除临时旧目录。

## 非目标

- 不修改或删除 `C:\Users\wangk\Documents\岭南岛屿游戏`。
- 不修改新版皇宫的玩法、素材、场景或碰撞。
- 不保留 Tiny Swords 旧工程副本。

## 验收条件

- [ ] `C:\Users\wangk\Documents\厂东英雄传` 是新版单层皇宫项目。
- [ ] 新版主场景为 `res://scenes/palace/palace_demo.tscn`。
- [ ] 原路径 `厂东英雄传-单层皇宫原型` 不再存在。
- [ ] Tiny Swords 旧工程临时目录已删除。
- [ ] `岭南岛屿游戏` 保持存在且未修改。

## 影响文档

- `docs/tech/architecture.md`
- 本变更记录

## 验证证据

- 待迁移后填写。

