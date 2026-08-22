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

## 水师主角正式世界素材

- 正式路径仍为 `assets/characters/protagonist/standard/{idle,walk}/{down,left,right,up}/`，运行时单帧继续固定为 64×64 RGBA，人物脚底统一位于 y=63，不新增运行时缩放例外。
- 2026-08-22 起使用 `assets/8.22素材更新/主角/` 的黑金甲、朱红披风年轻主帅：面朝下待机使用 16 帧；四方向移动分别使用源目录提供的完整帧序列。由于未提供侧向/背向独立待机，停止移动后四个朝向统一复用正式面朝下待机序列。
- 256/512 像素源帧只作为交付源图；接入时按透明内容等比缩放到现有约 50 像素可见高度并统一脚底，不拉伸、不改变动作顺序。
- 海上大地图 `protagonist_chibi_4dir_v1.png` 同步取用新主角四方向首帧，保持既有四格图集和显示尺度；运行时按船体方向补偿甲板中线，向下 `x=+3px`、向左 `x=-3px`、向右 `x=+3px`、向上 `x=-9px`。

## 对话立绘

- `assets/characters/protagonist/picture.png`：水师主帅新立绘。
- `assets/characters/soldier/picture.png`：水师士兵新立绘。
- `assets/characters/attendant/picture.png`：传令太监新立绘；世界小人动画继续复用现有角色，不再与士兵共用对话立绘。
- `assets/characters/emperor/picture.png`：皇帝新立绘，替代“帝”字占位卡。
- `assets/characters/magistrate/picture.png`：广州县令新立绘。
- `assets/sea_overworld/portraits/` 保存海霸天、海盗小兵、茶商与私盐商人的新对话立绘。
- 所有对话立绘使用透明背景、保持宽高比缩放；以既有 `440×520` 人物区域为基准校准头肩和人物占比，不得拉伸、过度放大或缩得难以辨认。

## 皇帝世界角色素材

- 路径：`assets/characters/emperor/standard/{idle,walk}/{up,left,down,right}/`。
- 第一幕实际使用的 `idle/down` 自 2026-08-22 起替换为 16 帧新皇帝待机序列；256×256 源帧确定性适配为 128×128 RGBA，人物脚底和可见高度继续匹配皇帝实例约 `0.55` 的既有缩放。
- 未交付的新方向待机和行走动作继续保留旧帧；第一幕皇帝没有剧情移动，因此不混用两套动作。
