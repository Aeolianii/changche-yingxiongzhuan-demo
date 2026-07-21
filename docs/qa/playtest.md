# QA and playtest

## Build smoke checks

- [x] Project opens without blocking import errors.
- [x] Main playable path starts.
- [x] Player cannot become permanently stuck on the expected path.
- [x] Completion or exit state is reachable.

## Current acceptance scenarios

| Scenario | Setup | Action | Expected | Result/build |
|---|---|---|---|---|
| 主角移动 | 进入皇宫 | 连续按方向输入 | 动画方向一致，相机平滑跟随 | passed / run 4 |
| 场景边界 | 左墙与殿外宫墙前 | 持续向阻挡物移动 | 左墙停在 x≈67；宫墙停在 y≈625 | passed / run 4 |
| 中央门洞 | 御道 x=768, y=700 | 持续向上移动 | 穿过门洞进入 y≈422 的殿内 | passed / run 4 |
| 装饰穿行 | 草木、旗帜和灯笼附近 | 检查场景物理节点 | 装饰无碰撞节点 | passed / run 4 |
| 开场旁白 | 新开游戏 | 点击继续 | 依次显示三份岭南急报 | passed / run 4 |
| 太监传召 | 关闭开场旁白 | 等待太监移动 | 太监从殿内经门洞抵达主帅附近 | passed / run 4 |
| 对话入殿 | 太监接近主帅 | 点击“对话” | 对话后太监与主帅自动进入正殿 | passed / run 4 |
| 觐见 | 主帅接近皇帝 | 点击“觐见” | 完整显示用户提供的两段正式对白 | passed / run 4 |
| 圣旨收尾 | 觐见对白结束 | 点击继续 | 显示圣旨旁白并完成场景 | passed / run 4 |
| 稳定性 | 新开游戏 | 走完整流程 | 当前运行日志无解析或运行时错误 | passed / run 4 |
| 合并项目入口 | 打开合并项目 | 按 F5 | 从皇宫场景开始，不直接进入场景二 | passed / combined run 1 |
| 自动串联 | 完成圣旨并进入场景一完成态 | 等待 2.5 秒 | 画面淡出并自动进入场景二 | passed / runtime transition test |
| 跳过等待 | 场景一完成态 | 点击“立即启程” | 立即淡出并进入场景二，不重复切换 | passed / runtime transition test |
| 场景二启动 | 从场景一完成跳转 | 等待场景二加载 | 南疆水师场景和 C# 脚本成功实例化 | passed / runtime transition test |
| 切换失败恢复 | 场景二加载返回错误 | 触发跳转 | 场景一恢复输入与按钮、显示错误提示并允许重试 | passed / static guard test |
| 内侍立绘 | 进入太监传召对白 | 查看对话框右侧 | 显示士兵 `picture.png`，名牌为“内侍” | passed / portrait runtime + render capture |
| 皇帝占位立绘 | 进入皇帝对白 | 查看对话框右侧 | 显示暗红金边“帝”字占位卡，名牌为“皇帝” | passed / portrait runtime + render capture |
| 主帅立绘 | 推进至主帅回复 | 查看对话框左侧 | 显示将军 `picture.png`，名牌为“水师主帅” | passed / portrait runtime + render capture |
| 无角色文本 | 查看旁白、圣旨和错误提示 | 推进或触发文本 | 立绘及名牌隐藏，不残留上一位说话者 | passed / portrait runtime test |
| Scene2 对话底板 | 与县令或士兵开始对话 | 查看底部对话区域 | `BackgroundBar.png` 覆盖完整底部；黑框外透出游戏背景、框内纸张不透明，且其他 UI 布局不变 | pending / alpha revision |

## 手动觐见与任务指引验收

- [x] 开场旁白显示期间主角仍可移动。
- [x] 太监在固定位置等待，玩家远离时没有“对话”按钮。
- [x] 玩家接近太监后出现“对话”，传召结束显示“奉诏入殿”。
- [x] 主角不会被自动带入殿内，必须由玩家自行通过中央门洞。
- [x] 玩家远离皇帝时没有“觐见”，接近后出现。
- [x] 完成觐见和圣旨后任务显示“领旨南下”。

## 安全活动区验收

- [x] 右侧持续移动时停在安全边界，不进入画面边缘。
- [x] 向下持续移动时停在石像上方的安全边界。
- [x] 右下角分别用左、上、左上输入测试，均可立即脱离。
- [x] 从右庭院可回到中央御道和左庭院。
- [x] 中央门洞仍可双向通行。

## 正殿安全活动区验收

- [x] 从殿内向下移动，停在屋顶墙檐之前。
- [x] 向上移动，停在顶部陈设之前。
- [x] 正殿左右边界均不会进入装饰区。
- [x] 正殿四角向中央方向移动均能脱离。
- [x] 中央门洞双向通行且“觐见”仍可触发。

## 输入、UI 与墙体优化验收

- [ ] 对话框缩小并下移，不遮挡画面中央人物。
- [ ] WASD 与方向键移动测试通过。
- [ ] 仅使用空格键可从第一份急报走到场景完成。
- [ ] 外墙、左右殿墙和御座碰撞双侧测试通过。
- [ ] 中央门洞从殿外进入与从殿内离开均可通行。

## Playtest observations

| Date/build | Player | Observation | Evidence | Follow-up |
|---|---|---|---|---|
| 2026-07-18 / run 4 | Codex | 场景一可从急报完整走到圣旨收尾 | 运行截图、状态机结果与坐标检查 | 交付用户试玩 |
| 2026-07-18 / run 10 | Codex | 任务栏、距离交互和全程自由移动通过 | 任务文本、交互可见性、角色坐标与运行日志 | 交付用户试玩 |
| 2026-07-18 / run 12 | Codex | 右下角不再形成死角，安全活动区与用户红线近似一致 | 可见碰撞截图、边界与三方向脱离坐标 | 交付用户试玩 |
| 2026-07-18 / run 16 | Codex | 正殿安全区完成，角色不再站到屋顶墙檐 | 可见碰撞截图、四边停止坐标、四角脱离与觐见检查 | 交付用户试玩 |
| 2026-07-20 / combined run 1 | Codex | 两个项目合并后，资源重新分配唯一 UID；Scene1、Scene2 和两条切换路径均无运行错误 | Godot .NET 4.7.1 headless 导入/启动日志、自动切换测试 | 交付用户试玩 |
| 2026-07-21 / portrait run 1 | Codex | Scene1 内侍、皇帝与主帅立绘按对白和左右站位切换，正式长对白没有溢出 | 1344×896 三角色渲染截图、立绘运行态测试、完整串联回归 | 等待正式皇帝立绘 |
| 2026-07-21 / Scene2 UI run 1 | Codex | Scene2 米黄色程序底板已替换为 `BackgroundBar.png`，其他对话 UI 布局未变化 | 1344×896 渲染截图、节点布局断言、完整串联回归 | 交付用户试玩 |

## Known issues

- 皇帝世界小人暂用县令素材，对话立绘暂用“帝”字卡；太监世界小人与对话立绘暂用士兵素材。
- 圣旨正文为原型占位，等待策划提供正式版本。
