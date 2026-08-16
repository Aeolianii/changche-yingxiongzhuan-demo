class_name ShipScreen
extends Control

const CATALOG := preload("res://scripts/economy/item_catalog.gd")
const ECONOMY := preload("res://scripts/economy/economy_state.gd")
const QUEST_BACKGROUND := preload("res://assets/ui/quest_screen/quest_screen_background.png")
const FUNCTION_BUTTON_FRAME := preload("res://assets/ui/exploration_hud/function_button.png")
const RETURN_ICON := preload("res://assets/ui/icons/menu_return_title.png")
const SCROLLBAR_SHEET := preload("res://assets/ui/ship_screen/ship_scrollbar_sheet_v1.png")
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
var _crew_label: Label
var _construction_label: Label

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
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.clip_contents = true
	add_child(scroll)
	_style_ship_scrollbar(scroll.get_v_scroll_bar())

	_ship_list = VBoxContainer.new()
	_ship_list.name = "ShipList"
	_ship_list.custom_minimum_size = Vector2(352, 0)
	_ship_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_list.add_theme_constant_override("separation", 10)
	_ship_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_ship_list)


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
	_stats.position = Vector2(544, 624)
	_stats.size = Vector2(718, 92)
	_stats.add_theme_constant_override("h_separation", 10)
	_stats.add_theme_constant_override("v_separation", 8)
	_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stats)

	_crew_label = _make_label("", 16, TEXT_LIGHT)
	_crew_label.name = "CrewLabel"
	_crew_label.position = Vector2(548, 738)
	_crew_label.size = Vector2(340, 28)
	add_child(_crew_label)

	_construction_label = _make_label("", 15, TEXT_MUTED)
	_construction_label.name = "ConstructionLabel"
	_construction_label.position = Vector2(548, 774)
	_construction_label.size = Vector2(710, 30)
	add_child(_construction_label)


func _select_ship(index: int) -> void:
	if index < 0 or index >= _ships.size():
		return
	_selected_index = index
	_refresh_selectors()
	_refresh_detail()


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
		return

	var ship := _ships[_selected_index]
	var type_id := str(ship.get("type_id", ""))
	var definition := CATALOG.ship(type_id)
	var current_hp := int(ship.get("current_hp", definition.get("max_hp", 1)))
	var max_hp := maxi(1, int(ship.get("max_hp", definition.get("max_hp", 1))))
	_preview.texture = SHIP_ICONS.get(type_id) as Texture2D
	_detail_name.text = "[color=#f1c24f]%s[/color]" % str(definition.get("name", "未知舰船"))
	_detail_role.text = "【%s】" % str(definition.get("role", "未分类"))
	_detail_id.text = "舰号  %s　·　编制序列  %s" % [_ship_number(str(ship.get("id", ""))), str(ship.get("id", ""))]
	_description.text = str(definition.get("description", "暂无舰船说明。"))
	_durability.max_value = max_hp
	_durability.value = clampi(current_hp, 0, max_hp)
	_durability_label.text = "%d / %d" % [current_hp, max_hp]
	_rebuild_stats(definition)
	_crew_label.text = "核定编制　%d 人" % int(definition.get("crew", 0))
	_construction_label.text = "建造需求　军饷 %d　·　木材 %d　·　铁石 %d" % [int(definition.get("pay", 0)), int(definition.get("wood", 0)), int(definition.get("ironstone", 0))]


func _rebuild_stats(definition: Dictionary) -> void:
	_clear_stats()
	for data in [
		["火力", int(definition.get("firepower", 0))],
		["航速", int(definition.get("speed", 0))],
		["装甲", int(definition.get("armor", 0))],
		["载货", int(definition.get("cargo", 0))],
	]:
		_stats.add_child(_make_stat_card(str(data[0]), int(data[1])))


func _clear_stats() -> void:
	for child in _stats.get_children():
		_stats.remove_child(child)
		child.queue_free()


func _make_stat_card(title: String, value: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(172, 86)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _flat_style(PANEL_INK, Color(GOLD.r, GOLD.g, GOLD.b, 0.34), 1))
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stack)
	var title_label := _make_label(title, 15, TEXT_MUTED)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title_label)
	var value_label := _make_label("%d / 5" % value, 23, GOLD_BRIGHT)
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
	scrollbar.custom_minimum_size.x = 24.0
	scrollbar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scrollbar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var track := _scrollbar_atlas(Rect2(440, 0, 144, 1120))
	var thumb := _scrollbar_atlas(Rect2(440, 1152, 144, 384))
	scrollbar.add_theme_stylebox_override("scroll", _scrollbar_style(track))
	scrollbar.add_theme_stylebox_override("scroll_focus", _scrollbar_style(track))
	scrollbar.add_theme_stylebox_override("grabber", _scrollbar_style(thumb))
	scrollbar.add_theme_stylebox_override("grabber_highlight", _scrollbar_style(thumb, Color(1.12, 1.08, 0.92, 1.0)))
	scrollbar.add_theme_stylebox_override("grabber_pressed", _scrollbar_style(thumb, Color(1.18, 1.08, 0.74, 1.0)))


func _scrollbar_atlas(region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = SCROLLBAR_SHEET
	texture.region = region
	return texture


func _scrollbar_style(texture: Texture2D, tint := Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = tint
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
