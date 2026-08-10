# CHG-20260810-fubo-guling-medium-map-minigames

- Status: in-progress
- Type: gameplay / map composition / generated art / audio
- Owner: Project owner
- Created: 2026-08-10

## Goal and player-visible outcome

将伏波古岭升级为约 3200×2200 的中型跟随相机地图。玩家沿连续山路依次发现守备院、古渠、校场与观景台；到达古渠或校场并确认后，进入独立全屏轻量小游戏，完成后返回同一地图现场。

## Scope

- 四张清新中式连续局部底图与 10–15 个关键独立对象。
- 6–10 个大型禁行碰撞区，替代逐件装饰碰撞。
- `FuboMinigameHost`、三渠引水与听令回鼓两个独立 `PackedScene`。
- 水渠鼠标操作；军鼓使用 `A/S/D` 与方向键，并采用三种明显不同的鼓类 WAV。
- Web 失焦暂停、三拍恢复、重复触发保护和地图状态恢复。

## Non-goals

- 不增加第三项小游戏、战斗、经济、室内或完整开放世界。
- 不为背景中的每棵树、每块石头和每件装饰建立独立节点或碰撞。
- 不创建操作系统级窗口，不从生成图片自动推导碰撞。

## Acceptance checks

- [ ] 正常 1344×896 镜头无法同时看清五个地点。
- [ ] 两项小游戏都由对应地点确认触发并能返回原地图。
- [ ] 水渠使用鼠标、军鼓使用键盘，失败只重置当前轮。
- [ ] 三种鼓声在普通扬声器和低音量下仍可明显区分。
- [ ] 大块碰撞封闭非游玩区且道路无碎碰撞卡顿。
- [ ] 至少一座房屋和一棵近景树正确表现人物前后遮挡。
- [ ] Godot MCP 截图、日志、专项测试和项目回归通过。

## Documentation impact

- `docs/design/fubo-guling-slice.md`
- `docs/design/art-direction.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `docs/assets/fubo-guling-generated-assets.md`

## Likely files

- `scripts/fubo_guling/`
- `scenes/fubo_guling/`
- `assets/fubo_guling/`
- `assets/audio/fubo_guling/`
- `tests/test_fubo_*.gd`

## Verification evidence

- Baseline: `Godot_v4.7-stable_win64.exe --headless --path C:\Users\wangk\Desktop\厂车v3 --script res://tests/test_fubo_guling.gd` exited `0` and printed `Fubo Guling skeleton verification passed.`
- Final tasks append post-change commands, screenshots and log evidence.

## Changed files

- This record and the affected canonical documents are updated before implementation.
