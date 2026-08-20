# CHG-20260820 海域雾笔方向去重复

- Status: complete
- Type: visual-rendering
- Owner: Codex
- Created: 2026-08-20

## Goal and player/project outcome

打散海域探索雾中由同一张斜向雾笔反复叠加形成的平行线，使航行大地图与完整海图仍保持战斗迷雾的尺度、浓淡和孔洞层次，但不再暴露单片素材的固定笔触方向。

## Scope

- 保留战斗 26 像素格、尺寸、位置偏移、透明度、隐藏邻居和四分之一落点密度规则。
- 战斗与海域共同改为每个 2×2 表现格由确定性混合哈希选择一个雾笔候选，消除原 `seed % 4` 低两位造成的严格四格斜线周期，同时稳定维持四分之一落点密度，避免纯随机聚团和大面积空洞。
- 每个尺寸预生成原图、水平镜像、垂直镜像和双向镜像四种稳定方向变体。
- 用同一格哈希确定方向，保证重建、切场和打开海图时结果一致且不闪烁。
- 航行画面与完整海图使用相同的方向选择逻辑。

## Non-goals

- 不修改探索范围、存档、地点显隐、海面遮蔽层、战斗雾素材或战斗可见性规则。
- 不引入随时间旋转、随机刷新或运行时缩放模糊。

## Acceptance checks

- [x] 同一尺寸存在四种镜像方向，雾笔不再全部沿同一斜向排列。
- [x] 战斗与海域的候选格不再每四行重复同一对角周期，每个 2×2 格稳定落一片，既无平行线也无随机大空洞。
- [x] 方向由坐标哈希稳定决定，探索遮罩重建后纹理不跳变。
- [x] 原有中小尺度、浓淡、小孔洞、未知建筑遮蔽和海图满框规则保持不变。
- [x] 专项测试与 OpenGL 海图截图通过。

## Documentation impact

- Canonical documents: `docs/design/sea-overworld-design.md`, `docs/design/art-direction.md`, `docs/tech/architecture.md`, `docs/qa/playtest.md`

## Verification evidence

- Automated: `dotnet build ChangcheHeroes.csproj --no-restore` 通过，0 警告、0 错误；`tests/test_sea_fog_of_war.gd` headless 通过，验证 24 个尺寸/方向缓存、候选密度、四行非周期、浓淡孔洞、未知建筑遮蔽与探索持久化；`tests/test_naval_scene_smoke.gd` 通过。
- Manual/in-engine: OpenGL Compatibility 1344×896 海图截图通过；未知区保持连续的中小雾团与少量孔洞，候选落点不再形成贯穿画面的斜向平行带，重开海图纹理稳定。

## Final reconciliation

- Files changed: `scripts/sea_fog_of_war.gd`, `scripts/naval/presentation/NavalGridView.cs`, `tests/test_sea_fog_of_war.gd`，以及本记录和四份规范/验收文档。
- Documented limitations/follow-ups: 海域额外使用四种镜像变体；战斗与海域共同使用 2×2 抖动候选格。素材本身仍为同一张战斗雾组件，但固定朝向和低位哈希周期均不再直接暴露。
