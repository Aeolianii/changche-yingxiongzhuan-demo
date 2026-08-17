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
	# 布阵控制器自 ships.json 装配双方各 4 舰
	if deploy.PlayerShipCount() != 4 or deploy.EnemyShipCount() != 4:
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
	var player_ship_ids: Array[String] = ["p1", "p2", "p3", "p4"]
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
	var escape_setup_error: String = deploy.PlaceShip("p1", 3, 17, "east")
	if escape_setup_error != "":
		push_error("FAIL: could not place flagship near escape cells: %s" % escape_setup_error)
		quit(1)
		return
	expected_flagship_camera = Vector2(deploy.ShipStateCenterX("p1"), deploy.ShipStateCenterY("p1"))
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
	if not is_equal_approx(camera.zoom.x, 3.0) or not camera.position.is_equal_approx(expected_flagship_camera):
		push_error("FAIL: battle must reset tutorial zoom and center on player flagship (zoom=%s actual=%s expected=%s)" % [camera.zoom.x, camera.position, expected_flagship_camera])
		quit(1)
		return
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
	# T13：行动可用性全部来自规则层查询——选中 p2（护卫舰）后按钮 disabled 与 ActionAvailable 一致
	controller.OnShipClicked("p2")
	if not controller.ActionAvailable("arrow_rain"):
		push_error("FAIL: arrow rain should be available at start")
		quit(1)
		return
	if attack_btn.disabled:
		push_error("FAIL: arrow rain button disabled but ActionAvailable true")
		quit(1)
		return
	# UX-7 武器感知：p2 装载砲击 → 砲击可用；未装载火炮 → 火炮按钮隐藏
	if not controller.ActionAvailable("bombardment"):
		push_error("FAIL: bombardment should be available for frigate")
		quit(1)
		return
	var cannon_btn: Node = demo.get_node_or_null("Battle/Hud/ActionPanel/Box/CommandStrip/AttackCommands/Cannon")
	if cannon_btn != null and cannon_btn.visible:
		push_error("FAIL: cannon button visible but frigate has no cannon")
		quit(1)
		return
	# 护卫舰播种布局为 {chain_shot, damage_control}，无火油 → 规则查询不可用 → 按钮禁用（UI 不重复实现规则）
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
	controller.OnGridClicked(controller.CellToWorld(26, 13)) # p2 砲击 e2 舰格 (26,13)（最近格距 5 = 上限）
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
