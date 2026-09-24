# CHG-20260924-exported-character-visibility: 修复导出后人物消失

- Status: done
- Type: fix
- Owner: Codex
- Created: 2026-09-24

## Goal and player/project outcome

Windows 发布包中的皇宫和南疆场景应显示主角、皇帝、内侍及其他人物，人物动画和对话立绘可正常加载。

## Scope

- 用确定的角色帧清单替代运行时目录扫描。
- 通过 Godot 资源加载器读取导入后的角色纹理和立绘。
- 重新导出并验证正式 exe 中人物帧可用。

## Non-goals

- 不修改人物美术、动画顺序、剧情、碰撞或存档。
- 不重新设计发布目录结构。

## Acceptance checks

- [x] 源工程中场景一和场景二的角色帧数量与现有素材一致。
- [x] 正式导出无错误，发布程序加载人物场景后角色纹理非空。
- [x] 发布 ZIP 与最新 exe 一致，完整发布目录可运行。

## Documentation impact

- Canonical documents to update before implementation: `docs/tech/architecture.md`、`docs/assets/character-assets.md`。
- Decisions/ADRs: 无。

## Implementation notes

- Likely files/modules: `scripts/character_actor.gd`、`scripts/scene_2.gd`、`scripts/character_frame_catalog.gd`、Windows 发布包。
- Constraints and risks: Godot 导出包把图片转换为可加载资源；原始 PNG 文件和文件夹枚举不等同于 `ResourceLoader` 的可用资源列表。

## Verification evidence

- Automated: 旧包在独立发布目录用 `--main-pack` 运行皇帝和场景二角色帧检查均失败；新包运行 `test_palace_emperor_sprite.gd`、`test_protagonist_sprite_visual.gd`、`test_protagonist_scene_two_frames.gd` 均退出 0。正式导出退出 0，导出日志没有 `ERROR` 或 `WARNING`；ZIP 的 190 个条目包含 exe 和 C# 程序集。
- Manual/in-engine: 新 exe 从独立发布目录无界面运行 120 帧以 0 退出；隐藏图形窗口运行 3 秒保持活动，Vulkan 初始化成功，标准错误为空。

## Final reconciliation

- Files changed: `scripts/character_actor.gd`、`scripts/scene_2.gd`、`scripts/character_frame_catalog.gd` 及其 UID、`docs/tech/architecture.md`、`docs/assets/character-assets.md`、本变更记录；新版发布目录与 ZIP 位于仓库外 `D:\厂车英雄传DEMO\发布包\`，旧版移到 `D:\厂车英雄传DEMO\发布包历史\20260923\`。
- Documented limitations/follow-ups: 发布包角色资源检查覆盖皇宫主角与皇帝、南疆主角和场景初始化时的其他人物加载；图形启动检查没有自动完成整段剧情。通过编辑器直接运行导出包的海战切换测试无法加载导出后的 C# 类，此限制属于测试启动方式，海战完整流程未在此轮重测。
