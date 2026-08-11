# CHG-20260810-fubo-guling-medium-map-minigames

- Status: done
- Type: gameplay / single-background map composition / generated art / audio
- Owner: Project owner
- Created: 2026-08-10

## Goal and player-visible outcome

将伏波古岭调整为与第一幕皇宫相同的轻量地图方法：使用一张完整、精美的像素背景图承载岭南海防军镇，配合有限相机跟随和少量手工大碰撞。玩家沿连续道路依次发现守备院、古渠、校场与观景台；到达古渠或校场并确认后，进入独立全屏轻量小游戏，完成后返回同一地图现场。

本次方向修订优先解决此前四张局部底图和独立模块造成的拼贴感、比例失控与实现复杂度。地图不追求大世界尺寸，而追求一张图内构图完整、角色比例舒服、局部移动有景观变化。

## Scope

- 一张约 1536×1024、与第一幕皇宫相同 3:2 生产规格的清新中式岭南像素底图；最终以生图模型稳定输出尺寸为准，不拆分、不扩图拼接。
- 地貌以植被覆盖的低缓红土丘陵、红褐夯土路和局部红壤裸露面为主体；石材只用于登陆码头、古渠护岸、建筑基脚和极少量自然露岩。
- 地图采用明确的三级视觉层级：连续浅红褐主路与活动空地最清楚，深绿植被与较深红土坡表示禁行区，小游戏地标用少量高对比色强调。装饰不得与主路争夺注意力。
- 删除装饰性木围栏；边界优先使用草缘、红土坡沿、树丛和建筑自然形成。仅剧情锁路需要独立障碍节点，且不烘焙成连续栅栏。
- 6–9 个手工 `CollisionPolygon2D` 大碰撞，整体封闭海水、山体、密林、房屋和画面安全边界。
- 角色、守岭人、剧情障碍、交互提示和三个地点触发保留为独立节点；普通房屋、树木、道路、古渠外观、校场与观景台全部烘焙进底图。
- `FuboMinigameHost`、三渠引水与听令回鼓两个独立 `PackedScene`。
- 水渠鼠标操作；军鼓使用 `A/S/D` 与方向键，并采用三种明显不同的鼓类 WAV。
- Web 失焦暂停、三拍恢复、重复触发保护和地图状态恢复。

## Non-goals

- 不增加第三项小游戏、战斗、经济、室内或完整开放世界。
- 不制作四张局部底图、TileMap、地形图集或大批透明模块。
- 不实现人物从屋顶或树冠后方穿行；背景中的大型物体直接纳入禁行区。
- 不为背景中的每棵树、每块石头和每件装饰建立独立节点、Y 排序或碰撞。
- 不创建操作系统级窗口，不从生成图片自动推导碰撞。

## Acceptance checks

- [x] 主地图只使用一个完整背景 `Sprite2D`，没有四板拼接、接缝或地表贴片堆叠。
- [x] 1344×896 运行画面不露出底图边缘，相机只在底图安全范围内有限跟随。
- [x] 画面与第一幕皇宫的像素尺度和清晰度相容，同时明确呈现红土丘陵、灰砖黛瓦、镬耳墙、岭南植物、古渠与海防校场。
- [x] 不出现大面积灰色峭壁、石林、连续石墙或遍地碎石；建筑不采用江南园林式飞檐院落作为主体。
- [x] 从登陆处到守岭院、古渠、校场和观景台的主路始终连续，宽度与明度稳定；任一局部镜头都能判断下一段前进方向。
- [x] 画面没有成片木围栏、零散路障或横切道路的装饰；可走地面比周围禁行区更亮、更平整、纹理更少。
- [x] 两项小游戏都由对应地点确认触发并能返回原地图。
- [x] 水渠使用鼠标、军鼓使用键盘，失败只重置当前轮。
- [x] 三种鼓声使用三个独立采样，普通扬声器与低音量试听方向已由项目负责人确认。
- [x] 项目负责人标注的闭合红线作为单一分段碰撞边界，封闭全部非游玩区且道路无碎碰撞。
- [x] 玩家无法进入底图房屋、屋顶、密林和大型树冠区域；无需背景物件前后遮挡切换。
- [x] Godot MCP 截图、日志、专项测试和项目回归通过。

## Documentation impact

- `docs/design/fubo-guling-slice.md`
- `docs/design/art-direction.md`
- `docs/tech/architecture.md`
- `docs/qa/playtest.md`
- `docs/assets/fubo-guling-generated-assets.md`
- `docs/index.md`

## Likely files

- `scripts/fubo_guling/`
- `scenes/fubo_guling/`
- `assets/fubo_guling/`
- `assets/audio/fubo_guling/`
- `tests/test_fubo_*.gd`

## Verification evidence

- 2026-08-10 owner collision annotation: the owner supplied a red closed outline defining the only walkable area. The implementation must use that outline as a closed segment boundary, spawn the player on the dock, place the keeper at the house-front X, and place optional canal/drum entry prompts at their marked X positions. Existing broad blocked-region estimates are superseded by this exact boundary rule.

- Baseline: `Godot_v4.7-stable_win64.exe --headless --path C:\Users\wangk\Desktop\厂车v3 --script res://tests/test_fubo_guling.gd` exited `0` and printed `Fubo Guling skeleton verification passed.`
- Design reference: `docs/design/palace-scene.md` confirms the accepted first-act method is one approximately 1536×1024 background, manually authored broad collisions, limited camera follow, and Y-sort only between characters.
- 2026-08-10 direction review: canonical documents and runtime now use the approved single-background Lingnan composition.
- 2026-08-10 image review: the first two single-background drafts were rejected because exposed grey cliffs, stone walls and loose rocks dominated the terrain, while the compound read as a generic Jiangnan courtyard. The replacement prompt now requires low lateritic hills, red-brown earth, sparse functional stonework and plainer Lingnan garrison buildings.
- 2026-08-10 terrain revision preview: built-in ImageGen produced `C:\Users\wangk\.codex\generated_images\019fea9a-7a02-79e2-918a-8999d20fe048\exec-014e17ca-015a-4c6f-92ac-e6a2306b99fb.png`. The draft replaces grey cliffs and continuous stonework with red-soil low hills, plant-covered banks, timber boundaries and sparse functional masonry. It remains outside the project and awaits owner visual approval.
- 2026-08-10 map-readability review: the red-soil direction was accepted as close, but decorative timber fencing and low-contrast route edges were rejected. Official `Sea of Stars` and `Eastward` references plus the Level Design Book critical-path/landscape guidance informed the revised rule: one continuous low-noise route, decoration outside it, and landmarks revealed along the path.
- 2026-08-10 path-readability preview: built-in ImageGen produced `C:\Users\wangk\.codex\generated_images\019fea9a-7a02-79e2-918a-8999d20fe048\exec-772f7149-e9d1-49ee-aeda-1accebac8ba5.png`. Visual inspection confirms decorative fences and target boards are gone, the light terracotta route is continuous from the dock through the central clearing to the training yard/lookout, and the route center remains low-noise. The preview remains outside the project pending owner approval.
- 2026-08-10 owner selection: the user selected `C:\Users\wangk\AppData\Local\Temp\codex-clipboard-e2fe3b8a-77a6-4ff7-ba99-a7663d66a0d0.png` as the production background and cancelled the remaining style variants. It is assigned at `assets/fubo_guling/backgrounds/fubo_guling_complete.png`.
- Asset copy verification: `fubo_guling_complete.png` exists at 1536×1024, 3,442,520 bytes, SHA-256 `1BD476F6FC176F93779BE6B42B040099DF0AE839D9976840F78539A82B8407DA`. No existing project asset was overwritten.
- Documentation verification: `git diff --check` passed for all nine touched documents; a canonical-document scan found no active requirement for four background plates, `BackgroundPlates`, environment Y-sorting, or a 3200×2200 Fubo world.
- Godot MCP runtime verification: exact-scene runs at the dock and drum叉点 produced 1344×896 screenshots with no exposed background edge. Collision debug showed one closed red segment boundary matching the owner annotation. Runtime evaluation returned `phase=0`, dock spawn `(420, 820)`, and confirmed entering the canal trigger leaves `active_minigame=null` while showing the optional-entry prompt.
- Godot MCP log verification: the final scene run contained only the game-helper registration line and no runtime error.
- Automated verification: `test_fubo_guling.gd`, `test_fubo_canal_game.gd`, `test_fubo_drum_game.gd`, and `test_fubo_minigame_host.gd` all exited `0`. The Fubo test prints the expected pass message; Godot reports known shutdown leak diagnostics after completion but no test failure.

## Changed files

- Documentation: this record, `docs/index.md`, `docs/assets/fubo-guling-generated-assets.md`, and the previously updated canonical Fubo design/QA documents.
- Production asset: `assets/fubo_guling/backgrounds/fubo_guling_complete.png`.
- Runtime: `scenes/fubo_guling/fubo_guling.tscn`, `scripts/fubo_guling/fubo_guling.gd`, and `tests/test_fubo_guling.gd` now implement the approved background, 1536×1024 camera limits, dock spawn, marked interaction points, optional-entry prompts, and the owner-drawn closed walkable boundary.
