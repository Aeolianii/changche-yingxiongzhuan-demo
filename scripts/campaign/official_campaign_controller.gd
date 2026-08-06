class_name OfficialCampaignController
extends Node2D

const StateScript = preload("res://scripts/campaign/official_campaign_state.gd")
const BattleScene = preload("res://scenes/naval_tactics.tscn")
const SAVE_PATH := "user://official_campaign_save.json"

const BG_COLOR := Color("071923")
const PANEL_COLOR := Color(0.025, 0.09, 0.13, 0.95)
const PANEL_LIGHT := Color(0.045, 0.15, 0.19, 0.96)
const TEAL := Color("39b8cf")
const GOLD := Color("f5cf6a")
const TEXT := Color("edf7f4")
const MUTED := Color("9eb8bd")
const WARNING := Color("f18c7e")
const GOOD := Color("8fe3ba")

var state = StateScript.new()
var disable_save_for_test := false
var save_path_override := ""
var camp_ui: Control
var facility_buttons: Dictionary = {}
var order_buttons: Dictionary = {}
var ship_cards: Dictionary = {}
var launch_button: Button
var order_detail_label: RichTextLabel
var report_label: Label
var rank_label: Label
var pay_label: Label
var merit_label: Label
var save_status_label: Label
var content_root: Control
var content_title_label: Label
var active_battle: Node = null
var active_facility := "command"
var reset_confirmation_pending := false


func _ready() -> void:
	_build_ui()
	if not disable_save_for_test:
		_load_campaign()
	_refresh_all()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), BG_COLOR, true)
	for band in 9:
		var y := 90.0 + float(band) * 72.0
		var color := Color(0.08, 0.31, 0.38, 0.11 if band % 2 == 0 else 0.06)
		draw_rect(Rect2(0.0, y, 1280.0, 36.0), color, true)
	for index in 12:
		var start := Vector2(float(index) * 128.0 - 60.0, 96.0 + float(index % 3) * 18.0)
		draw_arc(start, 120.0, 0.1, 2.85, 32, Color(0.22, 0.61, 0.67, 0.08), 2.0, true)


func select_order_for_test(order_id: String) -> Dictionary:
	var result_value: Dictionary = state.select_order(order_id)
	if result_value.get("ok", false):
		active_facility = "command"
		_save_campaign()
	_refresh_all()
	return result_value


func show_facility_for_test(facility_id: String) -> void:
	if facility_id not in ["command", "repair", "shipyard"]:
		return
	active_facility = facility_id
	reset_confirmation_pending = false
	_refresh_all()


func repair_ship_for_test(ship_id: String) -> Dictionary:
	var result_value: Dictionary = state.repair_ship(ship_id)
	if not result_value.get("ok", false):
		state.last_report = _action_error_text(result_value.get("reason", "invalid_ship"))
	_save_campaign()
	_refresh_all()
	return result_value


func upgrade_ship_for_test(ship_id: String, module_id: String) -> Dictionary:
	var result_value: Dictionary = state.upgrade_ship(ship_id, module_id)
	if not result_value.get("ok", false):
		state.last_report = _action_error_text(result_value.get("reason", "invalid_module"))
	_save_campaign()
	_refresh_all()
	return result_value


func launch_selected_order_for_test():
	var order: Dictionary = state.active_order()
	if order.is_empty() or active_battle != null:
		state.last_report = "请先在中军帐领取一项军令。"
		_refresh_all()
		return null
	var battle_node = BattleScene.instantiate()
	active_battle = battle_node
	add_child(battle_node)
	battle_node.campaign_battle_finished.connect(_on_campaign_battle_finished)
	var start_result: Dictionary = battle_node.start_campaign_mission(order["mission_id"], state.battle_fleet_state())
	if not start_result.get("ok", false):
		battle_node.queue_free()
		active_battle = null
		state.last_report = "官船编队状态异常，无法出航。"
		_refresh_all()
		return null
	camp_ui.visible = false
	return battle_node


func reset_campaign_for_test() -> void:
	state.reset()
	active_facility = "command"
	reset_confirmation_pending = false
	_save_campaign()
	_refresh_all()


func save_campaign_for_test() -> bool:
	return _save_campaign()


func _on_campaign_battle_finished(payload: Dictionary) -> void:
	if active_battle == null:
		return
	var settlement: Dictionary = state.resolve_battle(
		str(payload.get("result", "defeat")),
		payload.get("ships", {})
	)
	if not settlement.get("ok", false):
		state.last_report = "战果文书异常，未改变军饷和军功。"
	var finished_battle := active_battle
	active_battle = null
	finished_battle.queue_free()
	camp_ui.visible = true
	active_facility = "command"
	_save_campaign()
	_refresh_all()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "CampaignHUD"
	add_child(layer)
	camp_ui = Control.new()
	camp_ui.name = "CampUI"
	camp_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(camp_ui)

	var top_panel := _panel(Rect2(0.0, 0.0, 1280.0, 92.0), Color(0.018, 0.07, 0.10, 0.98))
	camp_ui.add_child(top_panel)
	var title := _label("岭海水师 · 榕湾水寨", 28, TEXT)
	title.position = Vector2(24.0, 12.0)
	top_panel.add_child(title)
	var subtitle := _label("护商路 · 靖海寇 · 守群岛", 15, MUTED)
	subtitle.position = Vector2(26.0, 52.0)
	top_panel.add_child(subtitle)
	rank_label = _label("", 18, GOLD)
	rank_label.position = Vector2(490.0, 17.0)
	rank_label.size = Vector2(230.0, 56.0)
	top_panel.add_child(rank_label)
	pay_label = _label("", 20, GOOD)
	pay_label.position = Vector2(735.0, 18.0)
	pay_label.size = Vector2(150.0, 30.0)
	top_panel.add_child(pay_label)
	merit_label = _label("", 18, TEAL)
	merit_label.position = Vector2(900.0, 18.0)
	merit_label.size = Vector2(170.0, 30.0)
	top_panel.add_child(merit_label)
	save_status_label = _label("", 13, MUTED)
	save_status_label.position = Vector2(1080.0, 20.0)
	save_status_label.size = Vector2(175.0, 44.0)
	save_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_panel.add_child(save_status_label)

	var left_panel := _panel(Rect2(18.0, 108.0, 210.0, 500.0), PANEL_COLOR)
	camp_ui.add_child(left_panel)
	var left_title := _label("水寨设施", 18, TEAL)
	left_title.position = Vector2(16.0, 14.0)
	left_panel.add_child(left_title)
	var facility_specs := [
		["command", "中军帐", "领取军令 / 出航"],
		["repair", "修船坞", "修复战损"],
		["shipyard", "百工造船局", "一级模块升级"],
	]
	for index in facility_specs.size():
		var spec: Array = facility_specs[index]
		var button := _button("%s\n%s" % [spec[1], spec[2]], Vector2(178.0, 72.0), 15)
		button.position = Vector2(16.0, 54.0 + float(index) * 84.0)
		button.pressed.connect(show_facility_for_test.bind(spec[0]))
		left_panel.add_child(button)
		facility_buttons[spec[0]] = button
	var career_note := _label("当前编制\n两船巡哨队\n\n晋升目标\n30 军功", 15, MUTED)
	career_note.position = Vector2(18.0, 326.0)
	career_note.size = Vector2(174.0, 96.0)
	left_panel.add_child(career_note)
	var reset_button := _button("重开官船生涯", Vector2(178.0, 42.0), 13)
	reset_button.position = Vector2(16.0, 442.0)
	reset_button.pressed.connect(_on_reset_pressed.bind(reset_button))
	left_panel.add_child(reset_button)

	var center_panel := _panel(Rect2(244.0, 108.0, 650.0, 500.0), PANEL_COLOR)
	camp_ui.add_child(center_panel)
	content_root = Control.new()
	content_root.position = Vector2(0.0, 0.0)
	content_root.size = Vector2(650.0, 500.0)
	center_panel.add_child(content_root)

	var right_panel := _panel(Rect2(910.0, 108.0, 352.0, 500.0), PANEL_COLOR)
	camp_ui.add_child(right_panel)
	var fleet_title := _label("官船名册 · 出航编队", 18, TEAL)
	fleet_title.position = Vector2(16.0, 14.0)
	right_panel.add_child(fleet_title)
	var fleet_note := _label("船型在双方阵营保持一致；官帆与圆徽用于阵营识别。", 13, MUTED)
	fleet_note.position = Vector2(16.0, 43.0)
	fleet_note.size = Vector2(320.0, 42.0)
	fleet_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_panel.add_child(fleet_note)
	for index in 2:
		var ship_id := "player_%d" % (index + 1)
		var card_panel := _panel(Rect2(14.0, 92.0 + float(index) * 190.0, 324.0, 170.0), PANEL_LIGHT)
		right_panel.add_child(card_panel)
		var card := RichTextLabel.new()
		card.name = "ShipCard_%s" % ship_id
		card.bbcode_enabled = true
		card.fit_content = false
		card.scroll_active = false
		card.position = Vector2(14.0, 10.0)
		card.size = Vector2(296.0, 150.0)
		card.add_theme_font_size_override("normal_font_size", 14)
		card.add_theme_font_size_override("bold_font_size", 16)
		card_panel.add_child(card)
		ship_cards[ship_id] = card

	var report_panel := _panel(Rect2(18.0, 620.0, 1244.0, 82.0), Color(0.018, 0.07, 0.10, 0.98))
	camp_ui.add_child(report_panel)
	var report_title := _label("军情与结算", 14, GOLD)
	report_title.position = Vector2(16.0, 10.0)
	report_panel.add_child(report_title)
	report_label = _label("", 15, TEXT)
	report_label.position = Vector2(16.0, 34.0)
	report_label.size = Vector2(1210.0, 36.0)
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_panel.add_child(report_label)


func _refresh_all() -> void:
	if camp_ui == null:
		return
	rank_label.text = "军阶  %s\n%s" % [state.rank_name(), "已获两船指挥权" if state.rank_id == "squad_leader" else "榕湾水寨见习编制"]
	pay_label.text = "军饷  %d" % state.pay
	merit_label.text = "军功  %d / 30" % mini(state.merit, 30)
	report_label.text = state.last_report
	for facility_id in facility_buttons:
		var button: Button = facility_buttons[facility_id]
		button.modulate = Color.WHITE if facility_id == active_facility else Color(0.65, 0.72, 0.73)
	for ship_id in ship_cards:
		_refresh_ship_card(ship_id)
	_render_active_facility()


func _refresh_ship_card(ship_id: String) -> void:
	var ship: Dictionary = state.ships[ship_id]
	var card: RichTextLabel = ship_cards[ship_id]
	var full_name := str(ship["name"])
	var registry_name := full_name.get_slice("·", 1) if "·" in full_name else full_name
	var warning := "整备完好"
	var warning_color := "#8fe3ba"
	if int(ship["hp"]) < int(ship["max_hp"]):
		warning = "存在战损 · 修船坞可整修"
		warning_color = "#f5cf6a"
	card.text = "[font_size=16]● %s[/font_size]\n[color=#39b8cf]%s[/color]  [color=%s]%s[/color]\n耐久  [b]%d/%d[/b]  %s\n升级  耐久%d  武备%d\n%s" % [
		registry_name, ship["class_name"], warning_color, warning,
		ship["hp"], ship["max_hp"], _bar(int(ship["hp"]), int(ship["max_hp"])),
		ship["durability_level"], ship["weapon_level"],
		"机动3格 · 扰乱射击" if ship["class_id"] == "fast" else "机动2格 · 侧舷齐射",
	]


func _render_active_facility() -> void:
	for child in content_root.get_children():
		child.queue_free()
	order_buttons.clear()
	launch_button = null
	order_detail_label = null
	match active_facility:
		"repair":
			_render_repair()
		"shipyard":
			_render_shipyard()
		_:
			_render_command()


func _render_command() -> void:
	content_title_label = _section_header("中军帐 · 领取官船军令", "公开任务目标、敌舰规模和奖赏；不显示敌人下一步行动。")
	var definitions: Dictionary = state.orders()
	var ordered_ids := ["coast_patrol", "black_tide_flagship", "beacon_defense"]
	for index in ordered_ids.size():
		var order_id: String = ordered_ids[index]
		var order: Dictionary = definitions[order_id]
		var selected_mark := "【已领取】" if state.active_order_id == order_id else ""
		var button := _button("%s%s\n%s  ·  军饷 %d  军功 %d" % [selected_mark, order["display_name"], order["enemy_summary"], order["pay"], order["merit"]], Vector2(610.0, 68.0), 14)
		button.position = Vector2(20.0, 82.0 + float(index) * 78.0)
		button.pressed.connect(select_order_for_test.bind(order_id))
		content_root.add_child(button)
		order_buttons[order_id] = button
	order_detail_label = RichTextLabel.new()
	order_detail_label.bbcode_enabled = true
	order_detail_label.fit_content = false
	order_detail_label.scroll_active = false
	order_detail_label.position = Vector2(22.0, 324.0)
	order_detail_label.size = Vector2(390.0, 118.0)
	order_detail_label.add_theme_font_size_override("normal_font_size", 14)
	content_root.add_child(order_detail_label)
	launch_button = _button("官船编队出航", Vector2(190.0, 64.0), 18)
	launch_button.position = Vector2(430.0, 356.0)
	launch_button.pressed.connect(launch_selected_order_for_test)
	content_root.add_child(launch_button)
	var active: Dictionary = state.active_order()
	launch_button.disabled = active.is_empty()
	if active.is_empty():
		order_detail_label.text = "[color=#9eb8bd]从上方选择一项军令。两艘官船将共同出航。[/color]"
	else:
		order_detail_label.text = "[b]%s[/b]\n目标：%s\n敌情：两艘海盗船（%s）\n奖赏：军饷 %d · 军功 %d" % [active["display_name"], active["objective"], active["enemy_summary"], active["pay"], active["merit"]]


func _render_repair() -> void:
	content_title_label = _section_header("修船坞 · 战损整修", "修复会补满耐久；费用为缺损耐久的一半，向上取整。")
	for index in 2:
		var ship_id := "player_%d" % (index + 1)
		var ship: Dictionary = state.ships[ship_id]
		var quote: int = state.repair_quote(ship_id)
		var box := _panel(Rect2(20.0, 92.0 + float(index) * 166.0, 610.0, 142.0), PANEL_LIGHT)
		content_root.add_child(box)
		var title := _label("%s · %s" % [ship["name"], ship["class_name"]], 17, TEXT)
		title.position = Vector2(16.0, 14.0)
		box.add_child(title)
		var detail := _label("缺损耐久  %d / %d" % [int(ship["max_hp"]) - int(ship["hp"]), int(ship["max_hp"])], 14, MUTED)
		detail.position = Vector2(16.0, 52.0)
		box.add_child(detail)
		var button_text := "无需修理" if quote == 0 else "整船修复  ·  军饷 %d" % quote
		var button := _button(button_text, Vector2(190.0, 52.0), 15)
		button.position = Vector2(400.0, 67.0)
		button.disabled = quote <= 0 or state.pay < quote
		button.pressed.connect(repair_ship_for_test.bind(ship_id))
		box.add_child(button)


func _render_shipyard() -> void:
	content_title_label = _section_header("百工造船局 · 一级官造升级", "只保留耐久与武备两条成长线；每项军饷 70，每艘船各升级一次。")
	for index in 2:
		var ship_id := "player_%d" % (index + 1)
		var ship: Dictionary = state.ships[ship_id]
		var y := 88.0 + float(index) * 180.0
		var title := _label("%s · %s" % [ship["name"], ship["class_name"]], 17, TEXT)
		title.position = Vector2(22.0, y)
		content_root.add_child(title)
		var modules := [
			["durability", "耐久 +6"],
			["weapon", "武备 +2"],
		]
		for module_index in modules.size():
			var module: Array = modules[module_index]
			var level: int = int(ship["%s_level" % module[0]])
			var text_value := "%s\n%s" % [module[1], "已完成" if level >= 1 else "军饷 70"]
			var button := _button(text_value, Vector2(140.0, 72.0), 14)
			button.position = Vector2(20.0 + float(module_index) * 153.0, y + 38.0)
			button.disabled = level >= 1 or state.pay < StateScript.UPGRADE_COST
			button.pressed.connect(upgrade_ship_for_test.bind(ship_id, module[0]))
			content_root.add_child(button)
		var weapon_note := _label("武备效果：%s" % ("扰乱射击耐久伤害 +2" if ship["class_id"] == "fast" else "侧舷炮耐久伤害 +2"), 13, MUTED)
		weapon_note.position = Vector2(22.0, y + 116.0)
		content_root.add_child(weapon_note)


func _section_header(title_text: String, subtitle_text: String) -> Label:
	var title := _label(title_text, 21, TEXT)
	title.position = Vector2(20.0, 16.0)
	content_root.add_child(title)
	var subtitle := _label(subtitle_text, 14, MUTED)
	subtitle.position = Vector2(22.0, 50.0)
	subtitle.size = Vector2(606.0, 36.0)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_root.add_child(subtitle)
	return title


func _load_campaign() -> void:
	var save_path := _effective_save_path()
	if not FileAccess.file_exists(save_path):
		save_status_label.text = "新生涯\n尚未保存"
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		state.last_report = "无法读取旧存档，已使用新的官船生涯。"
		save_status_label.text = "读取失败"
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		state.last_report = "存档内容损坏，已安全回到新的官船生涯。"
		save_status_label.text = "存档损坏"
		return
	var result_value: Dictionary = state.load_save_data(parsed)
	if result_value.get("ok", false):
		save_status_label.text = "已读取\n自动存档"
	else:
		state.last_report = "存档版本或内容不兼容，已安全回到新的官船生涯。"
		save_status_label.text = "存档不兼容"


func _save_campaign() -> bool:
	if disable_save_for_test:
		save_status_label.text = "测试模式\n不写存档"
		return true
	var save_path := _effective_save_path()
	var temp_path := save_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		save_status_label.text = "保存失败"
		return false
	file.store_string(JSON.stringify(state.to_save_data(), "\t"))
	file.flush()
	file.close()
	var temp_absolute := ProjectSettings.globalize_path(temp_path)
	var save_absolute := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_absolute)
	var rename_error := DirAccess.rename_absolute(temp_absolute, save_absolute)
	if rename_error != OK:
		save_status_label.text = "保存失败"
		return false
	save_status_label.text = "已保存\n自动存档"
	return true


func _effective_save_path() -> String:
	return save_path_override if save_path_override != "" else SAVE_PATH


func _on_reset_pressed(button: Button) -> void:
	if not reset_confirmation_pending:
		reset_confirmation_pending = true
		button.text = "再次点击确认重开"
		state.last_report = "再次点击重开按钮，将清除当前官船生涯进度。"
		_refresh_all()
		return
	reset_campaign_for_test()


func _action_error_text(reason: String) -> String:
	return {
		"invalid_ship": "未找到这艘官船。",
		"invalid_module": "该模块不能升级。",
		"insufficient_pay": "军饷不足，无法执行这项整备。",
		"already_repaired": "该船没有需要修复的战损。",
		"max_level": "该模块在本版本已完成一级升级。",
	}.get(reason, "当前无法执行这项操作。")


func _panel(rect: Rect2, color: Color) -> ColorRect:
	var panel := ColorRect.new()
	panel.color = color
	panel.position = rect.position
	panel.size = rect.size
	return panel


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text_value: String, minimum_size: Vector2, font_size: int) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = minimum_size
	button.size = minimum_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	return button


func _bar(value: int, maximum: int) -> String:
	var filled := clampi(int(round(float(value) / float(maxi(maximum, 1)) * 8.0)), 0, 8)
	return "▰".repeat(filled) + "▱".repeat(8 - filled)
