extends SceneTree
# CHG-20260818：舰队配置页签（勾选出战 + 小地图阵型编辑器 + 预设）→ 布阵按预设阵型闭环。
# 覆盖：勾选出战→布阵只有勾选舰；阵型保存/载入→布阵按阵型摆位；默认预设一字排开；布阵手动调整不被预设覆盖。

const PRESET_REL := "user://fleet_formation_test.json"

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var preset_path := ProjectSettings.globalize_path(PRESET_REL)
	if FileAccess.file_exists(PRESET_REL):
		DirAccess.remove_absolute(preset_path)

	# ---- 共享的 ship_screen 与布阵场景（跨阶段复用，仅换预设文件后 Rebuild） ----
	var screen_scene: PackedScene = load("res://scenes/ui/ship_screen.tscn")
	var screen: Control = screen_scene.instantiate()
	root.add_child(screen)
	screen.fleet_preset_path_override = PRESET_REL
	screen.call("show_screen")
	await process_frame
	var deploy: Node = await _make_deploy()

	# ================= 阶段一：勾选出战 → 布阵只有勾选舰 =================
	screen.call("set_ship_checked_for_test", "ship_002", false)
	screen.call("set_ship_checked_for_test", "ship_005", false)
	await process_frame
	var checked: Array = screen.call("checked_ship_ids_for_test")
	_expect(checked == ["ship_001", "ship_003", "ship_004"], "取消 2 艘后勾选应为 3 艘（实得 %s）" % [checked])
	_expect(screen.call("save_fleet_preset_for_test", "勾选三舰"), "保存「勾选三舰」应成功")
	_expect(screen.call("load_fleet_preset_for_test", "勾选三舰"), "载入「勾选三舰」应成功")
	deploy.call("UseFleetPresetsPathForTest", preset_path)
	deploy.call("RebuildBattleForTest", 7)
	await process_frame
	_expect(deploy.PlayerShipCount() == 3, "勾选 3 艘 → 布阵应只出战 3 舰，实得 %d" % deploy.PlayerShipCount())
	_expect(deploy.PlayerShipType("p1") == "frigate" and deploy.PlayerShipType("p2") == "merchant" and deploy.PlayerShipType("p3") == "frigate",
		"勾选序列应映射为 p1护卫舰/p2商船/p3护卫舰")

	# ================= 阶段二：小地图阵型保存/载入 → 布阵按阵型摆位 =================
	screen.call("show_screen")  # 重置为全勾选 + 自动摆位
	await process_frame
	_expect(screen.call("place_ship_at_for_test", "ship_001", 5, 6, "east"), "摆位 ship_001 应成功")
	_expect(screen.call("place_ship_at_for_test", "ship_002", 10, 8, "north"), "摆位 ship_002 应成功")
	_expect(screen.call("place_ship_at_for_test", "ship_003", 15, 12, "west"), "摆位 ship_003 应成功")
	_expect(screen.call("place_ship_at_for_test", "ship_004", 5, 20, "east"), "摆位 ship_004 应成功")
	_expect(screen.call("place_ship_at_for_test", "ship_005", 10, 24, "east"), "摆位 ship_005 应成功")
	_expect(screen.call("save_fleet_preset_for_test", "阵型五舰"), "保存「阵型五舰」应成功")
	_expect(screen.call("load_fleet_preset_for_test", "阵型五舰"), "载入「阵型五舰」应成功")
	var saved_formation: Array = screen.call("fleet_preset_formation_for_test", "阵型五舰")
	_expect(saved_formation.size() == 5, "预设 Formation 应为 5 格（实得 %d）" % saved_formation.size())
	deploy.call("UseFleetPresetsPathForTest", preset_path)
	deploy.call("RebuildBattleForTest", 7)
	await process_frame
	_expect(deploy.PlayerShipCount() == 5, "阵型五舰 → 布阵 5 舰")
	_expect(deploy.BowX("p1") == 5 and deploy.BowY("p1") == 6 and deploy.FacingIndex("p1") == 1, "p1 应按阵型 (5,6) 朝东")
	_expect(deploy.BowX("p2") == 10 and deploy.BowY("p2") == 8 and deploy.FacingIndex("p2") == 0, "p2 应按阵型 (10,8) 朝北")
	_expect(deploy.BowX("p3") == 15 and deploy.BowY("p3") == 12 and deploy.FacingIndex("p3") == 3, "p3 应按阵型 (15,12) 朝西")
	_expect(deploy.BowX("p4") == 5 and deploy.BowY("p4") == 20 and deploy.FacingIndex("p4") == 1, "p4 应按阵型 (5,20) 朝东")
	_expect(deploy.BowX("p5") == 10 and deploy.BowY("p5") == 24 and deploy.FacingIndex("p5") == 1, "p5 应按阵型 (10,24) 朝东")

	# ================= 阶段三：默认预设 = 全舰一字排开 =================
	screen.call("show_screen")
	await process_frame
	screen.call("_set_default_preset")  # apply_default_formation + 存「默认阵型」+ 设下次出战
	await process_frame
	_expect(screen.call("active_fleet_preset_for_test") == "默认阵型", "设默认后活动预设应为「默认阵型」")
	var row_formation: Array = screen.call("fleet_formation_for_test")
	_expect(row_formation.size() == 5, "默认一字排开应为 5 舰阵型")
	var row_y: int = (row_formation[0] as Dictionary)["Y"]
	var all_same_y := true
	var all_east := true
	for f in row_formation:
		if (f as Dictionary)["Y"] != row_y:
			all_same_y = false
		if (f as Dictionary)["Facing"] != "east":
			all_east = false
	_expect(all_same_y and all_east, "默认阵型应为单行、全朝东")
	deploy.call("UseFleetPresetsPathForTest", preset_path)
	deploy.call("RebuildBattleForTest", 7)
	await process_frame
	_expect(deploy.PlayerShipCount() == 5, "默认阵型 → 布阵 5 舰")
	_expect(deploy.BowX("p1") == 2 and deploy.BowY("p1") == 5 and deploy.FacingIndex("p1") == 1, "p1 默认 (2,5) 朝东")
	_expect(deploy.BowX("p2") == 5 and deploy.BowY("p2") == 5 and deploy.FacingIndex("p2") == 1, "p2 默认 (5,5) 朝东")
	_expect(deploy.BowX("p3") == 9 and deploy.BowY("p3") == 5 and deploy.FacingIndex("p3") == 1, "p3 默认 (9,5) 朝东")
	_expect(deploy.BowX("p4") == 11 and deploy.BowY("p4") == 5 and deploy.FacingIndex("p4") == 1, "p4 默认 (11,5) 朝东")
	_expect(deploy.BowX("p5") == 14 and deploy.BowY("p5") == 5 and deploy.FacingIndex("p5") == 1, "p5 默认 (14,5) 朝东")

	# ================= 阶段四：布阵手动调整不被预设覆盖（确认布阵不重放阵型） =================
	var move_error: String = deploy.PlaceShip("p2", 18, 20, "south")
	_expect(move_error == "", "手动移动 p2 应成功（%s）" % move_error)
	_expect(deploy.BowX("p2") == 18 and deploy.BowY("p2") == 20 and deploy.FacingIndex("p2") == 2, "手动移动应立即生效（(18,20) 朝南）")
	var confirm_error: String = deploy.ConfirmDeployment()
	_expect(confirm_error == "", "确认布阵应成功（%s）" % confirm_error)
	_expect(deploy.BowX("p2") == 18 and deploy.BowY("p2") == 20 and deploy.FacingIndex("p2") == 2, "确认布阵不应被预设阵型覆盖手动调整")
	var battle: Node = deploy.get_node_or_null("../../Battle")
	if battle != null:
		var controller: Node = battle.get_node_or_null("BattleController")
		if controller != null:
			_expect(controller.CurrentFaction() == 0 and controller.Round() == 1, "布阵→战斗应正常开始")

	# ---- 清理 ----
	deploy.queue_free()
	screen.queue_free()
	await process_frame
	if FileAccess.file_exists(PRESET_REL):
		DirAccess.remove_absolute(preset_path)
	if failures.is_empty():
		print("PASS: fleet formation (勾选出战 / 阵型摆位 / 默认一字排开 / 手动不被覆盖)")
		quit(0)
		return
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(1)


func _make_deploy() -> Node:
	var scene: PackedScene = load("res://scenes/naval/NavalDemo.tscn")
	if scene == null:
		push_error("FAIL: NavalDemo.tscn missing")
		quit(1)
		return null
	var demo: Node = scene.instantiate()
	root.add_child(demo)
	await process_frame
	var deploy: Node = demo.get_node_or_null("Deployment")
	if deploy == null:
		push_error("FAIL: Deployment node missing")
		quit(1)
		return null
	return deploy


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
