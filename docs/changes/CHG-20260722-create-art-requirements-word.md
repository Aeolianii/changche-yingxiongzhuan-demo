# CHG-20260722-create-art-requirements-word: 创建美术素材需求书 Word 文档

- Status: done
- Type: docs-only
- Owner: TSOC
- Created: 2026-07-22

## Goal and player/project outcome

将混合 2.5D 路线所需的美术资产整理为一份可以交给内部成员、外包画师和 3D 美术直接执行的 Word 需求书，明确资产范围、数量、优先级、格式、验收标准和最小验证阶段边界，并使用规范中文排版降低沟通成本。

## Scope

- 新增《厂东英雄传美术素材需求书》DOCX。
- 全文使用宋体；设置明确的文档标题、一级标题、二级标题和正文字号。
- 正文使用规范首行缩进、行距和段前段后间距。
- 覆盖 V0 最小验证资产、Steam Demo 资产、3D/2D/UI/VFX 交付规范、生产顺序和验收清单。
- 使用 Word 原生样式、真实列表、固定表格宽度和页眉页脚。
- 渲染为逐页 PNG 并检查全部页面。
- 在 `docs/index.md` 中增加文档入口。

## Non-goals

- 不修改当前游戏代码、场景、资源或运行入口。
- 不覆盖 `docs/product/project-plan.md` 的现有未提交修改。
- 不在本变更中生产任何正式角色、背景、UI 或特效素材。
- 不承诺未经 M0 验证的最终模型面数、纹理预算和同屏单位数量。

## Acceptance checks

- [x] DOCX 可正常打开并完整显示中文。
- [x] 全文使用宋体，标题与正文层级字号明确一致。
- [x] 正文首行缩进 2 字符，1.5 倍行距，段落间距统一。
- [x] 表格无截断、重叠、边界拥挤或异常跨页。
- [x] 每页页眉、页脚和页码位置一致。
- [x] 美术需求覆盖技术路线、V0、Steam Demo、交付规范、生产优先级和验收标准。
- [x] 所有页面完成渲染与视觉检查。
- [x] 提交不包含 `docs/product/project-plan.md` 与 `scenes/Scene2.tscn` 的现有用户修改。

## Documentation impact

- Canonical documents to update before implementation: `docs/index.md`
- Decisions/ADRs: none；本文件展开既有项目计划书中的美术需求，不改变运行时架构决策。

## Implementation notes

- Likely files/modules: `docs/assets/厂东英雄传-美术素材需求书.docx`、`docs/index.md`
- Constraints and risks: 宋体必须同时设置中文、ASCII、HAnsi 和 EastAsia 字体映射；LibreOffice 渲染可能替换字体，需要逐页检查。

## Verification evidence

- Automated: DOCX 可由 Microsoft Word 16 打开并重新分页为 15 页；`heading_audit.py` 识别 15 个一级标题和 28 个二级标题；`table_geometry.py` 确认 14 个表格的总宽、缩进、网格和单元格宽度一致；`a11y_audit.py` 返回 0 条高、中、低级问题；`style_lint.py` 确认正文字符字体为 SimSun。
- Manual/in-engine: 使用 Microsoft Print to PDF 与 Poppler 以 150 DPI 渲染全部 15 页，并逐页检查封面、标题、正文缩进、表格跨页、页眉页脚、页码及末页；未发现遮挡、溢出、裁切、乱码或异常大块留白。文档任务不涉及 Godot 运行时验证。

## Final reconciliation

- Files changed: `docs/assets/厂东英雄传-美术素材需求书.docx`、`docs/index.md`、`docs/changes/CHG-20260722-create-art-requirements-word.md`
- Documented limitations/follow-ups: 正交镜头角度与尺寸、角色标准高度与脚点、卡通材质参数、骨骼挂点、模型与纹理预算、背景分层模板和 UI 设计系统仍须在 M0 评审后锁定；M0 完成后应按性能、视觉和盲测结果修订本文档。
