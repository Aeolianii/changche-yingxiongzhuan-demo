extends SceneTree
# CHG-20260818：舰队配置页签（勾选出战 + 小地图阵型编辑器 + 预设）→ 布阵按预设阵型闭环。
# 覆盖：勾选出战→布阵只有勾选舰；阵型保存/载入→布阵按阵型摆位；默认预设一字排开；布阵手动调整不被预设覆盖。

const PRESET_REL := "user://fleet_formation_test.json"
const SCREENSHOT_PATH := "res://.godot/fleet_config_preview.png"

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

	# ================= 阶段零（CHG-20260819 F-3）：缩小布阵区 + 舰船贴图 + 右键悬停提示 =================
	# 布阵区缩小到 12×10（正常战斗可配置范围），与海战自由模式 PlayerZone 同源：预设阵型可落入战斗布阵区。
	var formation_zone: Rect2i = screen.call("formation_zone_for_test")
	_expect(formation_zone == Rect2i(1, 12, 12, 10), "小地图布阵区应为 12×10（实得 %s）" % [formation_zone])
	_expect(int(screen.call("formation_zone_cell_size_for_test")) == 26, "小地图单格像素应为 26")
	# CHG-20260820：面板不压页签/不越背景框；放大棋盘；三个操作按钮在右侧竖排；预设列表改为竖向滚动。
	var fleet_panel := screen.get_node("FleetConfigPage") as Panel
	var fleet_tab := screen.get_node("FleetConfigTab") as Button
	fleet_tab.pressed.emit()
	await process_frame
	var minimap := fleet_panel.get_node("FormationMinimap") as Control
	var rotate := fleet_panel.get_node("FormationRotate") as Button
	var deselect := fleet_panel.get_node("FormationDeselect") as Button
	var default_row := fleet_panel.get_node("FormationDefaultRow") as Button
	var operation_hint := fleet_panel.get_node("FleetCheckHint") as Label
	var preset_scroll := fleet_panel.get_node("PresetListScroll") as ScrollContainer
	_expect(fleet_panel.position.y >= fleet_tab.position.y + fleet_tab.size.y, "舰队配置面板不应压住页签按钮")
	_expect(fleet_panel.position.y + fleet_panel.size.y <= 800.0, "舰队配置面板应完整收入 UI 背景边框")
	_expect(minimap.size == Vector2(320, 268), "阵型棋盘应放大为 12×10 格（实得 %s）" % [minimap.size])
	_expect(rotate.position.x > minimap.position.x + minimap.size.x and rotate.position.y < deselect.position.y and deselect.position.y < default_row.position.y,
		"旋转/退选/一字排开应在棋盘右侧从上到下排列")
	_expect(deselect.position.y - (rotate.position.y + rotate.size.y) >= 24.0 and default_row.position.y - (deselect.position.y + deselect.size.y) >= 24.0,
		"三个阵型操作按钮之间应保留至少 24px 间距")
	_expect(operation_hint.get_theme_font_size("font_size") == 12, "操作提示字号应为 12")
	_expect(preset_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED and preset_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
		"预设列表应竖向滚动，避免文字挤在一行并向右溢出")
	var preset_scrollbar := preset_scroll.get_v_scroll_bar()
	_expect(preset_scroll.size.y >= 64.0, "预设列表可见高度应至少完整容纳两条预设")
	_expect(preset_scrollbar.custom_minimum_size.x >= 18.0 and preset_scrollbar.mouse_filter == Control.MOUSE_FILTER_STOP,
		"预设滚动条应有足够宽的鼠标拖动命中区")
	var preview_presets := ["南海远征旗舰编队预设", "近海护航编队", "远洋火力编队"]
	for preview_preset in preview_presets:
		_expect(screen.call("save_fleet_preset_for_test", preview_preset), "布局预览用预设应保存成功：%s" % preview_preset)
	await process_frame
	await process_frame
	var preset_list := preset_scroll.get_node("PresetList") as VBoxContainer
	var preview_row := preset_list.get_child(0) as Control
	_expect(preview_row.size.x <= preset_scroll.size.x, "长名预设项不应向右越出可见范围")
	var preview_row_right := preset_list.position.x + preview_row.position.x + preview_row.size.x
	_expect(preview_row_right <= preset_scrollbar.position.x - 24.0, "载入/删除按钮与滚动条之间应保留至少 24px 安全间距")
	var second_row := preset_list.get_child(1) as Control
	_expect(second_row.position.y + second_row.size.y <= preset_scroll.size.y, "列表应完整显示前两条预设")
	_expect(preset_scrollbar.visible and preset_scrollbar.max_value > preset_scrollbar.page,
		"三条预设时应显示可拖动的纵向滚动条（visible=%s max=%s page=%s list_h=%s）" % [preset_scrollbar.visible, preset_scrollbar.max_value, preset_scrollbar.page, preset_list.size.y])
	preset_scrollbar.value = preset_scrollbar.max_value
	await process_frame
	_expect(preset_scroll.scroll_vertical > 0, "拖动预设滚动条应联动列表纵向滚动")
	preset_scrollbar.value = 0.0
	await process_frame
	if DisplayServer.get_name() != "headless":
		var screenshot_error := root.get_texture().get_image().save_png(SCREENSHOT_PATH)
		_expect(screenshot_error == OK, "舰队配置界面预览截图保存失败")
	for preview_preset in preview_presets:
		_expect(screen.call("delete_fleet_preset_for_test", preview_preset), "布局预览用预设应清理成功：%s" % preview_preset)
	var deploy: Node = await _make_deploy()
	var deploy_zone: Rect2i = deploy.PlayerZoneForTest()
	_expect(deploy_zone == formation_zone, "海战 PlayerZone 应与小地图布阵区同源（%s vs %s）" % [deploy_zone, formation_zone])
	# 经济舰队 5 舰默认阵型全部落在区内（show_screen 后全勾选 + 自动摆位）。
	var expected_types := {
		"ship_001": "patrol_boat", "ship_002": "cannon_warship", "ship_003": "escort_junk",
		"ship_004": "patrol_boat", "ship_005": "cannon_warship",
	}
	for ship_id: String in expected_types:
		_expect(str(screen.call("minimap_block_type_for_test", ship_id)) == expected_types[ship_id],
			"%s 小地图块应按经济舰型 %s（实得 %s）" % [ship_id, expected_types[ship_id], screen.call("minimap_block_type_for_test", ship_id)])
		_expect(str(screen.call("minimap_ship_texture_path_for_test", ship_id)).ends_with(".png"),
			"%s 小地图应使用具体舰船贴图（%s）" % [ship_id, screen.call("minimap_ship_texture_path_for_test", ship_id)])
	# 右键舰块 → 悬停提示 = 海战舰型名 + 编号。
	var expected_tooltips := {
		"ship_001": "护卫舰 1 号", "ship_002": "旗舰 2 号", "ship_003": "商船 3 号",
		"ship_004": "护卫舰 4 号", "ship_005": "旗舰 5 号",
	}
	for ship_id: String in expected_tooltips:
		var tip: String = screen.call("minimap_tooltip_for_test", ship_id)
		_expect(tip == expected_tooltips[ship_id], "%s 右键提示应为 %s（实得 %s）" % [ship_id, expected_tooltips[ship_id], tip])

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
	_expect(screen.call("place_ship_at_for_test", "ship_001", 2, 13, "east"), "摆位 ship_001 应成功")
	_expect(screen.call("place_ship_at_for_test", "ship_002", 4, 15, "north"), "摆位 ship_002 应成功")
	_expect(screen.call("place_ship_at_for_test", "ship_003", 9, 13, "west"), "摆位 ship_003 应成功")
	_expect(screen.call("place_ship_at_for_test", "ship_004", 2, 18, "east"), "摆位 ship_004 应成功")
	_expect(screen.call("place_ship_at_for_test", "ship_005", 6, 18, "east"), "摆位 ship_005 应成功")
	_expect(screen.call("save_fleet_preset_for_test", "阵型五舰"), "保存「阵型五舰」应成功")
	_expect(screen.call("load_fleet_preset_for_test", "阵型五舰"), "载入「阵型五舰」应成功")
	var saved_formation: Array = screen.call("fleet_preset_formation_for_test", "阵型五舰")
	_expect(saved_formation.size() == 5, "预设 Formation 应为 5 格（实得 %d）" % saved_formation.size())
	deploy.call("UseFleetPresetsPathForTest", preset_path)
	deploy.call("RebuildBattleForTest", 7)
	await process_frame
	_expect(deploy.PlayerShipCount() == 5, "阵型五舰 → 布阵 5 舰")
	_expect(deploy.BowX("p1") == 2 and deploy.BowY("p1") == 13 and deploy.FacingIndex("p1") == 1, "p1 应按阵型 (2,13) 朝东")
	_expect(deploy.BowX("p2") == 4 and deploy.BowY("p2") == 15 and deploy.FacingIndex("p2") == 0, "p2 应按阵型 (4,15) 朝北")
	_expect(deploy.BowX("p3") == 9 and deploy.BowY("p3") == 13 and deploy.FacingIndex("p3") == 3, "p3 应按阵型 (9,13) 朝西")
	_expect(deploy.BowX("p4") == 2 and deploy.BowY("p4") == 18 and deploy.FacingIndex("p4") == 1, "p4 应按阵型 (2,18) 朝东")
	_expect(deploy.BowX("p5") == 6 and deploy.BowY("p5") == 18 and deploy.FacingIndex("p5") == 1, "p5 应按阵型 (6,18) 朝东")

	# ================= 阶段三：默认预设 = 全舰一字排开（紧凑多行，全部落在 12 宽区内） =================
	screen.call("show_screen")
	await process_frame
	screen.call("_set_default_preset")  # apply_default_formation + 存「默认阵型」+ 设下次出战
	await process_frame
	_expect(screen.call("active_fleet_preset_for_test") == "默认阵型", "设默认后活动预设应为「默认阵型」")
	var row_formation: Array = screen.call("fleet_formation_for_test")
	_expect(row_formation.size() == 5, "默认一字排开应为 5 舰阵型")
	var all_east := true
	for f in row_formation:
		var x := int((f as Dictionary)["X"])
		var y := int((f as Dictionary)["Y"])
		_expect(x >= 1 and x < 13 and y >= 12 and y < 22, "默认阵型应全落在布阵区内（(%d,%d)）" % [x, y])
		if (f as Dictionary)["Facing"] != "east":
			all_east = false
	_expect(all_east, "默认阵型应全朝东")
	deploy.call("UseFleetPresetsPathForTest", preset_path)
	deploy.call("RebuildBattleForTest", 7)
	await process_frame
	_expect(deploy.PlayerShipCount() == 5, "默认阵型 → 布阵 5 舰")
	_expect(deploy.BowX("p1") == 3 and deploy.BowY("p1") == 13 and deploy.FacingIndex("p1") == 1, "p1 默认 (3,13) 朝东")
	_expect(deploy.BowX("p2") == 7 and deploy.BowY("p2") == 13 and deploy.FacingIndex("p2") == 1, "p2 默认 (7,13) 朝东")
	_expect(deploy.BowX("p3") == 12 and deploy.BowY("p3") == 13 and deploy.FacingIndex("p3") == 1, "p3 默认 (12,13) 朝东")
	_expect(deploy.BowX("p4") == 3 and deploy.BowY("p4") == 16 and deploy.FacingIndex("p4") == 1, "p4 默认 (3,16) 朝东")
	_expect(deploy.BowX("p5") == 7 and deploy.BowY("p5") == 16 and deploy.FacingIndex("p5") == 1, "p5 默认 (7,16) 朝东")

	# ================= 阶段四：布阵手动调整不被预设覆盖（确认布阵不重放阵型） =================
	# 朝南时船体向 y 减方向延伸（bow - south*i），(8,15) 使脚尾 (8,13) 仍在区下缘内。
	var move_error: String = deploy.PlaceShip("p2", 8, 15, "south")
	_expect(move_error == "", "手动移动 p2 应成功（%s）" % move_error)
	_expect(deploy.BowX("p2") == 8 and deploy.BowY("p2") == 15 and deploy.FacingIndex("p2") == 2, "手动移动应立即生效（(8,15) 朝南）")
	var confirm_error: String = deploy.ConfirmDeployment()
	_expect(confirm_error == "", "确认布阵应成功（%s）" % confirm_error)
	_expect(deploy.BowX("p2") == 8 and deploy.BowY("p2") == 15 and deploy.FacingIndex("p2") == 2, "确认布阵不应被预设阵型覆盖手动调整")
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
