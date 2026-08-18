# CHG-20260809-sea-overworld-layout-graybox-v4: 中央留白与 B 区地标层级调整

- Status: done
- Type: content
- Owner: Codex
- Created: 2026-08-09

## Goal and player/project outcome

在 v3 的功能岛差异、南北海域气质和 A4/B5/C4/D3 地点分配不变的前提下，将 B 区棱角型海防堡垒向中央偏右海域迁移，缩小中央空洞，并降低右上三个大型建筑地标互相竞争的问题。

## Scope

- 保留 v1、v2、v3 历史图，新增 `sea_overworld_stage1_graybox_v4.png`。
- 只移动 B 区既有的沧门礁堡，不新增、删除、合并或重绘其他主要地点。
- 沧门礁堡从右上建筑密集区迁到中央偏右、仍属于 B 区的海面，成为北线进入中央水门前的门户。
- 右上区域以月环商港为主地标、伏波古岭长岛为次地标，小渔村和自然岛继续弱化。
- 将右上月环商港在原位置水平转向，使月牙港湾开口与主要码头朝左，视觉动势指回中央门户。
- 保留中央沉船、微型礁石、十字通航水门与 B 区宽阔主航道。

## Non-goals

- 不增加岛屿、建筑、礁石、航线或可进入地点。
- 不精修岛屿材质、建筑、植被、海浪、光影和特效。
- 不替换运行时背景，不修改场景、坐标数据、碰撞、触发、UI、事件和测试。

## Acceptance checks

- [x] v1、v2、v3 文件保持不变，v4 使用独立文件名。
- [x] 沧门礁堡已从右上建筑密集区迁到中央偏右海域，旧位置恢复为干净海水。
- [x] 中央留白明显缩小，但东西、南北方向仍保留连续可航行水面。
- [x] 右上区域形成“月环商港主地标—伏波古岭次地标”的清楚层级，不再有三个同级建筑岛竞争。
- [x] 月环商港保持原位置、体量和功能造型，但港湾开口与主要码头朝左。
- [x] A4、B5、C4、D3 的地点数量和其他岛屿位置、轮廓保持不变。
- [x] v4 已保存到项目目录并完成原始分辨率视觉检查。

## Documentation impact

- Canonical documents to update before implementation: `docs/design/sea-overworld-design.md`
- Supporting documents: `docs/assets/sea-overworld-stage1-layout.md`, `docs/assets/sea-overworld-generated-assets.md`
- Decisions/ADRs: none

## Implementation notes

- Edit target: 当时的上一版灰模
- Output: `assets/backgrounds/sea_overworld/concepts/sea_overworld_stage1_graybox_v4.png`
- Constraints and risks: 局部生图编辑可能误改其他地点或生成新岛；验收时优先检查地点数量、旧位置清除、通航留白和右上视觉层级。

## Verification evidence

- Automated: v1/v2/v3 SHA-256 与历史记录一致；v4 为 1672×941、24-bit RGB，SHA-256 为 `A92E7484DD89471BB48347350F15FFAAC13E4899B49C06ADD432BA1F471A71F2`。坐标表保持 16 行，其中 A4、B5、C4、D3；Markdown 围栏成对；`git diff --check` 无错误。
- Manual/in-engine: 已按原始分辨率检查 v4。沧门礁堡只出现一次并位于中央偏右；旧位置为连续海水；中央沉船和微型礁石保留；堡垒上下、左右均有可辨认水道；右上月环商港开口和主码头朝左，且与伏波古岭形成主次层级。概念图未接入引擎，符合非目标约束。

## Final reconciliation

- Files changed: `assets/backgrounds/sea_overworld/concepts/sea_overworld_stage1_graybox_v4.png`, `docs/design/sea-overworld-design.md`, `docs/assets/sea-overworld-stage1-layout.md`, `docs/assets/sea-overworld-generated-assets.md`, 本变更记录。
- Documented limitations/follow-ups: v4 仍是构图灰模，不作为运行时生产背景；下一阶段拆分生产分块时需按新坐标校准沧门礁堡的地点标记、碰撞与航道宽度。
