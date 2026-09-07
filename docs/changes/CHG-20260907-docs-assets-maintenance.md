# CHG-20260907：过时文档与素材整理

- 状态：`done`
- 日期：2026-09-07

## 目标

把已完成的实施计划与当前规范分开存放，并清理已有正式替代版本、且运行时未再引用的旧图片，降低交付仓库的阅读和资源扫描噪声。

## 文档整理

- 将 `docs/plans/` 与 `docs/superpowers/` 移入 `docs/archive/`，保留历史但不再作为当前事实来源。
- 将阶段性 `docs/本地修改记录.md` 归档并标注截止日期。
- 新增归档说明，更新文档索引和历史记录中的路径。
- `docs/changes/` 保留为实施历史；产品、设计、技术和 QA 文档继续作为当前文档入口。

## 素材清理

- 删除已由 v2 正式替代的四张海战地形印章 v1：`archipelago`、`fjord`、`lagoon`、`river_mouth_island`。
- 删除已由沙滩版 v2 替代的两张海图地点草稿：`chuanshan_fishing_village_hd_v1.png`、`shanwan_fishing_chain_hd_v1.png`。
- 删除未被代码、场景、数据或测试引用的 `ship_placeholder.svg` 与 `terrain_placeholder.svg`。
- 同步删除上述资源的 Godot `.import` 文件；全部历史版本仍可从 Git 历史恢复。

## 保留项

- 保留运行时正在使用的 v2 素材、海图生产分块和构图灰模。
- 保留通过目录或文件名规则动态加载的角色、舰船、地形、商品与船型资源。
- 保留分别被商店、背包和船只详情界面使用的两套 `cannon_warship` 图片。
- 不纳入工作区原有的未提交图片、`.uid`、`.import` 与旧工程备份。

## 验证

- 共清理 8 个旧素材及其 8 个 `.import` 文件，工作树减少 11.19 MiB；全工程运行时代码、场景、数据、测试和工具中的被删资源引用为 0。
- Godot 4.7.1 .NET headless 项目导入和资源扫描通过，退出码 0。
- `test_naval_terrain_stamp.gd`、`test_sea_overworld_sea_monster_event.gd` 与 `test_ship_screen.gd` 均通过。
- Markdown 相对链接检查无断链，`git diff --check` 通过；提交清单不含工作区既有改动。
