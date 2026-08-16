class_name ShipScreen
extends Control

const CATALOG := preload("res://scripts/economy/item_catalog.gd")
const ECONOMY := preload("res://scripts/economy/economy_state.gd")
const QUEST_BACKGROUND := preload("res://assets/ui/quest_screen/quest_screen_background.png")
const FUNCTION_BUTTON_FRAME := preload("res://assets/ui/exploration_hud/function_button.png")
const RETURN_ICON := preload("res://assets/ui/icons/menu_return_title.png")
const SCROLLBAR_SHEET := preload("res://assets/ui/ship_screen/ship_scrollbar_sheet_v1.png")
const DETAIL_BUTTON_FRAME := preload("res://assets/ui/ship_screen/ship_detail_button_frame_v1.png")
const SHIP_ICONS := {
	"patrol_boat": preload("res://assets/ui/merchant_shop/ships/patrol_boat.png"),
	"cannon_warship": preload("res://assets/ui/merchant_shop/ships/cannon_warship.png"),
	"escort_junk": preload("res://assets/ui/merchant_shop/ships/escort_junk.png"),
}

const GOLD := Color(0.73, 0.59, 0.32, 1.0)
const GOLD_BRIGHT := Color(0.96, 0.78, 0.28, 1.0)
const JADE := Color(0.28, 0.58, 0.52, 1.0)
const TEXT_LIGHT := Color(0.94, 0.91, 0.80, 1.0)
const TEXT_MUTED := Color(0.69, 0.70, 0.63, 1.0)
const PANEL_INK := Color(0.025, 0.045, 0.04, 0.78)

var _ships: Array[Dictionary] = []
var _selected_index := 0
var _ship_buttons: Array[Button] = []
var _ship_list: VBoxContainer
var _fleet_count: Label
var _preview: TextureRect
var _detail_name: RichTextLabel
var _detail_role: Label
var _detail_id: Label
var _description: RichTextLabel
var _durability: ProgressBar
var _durability_label: Label
var _stats: GridContainer
var _upgrade_title: Label
var _upgrade_grid: GridContainer
var _upgrade_controls: Dictionary = {}
var _upgrade_status: Label
var _crew_label: Label
var _construction_label: Label
var _hull_nodes: Array[CanvasItem] = []
var _hull_tab: Button
var _equipment_tab: Button
var _repair_button: Button
var _repair_status: Label
var _equipment_page: Panel
var _equipment_name: Label
var _equipment_summary: Label
var _equipment_status: Label
var _equipment_controls: Dictionary = {}
var _weapon_definitions: Array[Dictionary] = []
var _skill_definitions: Array[Dictionary] = []
var _detail_mode := "hull"

signal close_requested


func _ready() -> void:
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background()
	_build_headers()
	_build_return_button()
	_build_ship_list()
	_build_ship_detail()
	hide()


func show_screen() -> void:
	_load_ships()
	_selected_index = clampi(_selected_index, 0, maxi(0, _ships.size() - 1))
	_rebuild_ship_list()
	_refresh_detail()
	show()


func selected_ship_id_for_test() -> String:
	if _ships.is_empty():
		return ""
	return str(_ships[_selected_index].get("id", ""))


func ship_ids_for_test() -> Array[String]:
	var ids: Array[String] = []
	for ship in _ships:
		ids.append(str(ship.get("id", "")))
	return ids


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_requested.emit()


func _load_ships() -> void:
	var state := ECONOMY.make_default()
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		state = game_state.call("get_economy_state") as Dictionary
	_ships.clear()
	var raw_ships = state.get("ships", [])
	if raw_ships is Array:
		for ship_value in raw_ships:
			if ship_value is Dictionary:
				var ship := (ship_value as Dictionary).duplicate(true)
				if not CATALOG.ship(str(ship.get("type_id", ""))).is_empty():
					_ships.append(ship)


func _build_background() -> void:
	var background := TextureRect.new()
	background.name = "GeneratedShipBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = QUEST_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)


func _build_headers() -> void:
	var title := _make_label("船只", 36, TEXT_LIGHT)
	title.name = "ScreenTitle"
	title.position = Vector2(180, 58)
	title.size = Vector2(300, 58)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var list_title := _make_label("舰队名册", 24, TEXT_LIGHT)
	list_title.name = "ShipListTitle"
	list_title.position = Vector2(148, 174)
	list_title.size = Vector2(240, 46)
	list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(list_title)

	var detail_title := _make_label("舰船详情", 24, TEXT_LIGHT)
	detail_title.name = "ShipDetailHeader"
	detail_title.position = Vector2(740, 174)
	detail_title.size = Vector2(330, 46)
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(detail_title)


func _build_return_button() -> void:
	var slot := Control.new()
	slot.name = "ShipReturnSlot"
	slot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	slot.offset_left = -126.0
	slot.offset_top = 12.0
	slot.offset_right = -16.0
	slot.offset_bottom = 122.0
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)

	var frame := TextureRect.new()
	frame.name = "GeneratedReturnFrame"
	frame.position = Vector2(8, -2)
	frame.size = Vector2(94, 94)
	frame.texture = FUNCTION_BUTTON_FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(frame)

	var icon := TextureRect.new()
	icon.name = "ReturnIcon"
	icon.position = Vector2(28, 18)
	icon.size = Vector2(54, 54)
	icon.texture = RETURN_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var label := _make_label("返回", 17, TEXT_LIGHT)
	label.name = "ReturnLabel"
	label.position = Vector2(5, 84)
	label.size = Vector2(100, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_child(label)

	var button := Button.new()
	button.name = "ShipReturnButton"
	button.position = Vector2(5, 0)
	button.size = Vector2(100, 108)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "返回游戏"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _flat_style(Color(0.82, 0.65, 0.28, 0.16), Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override("pressed", _flat_style(Color(0.92, 0.72, 0.30, 0.24), Color.TRANSPARENT, 0))
	button.pressed.connect(close_requested.emit)
	slot.add_child(button)


func _build_ship_list() -> void:
	_fleet_count = _make_label("当前舰队  0 艘", 16, TEXT_MUTED)
	_fleet_count.name = "FleetCount"
	_fleet_count.position = Vector2(92, 236)
	_fleet_count.size = Vector2(350, 30)
	_fleet_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_fleet_count)

	var scroll := ScrollContainer.new()
	scroll.name = "ShipListScroll"
	scroll.position = Vector2(78, 274)
	scroll.size = Vector2(388, 506)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.clip_contents = true
	add_child(scroll)
	_style_ship_scrollbar(scroll.get_v_scroll_bar())

	var list_inset := MarginContainer.new()
	list_inset.name = "ShipListInset"
	list_inset.custom_minimum_size = Vector2(356, 0)
	list_inset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	list_inset.add_theme_constant_override("margin_left", 6)
	list_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(list_inset)

	_ship_list = VBoxContainer.new()
	_ship_list.name = "ShipList"
	_ship_list.custom_minimum_size = Vector2(350, 0)
	_ship_list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_ship_list.add_theme_constant_override("separation", 10)
	_ship_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_inset.add_child(_ship_list)


func _rebuild_ship_list() -> void:
	for child in _ship_list.get_children():
		_ship_list.remove_child(child)
		child.queue_free()
	_ship_buttons.clear()
	_fleet_count.text = "当前舰队  %d 艘" % _ships.size()

	if _ships.is_empty():
		var empty := _make_label("当前没有可用舰船", 18, TEXT_MUTED)
		empty.custom_minimum_size = Vector2(350, 100)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_ship_list.add_child(empty)
		return

	for index in range(_ships.size()):
		var ship := _ships[index]
		var definition := CATALOG.ship(str(ship.get("type_id", "")))
		var selector := Button.new()
		selector.name = "ShipChoice%d" % index
		selector.custom_minimum_size = Vector2(350, 126)
		selector.flat = false
		selector.focus_mode = Control.FOCUS_NONE
		selector.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		selector.tooltip_text = str(definition.get("name", "舰船"))
		selector.pressed.connect(_select_ship.bind(index))
		_ship_list.add_child(selector)
		_ship_buttons.append(selector)

		var preview := TextureRect.new()
		preview.name = "ShipIcon"
		preview.position = Vector2(12, 13)
		preview.size = Vector2(100, 100)
		preview.texture = SHIP_ICONS.get(str(ship.get("type_id", ""))) as Texture2D
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selector.add_child(preview)

		var name_label := _make_label(str(definition.get("name", "未知舰船")), 21, TEXT_LIGHT)
		name_label.name = "ShipName"
		name_label.position = Vector2(120, 16)
		name_label.size = Vector2(218, 30)
		selector.add_child(name_label)

		var role_label := _make_label("【%s】" % str(definition.get("role", "未分类")), 15, JADE)
		role_label.name = "ShipRole"
		role_label.position = Vector2(120, 48)
		role_label.size = Vector2(218, 24)
		selector.add_child(role_label)

		var summary := _make_label(
			"耐久 %d / %d  ·  舰号 %s" % [int(ship.get("current_hp", 0)), int(ship.get("max_hp", 0)), _ship_number(str(ship.get("id", "")))],
			14,
			TEXT_MUTED
		)
		summary.name = "ShipSummary"
		summary.position = Vector2(120, 80)
		summary.size = Vector2(218, 26)
		selector.add_child(summary)
	_refresh_selectors()


func _build_ship_detail() -> void:
	_build_detail_tabs()
	_preview = TextureRect.new()
	_preview.name = "SelectedShipPreview"
	_preview.position = Vector2(536, 260)
	_preview.size = Vector2(318, 236)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_preview)

	_detail_name = _make_rich_text(27)
	_detail_name.name = "SelectedShipName"
	_detail_name.position = Vector2(872, 272)
	_detail_name.size = Vector2(390, 45)
	add_child(_detail_name)

	_detail_role = _make_label("", 18, JADE)
	_detail_role.name = "SelectedShipRole"
	_detail_role.position = Vector2(872, 322)
	_detail_role.size = Vector2(390, 30)
	add_child(_detail_role)

	_detail_id = _make_label("", 15, TEXT_MUTED)
	_detail_id.name = "SelectedShipId"
	_detail_id.position = Vector2(872, 354)
	_detail_id.size = Vector2(390, 26)
	add_child(_detail_id)

	_description = _make_rich_text(17)
	_description.name = "ShipDescription"
	_description.position = Vector2(872, 392)
	_description.size = Vector2(390, 94)
	add_child(_description)

	var separator := ColorRect.new()
	separator.name = "DetailSeparator"
	separator.position = Vector2(528, 510)
	separator.size = Vector2(744, 1)
	separator.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.38)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(separator)

	var durability_title := _make_label("船体耐久", 19, GOLD_BRIGHT)
	durability_title.position = Vector2(544, 530)
	durability_title.size = Vector2(180, 30)
	add_child(durability_title)

	_durability = ProgressBar.new()
	_durability.name = "DurabilityBar"
	_durability.position = Vector2(544, 567)
	_durability.size = Vector2(718, 34)
	_durability.show_percentage = false
	_durability.add_theme_stylebox_override("background", _flat_style(Color(0.015, 0.03, 0.028, 0.88), Color(GOLD.r, GOLD.g, GOLD.b, 0.28), 1))
	_durability.add_theme_stylebox_override("fill", _flat_style(Color(0.18, 0.52, 0.42, 0.92), Color(0.45, 0.78, 0.63, 0.8), 1))
	add_child(_durability)

	_durability_label = _make_label("", 16, TEXT_LIGHT)
	_durability_label.name = "DurabilityLabel"
	_durability_label.position = _durability.position
	_durability_label.size = _durability.size
	_durability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_durability_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_durability_label)

	_stats = GridContainer.new()
	_stats.name = "ShipStats"
	_stats.columns = 4
	_stats.position = Vector2(544, 612)
	_stats.size = Vector2(718, 54)
	_stats.add_theme_constant_override("h_separation", 10)
	_stats.add_theme_constant_override("v_separation", 8)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stats)
	_build_upgrade_grid()

	_crew_label = _make_label("", 16, TEXT_LIGHT)
	_crew_label.name = "CrewLabel"
	_crew_label.position = Vector2(548, 784)
	_crew_label.size = Vector2(210, 22)
	add_child(_crew_label)

	_construction_label = _make_label("", 15, TEXT_MUTED)
	_construction_label.name = "ConstructionLabel"
	_construction_label.position = Vector2(750, 784)
	_construction_label.size = Vector2(510, 22)
	_construction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_construction_label)

	_repair_status = _make_label("", 14, JADE)
	_repair_status.name = "RepairStatus"
	_repair_status.position = Vector2(850, 235)
	_repair_status.size = Vector2(280, 34)
	_repair_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_repair_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_repair_status)

	_repair_button = _make_action_button("修复船体", Vector2(1138, 232), Vector2(122, 38), true)
	_repair_button.name = "RepairButton"
	_repair_button.pressed.connect(_repair_selected_ship)
	add_child(_repair_button)

	_hull_nodes = [
		_preview, _detail_name, _detail_role, _detail_id, _description, separator,
		durability_title, _durability, _durability_label, _stats, _upgrade_title, _upgrade_grid, _upgrade_status, _crew_label,
		_construction_label, _repair_status, _repair_button,
	]
	_build_equipment_page()
	_switch_detail_mode("hull")


func _build_detail_tabs() -> void:
	_hull_tab = _make_action_button("船体", Vector2(544, 228), Vector2(126, 40), true)
	_hull_tab.name = "HullTab"
	_add_detail_tab_bottom_border(_hull_tab)
	_hull_tab.pressed.connect(_switch_detail_mode.bind("hull"))
	add_child(_hull_tab)
	_equipment_tab = _make_action_button("装备", Vector2(680, 228), Vector2(126, 40), true)
	_equipment_tab.name = "EquipmentTab"
	_add_detail_tab_bottom_border(_equipment_tab)
	_equipment_tab.pressed.connect(_switch_detail_mode.bind("equipment"))
	add_child(_equipment_tab)


func _add_detail_tab_bottom_border(button: Button) -> void:
	var border := ColorRect.new()
	border.name = "BottomGoldBorder"
	border.color = GOLD
	border.position = Vector2(5.0, button.size.y - 4.0)
	border.size = Vector2(button.size.x - 10.0, 1.0)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(border)


func _build_upgrade_grid() -> void:
	_upgrade_title = _make_label("船体强化", 17, GOLD_BRIGHT)
	_upgrade_title.name = "UpgradeTitle"
	_upgrade_title.position = Vector2(544, 670)
	_upgrade_title.size = Vector2(180, 26)
	add_child(_upgrade_title)
	_upgrade_status = _make_label("", 13, JADE)
	_upgrade_status.name = "UpgradeStatus"
	_upgrade_status.position = Vector2(760, 670)
	_upgrade_status.size = Vector2(500, 26)
	_upgrade_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_upgrade_status)
	_upgrade_grid = GridContainer.new()
	_upgrade_grid.name = "ShipUpgradeGrid"
	_upgrade_grid.columns = 4
	_upgrade_grid.position = Vector2(544, 699)
	_upgrade_grid.size = Vector2(718, 78)
	_upgrade_grid.add_theme_constant_override("h_separation", 10)
	_upgrade_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_upgrade_grid)
	for project_data in [
		["hull", "生命值"],
		["weapon_slots", "武器槽上限"],
		["skill_slots", "技能槽上限"],
		["speed", "速度"],
	]:
		_upgrade_grid.add_child(_make_upgrade_card(str(project_data[0]), str(project_data[1])))


func _make_upgrade_card(project: String, title: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Upgrade_%s" % project
	card.custom_minimum_size = Vector2(172, 78)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _flat_style(PANEL_INK, Color(GOLD.r, GOLD.g, GOLD.b, 0.42), 1))
	var content := Control.new()
	content.name = "Content"
	content.custom_minimum_size = Vector2(172, 78)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	var title_label := _make_label(title, 14, TEXT_LIGHT)
	title_label.position = Vector2(9, 5)
	title_label.size = Vector2(122, 21)
	content.add_child(title_label)
	var value_label := _make_label("", 13, GOLD_BRIGHT)
	value_label.name = "Value"
	value_label.position = Vector2(9, 26)
	value_label.size = Vector2(122, 20)
	content.add_child(value_label)
	var cost_label := _make_label("", 11, TEXT_MUTED)
	cost_label.name = "Cost"
	cost_label.position = Vector2(9, 50)
	cost_label.size = Vector2(154, 18)
	content.add_child(cost_label)
	var plus := _make_action_button("+", Vector2(134, 9), Vector2(29, 32))
	plus.name = "Plus"
	plus.pressed.connect(_upgrade_selected_ship.bind(project))
	content.add_child(plus)
	_upgrade_controls[project] = {"value": value_label, "cost": cost_label, "plus": plus}
	return card


func _build_equipment_page() -> void:
	_load_equipment_definitions()
	_equipment_page = Panel.new()
	_equipment_page.name = "EquipmentPage"
	_equipment_page.position = Vector2(520, 276)
	_equipment_page.size = Vector2(752, 528)
	_equipment_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_equipment_page.add_theme_stylebox_override("panel", _flat_style(Color(0.018, 0.038, 0.034, 0.80), Color(GOLD.r, GOLD.g, GOLD.b, 0.42), 1))
	add_child(_equipment_page)

	_equipment_name = _make_label("舰船装备", 23, GOLD_BRIGHT)
	_equipment_name.name = "EquipmentShipName"
	_equipment_name.position = Vector2(18, 10)
	_equipment_name.size = Vector2(710, 34)
	_equipment_page.add_child(_equipment_name)

	_equipment_summary = _make_label("", 15, TEXT_MUTED)
	_equipment_summary.name = "EquipmentSlotsSummary"
	_equipment_summary.position = Vector2(18, 46)
	_equipment_summary.size = Vector2(710, 28)
	_equipment_page.add_child(_equipment_summary)

	var weapon_title := _make_label("武器配置", 18, GOLD_BRIGHT)
	weapon_title.position = Vector2(18, 80)
	weapon_title.size = Vector2(200, 28)
	_equipment_page.add_child(weapon_title)
	var weapon_grid := HBoxContainer.new()
	weapon_grid.name = "WeaponGrid"
	weapon_grid.position = Vector2(18, 112)
	weapon_grid.size = Vector2(716, 104)
	weapon_grid.add_theme_constant_override("separation", 10)
	_equipment_page.add_child(weapon_grid)
	for definition in _weapon_definitions:
		weapon_grid.add_child(_make_equipment_card("weapons", str(definition["Id"]), str(definition["DisplayName"]), "负载 %d" % int(definition.get("LoadCost", 0)), 232.0))

	var skill_title := _make_label("战术技能", 18, GOLD_BRIGHT)
	skill_title.position = Vector2(18, 226)
	skill_title.size = Vector2(200, 28)
	_equipment_page.add_child(skill_title)
	var skill_grid := HBoxContainer.new()
	skill_grid.name = "SkillGrid"
	skill_grid.position = Vector2(18, 258)
	skill_grid.size = Vector2(716, 104)
	skill_grid.add_theme_constant_override("separation", 8)
	_equipment_page.add_child(skill_grid)
	for definition in _skill_definitions:
		skill_grid.add_child(_make_equipment_card("skills", str(definition["Id"]), str(definition["DisplayName"]), "每槽 %d 次" % int(definition.get("UsesPerSlot", 0)), 173.0))

	var armor_title := _make_label("护甲整备", 18, GOLD_BRIGHT)
	armor_title.position = Vector2(18, 376)
	armor_title.size = Vector2(200, 28)
	_equipment_page.add_child(armor_title)
	var armor_row := HBoxContainer.new()
	armor_row.name = "ArmorRow"
	armor_row.position = Vector2(18, 398)
	armor_row.size = Vector2(716, 100)
	_equipment_page.add_child(armor_row)
	armor_row.add_child(_make_equipment_card("armor", "armor", "船体护甲", "每级强化减伤", 232.0, 100.0))
	var armor_hint := _make_label("沿用战前配置规则：武器与技能受槽位限制，撞角最多一件。", 14, TEXT_MUTED)
	armor_hint.custom_minimum_size = Vector2(470, 100)
	armor_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	armor_row.add_child(armor_hint)

	_equipment_status = _make_label("", 14, JADE)
	_equipment_status.name = "EquipmentStatus"
	_equipment_status.position = Vector2(18, 500)
	_equipment_status.size = Vector2(710, 22)
	_equipment_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_equipment_page.add_child(_equipment_status)


func _make_equipment_card(category: String, equipment_id: String, display_name: String, detail: String, width: float, height := 100.0) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "%s_%s" % [category.trim_suffix("s").capitalize(), equipment_id]
	card.custom_minimum_size = Vector2(width, height)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _flat_style(PANEL_INK, Color(GOLD.r, GOLD.g, GOLD.b, 0.34), 1))
	var content := Control.new()
	content.name = "Content"
	content.custom_minimum_size = Vector2(width, height)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	var title := _make_label(display_name, 16, TEXT_LIGHT)
	title.position = Vector2(12, 8)
	title.size = Vector2(width - 24.0, 24)
	content.add_child(title)
	var subtitle := _make_label(detail, 12, TEXT_MUTED)
	subtitle.position = Vector2(12, 30)
	subtitle.size = Vector2(width - 24.0, 20)
	content.add_child(subtitle)
	var minus := _make_action_button("−", Vector2(12, height - 42.0), Vector2(38, 30))
	minus.name = "Minus"
	minus.pressed.connect(_change_equipment.bind(category, equipment_id, -1))
	content.add_child(minus)
	var count := _make_label("×0", 16, GOLD_BRIGHT)
	count.name = "Count"
	count.position = Vector2(54, height - 42.0)
	count.size = Vector2(maxf(40.0, width - 108.0), 30)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(count)
	var plus := _make_action_button("+", Vector2(width - 50.0, height - 42.0), Vector2(38, 30))
	plus.name = "Plus"
	plus.pressed.connect(_change_equipment.bind(category, equipment_id, 1))
	content.add_child(plus)
	_equipment_controls["%s/%s" % [category, equipment_id]] = {"minus": minus, "count": count, "plus": plus}
	return card


func _load_equipment_definitions() -> void:
	_weapon_definitions = _read_definition_array("res://data/naval/weapons.json")
	_skill_definitions = _read_definition_array("res://data/naval/skills.json")


func _read_definition_array(path: String) -> Array[Dictionary]:
	var definitions: Array[Dictionary] = []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Array:
		for value in parsed:
			if value is Dictionary:
				definitions.append((value as Dictionary).duplicate(true))
	return definitions


func _select_ship(index: int) -> void:
	if index < 0 or index >= _ships.size():
		return
	_selected_index = index
	_repair_status.text = ""
	_upgrade_status.text = ""
	_equipment_status.text = ""
	_refresh_selectors()
	_refresh_detail()


func _switch_detail_mode(mode: String) -> void:
	_detail_mode = "equipment" if mode == "equipment" else "hull"
	for node in _hull_nodes:
		node.visible = _detail_mode == "hull"
	_equipment_page.visible = _detail_mode == "equipment"
	var hull_selected := _detail_mode == "hull"
	_hull_tab.add_theme_stylebox_override("normal", _detail_button_style(Color(1.0, 0.88, 0.55, 1.0) if hull_selected else Color(0.78, 0.80, 0.74, 1.0)))
	_equipment_tab.add_theme_stylebox_override("normal", _detail_button_style(Color(1.0, 0.88, 0.55, 1.0) if not hull_selected else Color(0.78, 0.80, 0.74, 1.0)))
	_hull_tab.add_theme_color_override("font_color", GOLD_BRIGHT if hull_selected else TEXT_MUTED)
	_equipment_tab.add_theme_color_override("font_color", GOLD_BRIGHT if not hull_selected else TEXT_MUTED)
	if _detail_mode == "equipment":
		_refresh_equipment_page()


func _repair_selected_ship() -> void:
	if _ships.is_empty():
		return
	var ship_id := str(_ships[_selected_index].get("id", ""))
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	var result := game_state.call("repair_economy_ship", ship_id) as Dictionary
	_repair_status.text = "船体修复完成" if result.get("ok", false) else "船体无需修复"
	_reload_selected_ship(ship_id)


func _upgrade_selected_ship(project: String) -> void:
	if _ships.is_empty():
		return
	var ship_id := str(_ships[_selected_index].get("id", ""))
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	var result := game_state.call("upgrade_economy_ship", ship_id, project) as Dictionary
	_upgrade_status.text = "%s强化完成" % _upgrade_name(project) if result.get("ok", false) else _upgrade_error(str(result.get("reason", "failed")))
	_reload_selected_ship(ship_id)


func _change_equipment(category: String, equipment_id: String, delta: int) -> void:
	if _ships.is_empty():
		return
	var ship_id := str(_ships[_selected_index].get("id", ""))
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	var result := game_state.call("adjust_economy_ship_equipment", ship_id, category, equipment_id, delta) as Dictionary
	_equipment_status.text = "装备配置已保存" if result.get("ok", false) else _equipment_error(str(result.get("reason", "failed")))
	_reload_selected_ship(ship_id)


func _reload_selected_ship(ship_id: String) -> void:
	_load_ships()
	for index in range(_ships.size()):
		if str(_ships[index].get("id", "")) == ship_id:
			_selected_index = index
			break
	_rebuild_ship_list()
	_refresh_detail()


func _equipment_error(reason: String) -> String:
	return {"slots_full": "装备槽位已满", "none_equipped": "当前未装载", "unknown_ship": "未找到舰船"}.get(reason, "无法调整装备")


func _upgrade_error(reason: String) -> String:
	return {"max_level": "该项目已强化至上限", "insufficient_pay": "军饷不足", "insufficient_material": "强化材料不足", "unknown_ship": "未找到舰船"}.get(reason, "无法进行强化")


func _upgrade_name(project: String) -> String:
	return {"hull": "生命值", "weapon_slots": "武器槽", "skill_slots": "技能槽", "speed": "速度"}.get(project, "船体")


func _refresh_selectors() -> void:
	for index in range(_ship_buttons.size()):
		var selected := index == _selected_index
		var button := _ship_buttons[index]
		button.add_theme_stylebox_override("normal", _selector_style(selected, false))
		button.add_theme_stylebox_override("hover", _selector_style(selected, true))
		button.add_theme_stylebox_override("pressed", _selector_style(true, true))


func _refresh_detail() -> void:
	if _ships.is_empty():
		_preview.texture = null
		_detail_name.text = "[color=#f1c24f]暂无舰船[/color]"
		_detail_role.text = ""
		_detail_id.text = ""
		_description.text = "当前舰队没有可查看的舰船。"
		_durability.value = 0
		_durability_label.text = "0 / 0"
		_clear_stats()
		_crew_label.text = ""
		_construction_label.text = ""
		_repair_button.disabled = true
		_refresh_equipment_page()
		return

	var ship := _ships[_selected_index]
	var type_id := str(ship.get("type_id", ""))
	var definition := CATALOG.ship(type_id)
	var current_hp := int(ship.get("current_hp", definition.get("max_hp", 1)))
	var max_hp := maxi(1, int(ship.get("max_hp", definition.get("max_hp", 1))))
	_preview.texture = SHIP_ICONS.get(type_id) as Texture2D
	_detail_name.text = "[color=#f1c24f]%s[/color]" % str(definition.get("name", "未知舰船"))
	_detail_role.text = "【%s】" % str(definition.get("role", "未分类"))
	_detail_id.text = "舰号  %s" % _ship_number(str(ship.get("id", "")))
	_description.text = str(definition.get("description", "暂无舰船说明。"))
	_durability.max_value = max_hp
	_durability.value = clampi(current_hp, 0, max_hp)
	_durability_label.text = "%d / %d" % [current_hp, max_hp]
	_rebuild_stats(definition, ship)
	_refresh_upgrades(ship, definition)
	_crew_label.text = "核定编制　%d 人" % int(definition.get("crew", 0))
	var economy_state := get_node("/root/GameState").call("get_economy_state") as Dictionary
	var items := economy_state.get("items", {}) as Dictionary
	var upgrade_materials := economy_state.get("ship_upgrade_materials", {}) as Dictionary
	_construction_label.text = "军饷 %d　木材 %d　铁石 %d　帆布 %d" % [int(economy_state.get("pay", 0)), int(items.get("wood", 0)), int(items.get("ironstone", 0)), int(upgrade_materials.get("canvas", 0))]
	_repair_button.disabled = current_hp >= max_hp
	_repair_button.text = "船体完好" if _repair_button.disabled else "修复船体"
	_refresh_equipment_page()


func _refresh_equipment_page() -> void:
	if _equipment_page == null:
		return
	if _ships.is_empty():
		_equipment_name.text = "暂无舰船"
		_equipment_summary.text = ""
		return
	var ship := _ships[_selected_index]
	var definition := CATALOG.ship(str(ship.get("type_id", "")))
	var equipment := ship.get("equipment", {}) as Dictionary
	var weapons := equipment.get("weapons", {}) as Dictionary
	var skills := equipment.get("skills", {}) as Dictionary
	var used_weapons := _sum_counts(weapons)
	var used_skills := _sum_counts(skills)
	var upgrades := ship.get("upgrades", {}) as Dictionary
	var weapon_cap := int(definition.get("weapon_slots", 0)) + int(upgrades.get("weapon_slots", 0))
	var skill_cap := int(definition.get("skill_slots", 0)) + int(upgrades.get("skill_slots", 0))
	var armor_level := int(equipment.get("armor_level", 0))
	var armor_cap := int(definition.get("armor_slots", 0))
	_equipment_name.text = "%s　·　装备整备" % str(definition.get("name", "未知舰船"))
	_equipment_summary.text = "武器位 %d / %d　·　技能位 %d / %d　·　护甲位 %d / %d" % [used_weapons, weapon_cap, used_skills, skill_cap, armor_level, armor_cap]
	for definition_value in _weapon_definitions:
		var equipment_id := str(definition_value["Id"])
		_refresh_equipment_control("weapons", equipment_id, int(weapons.get(equipment_id, 0)), used_weapons >= weapon_cap or (equipment_id == "ram" and int(weapons.get(equipment_id, 0)) >= 1))
	for definition_value in _skill_definitions:
		var equipment_id := str(definition_value["Id"])
		_refresh_equipment_control("skills", equipment_id, int(skills.get(equipment_id, 0)), used_skills >= skill_cap)
	_refresh_equipment_control("armor", "armor", armor_level, armor_level >= armor_cap)


func _refresh_equipment_control(category: String, equipment_id: String, count: int, at_cap: bool) -> void:
	var controls := _equipment_controls.get("%s/%s" % [category, equipment_id], {}) as Dictionary
	if controls.is_empty():
		return
	(controls["count"] as Label).text = "×%d" % count
	(controls["minus"] as Button).disabled = count <= 0
	(controls["plus"] as Button).disabled = at_cap


func _sum_counts(entries: Dictionary) -> int:
	var total := 0
	for count in entries.values():
		total += int(count)
	return total


func _refresh_upgrades(ship: Dictionary, definition: Dictionary) -> void:
	var economy_state := get_node("/root/GameState").call("get_economy_state") as Dictionary
	var items := economy_state.get("items", {}) as Dictionary
	var upgrade_materials := economy_state.get("ship_upgrade_materials", {}) as Dictionary
	var upgrades := ship.get("upgrades", {}) as Dictionary
	var values := {
		"hull": "耐久 %d" % int(ship.get("max_hp", definition.get("max_hp", 1))),
		"weapon_slots": "上限 %d" % (int(definition.get("weapon_slots", 0)) + int(upgrades.get("weapon_slots", 0))),
		"skill_slots": "上限 %d" % (int(definition.get("skill_slots", 0)) + int(upgrades.get("skill_slots", 0))),
		"speed": "航速 %d" % (int(definition.get("speed", 0)) + int(upgrades.get("speed", 0))),
	}
	var resource_names := {"wood": "木材", "ironstone": "铁石", "canvas": "帆布"}
	for project in _upgrade_controls:
		var controls := _upgrade_controls[project] as Dictionary
		var cost := ECONOMY.ship_upgrade_cost(ship, str(project))
		var at_cap := int(cost.get("level", 0)) >= int(cost.get("cap", 0))
		var resource_id := str(cost.get("resource", ""))
		(controls["value"] as Label).text = "%s　%d/%d级" % [str(values[project]), int(cost.get("level", 0)), int(cost.get("cap", 0))]
		if at_cap:
			(controls["cost"] as Label).text = "已强化至上限"
		else:
			(controls["cost"] as Label).text = "饷%d · %s%d" % [int(cost.get("pay", 0)), str(resource_names.get(resource_id, "材料")), int(cost.get("material", 0))]
		var available_material := int(upgrade_materials.get("canvas", 0)) if resource_id == "canvas" else int(items.get(resource_id, 0))
		(controls["plus"] as Button).disabled = at_cap or int(economy_state.get("pay", 0)) < int(cost.get("pay", 0)) or available_material < int(cost.get("material", 0))


func _rebuild_stats(definition: Dictionary, ship: Dictionary) -> void:
	_clear_stats()
	var upgrades := ship.get("upgrades", {}) as Dictionary
	var speed := int(definition.get("speed", 0)) + int(upgrades.get("speed", 0))
	var speed_cap := int(definition.get("speed", 0)) + int(ECONOMY.ship_upgrade_cost(ship, "speed").get("cap", 0))
	for data in [
		["火力", int(definition.get("firepower", 0)), 5],
		["航速", speed, speed_cap],
		["装甲", int(definition.get("armor", 0)), 5],
		["载货", int(definition.get("cargo", 0)), 5],
	]:
		_stats.add_child(_make_stat_card(str(data[0]), int(data[1]), int(data[2])))


func _clear_stats() -> void:
	for child in _stats.get_children():
		_stats.remove_child(child)
		child.queue_free()


func _make_stat_card(title: String, value: int, maximum: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(172, 54)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _flat_style(PANEL_INK, Color(GOLD.r, GOLD.g, GOLD.b, 0.34), 1))
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stack)
	var title_label := _make_label(title, 13, TEXT_MUTED)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title_label)
	var value_label := _make_label("%d / %d" % [value, maximum], 18, GOLD_BRIGHT)
	value_label.name = "%sValue" % title
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(value_label)
	return panel


func _ship_number(ship_id: String) -> String:
	if ship_id.begins_with("ship_"):
		return ship_id.trim_prefix("ship_")
	return ship_id if not ship_id.is_empty() else "---"


func _selector_style(selected: bool, hovered: bool) -> StyleBoxFlat:
	var background := Color(0.38, 0.30, 0.13, 0.50) if selected else PANEL_INK
	if hovered:
		background = background.lightened(0.08)
	var style := _flat_style(background, Color(GOLD.r, GOLD.g, GOLD.b, 0.58 if selected else 0.22), 1)
	style.set_border_width(SIDE_LEFT, 4 if selected else 2)
	style.content_margin_left = 12.0
	return style


func _style_ship_scrollbar(scrollbar: VScrollBar) -> void:
	scrollbar.name = "ShipListScrollbar"
	scrollbar.custom_minimum_size.x = 26.0
	scrollbar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scrollbar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var track := StyleBoxTexture.new()
	var track_texture := AtlasTexture.new()
	track_texture.atlas = SCROLLBAR_SHEET
	track_texture.region = Rect2(440, 0, 144, 1120)
	track.texture = track_texture
	scrollbar.add_theme_stylebox_override("scroll", track)
	scrollbar.add_theme_stylebox_override("scroll_focus", track)
	scrollbar.add_theme_stylebox_override("grabber", _solid_scrollbar_style(Color(0.58, 0.40, 0.16, 1.0), 56.0, 6, 6, 34, 34))
	scrollbar.add_theme_stylebox_override("grabber_highlight", _solid_scrollbar_style(Color(0.76, 0.55, 0.22, 1.0), 56.0, 6, 6, 34, 34))
	scrollbar.add_theme_stylebox_override("grabber_pressed", _solid_scrollbar_style(Color(0.91, 0.68, 0.28, 1.0), 56.0, 6, 6, 34, 34))


func _solid_scrollbar_style(background: Color, minimum_visible_height := 0.0, left_inset := 0, right_inset := 0, top_inset := 0, bottom_inset := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color.TRANSPARENT
	style.set_border_width(SIDE_LEFT, left_inset)
	style.set_border_width(SIDE_RIGHT, right_inset)
	style.set_border_width(SIDE_TOP, top_inset)
	style.set_border_width(SIDE_BOTTOM, bottom_inset)
	style.set_corner_radius_all(2)
	var minimum_total_height := minimum_visible_height + top_inset + bottom_inset
	style.content_margin_top = minimum_total_height * 0.5
	style.content_margin_bottom = minimum_total_height * 0.5
	return style


func _make_action_button(text_value: String, button_position: Vector2, button_size: Vector2, use_detail_frame := false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = button_position
	button.size = button_size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", TEXT_LIGHT)
	button.add_theme_color_override("font_disabled_color", Color(TEXT_MUTED.r, TEXT_MUTED.g, TEXT_MUTED.b, 0.56))
	if use_detail_frame:
		button.add_theme_stylebox_override("normal", _detail_button_style(Color(0.78, 0.80, 0.74, 1.0)))
		button.add_theme_stylebox_override("hover", _detail_button_style(Color(1.0, 0.94, 0.72, 1.0)))
		button.add_theme_stylebox_override("pressed", _detail_button_style(Color(0.92, 0.76, 0.42, 1.0)))
		button.add_theme_stylebox_override("disabled", _detail_button_style(Color(0.42, 0.44, 0.40, 0.68)))
	else:
		button.add_theme_stylebox_override("normal", _flat_style(Color(0.025, 0.055, 0.048, 0.92), Color(GOLD.r, GOLD.g, GOLD.b, 0.54), 1))
		button.add_theme_stylebox_override("hover", _flat_style(Color(0.13, 0.16, 0.10, 0.96), GOLD, 1))
		button.add_theme_stylebox_override("pressed", _flat_style(Color(0.28, 0.21, 0.09, 0.96), GOLD_BRIGHT, 1))
		button.add_theme_stylebox_override("disabled", _flat_style(Color(0.025, 0.04, 0.036, 0.54), Color(GOLD.r, GOLD.g, GOLD.b, 0.20), 1))
	return button


func _detail_button_style(tint: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = DETAIL_BUTTON_FRAME
	style.modulate_color = tint
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _make_label(text_value: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_rich_text(font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", TEXT_LIGHT)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _flat_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(3)
	return style
