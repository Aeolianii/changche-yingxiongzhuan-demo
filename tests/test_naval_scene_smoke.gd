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
	var camera_before := camera.position
	var select_err: String = deploy.SelectShipForDeploy("p1")
	if select_err != "":
		push_error("FAIL: deployment select ship error: %s" % select_err)
		quit(1)
		return
	var expected_camera := Vector2(deploy.ShipStateCenterX("p1"), deploy.ShipStateCenterY("p1"))
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
	# 战斗顶部两行文字试调：只增大字号与描边，不依赖背景底板。
	var battle_status := demo.get_node_or_null("Battle/Hud/StatusLabel") as Label
	var battle_message := demo.get_node_or_null("Battle/Hud/MessageLabel") as Label
	if battle_status == null or battle_status.get_theme_font_size("font_size") != 24 \
			or battle_status.get_theme_constant("outline_size") != 5:
		push_error("FAIL: battle top status typography wrong")
		quit(1)
		return
	if battle_message == null or battle_message.get_theme_font_size("font_size") != 18 \
			or battle_message.get_theme_constant("outline_size") != 4:
		push_error("FAIL: battle top message typography wrong")
		quit(1)
		return
	if battle_message.size.x < 700.0:
		push_error("FAIL: battle top message label too narrow for enlarged text")
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
