extends SceneTree

func _init() -> void:
	var scene: PackedScene = load("res://scenes/naval/NavalDemo.tscn")
	if scene == null:
		push_error("FAIL: NavalDemo.tscn missing")
		quit(1)
		return
	var demo: Node = scene.instantiate()
	root.add_child(demo)
	# 延迟一帧让 _ready 执行
	await process_frame
	# Vulkan 实机下布阵镜头使用 Tween 聚焦；等待其完成再检查初始镜头，headless 仍保持即时断言。
	if DisplayServer.get_name() != "headless":
		await create_timer(0.55).timeout
	var deploy: Node = demo.get_node_or_null("Deployment")
	if deploy == null:
		push_error("FAIL: Deployment node missing")
		quit(1)
		return
	var battleRoot: Node = demo.get_node_or_null("Battle")
	if battleRoot == null:
		push_error("FAIL: Battle node missing")
		quit(1)
		return
	var controller: Node = demo.get_node_or_null("Battle/BattleController")
	if controller == null:
		push_error("FAIL: BattleController missing")
		quit(1)
		return
	var grid: Node = demo.get_node_or_null("Battle/GridView")
	if grid == null:
		push_error("FAIL: GridView missing")
		quit(1)
		return
	# 动态海面必须使用边界连续的镜像采样，避免非无缝底图被 fract 硬拼后出现矩形分割线。
	if not grid.AnimatedSeaUsesSeamlessMirrorSampling():
		push_error("FAIL: animated sea must use seamless mirror sampling without hard fract texture wraps")
		quit(1)
		return
	if not grid.AnimatedSeaCausticsReduced():
		push_error("FAIL: animated sea caustic brightness must stay reduced")
		quit(1)
		return
	if not grid.FogMistTextureLoaded() or not grid.FogUsesLightInkStyle():
		push_error("FAIL: naval fog must load the generated light pixel ink-mist component")
		quit(1)
		return
	if not grid.EscapeCellTextureLoaded():
		push_error("FAIL: naval escape cells must load the generated pixel sailboat component")
		quit(1)
		return
	if float(grid.EscapeCellOpacityValue()) >= 0.75:
		push_error("FAIL: naval escape-cell material must remain visibly semi-transparent")
		quit(1)
		return
	if float(grid.EscapeIconOpacityValue()) < 0.9 or not grid.EscapeCellUsesThreeLayers():
		push_error("FAIL: escape cells must render sea/waves, translucent green overlay, and an independent opaque sailboat icon")
		quit(1)
		return
	# CHG-20260818：自由模式玩家舰队 = 经济舰队（默认 5 舰），敌方保持默认 4 舰。
	if deploy.PlayerShipCount() != 5 or deploy.EnemyShipCount() != 4:
		push_error("FAIL: deployment fleet not built (player=%d enemy=%d)" % [deploy.PlayerShipCount(), deploy.EnemyShipCount()])
		quit(1)
		return
	# 布阵选舰复用战斗阶段镜头聚焦：headless 下立即落到舰船几何中心。
	var camera := demo.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		push_error("FAIL: shared naval camera missing")
		quit(1)
		return
	var deploy_grid: Node = demo.get_node_or_null("Deployment/DeployGrid")
	if deploy_grid == null:
		push_error("FAIL: deployment GridView missing")
		quit(1)
		return
	var viewport_center := demo.get_viewport().get_visible_rect().get_center()
	var expected_flagship_camera := Vector2(deploy.ShipStateCenterX("p1"), deploy.ShipStateCenterY("p1"))
	var player_ship_ids: Array[String] = ["p1", "p2", "p3", "p4", "p5"]
	var initial_ship_camera_positions: Array[Vector2] = []
	for ship_id: String in player_ship_ids:
		initial_ship_camera_positions.append(Vector2(deploy.ShipStateCenterX(ship_id), deploy.ShipStateCenterY(ship_id)))
	if not is_equal_approx(camera.zoom.x, 3.0) or not initial_ship_camera_positions.any(func(pos: Vector2) -> bool: return camera.position.is_equal_approx(pos)):
		push_error("FAIL: deployment must start at tutorial zoom centered on a player ship when no flagship is assigned (zoom=%s actual=%s candidates=%s)" % [camera.zoom.x, camera.position, initial_ship_camera_positions])
		quit(1)
		return
	# 滚轮范围：最近可超过教程倍率，最远比完整适配再退一点，并始终受海面背景边界约束。
	var anchor_screen := viewport_center + Vector2(120.0, 80.0)
	var anchor_offset := anchor_screen - viewport_center
	var anchor_world_before := camera.position + anchor_offset / camera.zoom.x
	deploy_grid.ZoomCameraAt(1.0, anchor_screen)
	var anchor_world_after := camera.position + anchor_offset / camera.zoom.x
	if not anchor_world_after.is_equal_approx(anchor_world_before):
		push_error("FAIL: naval camera wheel zoom did not preserve mouse world anchor (before=%s after=%s)" % [anchor_world_before, anchor_world_after])
		quit(1)
		return
	for i in range(8):
		deploy_grid.ZoomCameraAt(1.0, viewport_center)
	if not is_equal_approx(camera.zoom.x, deploy_grid.CameraMaximumZoomValue()) or camera.zoom.x <= 3.0:
		push_error("FAIL: naval camera maximum zoom must exceed tutorial zoom: %s" % camera.zoom.x)
		quit(1)
		return
	for i in range(32):
		deploy_grid.ZoomCameraAt(-1.0, viewport_center)
	if not is_equal_approx(camera.zoom.x, deploy_grid.CameraMinimumZoomValue()) \
			or camera.zoom.x >= deploy_grid.CameraFitZoomValue() or not deploy_grid.CameraViewInsideBackground():
		push_error("FAIL: naval camera overview zoom/bounds wrong (zoom=%s min=%s fit=%s inside=%s)" % [camera.zoom.x, deploy_grid.CameraMinimumZoomValue(), deploy_grid.CameraFitZoomValue(), deploy_grid.CameraViewInsideBackground()])
		quit(1)
		return
	var camera_before := camera.position
	var focus_ship_id := ""
	for ship_id: String in player_ship_ids:
		var ship_center := Vector2(deploy.ShipStateCenterX(ship_id), deploy.ShipStateCenterY(ship_id))
		if not camera_before.is_equal_approx(ship_center):
			focus_ship_id = ship_id
			break
	var select_err: String = deploy.SelectShipForDeploy(focus_ship_id)
	if select_err != "":
		push_error("FAIL: deployment select ship error: %s" % select_err)
		quit(1)
		return
	if DisplayServer.get_name() != "headless":
		await create_timer(0.45).timeout
	var expected_camera := Vector2(deploy.ShipStateCenterX(focus_ship_id), deploy.ShipStateCenterY(focus_ship_id))
	if camera.position.is_equal_approx(camera_before) or not camera.position.is_equal_approx(expected_camera):
		push_error("FAIL: deployment camera did not focus selected ship (before=%s actual=%s expected=%s)" % [camera_before, camera.position, expected_camera])
		quit(1)
		return
	# 三个卷轴小标题统一为白字、纯黑粗描边；按钮样式不在本次改动范围。
	var deployment_titles: Array[String] = [
		"Deployment/DeployHud/Panel/Box/Columns/ShipCommands/Title",
		"Deployment/DeployHud/Panel/Box/Columns/FleetCommands/Title",
		"Deployment/DeployHud/Panel/Box/Columns/BattleCommand/Title",
	]
	for title_path: String in deployment_titles:
		var title := demo.get_node_or_null(title_path) as Label
		if title == null or title.get_theme_color("font_color") != Color.WHITE \
				or title.get_theme_color("font_outline_color") != Color.BLACK \
				or title.get_theme_constant("outline_size") != 8:
			push_error("FAIL: deployment title style wrong: %s" % title_path)
			quit(1)
			return
	# 逃跑格必须每图存在且按大地图扩展为 6 格；把旗舰放到左出口两步内，验证鼠标点帆船格可直接逃跑。
	if deploy.ExitCellCount() != 6 or not deploy.IsExitCell(0, 16) or not deploy.IsExitCell(0, 17) or not deploy.IsExitCell(0, 18) \
			or not deploy.IsExitCell(47, 16) or not deploy.IsExitCell(47, 17) or not deploy.IsExitCell(47, 18):
		push_error("FAIL: large free map must expose three safe escape cells on each side")
		quit(1)
		return
	if not deploy.RandomMapsAlwaysHaveSafeExits(36):
		push_error("FAIL: every sampled random map must keep deep-water escape cells even when the legacy IncludeExits flag is false")
		quit(1)
		return
	if not deploy.OneSidedExitMapRebalancesAcrossBothEdges():
		push_error("FAIL: legacy maps with exits only on one side must be rebalanced across both edges")
		quit(1)
		return
	# CHG-20260818：经济舰队下 p1 为护卫舰（不再默认旗舰）。逃跑/砲击验证先放到指定格位；
	# 指挥舰改为运行时查询（自动指挥舰 = 占格最多的旗舰型，此处为 p2），避免硬编码舰 id。
	var escape_setup_error: String = deploy.PlaceShip("p1", 3, 17, "east")
	if escape_setup_error != "":
		push_error("FAIL: could not place flagship near escape cells: %s" % escape_setup_error)
		quit(1)
		return
	# CHG-20260819（F-3）：布阵区缩为 12×10 后 p4 放 (12,17)：船头 (12,17) 到敌方 e2 舰格 (17,17) 平方距离 25 = 砲击射程上限（供 T13 砲击命中验证）。
	var bombard_setup_error: String = deploy.PlaceShip("p4", 12, 17, "east")
	if bombard_setup_error != "":
		push_error("FAIL: could not place frigate for bombardment test: %s" % bombard_setup_error)
		quit(1)
		return
	var player_flagship: String = deploy.PlayerFlagship()
	if player_flagship == "":
		push_error("FAIL: no auto flagship assigned for economy fleet")
		quit(1)
		return
	expected_flagship_camera = Vector2(deploy.ShipStateCenterX(player_flagship), deploy.ShipStateCenterY(player_flagship))
	# 控制器能经布阵确认构建种子战斗
	var err: String = deploy.ConfirmDeployment()
	if err != "":
		push_error("FAIL: confirm deployment error: %s" % err)
		quit(1)
		return
	if controller.CurrentFaction() != 0 or controller.Round() != 1:
		push_error("FAIL: battle not started from deployment")
		quit(1)
		return
	# 水雷使用正式透明素材；点选可见水雷复用左下舰况卡，仅显示名称、立绘与生命值。
	if not controller.MineTextureLoaded():
		push_error("FAIL: generated naval mine texture not loaded")
		quit(1)
		return
	if not controller.PlaceRevealedMineForDemo(18, 8, 100):
		push_error("FAIL: could not place revealed mine for UI smoke test")
		quit(1)
		return
	controller.OnGridClicked(controller.CellToWorld(18, 8))
	if controller.SelectedMineCell() != "18,8" or not controller.ShipStatusPanelVisible() \
			or controller.ActionPanelVisible() or not controller.MineStatusOnly():
		push_error("FAIL: clicking revealed mine must show HP-only status panel")
		quit(1)
		return
	if controller.ShipStatusPanelText() != "水雷\n生命：100/100":
		push_error("FAIL: mine status panel text wrong: %s" % controller.ShipStatusPanelText())
		quit(1)
		return
	if DisplayServer.get_name() != "headless":
		await process_frame
		var mine_ui_capture_error := root.get_texture().get_image().save_png("res://.godot/naval_mine_ui_preview.png")
		if mine_ui_capture_error != OK:
			push_error("FAIL: could not capture naval mine status preview")
			quit(1)
			return
	if not controller.OnRightClick() or controller.ShipStatusPanelVisible():
		push_error("FAIL: right click must dismiss selected mine status")
		quit(1)
		return
	if not is_equal_approx(camera.zoom.x, 3.0) or not camera.position.is_equal_approx(expected_flagship_camera):
		push_error("FAIL: battle must reset tutorial zoom and center on player flagship (zoom=%s actual=%s expected=%s)" % [camera.zoom.x, camera.position, expected_flagship_camera])
		quit(1)
		return
	# 舰船状态：生图透明纹理驱动三类动态粒子，四种状态图标统一进入左下舰况卡并提供具体 tooltip。
	if not controller.StatusAssetsLoaded() or not controller.SetShipStatusesForDemo("p4", 3, 2, 5, true):
		push_error("FAIL: generated ship status assets missing or preview state setup failed")
		quit(1)
		return
	controller.OnShipClicked("p4")
	if not controller.ShipStatusParticleTexturesLoaded("p4") or controller.ShipStatusParticleKinds("p4") != 3:
		push_error("FAIL: burn/slow/repair particle textures must all drive the selected ship")
		quit(1)
		return
	if controller.VisibleShipStatusIconCount() != 4:
		push_error("FAIL: burn/slow/repair/self-sink icons must all appear in ship status panel")
		quit(1)
		return
	if not controller.ShipStatusTooltip("burn").contains("50 点无视护甲") \
			or not controller.ShipStatusTooltip("slow").contains("降低 1 级速度") \
			or not controller.ShipStatusTooltip("repair").contains("最大生命 2%") \
			or not controller.ShipStatusTooltip("self_sink").contains("无法移动或转向"):
		push_error("FAIL: ship status icon tooltips must explain concrete effects")
		quit(1)
		return
	if DisplayServer.get_name() != "headless":
		await create_timer(0.55).timeout
		var status_capture_error := root.get_texture().get_image().save_png("res://.godot/naval_ship_status_fx_preview.png")
		if status_capture_error != OK:
			push_error("FAIL: could not capture ship status particle preview")
			quit(1)
			return
	controller.SetShipStatusesForDemo("p4", 0, 0, 0, false)
	controller.OnRightClick()
	# 战斗顶部两行文字试调：只增大字号与描边，不依赖背景底板。
	var battle_status := demo.get_node_or_null("Battle/Hud/StatusLabel") as Label
	var battle_message := demo.get_node_or_null("Battle/Hud/MessageLabel") as Label
	if battle_status == null or battle_status.get_theme_font_size("font_size") != 26 \
			or battle_status.get_theme_constant("outline_size") != 6:
		push_error("FAIL: battle top status typography wrong")
		quit(1)
		return
	if battle_message == null or battle_message.get_theme_font_size("font_size") != 20 \
			or battle_message.get_theme_constant("outline_size") != 5:
		push_error("FAIL: battle top message typography wrong")
		quit(1)
		return
	if battle_message.size.x < 800.0:
		push_error("FAIL: battle top message label too narrow for enlarged text")
		quit(1)
		return
	var viewport_center_x := demo.get_viewport().get_visible_rect().size.x * 0.5
	var status_center_x := battle_status.position.x + battle_status.size.x * 0.5
	var message_center_x := battle_message.position.x + battle_message.size.x * 0.5
	if not is_equal_approx(status_center_x, viewport_center_x) or not is_equal_approx(message_center_x, viewport_center_x):
		push_error("FAIL: battle top labels not centered (viewport=%s status=%s message=%s)" % [viewport_center_x, status_center_x, message_center_x])
		quit(1)
		return
	# 选船第二行只保留决策信息，不重复船名；玩家主动退选后清空该行。
	controller.OnShipClicked("p1")
	var selected_message: String = controller.LastMessage()
	if not selected_message.begins_with("剩余移动 ") or selected_message.contains("选中") or selected_message.contains("旗舰"):
		push_error("FAIL: selected ship message should omit selection wording and ship name: %s" % selected_message)
		quit(1)
		return
	if not controller.OnRightClick() or controller.LastMessage() != "":
		push_error("FAIL: player deselect should clear the second battle header line")
		quit(1)
		return
	controller.OnShipClicked("p1")
	controller.OnGridClicked(controller.CellToWorld(0, 17))
	if controller.ShipHitPoints("p1") != -1:
		push_error("FAIL: clicking a footprint escape cell must route the ship to it and trigger escape")
		quit(1)
		return
	# T13/UX-7：行动面板按钮全部存在（场景接线完成）；普攻区含 箭雨/砲击/火炮/撞击/接舷
	var new_buttons: Array[String] = [
		"Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/ArrowRain",
		"Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/Bombardment",
		"Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/Cannon",
		"Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/Ram",
		"Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/Board",
		"Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/Exchange",
		"Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/Disengage",
		"Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/ChainShot",
		"Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/FireOil",
		"Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/DamageControl",
		"Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/Mine",
	]
	for path: String in new_buttons:
		if demo.get_node_or_null(path) == null:
			push_error("FAIL: action panel button missing: %s" % path)
			quit(1)
			return
	# R-3：战斗令牌细化分组——武器组 5 + 技能组 4，组头标签正确，动作 id 覆盖全部令牌。
	var weapon_label: Label = demo.get_node_or_null("Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/WeaponLabel")
	var skill_label: Label = demo.get_node_or_null("Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/SkillLabel")
	var boarding_label: Label = demo.get_node_or_null("Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/BoardingLabel")
	if weapon_label == null or skill_label == null or boarding_label == null:
		push_error("FAIL: token group header labels missing")
		quit(1)
		return
	if weapon_label.text != "武\n器" or skill_label.text != "技\n能" or boarding_label.text != "接\n舷":
		push_error("FAIL: token group header labels wrong: %s/%s/%s" % [weapon_label.text, skill_label.text, boarding_label.text])
		quit(1)
		return
	if weapon_label.visible or skill_label.visible:
		push_error("FAIL: weapon and skill group headers must stay hidden beside the command tokens")
		quit(1)
		return
	if controller.WeaponGroupTokenCount() != 5 or controller.SkillGroupTokenCount() != 4:
		push_error("FAIL: weapons/skills token groups should have 5/4 members")
		quit(1)
		return
	if controller.AttackGroupCount() != 3 or controller.AttackGroupHeader(0) != "武器" \
			or controller.AttackGroupHeader(1) != "技能" or controller.AttackGroupHeader(2) != "接舷":
		push_error("FAIL: token group headers should be 武器/技能/接舷")
		quit(1)
		return
	var expected_ids: Array[String] = [
		"arrow_rain", "ram", "cannon", "board", "bombardment",
		"damage_control", "fire_oil", "chain_shot", "mine", "board_exchange", "disengage",
	]
	for id: String in controller.AllAttackTokenActionIds():
		if not expected_ids.has(id):
			push_error("FAIL: token def covers unexpected action id: %s" % id)
			quit(1)
			return
	for id: String in expected_ids:
		if not controller.AllAttackTokenActionIds().has(id):
			push_error("FAIL: token def missing action id: %s" % id)
			quit(1)
			return
	var attack_btn: Node = demo.get_node_or_null("Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/ArrowRain")
	var fireoil_btn: Node = demo.get_node_or_null("Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/FireOil")
	if attack_btn == null or fireoil_btn == null:
		push_error("FAIL: action panel base buttons missing")
		quit(1)
		return
	# T13：行动可用性全部来自规则层查询——选中 p4（经济舰型 patrol_boat → 海战护卫舰）后按钮 disabled 与 ActionAvailable 一致
	controller.OnShipClicked("p4")
	if not controller.ActionAvailable("arrow_rain"):
		push_error("FAIL: arrow rain should be available at start")
		quit(1)
		return
	if attack_btn.disabled:
		push_error("FAIL: arrow rain button disabled but ActionAvailable true")
		quit(1)
		return
	# UX-7 武器感知：p4 经济默认装载砲击（bombardment:1）→ 砲击可用；未装载火炮 → 火炮按钮隐藏
	if not controller.ActionAvailable("bombardment"):
		push_error("FAIL: bombardment should be available for frigate")
		quit(1)
		return
	var cannon_btn: Node = demo.get_node_or_null("Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/Cannon")
	if cannon_btn != null and cannon_btn.visible:
		push_error("FAIL: cannon button visible but frigate has no cannon")
		quit(1)
		return
	# 护卫舰经济默认技能 {chain_shot}，无火油 → 规则查询不可用 → 按钮禁用（UI 不重复实现规则）
	if controller.ActionAvailable("fire_oil"):
		push_error("FAIL: fire_oil available but frigate has no fire_oil slot")
		quit(1)
		return
	if not fireoil_btn.disabled:
		push_error("FAIL: fire_oil button enabled but ActionAvailable false")
		quit(1)
		return
	# T13：事件订阅接线——砲击命中敌舰后 EventsPlayedCount 增长；规则将 attack 置为不可用，按钮随之禁用
	var events_before: int = controller.EventsPlayedCount()
	controller.OnAction("bombardment") # UX-7：点砲击展开砲击可攻击范围，再点目标格执行砲击命令
	controller.OnGridClicked(controller.CellToWorld(17, 17)) # p4（置于 (12,17)）砲击 e2 舰格 (17,17)（平方距离 25 = 上限）
	if controller.EventsPlayedCount() <= events_before:
		push_error("FAIL: no events played for ranged attack (wiring broken)")
		quit(1)
		return
	if controller.ActionAvailable("arrow_rain"):
		push_error("FAIL: arrow rain still available after attacking")
		quit(1)
		return
	if not attack_btn.disabled:
		push_error("FAIL: arrow rain button not disabled after rule cleared availability")
		quit(1)
		return
	print("PASS: naval demo scene smoke")
	quit(0)
