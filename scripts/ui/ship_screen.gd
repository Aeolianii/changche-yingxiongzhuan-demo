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
	"cannon_warship": preload("res://assets/ui/merchant_shop/ships/cannon_warship_v2.png"),
	"escort_junk": preload("res://assets/ui/merchant_shop/ships/escort_junk.png"),
}
# CHG-20260818：舰队预设文件路径（与 C# FleetPresetStore 共用同一 user:// JSON 与 schema）。
const FLEET_PRESET_PATH := "user://fleet_presets.json"
# CHG-20260819（F-3）：小地图阵型编辑器——玩家布阵区缩小为正常战斗可配置范围（与 C# NavalDeploymentController.PlayerZone 同源：
# x[1,13) y[12,22)，12 宽 × 10 高）。小地图按 1:1 记录海战布阵坐标，保存到预设 Formation，布阵侧直接按坐标摆位。
const FORMATION_ZONE_X := 1
const FORMATION_ZONE_Y := 12
const FORMATION_ZONE_W := 12
const FORMATION_ZONE_H := 10
# CHG-20260820：小地图单格由 20px 放大到 26px，让格子与舰船贴图更容易辨认。
const FORMATION_CELL_SIZE := 26
# 「设默认」使用的预留预设名（默认预设 = 全舰一字排开）。
const DEFAULT_PRESET_NAME := "默认阵型"
# CHG-20260819（F-1 讨伐饰品）：饰品定义（与 C# FleetTreasure 宝物一一对应；economy_state.accessories 同 id）。
const ACCESSORY_DEFS := {
	"sea_monster_horn": {"name": "海怪之角", "effect": "旗舰撞角升至Lv4（系数1.8）"},
	"sun_piercing_spear": {"name": "贯日神枪", "effect": "旗舰砲击升至Lv4（420伤害）"},
	"wokou_banner": {"name": "倭寇军旗", "effect": "全舰队射程+1格"},
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
# CHG-20260819（F-1 讨伐饰品）：饰品整备区块控件（装备/卸下按钮 + 状态文本），_refresh_equipment_page 刷新。
var _accessory_controls: Dictionary = {}
var _accessory_status: Label
var _detail_mode := "hull"
# CHG-20260818：舰队预设 UI（保存/载入/删除，存 user://fleet_presets.json，与 C# FleetPresetStore 共用 schema）。
var _preset_panel: Panel
var _preset_name: LineEdit
var _preset_status: Label
var _active_label: Label
var _preset_list: VBoxContainer
# 测试重定向预设文件路径（如 user:// 临时文件）；空 = 用默认 user://fleet_presets.json。
var fleet_preset_path_override := ""
# CHG-20260818：舰队配置页签——出战舰船勾选 + 小地图阵型编辑器 + 预设管理。
var _fleet_tab: Button
var _fleet_config_page: Panel
var _fleet_check_list: VBoxContainer
var _fleet_tab_status: Label
var _fleet_check_buttons: Dictionary = {}  # ship_id -> CheckButton（勾选=出战）
var _fleet_place_buttons: Dictionary = {}  # ship_id -> Button（摆位）
var _checked: Dictionary = {}  # ship_id -> bool（出战勾选）
var _placements: Dictionary = {}  # ship_id -> {x, y, facing}（海战布阵坐标 + 朝向）
var _type_by_id: Dictionary = {}  # ship_id -> economy 舰型 id
var _active_block := ""  # 小地图当前选中/待放置舰
var _minimap: FormationGrid
# CHG-20260819（F-3）：小地图舰块右键悬停提示（舰名 + 编号，如「护卫舰 3 号」）。
var _minimap_tooltip: Label

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
	_refresh_fleet_config()
	_refresh_fleet_preset_list()
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
	separator.position = Vector2(528, 492)
	separator.size = Vector2(744, 1)
	separator.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.38)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(separator)

	var durability_title := _make_label("船体耐久", 19, GOLD_BRIGHT)
	durability_title.position = Vector2(544, 512)
	durability_title.size = Vector2(180, 30)
	add_child(durability_title)

	_durability = ProgressBar.new()
	_durability.name = "DurabilityBar"
	_durability.position = Vector2(544, 549)
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
	_stats.position = Vector2(544, 594)
	_stats.size = Vector2(718, 54)
	_stats.add_theme_constant_override("h_separation", 10)
	_stats.add_theme_constant_override("v_separation", 8)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stats)
	_build_upgrade_grid()

	_crew_label = _make_label("", 16, TEXT_LIGHT)
	_crew_label.name = "CrewLabel"
	_crew_label.position = Vector2(548, 766)
	_crew_label.size = Vector2(210, 22)
	add_child(_crew_label)

	_construction_label = _make_label("", 15, TEXT_MUTED)
	_construction_label.name = "ConstructionLabel"
	_construction_label.position = Vector2(750, 766)
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
	_build_fleet_config_page()
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
	# CHG-20260818：舰队配置页签（第三个，与船体/装备并列）——勾选出战舰 + 小地图阵型编辑器 + 预设管理。
	_fleet_tab = _make_action_button("舰队配置", Vector2(816, 228), Vector2(126, 40), true)
	_fleet_tab.name = "FleetConfigTab"
	_add_detail_tab_bottom_border(_fleet_tab)
	_fleet_tab.pressed.connect(_switch_detail_mode.bind("fleet"))
	add_child(_fleet_tab)


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
	_upgrade_title.position = Vector2(544, 652)
	_upgrade_title.size = Vector2(180, 26)
	add_child(_upgrade_title)
	_upgrade_status = _make_label("", 13, JADE)
	_upgrade_status.name = "UpgradeStatus"
	_upgrade_status.position = Vector2(760, 652)
	_upgrade_status.size = Vector2(500, 26)
	_upgrade_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_upgrade_status)
	_upgrade_grid = GridContainer.new()
	_upgrade_grid.name = "ShipUpgradeGrid"
	_upgrade_grid.columns = 4
	_upgrade_grid.position = Vector2(544, 681)
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
	# CHG-20260819（F-1 讨伐饰品）：加高装备页（与舰队配置页同尺寸）以容纳底部饰品整备区块。
	_equipment_page.position = Vector2(520, 250)
	_equipment_page.size = Vector2(752, 640)
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

	# CHG-20260819（F-1 讨伐饰品）：饰品整备区块——已获饰品三张卡（装备/卸下按钮 + 状态）。
	var accessory_title := _make_label("饰品整备", 18, GOLD_BRIGHT)
	accessory_title.position = Vector2(18, 506)
	accessory_title.size = Vector2(200, 28)
	_equipment_page.add_child(accessory_title)
	var accessory_row := HBoxContainer.new()
	accessory_row.name = "AccessoryRow"
	accessory_row.position = Vector2(18, 538)
	accessory_row.size = Vector2(716, 74)
	accessory_row.add_theme_constant_override("separation", 10)
	_equipment_page.add_child(accessory_row)
	for accessory_id in ACCESSORY_DEFS:
		var def := ACCESSORY_DEFS[accessory_id] as Dictionary
		accessory_row.add_child(_make_accessory_card(accessory_id, str(def["name"]), str(def["effect"]), 232.0))

	_accessory_status = _make_label("", 14, JADE)
	_accessory_status.name = "AccessoryStatus"
	_accessory_status.position = Vector2(18, 616)
	_accessory_status.size = Vector2(710, 20)
	_accessory_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_equipment_page.add_child(_accessory_status)

	_equipment_status = _make_label("", 14, JADE)
	_equipment_status.name = "EquipmentStatus"
	_equipment_status.position = Vector2(18, 596)
	_equipment_status.size = Vector2(710, 20)
	_equipment_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_equipment_page.add_child(_equipment_status)


# CHG-20260819（F-1 讨伐饰品）：饰品卡——未获得置灰；已获得显示 装备/卸下 按钮，按下切换当前选中舰装备状态。
func _make_accessory_card(accessory_id: String, display_name: String, effect: String, width: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Accessory_%s" % accessory_id
	card.custom_minimum_size = Vector2(width, 74)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _flat_style(PANEL_INK, Color(JADE.r, JADE.g, JADE.b, 0.40), 1))
	var content := Control.new()
	content.name = "Content"
	content.custom_minimum_size = Vector2(width, 74)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	var title := _make_label(display_name, 15, TEXT_LIGHT)
	title.position = Vector2(12, 6)
	title.size = Vector2(width - 24.0, 22)
	content.add_child(title)
	var subtitle := _make_label(effect, 11, TEXT_MUTED)
	subtitle.position = Vector2(12, 28)
	subtitle.size = Vector2(width - 24.0, 18)
	content.add_child(subtitle)
	var state := _make_label("未获得", 12, TEXT_MUTED)
	state.name = "State"
	state.position = Vector2(12, 48)
	state.size = Vector2(maxf(90.0, width - 108.0), 22)
	content.add_child(state)
	var action := _make_action_button("装备", Vector2(width - 66.0, 42), Vector2(56, 28))
	action.name = "Action"
	action.pressed.connect(_toggle_accessory.bind(accessory_id))
	content.add_child(action)
	_accessory_controls[accessory_id] = {"state": state, "action": action}
	return card


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
	if _accessory_status != null:
		_accessory_status.text = ""
	_refresh_selectors()
	_refresh_detail()


func _switch_detail_mode(mode: String) -> void:
	_detail_mode = mode if mode == "fleet" else ("equipment" if mode == "equipment" else "hull")
	for node in _hull_nodes:
		node.visible = _detail_mode == "hull"
	_equipment_page.visible = _detail_mode == "equipment"
	if _fleet_config_page != null:
		_fleet_config_page.visible = _detail_mode == "fleet"
	var hull_selected := _detail_mode == "hull"
	_hull_tab.add_theme_stylebox_override("normal", _detail_button_style(Color(1.0, 0.88, 0.55, 1.0) if hull_selected else Color(0.78, 0.80, 0.74, 1.0)))
	_equipment_tab.add_theme_stylebox_override("normal", _detail_button_style(Color(1.0, 0.88, 0.55, 1.0) if _detail_mode == "equipment" else Color(0.78, 0.80, 0.74, 1.0)))
	if _fleet_tab != null:
		_fleet_tab.add_theme_stylebox_override("normal", _detail_button_style(Color(1.0, 0.88, 0.55, 1.0) if _detail_mode == "fleet" else Color(0.78, 0.80, 0.74, 1.0)))
	_hull_tab.add_theme_color_override("font_color", GOLD_BRIGHT if hull_selected else TEXT_MUTED)
	_equipment_tab.add_theme_color_override("font_color", GOLD_BRIGHT if _detail_mode == "equipment" else TEXT_MUTED)
	if _fleet_tab != null:
		_fleet_tab.add_theme_color_override("font_color", GOLD_BRIGHT if _detail_mode == "fleet" else TEXT_MUTED)
	if _detail_mode == "equipment":
		_refresh_equipment_page()
	if _detail_mode == "fleet":
		_refresh_fleet_config()


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


# CHG-20260819（F-1 讨伐饰品）：装备/卸下当前选中舰的饰品。
# 未获得 → 提示；已装备到当前舰 → 卸下；否则装备到当前舰（重复装备自动迁移）。
func _toggle_accessory(accessory_id: String) -> void:
	if _ships.is_empty():
		return
	if not (ACCESSORY_DEFS.has(accessory_id)):
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	if not bool(game_state.call("has_economy_accessory", accessory_id)):
		_accessory_status.text = "尚未获得此饰品"
		return
	var ship_id := str(_ships[_selected_index].get("id", ""))
	var accessory_name := str((ACCESSORY_DEFS[accessory_id] as Dictionary)["name"])
	var currently := str(game_state.call("equipped_economy_accessory_ship", accessory_id))
	if currently == ship_id:
		if bool(game_state.call("unequip_economy_accessory", accessory_id)):
			_accessory_status.text = "%s 已卸下" % accessory_name
		else:
			_accessory_status.text = "卸下失败"
	else:
		var result := game_state.call("equip_economy_accessory", accessory_id, ship_id) as Dictionary
		_accessory_status.text = "%s 已装备到当前舰" % accessory_name if result.get("ok", false) else "装备失败"
	_refresh_equipment_page()


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
	_refresh_accessories()


# CHG-20260819（F-1 讨伐饰品）：刷新饰品卡——未获得置灰；已获得显示 装备/已装备/装备到其它舰 状态。
func _refresh_accessories() -> void:
	if _ships.is_empty():
		return
	var ship_id := str(_ships[_selected_index].get("id", ""))
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	var equipped := game_state.call("equipped_economy_accessories") as Dictionary
	for accessory_id in _accessory_controls:
		var controls := _accessory_controls[accessory_id] as Dictionary
		var state := controls["state"] as Label
		var action := controls["action"] as Button
		var owned := bool(game_state.call("has_economy_accessory", accessory_id))
		var accessory_name := str((ACCESSORY_DEFS[accessory_id] as Dictionary)["name"])
		if not owned:
			state.text = "未获得"
			action.text = "装备"
			action.disabled = true
		else:
			var equipped_ship := str(equipped.get(accessory_id, ""))
			action.disabled = false
			if equipped_ship == ship_id:
				state.text = "已装备"
				action.text = "卸下"
			elif equipped_ship.is_empty():
				state.text = "未装备"
				action.text = "装备"
			else:
				state.text = "装备于其它舰"
				action.text = "装备"


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


func _style_preset_scrollbar(scrollbar: VScrollBar) -> void:
	# 短列表使用独立的紧凑样式：18px 宽命中区 + 高对比滑块，方便鼠标直接按住拖动。
	scrollbar.name = "PresetListScrollbar"
	scrollbar.custom_minimum_size.x = 18.0
	scrollbar.mouse_filter = Control.MOUSE_FILTER_STOP
	scrollbar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var track := _flat_style(Color(0.018, 0.034, 0.030, 0.96), Color(GOLD.r, GOLD.g, GOLD.b, 0.34), 1)
	scrollbar.add_theme_stylebox_override("scroll", track)
	scrollbar.add_theme_stylebox_override("scroll_focus", track)
	scrollbar.add_theme_stylebox_override("grabber", _solid_scrollbar_style(Color(0.56, 0.58, 0.54, 1.0), 18.0, 4, 4, 2, 2))
	scrollbar.add_theme_stylebox_override("grabber_highlight", _solid_scrollbar_style(Color(0.78, 0.66, 0.34, 1.0), 18.0, 3, 3, 2, 2))
	scrollbar.add_theme_stylebox_override("grabber_pressed", _solid_scrollbar_style(Color(0.94, 0.76, 0.30, 1.0), 18.0, 3, 3, 2, 2))


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


func _build_fleet_config_page() -> void:
	# CHG-20260818：舰队配置页签内容——出战舰船勾选 + 小地图阵型编辑器 + 预设管理（保存/载入/删除/设默认）。
	# 预设存「出战哪些舰（Ships）+ 各舰阵型位置/朝向（Formation）」，与 C# FleetPresetStore 共用 schema。
	_fleet_config_page = Panel.new()
	_fleet_config_page.name = "FleetConfigPage"
	# CHG-20260820：面板完整收入右侧 UI 边框，避免上方压住三个页签、下方越出背景框。
	_fleet_config_page.position = Vector2(520, 272)
	_fleet_config_page.size = Vector2(752, 526)
	_fleet_config_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fleet_config_page.add_theme_stylebox_override("panel", _flat_style(Color(0.018, 0.038, 0.034, 0.80), Color(GOLD.r, GOLD.g, GOLD.b, 0.42), 1))
	add_child(_fleet_config_page)

	var title := _make_label("舰队配置 · 出战舰船与初始阵型", 20, GOLD_BRIGHT)
	title.name = "FleetConfigTitle"
	title.position = Vector2(18, 8)
	title.size = Vector2(500, 30)
	_fleet_config_page.add_child(title)

	_fleet_tab_status = _make_label("", 13, TEXT_MUTED)
	_fleet_tab_status.name = "FleetConfigStatus"
	_fleet_tab_status.position = Vector2(18, 40)
	_fleet_tab_status.size = Vector2(716, 22)
	_fleet_tab_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fleet_config_page.add_child(_fleet_tab_status)

	var check_caption := _make_label("出战舰船（勾选 = 出战）", 15, TEXT_LIGHT)
	check_caption.name = "FleetCheckCaption"
	check_caption.position = Vector2(18, 66)
	check_caption.size = Vector2(230, 24)
	_fleet_config_page.add_child(check_caption)

	var check_scroll := ScrollContainer.new()
	check_scroll.name = "FleetCheckScroll"
	check_scroll.position = Vector2(18, 94)
	check_scroll.size = Vector2(212, 268)
	check_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	check_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	check_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	check_scroll.clip_contents = true
	check_scroll.add_theme_stylebox_override("panel", _flat_style(Color(0.02, 0.05, 0.045, 0.9), Color(GOLD.r, GOLD.g, GOLD.b, 0.3), 1))
	_fleet_config_page.add_child(check_scroll)

	var check_inset := MarginContainer.new()
	check_inset.name = "FleetCheckInset"
	check_inset.custom_minimum_size = Vector2(198, 0)
	check_inset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	check_inset.add_theme_constant_override("margin_left", 6)
	check_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check_scroll.add_child(check_inset)

	_fleet_check_list = VBoxContainer.new()
	_fleet_check_list.name = "FleetCheckList"
	_fleet_check_list.custom_minimum_size = Vector2(192, 0)
	_fleet_check_list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_fleet_check_list.add_theme_constant_override("separation", 6)
	_fleet_check_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check_inset.add_child(_fleet_check_list)

	var hint := _make_label("操作：点「摆位」后选棋盘空格；点舰船可再移动，右键查看舰名/编号。右侧可旋转、退选或重置阵型。", 12, TEXT_MUTED)
	hint.name = "FleetCheckHint"
	hint.position = Vector2(18, 364)
	hint.size = Vector2(698, 22)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fleet_config_page.add_child(hint)

	var minimap_caption := _make_label("初始阵型 · 玩家布阵区小地图", 15, TEXT_LIGHT)
	minimap_caption.name = "FormationMinimapCaption"
	minimap_caption.position = Vector2(246, 66)
	minimap_caption.size = Vector2(320, 24)
	_fleet_config_page.add_child(minimap_caption)

	_minimap = FormationGrid.new()
	_minimap.name = "FormationMinimap"
	_minimap.zone_x = FORMATION_ZONE_X
	_minimap.zone_y = FORMATION_ZONE_Y
	_minimap.zone_w = FORMATION_ZONE_W
	_minimap.zone_h = FORMATION_ZONE_H
	_minimap.cell_size = FORMATION_CELL_SIZE
	_minimap.grid_origin = Vector2(4, 4)
	_minimap.position = Vector2(246, 94)
	_minimap.size = Vector2(FORMATION_ZONE_W * FORMATION_CELL_SIZE + 8, FORMATION_ZONE_H * FORMATION_CELL_SIZE + 8)
	_minimap.mouse_filter = Control.MOUSE_FILTER_STOP
	_minimap.gui_input.connect(_on_minimap_input)
	_fleet_config_page.add_child(_minimap)

	# CHG-20260819（F-3）：小地图舰块右键悬停提示 Label（悬停/右键显示「护卫舰 3 号」类文本）。
	_minimap_tooltip = Label.new()
	_minimap_tooltip.name = "FormationTooltip"
	_minimap_tooltip.add_theme_font_size_override("font_size", 14)
	_minimap_tooltip.add_theme_color_override("font_color", TEXT_LIGHT)
	_minimap_tooltip.add_theme_stylebox_override("normal", _flat_style(Color(0.0, 0.0, 0.0, 0.82), Color(GOLD.r, GOLD.g, GOLD.b, 0.6), 1))
	_minimap_tooltip.add_theme_constant_override("content_margin_left", 6)
	_minimap_tooltip.add_theme_constant_override("content_margin_right", 6)
	_minimap_tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minimap_tooltip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_minimap_tooltip.visible = false
	_minimap_tooltip.z_index = 50
	_fleet_config_page.add_child(_minimap_tooltip)

	# 棋盘放大后，三个阵型操作改为右侧竖排，不再挤占棋盘下方空间。
	var rotate_button := _make_action_button("旋转朝向", Vector2(586, 100), Vector2(130, 34))
	rotate_button.name = "FormationRotate"
	rotate_button.pressed.connect(_rotate_active_block)
	_fleet_config_page.add_child(rotate_button)

	var deselect_button := _make_action_button("退选", Vector2(586, 158), Vector2(130, 34))
	deselect_button.name = "FormationDeselect"
	deselect_button.pressed.connect(_deselect_active_block)
	_fleet_config_page.add_child(deselect_button)

	var row_button := _make_action_button("一字排开", Vector2(586, 216), Vector2(130, 34))
	row_button.name = "FormationDefaultRow"
	row_button.pressed.connect(apply_default_formation)
	_fleet_config_page.add_child(row_button)

	var separator := ColorRect.new()
	separator.name = "FleetConfigSeparator"
	separator.position = Vector2(18, 389)
	separator.size = Vector2(716, 1)
	separator.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.38)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fleet_config_page.add_child(separator)

	_build_fleet_preset_bar()


func _build_fleet_preset_bar() -> void:
	# 舰队配置页内的预设管理：保存（当前勾选 + 阵型）/ 设默认（一字排开并存为「默认阵型」+ 设为下次出战）/
	# 每预设 载入（设 ActivePreset + 回填编辑器）/ 删除。
	_preset_panel = _fleet_config_page

	_preset_status = _make_label("", 12, JADE)
	_preset_status.name = "FleetPresetStatus"
	_preset_status.position = Vector2(18, 393)
	_preset_status.size = Vector2(698, 18)
	_preset_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_preset_panel.add_child(_preset_status)

	var caption := _make_label("预设", 14, GOLD_BRIGHT)
	caption.name = "FleetPresetCaption"
	caption.position = Vector2(18, 415)
	caption.size = Vector2(40, 28)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preset_panel.add_child(caption)

	_preset_name = LineEdit.new()
	_preset_name.name = "PresetNameEdit"
	_preset_name.position = Vector2(58, 415)
	_preset_name.size = Vector2(160, 28)
	_preset_name.placeholder_text = "预设名"
	_preset_name.max_length = 24
	_preset_name.add_theme_font_size_override("font_size", 15)
	_preset_name.add_theme_stylebox_override("normal", _flat_style(Color(0.02, 0.05, 0.045, 0.9), Color(GOLD.r, GOLD.g, GOLD.b, 0.4), 1))
	_preset_name.add_theme_stylebox_override("focus", _flat_style(Color(0.03, 0.07, 0.06, 0.95), GOLD_BRIGHT, 1))
	_preset_name.text_submitted.connect(func(_text: String) -> void: _save_fleet_preset())
	_preset_panel.add_child(_preset_name)

	var save_button := _make_action_button("保存", Vector2(224, 415), Vector2(56, 28))
	save_button.name = "PresetSave"
	save_button.pressed.connect(_save_fleet_preset)
	_preset_panel.add_child(save_button)

	var default_button := _make_action_button("设默认", Vector2(286, 415), Vector2(88, 28))
	default_button.name = "PresetSetDefault"
	default_button.pressed.connect(_set_default_preset)
	_preset_panel.add_child(default_button)

	_active_label = _make_label("", 12, JADE)
	_active_label.name = "ActivePresetLabel"
	_active_label.position = Vector2(386, 415)
	_active_label.size = Vector2(330, 28)
	_active_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_active_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preset_panel.add_child(_active_label)

	var scroll := ScrollContainer.new()
	scroll.name = "PresetListScroll"
	scroll.position = Vector2(18, 449)
	scroll.size = Vector2(698, 67)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.clip_contents = true
	_preset_panel.add_child(scroll)
	_style_preset_scrollbar(scroll.get_v_scroll_bar())

	_preset_list = VBoxContainer.new()
	_preset_list.name = "PresetList"
	# 右侧主动留白，避免每行的「载入/删除」紧贴或被纵向滚动条遮住。
	_preset_list.custom_minimum_size = Vector2(646, 0)
	_preset_list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_preset_list.add_theme_constant_override("separation", 4)
	_preset_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_preset_list)


func _fleet_preset_file_path() -> String:
	# 测试可重定向到临时文件；默认与 C# FleetPresetStore 共用 user://fleet_presets.json。
	return fleet_preset_path_override if not fleet_preset_path_override.is_empty() else FLEET_PRESET_PATH


func _read_fleet_preset_store() -> Dictionary:
	# 读取预设文件 → {presets: {预设名: {Ships: 舰队数组, Formation: 阵型数组}}, active: 活动预设名}；文件缺失/损坏 → 空集合。
	var presets := {}
	var active := ""
	if FileAccess.file_exists(_fleet_preset_file_path()):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(_fleet_preset_file_path()))
		if parsed is Dictionary:
			active = str((parsed as Dictionary).get("ActivePreset", ""))
			var raw_presets = (parsed as Dictionary).get("Presets", [])
			if raw_presets is Array:
				for entry in raw_presets:
					if entry is Dictionary:
						var entry_name := str((entry as Dictionary).get("Name", ""))
						var ships = (entry as Dictionary).get("Ships", [])
						if not entry_name.is_empty() and ships is Array and not (ships as Array).is_empty():
							var formation = (entry as Dictionary).get("Formation", [])
							presets[entry_name] = {"Ships": ships, "Formation": formation if formation is Array else []}
	return {"presets": presets, "active": active}


func _write_fleet_preset_store(presets: Dictionary, active: String) -> void:
	# 写回预设文件（schema 与 C# FleetPresetStore 一致：ActivePreset + Presets[]；Formation 为空时不写，向后兼容）。
	var payload := {"ActivePreset": active, "Presets": []}
	for name in presets:
		var entry := {"Name": name, "Ships": (presets[name] as Dictionary).get("Ships", [])}
		var formation = (presets[name] as Dictionary).get("Formation", [])
		if formation is Array and not (formation as Array).is_empty():
			entry["Formation"] = formation
		payload["Presets"].append(entry)
	var file := FileAccess.open(_fleet_preset_file_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))


func _save_fleet_preset() -> void:
	# 保存「出战舰船（勾选）+ 各舰阵型位置/朝向」为命名预设（Ships 按勾选顺序 = Formation.Slot）；同名覆盖。
	var preset_name := _preset_name.text.strip_edges()
	if preset_name.is_empty():
		_preset_status.text = "预设名不能为空"
		return
	var checked_ships := []
	for ship in _ships:
		if _checked.get(str(ship.get("id", "")), false):
			checked_ships.append(ship)
	if checked_ships.is_empty():
		_preset_status.text = "请先勾选出战舰船"
		return
	var preset_ships := []
	var formation := []
	for i in range(checked_ships.size()):
		var ship: Dictionary = checked_ships[i]
		var ship_id := str(ship.get("id", ""))
		var equipment = ship.get("equipment", {}) as Dictionary
		preset_ships.append({
			"ShipTypeId": str(ship.get("type_id", "")),
			"Equipment": {
				"Weapons": (equipment.get("weapons", {}) as Dictionary).duplicate(true),
				"Skills": (equipment.get("skills", {}) as Dictionary).duplicate(true),
				"ArmorLevel": int(equipment.get("armor_level", 0)),
			},
		})
		var placement = _placements.get(ship_id, {}) as Dictionary
		if not placement.is_empty():
			formation.append({
				"Slot": i,
				"X": int(placement.get("x", 0)),
				"Y": int(placement.get("y", 0)),
				"Facing": str(placement.get("facing", "east")),
			})
	var store := _read_fleet_preset_store()
	var presets: Dictionary = store["presets"]
	presets[preset_name] = {"Ships": preset_ships, "Formation": formation}
	_write_fleet_preset_store(presets, str(store["active"]))
	_preset_status.text = "已保存「%s」%d 艘 · 阵型 %d 格" % [preset_name, preset_ships.size(), formation.size()]
	_refresh_fleet_preset_list()


func _set_default_preset() -> void:
	# 设默认 = 全舰一字排开（默认阵型），保存为预留预设「默认阵型」并设为下次出战。
	apply_default_formation()
	_preset_name.text = DEFAULT_PRESET_NAME
	_save_fleet_preset()
	var store := _read_fleet_preset_store()
	var presets: Dictionary = store["presets"]
	_write_fleet_preset_store(presets, DEFAULT_PRESET_NAME)
	_preset_status.text = "已设默认阵型「%s」（全舰一字排开），下次出战沿用" % DEFAULT_PRESET_NAME
	_refresh_fleet_preset_list()


func _load_fleet_preset(preset_name: String) -> void:
	# 「载入」= 设为下次出战舰队（写活动预设字段，持久化），并把预设的 Ships/Formation 回填到编辑器。
	# 布阵侧按经济拥有数约束实际取用。
	var store := _read_fleet_preset_store()
	var presets: Dictionary = store["presets"]
	if not presets.has(preset_name):
		_preset_status.text = "预设不存在"
		return
	_write_fleet_preset_store(presets, preset_name)
	_load_preset_into_editor(presets[preset_name])
	_preset_status.text = "「%s」设为下次出战舰队" % preset_name
	_refresh_fleet_preset_list()


func _load_preset_into_editor(entry: Dictionary) -> void:
	# 按预设 Ships 序列勾选（每舰型顺序取用拥有的舰），并按 Formation 摆位；缺阵型舰自动摆位。
	_checked = {}
	_placements = {}
	var lineup_ids: Array[String] = []
	var cursor := {}
	for preset_ship in entry.get("Ships", []) as Array:
		if not preset_ship is Dictionary:
			continue
		var type_id := str((preset_ship as Dictionary).get("ShipTypeId", ""))
		var index := int(cursor.get(type_id, 0))
		cursor[type_id] = index + 1
		var picked := ""
		var seen := 0
		for ship in _ships:
			if str(ship.get("type_id", "")) != type_id:
				continue
			if seen < index:
				seen += 1
				continue
			picked = str(ship.get("id", ""))
			break
		if picked.is_empty():
			continue
		_checked[picked] = true
		lineup_ids.append(picked)
	for f in entry.get("Formation", []) as Array:
		if not f is Dictionary:
			continue
		var slot := int((f as Dictionary).get("Slot", -1))
		if slot < 0 or slot >= lineup_ids.size():
			continue
		var id := lineup_ids[slot]
		_placements[id] = {
			"x": int((f as Dictionary).get("X", 0)),
			"y": int((f as Dictionary).get("Y", 0)),
			"facing": str((f as Dictionary).get("Facing", "east")),
		}
	for ship in _ships:
		var ship_id := str(ship.get("id", ""))
		if _checked.get(ship_id, false) and not _placements.has(ship_id):
			_auto_place_ship(ship_id)
	_active_block = ""
	_hide_ship_tooltip()
	_rebuild_fleet_check_list()
	_sync_minimap()


func _delete_fleet_preset(preset_name: String) -> void:
	# 删除预设；若该预设正是活动预设，同时清除活动标记。
	var store := _read_fleet_preset_store()
	var presets: Dictionary = store["presets"]
	if not presets.has(preset_name):
		_preset_status.text = "预设不存在"
		return
	presets.erase(preset_name)
	var active := str(store["active"])
	if active == preset_name:
		active = ""
	_write_fleet_preset_store(presets, active)
	_preset_status.text = "已删除「%s」" % preset_name
	_refresh_fleet_preset_list()


func _refresh_fleet_preset_list() -> void:
	# 重建预设横排列表（预设名 + 载入/删除 按钮），并刷新「下次出战」活动标记。
	for child in _preset_list.get_children():
		_preset_list.remove_child(child)
		child.queue_free()
	var store := _read_fleet_preset_store()
	var presets: Dictionary = store["presets"]
	var active := str(store["active"])
	if _active_label != null:
		_active_label.text = "下次出战：%s" % active if not active.is_empty() else "下次出战：默认全部"
	for preset_name in presets:
		var entry := presets[preset_name] as Dictionary
		var count := (entry.get("Ships", []) as Array).size()
		_preset_list.add_child(_make_preset_row(str(preset_name), count))


func _make_preset_row(preset_name: String, ship_count: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "PresetRow_%s" % _safe_node_name(preset_name)
	row.custom_minimum_size = Vector2(640, 30)
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _make_label("%s（%d艘）" % [preset_name, ship_count], 13, TEXT_LIGHT)
	name_label.custom_minimum_size = Vector2(150, 30)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var load_button := _make_action_button("载入", Vector2.ZERO, Vector2(52, 28))
	load_button.name = "Load"
	load_button.custom_minimum_size = Vector2(52, 28)
	load_button.pressed.connect(_load_fleet_preset.bind(preset_name))
	row.add_child(load_button)
	var delete_button := _make_action_button("删除", Vector2.ZERO, Vector2(52, 28))
	delete_button.name = "Delete"
	delete_button.custom_minimum_size = Vector2(52, 28)
	delete_button.pressed.connect(_delete_fleet_preset.bind(preset_name))
	row.add_child(delete_button)
	return row


func _safe_node_name(raw_name: String) -> String:
	# 预设名 → 节点名（替换 Godot 节点名非法字符）。
	var safe := ""
	for character in raw_name:
		safe += "_" if character in ["/", ":", "@", ".", "\"", "\\", "[", "]"] else character
	safe = safe.strip_edges()
	return safe if not safe.is_empty() else "preset"


# --- CHG-20260818：舰队配置页签（出战舰船勾选 + 小地图阵型编辑器） ---

func _formation_zone() -> Rect2i:
	return Rect2i(FORMATION_ZONE_X, FORMATION_ZONE_Y, FORMATION_ZONE_W, FORMATION_ZONE_H)


func _naval_length(economy_type_id: String) -> int:
	# 海战舰长（ships.json Length）：护卫舰 2、旗舰 3、商船 1；经济→海战映射见 C# EconomyFleetMapper。
	return {"patrol_boat": 2, "cannon_warship": 3, "escort_junk": 1}.get(economy_type_id, 1)


func _refresh_fleet_config() -> void:
	# 同步勾选/阵型与当前舰队：清理已不拥有的舰，默认全勾选 + 未摆位自动摆，重建列表并重绘小地图。
	if _fleet_config_page == null:
		return
	_type_by_id.clear()
	for ship in _ships:
		_type_by_id[str(ship.get("id", ""))] = str(ship.get("type_id", ""))
	var owned := {}
	for ship in _ships:
		owned[str(ship.get("id", ""))] = true
	for ship_id in _checked.keys():
		if not owned.has(ship_id):
			_checked.erase(ship_id)
			_placements.erase(ship_id)
	for ship_id in _placements.keys():
		if not owned.has(ship_id):
			_placements.erase(ship_id)
	for ship in _ships:
		var ship_id := str(ship.get("id", ""))
		if not _checked.has(ship_id):
			_checked[ship_id] = true
		if _checked[ship_id] and not _placements.has(ship_id):
			_auto_place_ship(ship_id)
	if _active_block != "" and not _checked.get(_active_block, false):
		_active_block = ""
	_hide_ship_tooltip()
	_rebuild_fleet_check_list()
	_sync_minimap()
	if _fleet_tab_status != null:
		_fleet_tab_status.text = "出战舰船：%d / %d 艘" % [checked_ship_count(), _ships.size()]


func checked_ship_count() -> int:
	var count := 0
	for ship in _ships:
		if _checked.get(str(ship.get("id", "")), false):
			count += 1
	return count


func _rebuild_fleet_check_list() -> void:
	# 重建出战舰船勾选列表（每艘：勾选框 + 舰名 + 摆位按钮）。
	for child in _fleet_check_list.get_children():
		_fleet_check_list.remove_child(child)
		child.queue_free()
	_fleet_check_buttons.clear()
	_fleet_place_buttons.clear()
	if _ships.is_empty():
		var empty := _make_label("当前没有可用舰船", 15, TEXT_MUTED)
		empty.custom_minimum_size = Vector2(192, 60)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_fleet_check_list.add_child(empty)
		return
	for ship in _ships:
		var ship_id := str(ship.get("id", ""))
		var definition := CATALOG.ship(str(ship.get("type_id", "")))
		var row := HBoxContainer.new()
		row.name = "FleetCheck_%s" % _safe_node_name(ship_id)
		row.custom_minimum_size = Vector2(192, 28)
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fleet_check_list.add_child(row)

		var check := CheckButton.new()
		check.name = "Check"
		check.button_pressed = _checked.get(ship_id, true)
		check.focus_mode = Control.FOCUS_NONE
		check.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		check.tooltip_text = "勾选 = 出战"
		check.toggled.connect(_on_ship_check_toggled.bind(ship_id))
		row.add_child(check)
		_fleet_check_buttons[ship_id] = check

		var name_label := _make_label(str(definition.get("name", "未知舰船")), 13, TEXT_LIGHT)
		name_label.custom_minimum_size = Vector2(92, 26)
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)

		var place_button := Button.new()
		place_button.text = "摆位"
		place_button.custom_minimum_size = Vector2(48, 26)
		place_button.focus_mode = Control.FOCUS_NONE
		place_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		place_button.add_theme_stylebox_override("normal", _flat_style(Color(0.025, 0.055, 0.048, 0.92), Color(GOLD.r, GOLD.g, GOLD.b, 0.54), 1))
		place_button.add_theme_stylebox_override("hover", _flat_style(Color(0.13, 0.16, 0.10, 0.96), GOLD, 1))
		place_button.add_theme_stylebox_override("pressed", _flat_style(Color(0.28, 0.21, 0.09, 0.96), GOLD_BRIGHT, 1))
		place_button.add_theme_font_size_override("font_size", 13)
		place_button.pressed.connect(_on_place_button.bind(ship_id))
		row.add_child(place_button)
		_fleet_place_buttons[ship_id] = place_button


func _on_ship_check_toggled(checked: bool, ship_id: String) -> void:
	# 勾选 = 出战：新勾选自动摆位到小地图；取消勾选保留阵型数据但不参战/不显示。
	_checked[ship_id] = checked
	if checked and not _placements.has(ship_id):
		_auto_place_ship(ship_id)
	if not checked and _active_block == ship_id:
		_active_block = ""
	_hide_ship_tooltip()
	_sync_minimap()
	if _fleet_tab_status != null:
		_fleet_tab_status.text = "出战舰船：%d / %d 艘" % [checked_ship_count(), _ships.size()]


func _on_place_button(ship_id: String) -> void:
	# 「摆位」：确保该舰勾选并选中为待放置目标，随后点小地图格子放置/移动。
	if not _checked.get(ship_id, false):
		_checked[ship_id] = true
		if _fleet_check_buttons.has(ship_id):
			(_fleet_check_buttons[ship_id] as CheckButton).button_pressed = true
	if not _placements.has(ship_id):
		_auto_place_ship(ship_id)
	_active_block = ship_id
	_hide_ship_tooltip()
	_sync_minimap()
	if _preset_status != null:
		_preset_status.text = "已选中「%s」，点小地图空格放置/移动，可再点「旋转朝向」" % _ship_display_name(ship_id)


func _ship_display_name(ship_id: String) -> String:
	var type_id := str(_type_by_id.get(ship_id, ""))
	return str(CATALOG.ship(type_id).get("name", "舰船"))


# CHG-20260819（F-3）：经济舰型 → 海战舰型名（与 C# EconomyFleetMapper / ships.json DisplayName 一致），供右键悬停提示使用。
func _naval_type_name(economy_type_id: String) -> String:
	return {"patrol_boat": "护卫舰", "cannon_warship": "旗舰", "escort_junk": "商船"}.get(economy_type_id, "舰船")


func _auto_place_ship(ship_id: String) -> void:
	# 自动摆位：在玩家布阵区顶部逐行扫描第一个合法船头（朝东，不越界/不重叠）。
	var zone := _formation_zone()
	var len := _naval_length(str(_type_by_id.get(ship_id, "")))
	for y in range(zone.position.y + 1, min(zone.end.y, zone.position.y + 8)):
		for x in range(zone.position.x + 1, zone.end.x):
			var cells := _footprint_cells(x, y, len, "east")
			if _cells_in_zone(cells) and _cells_free(cells, ship_id):
				_placements[ship_id] = {"x": x, "y": y, "facing": "east"}
				return
	for y in range(zone.position.y, zone.end.y):
		for x in range(zone.position.x, zone.end.x):
			if _cells_free([Vector2i(x, y)], ship_id):
				_placements[ship_id] = {"x": x, "y": y, "facing": "east"}
				return
	_placements[ship_id] = {"x": zone.position.x + 1, "y": zone.position.y + 1, "facing": "east"}


func _sync_minimap() -> void:
	if _minimap == null:
		return
	_minimap.blocks.clear()
	_minimap.textures = SHIP_ICONS
	for ship_id in _placements:
		if not _checked.get(ship_id, false):
			continue
		var type_id := str(_type_by_id.get(ship_id, ""))
		var block: Dictionary = (_placements[ship_id] as Dictionary).duplicate(true)
		block["len"] = _naval_length(type_id)
		block["type"] = type_id
		_minimap.blocks[ship_id] = block
	_minimap.active_id = _active_block
	_minimap.queue_redraw()


func _on_minimap_input(event: InputEvent) -> void:
	# 左键：点舰块选中 / 点空格移动选中舰；右键：点舰块显示悬停提示（舰名 + 编号），点空格退选并隐藏提示。
	if not event is InputEventMouseButton or not event.pressed:
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index == MOUSE_BUTTON_RIGHT:
		var hit := _ship_at_cell(_minimap.screen_to_cell(mouse.position))
		if hit != "":
			_active_block = hit
			_show_ship_tooltip(hit, mouse.position)
		else:
			_active_block = ""
			_hide_ship_tooltip()
		_sync_minimap()
		return
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var cell := _minimap.screen_to_cell(mouse.position)
	if cell.x < 0:
		return
	var hit := _ship_at_cell(cell)
	if hit != "":
		_active_block = hit
		_hide_ship_tooltip()
		_sync_minimap()
		return
	if _active_block != "" and _checked.get(_active_block, false):
		_hide_ship_tooltip()
		_place_ship_block(_active_block, cell)


# 小地图格 → 命中的已勾选舰 id（无命中返回 ""）。右键提示与左键选中共用同一命中判定。
func _ship_at_cell(cell: Vector2i) -> String:
	for ship_id in _placements:
		if not _checked.get(ship_id, false):
			continue
		var p := _placements[ship_id] as Dictionary
		var cells := _footprint_cells(int(p.get("x", 0)), int(p.get("y", 0)), _naval_length(str(_type_by_id.get(ship_id, ""))), str(p.get("facing", "east")))
		if cells.has(cell):
			return ship_id
	return ""


# CHG-20260819（F-3）：在舰块上方显示悬停提示（海战舰型名 + 舰队序号，如「护卫舰 3 号」）。
func _show_ship_tooltip(ship_id: String, mouse_local: Vector2) -> void:
	if _minimap_tooltip == null:
		return
	var idx := 0
	for ship in _ships:
		if not _checked.get(str(ship.get("id", "")), false):
			continue
		idx += 1
		if str(ship.get("id", "")) == ship_id:
			break
	# 悬停提示 = 海战舰型名 + 舰队序号（与 _ship_display_name 一致；如护卫舰/旗舰/商船）。
	var label := "%s %d 号" % [_naval_type_name(str(_type_by_id.get(ship_id, ""))), idx]
	_minimap_tooltip.text = label
	# 提示定位在小地图（父级 fleet_config_page）局部坐标；舰块上方居中。cell 是海战坐标，转网格索引定位。
	var cell := _minimap.screen_to_cell(mouse_local)
	var gx := cell.x - FORMATION_ZONE_X
	var gy := cell.y - FORMATION_ZONE_Y
	var tip_w := maxi(60, label.length() * 16)
	var tip_h := 26
	var tip_x := _minimap.position.x + _minimap.grid_origin.x + (gx + 0.5) * _minimap.cell_size - tip_w * 0.5
	var tip_y := _minimap.position.y + _minimap.grid_origin.y + (gy + 0.5) * _minimap.cell_size - tip_h - 6.0
	# 贴图锚点 clamp 在小地图范围内，防止提示溢出页面。
	tip_x = clampf(tip_x, _minimap.position.x, _minimap.position.x + _minimap.size.x - tip_w)
	tip_y = maxf(tip_y, _minimap.position.y + 2.0)
	_minimap_tooltip.position = Vector2(tip_x, tip_y)
	_minimap_tooltip.size = Vector2(tip_w, tip_h)
	_minimap_tooltip.visible = true
	_minimap_tooltip.z_index = 60


func _hide_ship_tooltip() -> void:
	if _minimap_tooltip != null:
		_minimap_tooltip.visible = false


func _place_ship_block(ship_id: String, cell: Vector2i) -> void:
	var p := _placements.get(ship_id, {"facing": "east"}) as Dictionary
	var facing := str(p.get("facing", "east"))
	var len := _naval_length(str(_type_by_id.get(ship_id, "")))
	var cells := _footprint_cells(cell.x, cell.y, len, facing)
	if not _cells_in_zone(cells):
		if _preset_status != null:
			_preset_status.text = "超出布阵区，无法放置"
		return
	if not _cells_free(cells, ship_id):
		if _preset_status != null:
			_preset_status.text = "与其它舰船重叠，无法放置"
		return
	_placements[ship_id] = {"x": cell.x, "y": cell.y, "facing": facing}
	_sync_minimap()
	if _preset_status != null:
		_preset_status.text = "「%s」放置到 (%d, %d)" % [_ship_display_name(ship_id), cell.x, cell.y]


func _rotate_active_block() -> void:
	# 旋转选中舰朝向（east→south→west→north）；越界/重叠时保持原朝向。
	if _active_block == "" or not _placements.has(_active_block):
		if _preset_status != null:
			_preset_status.text = "请先选中一艘舰（点小地图舰块或「摆位」）"
		return
	var order := ["east", "south", "west", "north"]
	var p := _placements[_active_block] as Dictionary
	var current := str(p.get("facing", "east"))
	var next: String = order[(order.find(current) + 1) % 4]
	var len := _naval_length(str(_type_by_id.get(_active_block, "")))
	var cells := _footprint_cells(int(p.get("x", 0)), int(p.get("y", 0)), len, next)
	if not _cells_in_zone(cells) or not _cells_free(cells, _active_block):
		if _preset_status != null:
			_preset_status.text = "该朝向会越界/重叠，已保持原朝向"
		return
	p["facing"] = next
	_hide_ship_tooltip()
	_sync_minimap()
	if _preset_status != null:
		_preset_status.text = "「%s」朝向：%s" % [_ship_display_name(_active_block), next]


func _deselect_active_block() -> void:
	_active_block = ""
	_hide_ship_tooltip()
	_sync_minimap()


func apply_default_formation() -> void:
	# 默认阵型 = 全舰一字排开（侧舷平行）：每艘朝东、船头列对齐，沿 x 逐舰排布（步距 = 该舰实际长度 + 间距 2），
	# 行满（该舰脚尾越出阵型区右缘）换到下一行。CHG-20260819（F-3）：玩家区缩为 12 宽后单行放不下 5 舰，
	# 改为紧凑多行；起始列 = 区左缘 + 2（保证最大舰长 3 朝东时舰尾格仍在区内）。
	var zone := _formation_zone()
	var x := zone.position.x + 2
	var y := zone.position.y + 1
	for ship in _ships:
		var ship_id := str(ship.get("id", ""))
		if not _checked.get(ship_id, false):
			continue
		var len := _naval_length(str(_type_by_id.get(ship_id, "")))
		if x + len - 1 >= zone.end.x:
			y += 3 # 换行（行距 = 最大舰长 3）
			x = zone.position.x + 2
		_placements[ship_id] = {"x": x, "y": y, "facing": "east"}
		x += len + 2
	_active_block = ""
	_hide_ship_tooltip()
	_sync_minimap()
	if _preset_status != null:
		_preset_status.text = "已按默认阵型一字排开（侧舷平行，紧凑多行）"


func _footprint_cells(x: int, y: int, length: int, facing: String) -> Array[Vector2i]:
	# 舰船占格：船头在前，舰体向后延伸（与 C# FootprintCells 同口径：bow - facing * i）。
	var direction: Vector2i = {"east": Vector2i(1, 0), "west": Vector2i(-1, 0), "north": Vector2i(0, -1), "south": Vector2i(0, 1)}.get(facing, Vector2i(1, 0))
	var cells: Array[Vector2i] = []
	for i in range(maxi(1, length)):
		cells.append(Vector2i(x, y) - direction * i)
	return cells


func _cells_in_zone(cells: Array[Vector2i]) -> bool:
	var zone := _formation_zone()
	for cell in cells:
		if cell.x < zone.position.x or cell.x >= zone.end.x or cell.y < zone.position.y or cell.y >= zone.end.y:
			return false
	return true


func _cells_free(cells: Array[Vector2i], exclude_id: String) -> bool:
	for ship_id in _placements:
		if ship_id == exclude_id:
			continue
		var p := _placements[ship_id] as Dictionary
		var other := _footprint_cells(int(p.get("x", 0)), int(p.get("y", 0)), _naval_length(str(_type_by_id.get(ship_id, ""))), str(p.get("facing", "east")))
		for other_cell in other:
			if cells.has(other_cell):
				return false
	return true


# --- 测试钩子（headless 测试用） ---

func fleet_preset_names_for_test() -> Array[String]:
	var names: Array[String] = []
	var store := _read_fleet_preset_store()
	for name in (store["presets"] as Dictionary):
		names.append(str(name))
	return names


func active_fleet_preset_for_test() -> String:
	return str(_read_fleet_preset_store()["active"])


func save_fleet_preset_for_test(preset_name: String) -> bool:
	_preset_name.text = preset_name
	_save_fleet_preset()
	return fleet_preset_names_for_test().has(preset_name)


func load_fleet_preset_for_test(preset_name: String) -> bool:
	_load_fleet_preset(preset_name)
	return active_fleet_preset_for_test() == preset_name


func delete_fleet_preset_for_test(preset_name: String) -> bool:
	_delete_fleet_preset(preset_name)
	return not fleet_preset_names_for_test().has(preset_name)


# CHG-20260818：舰队配置页签测试钩子（勾选 / 摆位 / 阵型读取，供 test_fleet_formation.gd 驱动）。

func checked_ship_ids_for_test() -> Array[String]:
	# 当前勾选出战的舰 id（economy 顺序，与保存预设 Ships 顺序一致）。
	var ids: Array[String] = []
	for ship in _ships:
		if _checked.get(str(ship.get("id", "")), false):
			ids.append(str(ship.get("id", "")))
	return ids


func set_ship_checked_for_test(ship_id: String, checked: bool) -> void:
	# 逐舰勾选/取消出战（等价于点击勾选框），并重绘小地图。
	if not _checked.has(ship_id):
		return
	_checked[ship_id] = checked
	if _fleet_check_buttons.has(ship_id):
		(_fleet_check_buttons[ship_id] as CheckButton).button_pressed = checked
	_on_ship_check_toggled(checked, ship_id)


func fleet_formation_for_test() -> Array:
	# 当前编辑器阵型（按勾选顺序 = Slot）——与保存预设 Formation 数组同构。
	var ids := checked_ship_ids_for_test()
	var formation := []
	for i in range(ids.size()):
		var placement = _placements.get(ids[i], {}) as Dictionary
		if placement.is_empty():
			continue
		formation.append({"Slot": i, "X": int(placement.get("x", 0)), "Y": int(placement.get("y", 0)), "Facing": str(placement.get("facing", "east"))})
	return formation


func place_ship_at_for_test(ship_id: String, x: int, y: int, facing: String) -> bool:
	# 直接摆位（测试用，等价于小地图放置）并同步重绘。
	if not _checked.get(ship_id, false):
		return false
	_placements[ship_id] = {"x": x, "y": y, "facing": facing}
	_sync_minimap()
	return true


func placement_of_ship_for_test(ship_id: String) -> Dictionary:
	# 单舰当前阵型（副本），未摆位返回空字典。
	return (_placements.get(ship_id, {}) as Dictionary).duplicate(true)


func apply_default_formation_for_test() -> void:
	apply_default_formation()


# CHG-20260819（F-3）：小地图阵型编辑器测试钩子。

func formation_zone_for_test() -> Rect2i:
	# 玩家布阵区（与 C# PlayerZone 同源；供「缩小后预设仍能落入战斗布阵区」校验）。
	return _formation_zone()


func formation_zone_cell_size_for_test() -> int:
	# 小地图单格像素（供贴图可读性/布局校验）。
	return FORMATION_CELL_SIZE


func minimap_block_type_for_test(ship_id: String) -> String:
	# 小地图当前该舰块的经济舰型（供「按舰型贴图」校验；未显示返回 ""）。
	if _minimap == null or not _minimap.blocks.has(ship_id):
		return ""
	return str((_minimap.blocks[ship_id] as Dictionary).get("type", ""))


func minimap_ship_texture_path_for_test(ship_id: String) -> String:
	# 小地图该舰块当前渲染用的贴图路径（与 SHIP_ICONS 一致；无贴图返回 ""）。
	var type_id := minimap_block_type_for_test(ship_id)
	if type_id.is_empty():
		return ""
	var tex: Texture2D = SHIP_ICONS.get(type_id)
	return tex.resource_path if tex != null else ""


func minimap_tooltip_for_test(ship_id: String) -> String:
	# 小地图舰块右键悬停提示文本（如「护卫舰 3 号」；未命中/无提示返回 ""）。
	# 悬停提示定位锚点 = 该舰船头格中心（与右键命中同口径）。
	if _minimap == null or _minimap_tooltip == null or not _placements.has(ship_id):
		return ""
	var p := _placements[ship_id] as Dictionary
	var px := int(p.get("x", 0))
	var py := int(p.get("y", 0))
	var cell_center := Vector2(
		_minimap.grid_origin.x + (px - FORMATION_ZONE_X + 0.5) * _minimap.cell_size,
		_minimap.grid_origin.y + (py - FORMATION_ZONE_Y + 0.5) * _minimap.cell_size)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = cell_center
	_on_minimap_input(event)
	return _minimap_tooltip.text if _minimap_tooltip.visible else ""


func fleet_preset_formation_for_test(preset_name: String) -> Array:
	# 读已保存预设文件里的 Formation 数组。
	var store := _read_fleet_preset_store()
	var presets: Dictionary = store["presets"]
	if not presets.has(preset_name):
		return []
	return (presets[preset_name] as Dictionary).get("Formation", []) as Array


# --- CHG-20260818：小地图阵型编辑器自绘控件（格子 + 舰块） ---
# 内类自含颜色与占格计算（与 C# FootprintCells 同口径：bow - facing * i），不引用外脚本实例成员。

class FormationGrid:
	extends Control

	var zone_x := 1
	var zone_y := 12
	var zone_w := 12
	var zone_h := 10
	var cell_size := 20
	var grid_origin := Vector2(4, 4)
	var blocks: Dictionary = {}  # ship_id -> {x, y, facing, len, type}
	var active_id := ""
	# CHG-20260819（F-3）：经济舰型 → 舰船贴图（由外层 ship_screen 注入 SHIP_ICONS；内类自含绘制不引外实例）。
	var textures: Dictionary = {}

	func screen_to_cell(local_pos: Vector2) -> Vector2i:
		# 局部坐标 → 海战布阵坐标（网格整体映射布阵区：格 i,j ↔ 海战 (zone_x+i, zone_y+j)；超出网格返回 (-1,-1)）。
		var cx := floori((local_pos.x - grid_origin.x) / cell_size)
		var cy := floori((local_pos.y - grid_origin.y) / cell_size)
		if cx < 0 or cy < 0 or cx >= zone_w or cy >= zone_h:
			return Vector2i(-1, -1)
		return Vector2i(zone_x + cx, zone_y + cy)

	func _cell_rect(x: int, y: int) -> Rect2:
		return Rect2(grid_origin.x + x * cell_size, grid_origin.y + y * cell_size, cell_size, cell_size)

	func _ship_cells(x: int, y: int, length: int, facing: String) -> Array[Vector2i]:
		var direction: Vector2i = {"east": Vector2i(1, 0), "west": Vector2i(-1, 0), "north": Vector2i(0, -1), "south": Vector2i(0, 1)}.get(facing, Vector2i(1, 0))
		var cells: Array[Vector2i] = []
		for i in range(maxi(1, length)):
			cells.append(Vector2i(x, y) - direction * i)
		return cells

	func _draw() -> void:
		# 网格整体即玩家布阵区（zone_x/y 是海战布阵区原点，不参与绘制偏移）。
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.045, 0.04, 0.92), true)
		for gy in range(zone_h):
			for gx in range(zone_w):
				draw_rect(_cell_rect(gx, gy), Color(0.16, 0.24, 0.20, 0.35), false, 1.0)
		# 布阵区边框（整个网格）。
		draw_rect(Rect2(grid_origin, Vector2(zone_w * cell_size, zone_h * cell_size)), Color(0.36, 0.68, 0.58, 0.70), false, 1.0)
		for ship_id in blocks:
			var block: Dictionary = blocks[ship_id]
			var cells := _ship_cells(
				int(block.get("x", 0)), int(block.get("y", 0)),
				int(block.get("len", 1)), str(block.get("facing", "east")))
			# 舰脚外接矩形（覆盖全部占格；海战坐标 → 网格索引再取矩形）。
			var union := _cell_rect(cells[0].x - zone_x, cells[0].y - zone_y)
			for i in range(1, cells.size()):
				union = union.merge(_cell_rect(cells[i].x - zone_x, cells[i].y - zone_y))
			union = union.grow(-1.0)
			var tex: Texture2D = textures.get(str(block.get("type", "")))
			if tex != null:
				# 贴图按脚矩形成比例居中（保持长宽比，避免拉伸变形）。
				var scale := minf(union.size.x / float(maxi(1, tex.get_width())), union.size.y / float(maxi(1, tex.get_height())))
				var draw_size := Vector2(tex.get_width() * scale, tex.get_height() * scale)
				var offset := union.position + (union.size - draw_size) * 0.5
				var tint := Color(1.0, 1.0, 1.0, 1.0) if ship_id == active_id else Color(0.82, 0.86, 0.82, 0.96)
				draw_texture_rect(tex, Rect2(offset, draw_size), false, tint)
			else:
				# 无贴图回退：统一色块。
				draw_rect(union, Color(0.96, 0.78, 0.28, 0.95) if ship_id == active_id else Color(0.16, 0.42, 0.34, 0.9), true)
			# 脚边轮廓 + 选中高亮（金框）。
			draw_rect(union, Color(0.02, 0.04, 0.035, 1.0), false, 1.0)
			if ship_id == active_id:
				draw_rect(union.grow(1.0), Color(0.96, 0.78, 0.28, 0.95), false, 2.0)
