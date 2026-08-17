# 人物素材索引

## 来源

源目录：`C:\Users\wangk\Desktop\游戏资源\人物\assest`

素材来自 Universal LPC Spritesheet Character Generator，原目录中的 `credits`、`metadata.json` 和 `character.json` 必须保留。

## 已发现内容

- `protagonist`：537 张 PNG，64×64 标准帧，另有 128×128 扩展攻击帧。
- `new_soldier`：504 张 PNG，64×64 标准帧，另有 128/192 扩展帧。
- `new_‌county magistrate‌`：436 张 PNG，64×64 标准帧。
- `Paper UI`：原始包含 97 张 PNG；2026-08-17 清理后，工程仅保留运行时使用的 `PNGs/Icons/GameIcons/IconCoin.png`，完整来源包可从 Git 历史恢复。

## 首版导入白名单

- 三名角色的 `standard/idle/{up,left,down,right}`。
- 三名角色的 `standard/walk/{up,left,down,right}`。
- Paper UI 中当前实际引用的金币图标；其余未接入素材不留在工作树。
- 每套角色的完整授权与元数据文件。

其余战斗和特殊动作暂不导入，避免无意义的资源扫描。

## 场景一占位对应

- `protagonist`：水师主帅。
- `emperor`：第一幕皇帝正式世界小人；四方向待机与行走各 4 帧。
- `magistrate`：县令角色资源，不再用于第一幕皇帝世界小人。
- `soldier`：太监占位；正式太监素材到位后只替换角色资源，不改剧情流程。

## 年轻水师主角正式世界素材

- 正式路径：`assets/characters/protagonist/standard/{idle,walk}/{down,left,right,up}/1.png..4.png`。
- 生成与追溯包保留在 `assets/characters/protagonist_candidate/`。
- 单帧固定为 64×64 RGBA，人物可见高度约 48–50 像素，脚底统一位于 y=61–63，不新增运行时缩放例外。
- 待机和行走均为 down、left、right、up 四方向，每方向 4 帧。
- 角色为年轻无须的中国水师将领：黑色束发、蓝灰轻甲、朱红短披肩和中式佩刀；不采用欧洲板甲、日本武士甲或老年灰须形象。
- 最终 32 帧脚底统一位于 y=63；透明动作表、原始生图、处理元数据与 QC 记录保存在候选包的 `generation/`。
- 正式目录每方向只保留 4 帧；旧 LPC 待机/行走帧由 Git 历史恢复，不在项目内额外复制备份。

## 场景一对话立绘

- `assets/characters/protagonist/picture.png`：600×600 水师主帅半身立绘。
- `assets/characters/soldier/picture.png`：600×600 士兵半身立绘，场景一暂用于内侍对白。
- 皇帝暂不使用人物图片，以暗红金边“帝”字卡作为对话占位符。
- 立绘使用透明背景、保持宽高比缩放；不得拉伸到改变人物比例。

## 皇帝世界角色素材

- 路径：`assets/characters/emperor/standard/{idle,walk}/{up,left,down,right}/1.png..4.png`。
- 每帧为 128×128 RGBA PNG，透明背景、共享脚底锚点；待机与行走分别成组。
- 素材由 `agent-sprite-forge` 的 `generate2dsprite` 流程生成和后处理，是虚构朝廷人物，不声称复原真实历史皇帝。
- 原始试产包通过确定性检查确认 32 张交付帧完整，输出边缘触碰和粘贴裁切均为零；集成时保留生成提示与比例/QC 元数据用于追溯。
- 由于源画布大于 LPC 标准帧，Godot 只在皇帝实例上使用约 `0.55` 的最近邻缩放与既有脚底偏移，不重采样源文件。
