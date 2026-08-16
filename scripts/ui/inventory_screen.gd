class_name InventoryScreen
extends Control

signal close_requested

const CATALOG := preload("res://scripts/economy/item_catalog.gd")
const INK_BUTTON_NORMAL := preload("res://assets/ui/sea_overworld/interaction_button_ink_v1.png")
const INK_BUTTON_ACTIVE := preload("res://assets/ui/sea_overworld/interaction_button_ink_active_v1.png")
const COIN_ICON := preload("res://assets/ui/paper/PNGs/Icons/GameIcons/IconCoin.png")
const FLEET_ICON := preload("res://assets/ui/icons/hud_ship.png")
const ITEM_ICON_DIR := "res://assets/ui/merchant_shop/items/icons/"
const SHIP_ICON_DIR := "res://assets/ui/merchant_shop/ships/"
const FIRST_SCREEN_SLOT_COUNT := 12
const ITEM_ICONS := {
	"wood": ITEM_ICON_DIR + "wood.png",
	"ironstone": ITEM_ICON_DIR + "ironstone.png",
	"yellow_croaker": ITEM_ICON_DIR + "yellow_croaker.png",
	"grouper": ITEM_ICON_DIR + "grouper.png",
	"green_crab": ITEM_ICON_DIR + "green_crab.png",
	"old_boot": ITEM_ICON_DIR + "old_boot.png",
	"longjing_tea": ITEM_ICON_DIR + "longjing_tea.png",
	"private_salt": ITEM_ICON_DIR + "private_salt.png",
}
const SHIP_ICONS := {
	"patrol_boat": SHIP_ICON_DIR + "patrol_boat.png",
	"cannon_warship": SHIP_ICON_DIR + "cannon_warship.png",
	"escort_junk": SHIP_ICON_DIR + "escort_junk.png",
}
const FILTERS := [
	["全部", "all"],
	["材料", "material"],
	["岭南特产", "specialty"],
	["海上货物", "cargo"],
	["造船图纸", "blueprint"],
]
const SORT_MODES := ["类型优先", "数量优先", "名称排序"]
const CATEGORY_NAMES := {
	"material": "造船材料",
	"specialty": "岭南特产",
	"cargo": "海上货物",
	"misc": "海上杂物",
	"blueprint": "造船图纸",
}
const CATEGORY_COLORS := {
	"material": Color("#b98a43"),
	"specialty": Color("#6fa994"),
	"cargo": Color("#9382b8"),
	"misc": Color("#837c6d"),
	"blueprint": Color("#d2a84f"),
}
const ITEM_DETAILS := {
	"wood": ["晾晒整齐的造船木料。", "建造各类舰船，也可在月环货栈交易。"],
	"ironstone": ["用于铸造船钉与武备的铁料。", "建造各类舰船，也可在月环货栈交易。"],
	"yellow_croaker": ["近海常见的鲜活黄花鱼。", "岭南渔获，可在月环货栈出售。"],
	"grouper": ["肉质肥厚的大型石斑鱼。", "稀有渔获，可在月环货栈换取军饷。"],
	"green_crab": ["青壳有力的岭南海蟹。", "岭南渔获，可在月环货栈出售。"],
	"old_boot": ["被海水泡旧的靴子，仍有人愿意收。", "海上杂物，可在月环货栈折价出售。"],
	"longjing_tea": ["封装完好的江南茶货。", "贸易货物，可在月环货栈出售。"],
	"private_salt": ["来路隐秘的成包海盐。", "贸易货物，可在月环货栈出售。"],
}

var _canvas: Control
var _grid: GridContainer
var _detail_preview: TextureRect
var _detail_name: Label
var _detail_type: Label
var _detail_description: RichTextLabel
var _detail_source: Label
var _detail_use: Label
var _pay: Label
var _fleet: Label
var _sort_button: OptionButton
var _filter_tabs: HBoxContainer
var _filter_buttons: Array[Button] = []
var _filter := "all"
var _sort_mode := 0
var _selected_entry := ""


func _ready() -> void:
	_build()
	hide()


func show_screen() -> void:
	_filter = "all"
	_sort_mode = 0
	_sort_button.select(0)
	_update_filter_states()
	_refresh()
	show()


func selected_entry_for_test() -> String:
	return _selected_entry


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_requested.emit()
		return
	if event is InputEventKey:
		var key := (event as InputEventKey).keycode
		if key >= KEY_1 and key <= KEY_5:
			_set_filter(str(FILTERS[key - KEY_1][1]))


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.016, 0.014, 0.90)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var frame := PanelContainer.new()
	frame.name = "InventoryFrame"
	frame.position = Vector2(8, 8)
	frame.size = Vector2(1328, 880)
	frame.add_theme_stylebox_override("panel", _flat(Color("#0a1513f8"), Color("#a77a34"), 3, 7, 0))
	add_child(frame)

	_canvas = Control.new()
	_canvas.name = "InventoryCanvas"
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(_canvas)

	_add_panel("HeaderPanel", Vector2(16, 16), Vector2(1296, 88), Color("#13231fff"), Color("#73562f"), 1)
	_add_panel("InventoryPanel", Vector2(16, 162), Vector2(856, 632), Color("#0d1917f4"), Color("#72562f"), 1)
	_add_panel("DetailPanel", Vector2(888, 116), Vector2(424, 678), Color("#c7b586ff"), Color("#a37531"), 2)

	var title := Label.new()
	title.position = Vector2(48, 29)
	title.size = Vector2(430, 54)
	title.text = "水 师 大 仓"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#ead7a6"))
	title.add_theme_color_override("font_shadow_color", Color("#000000aa"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	_canvas.add_child(title)

	var close := Button.new()
	close.name = "CloseButton"
	close.position = Vector2(1138, 35)
	close.size = Vector2(146, 48)
	close.text = "关闭仓库  Esc"
	_style_ink_button(close, 16, 18.0, 8.0)
	close.pressed.connect(close_requested.emit)
	_canvas.add_child(close)

	_build_filter_tabs()
	_build_grid_area()
	_build_detail_area()
	_build_footer()
func _add_panel(node_name: String, panel_position: Vector2, panel_size: Vector2, background: Color, border: Color, width: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.position = panel_position
	panel.size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _flat(background, border, width, 4, 0))
	_canvas.add_child(panel)
	return panel


func _build_filter_tabs() -> void:
	_filter_tabs = HBoxContainer.new()
	_filter_tabs.name = "FilterTabs"
	_filter_tabs.position = Vector2(28, 112)
	_filter_tabs.size = Vector2(832, 44)
	_filter_tabs.add_theme_constant_override("separation", 4)
	_canvas.add_child(_filter_tabs)
	for spec in FILTERS:
		var button := Button.new()
		button.name = "Filter_%s" % str(spec[1])
		button.text = str(spec[0])
		button.custom_minimum_size = Vector2(163, 44)
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", Color("#bfb69f"))
		button.add_theme_color_override("font_hover_color", Color("#ffe1a0"))
		button.add_theme_color_override("font_pressed_color", Color("#ffe7ad"))
		button.pressed.connect(_set_filter.bind(str(spec[1])))
		_filter_tabs.add_child(button)
		_filter_buttons.append(button)
	_update_filter_states()


func _build_grid_area() -> void:
	var grid_title := Label.new()
	grid_title.name = "GridTitle"
	grid_title.position = Vector2(45, 181)
	grid_title.size = Vector2(260, 46)
	grid_title.text = "库藏"
	grid_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	grid_title.add_theme_font_size_override("font_size", 22)
	grid_title.add_theme_color_override("font_color", Color("#d6c69c"))
	_canvas.add_child(grid_title)

	_sort_button = OptionButton.new()
	_sort_button.name = "SortButton"
	_sort_button.position = Vector2(654, 184)
	_sort_button.size = Vector2(190, 40)
	for label in SORT_MODES:
		_sort_button.add_item(label)
	_sort_button.add_theme_font_size_override("font_size", 15)
	_sort_button.add_theme_color_override("font_color", Color("#d8cfb8"))
	_sort_button.add_theme_stylebox_override("normal", _flat(Color("#17231fff"), Color("#795d32"), 1, 3, 8))
	_sort_button.add_theme_stylebox_override("hover", _flat(Color("#263b34ff"), Color("#c69a48"), 2, 3, 8))
	_sort_button.item_selected.connect(_set_sort_mode)
	_canvas.add_child(_sort_button)

	var divider := ColorRect.new()
	divider.position = Vector2(44, 230)
	divider.size = Vector2(800, 1)
	divider.color = Color("#81643888")
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(divider)

	var scroll := ScrollContainer.new()
	scroll.name = "ItemScroll"
	scroll.position = Vector2(42, 247)
	scroll.size = Vector2(824, 525)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_theme_stylebox_override("panel", _flat(Color("#00000000"), Color("#00000000"), 0, 0, 0))
	_canvas.add_child(scroll)

	_grid = GridContainer.new()
	_grid.name = "ItemGrid"
	_grid.columns = 6
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)


func _build_detail_area() -> void:
	_detail_preview = TextureRect.new()
	_detail_preview.name = "ItemPreview"
	_detail_preview.position = Vector2(982, 142)
	_detail_preview.size = Vector2(232, 216)
	_detail_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_detail_preview)

	_detail_name = Label.new()
	_detail_name.name = "DetailName"
	_detail_name.position = Vector2(920, 365)
	_detail_name.size = Vector2(356, 44)
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_name.add_theme_font_size_override("font_size", 28)
	_detail_name.add_theme_color_override("font_color", Color("#29231a"))
	_canvas.add_child(_detail_name)

	_detail_type = Label.new()
	_detail_type.name = "DetailType"
	_detail_type.position = Vector2(1012, 414)
	_detail_type.size = Vector2(172, 34)
	_detail_type.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_type.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail_type.add_theme_font_size_override("font_size", 16)
	_detail_type.add_theme_color_override("font_color", Color("#3a3022"))
	_detail_type.add_theme_stylebox_override("normal", _flat(Color("#b5a16eff"), Color("#86652f"), 1, 3, 6))
	_canvas.add_child(_detail_type)

	var rule := ColorRect.new()
	rule.position = Vector2(920, 462)
	rule.size = Vector2(356, 1)
	rule.color = Color("#80653299")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(rule)

	_detail_description = RichTextLabel.new()
	_detail_description.name = "DetailDescription"
	_detail_description.position = Vector2(920, 482)
	_detail_description.size = Vector2(356, 58)
	_detail_description.bbcode_enabled = true
	_detail_description.fit_content = false
	_detail_description.scroll_active = false
	_detail_description.add_theme_font_size_override("normal_font_size", 18)
	_detail_description.add_theme_color_override("default_color", Color("#2e281f"))
	_canvas.add_child(_detail_description)

	_detail_use = Label.new()
	_detail_use.name = "DetailUse"
	_detail_use.position = Vector2(920, 558)
	_detail_use.size = Vector2(356, 92)
	_detail_use.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_use.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_detail_use.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_detail_use.add_theme_font_size_override("font_size", 17)
	_detail_use.add_theme_color_override("font_color", Color("#342d22"))
	_canvas.add_child(_detail_use)

	_detail_source = Label.new()
	_detail_source.name = "DetailSource"
	_detail_source.position = Vector2(920, 670)
	_detail_source.size = Vector2(356, 96)
	_detail_source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_source.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_detail_source.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_detail_source.add_theme_font_size_override("font_size", 15)
	_detail_source.add_theme_color_override("font_color", Color("#42382a"))
	_canvas.add_child(_detail_source)


func _build_footer() -> void:
	var footer := PanelContainer.new()
	footer.name = "FooterBar"
	footer.position = Vector2(16, 810)
	footer.size = Vector2(1296, 54)
	footer.add_theme_stylebox_override("panel", _flat(Color("#12221fff"), Color("#7d6034"), 1, 3, 14))
	_canvas.add_child(footer)

	var row := HBoxContainer.new()
	row.name = "FooterContent"
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 12)
	footer.add_child(row)

	var pay_block := _resource_block("PayBlock", COIN_ICON, 230)
	row.add_child(pay_block)
	_pay = Label.new()
	_pay.name = "PayLabel"
	_pay.add_theme_font_size_override("font_size", 21)
	_pay.add_theme_color_override("font_color", Color("#ead7a6"))
	_pay.custom_minimum_size = Vector2(150, 34)
	_pay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pay_block.add_child(_pay)

	var spacer := Control.new()
	spacer.name = "FooterSpacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var fleet_block := _resource_block("FleetBlock", FLEET_ICON, 245)
	row.add_child(fleet_block)
	_fleet = Label.new()
	_fleet.name = "FleetLabel"
	_fleet.add_theme_font_size_override("font_size", 21)
	_fleet.add_theme_color_override("font_color", Color("#ead7a6"))
	_fleet.custom_minimum_size = Vector2(165, 34)
	_fleet.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fleet_block.add_child(_fleet)


func _resource_block(node_name: String, icon_texture: Texture2D, minimum_width: float) -> HBoxContainer:
	var block := HBoxContainer.new()
	block.name = node_name
	block.custom_minimum_size = Vector2(minimum_width, 38)
	block.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	block.add_child(icon)
	return block


func _refresh() -> void:
	_clear_grid()
	var state: Dictionary = get_node("/root/GameState").call("get_economy_state")
	_pay.text = "军饷  %d" % int(state["pay"])
	_fleet.text = "舰队  %d / 10" % (state["ships"] as Array).size()
	var entries := _visible_entries(state)
	_sort_entries(entries)
	for entry in entries:
		_grid.add_child(_make_item_card(entry))
	for index in range(entries.size(), max(FIRST_SCREEN_SLOT_COUNT, entries.size())):
		_grid.add_child(_make_empty_slot(index))
	if entries.is_empty():
		_selected_entry = ""
		_show_empty_detail()
	else:
		_select_entry(entries[0])


func _visible_entries(state: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var items := state["items"] as Dictionary
	for id in items:
		var quantity := int(items[id])
		if quantity <= 0:
			continue
		var item := CATALOG.item(str(id))
		var category := str(item["category"])
		var matches_filter := _filter in ["all", category] or (_filter == "cargo" and category == "misc")
		if not matches_filter:
			continue
		entries.append({
			"id": str(id), "kind": "item", "name": str(item["name"]),
			"category": category, "quantity": quantity, "data": item,
		})
	if _filter in ["all", "blueprint"]:
		for id in state["blueprints"]:
			var ship := CATALOG.ship(str(id))
			entries.append({
				"id": str(id), "kind": "blueprint", "name": "%s图纸" % str(ship["name"]),
				"category": "blueprint", "quantity": 1, "data": ship,
			})
	return entries


func _sort_entries(entries: Array[Dictionary]) -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if _sort_mode == 1 and int(a["quantity"]) != int(b["quantity"]):
			return int(a["quantity"]) > int(b["quantity"])
		if _sort_mode == 2:
			return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0
		var category_order := {"material": 0, "specialty": 1, "cargo": 2, "misc": 3, "blueprint": 4}
		var a_rank := int(category_order.get(str(a["category"]), 9))
		var b_rank := int(category_order.get(str(b["category"]), 9))
		if a_rank != b_rank:
			return a_rank < b_rank
		return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0
	)


func _make_item_card(entry: Dictionary) -> Button:
	var category := str(entry["category"])
	var accent := CATEGORY_COLORS.get(category, Color("#8d8066")) as Color
	var card := Button.new()
	card.name = "Item_%s" % str(entry["id"])
	card.custom_minimum_size = Vector2(126, 220)
	card.toggle_mode = true
	card.tooltip_text = str(entry["name"])
	card.add_theme_stylebox_override("normal", _flat(Color("#111f1cff"), accent.darkened(0.35), 1, 4, 4))
	card.add_theme_stylebox_override("hover", _flat(Color("#1b302aff"), accent, 2, 4, 4))
	card.add_theme_stylebox_override("pressed", _flat(Color("#24362fff"), Color("#e0b45b"), 3, 4, 4))
	card.add_theme_stylebox_override("hover_pressed", _flat(Color("#293e36ff"), Color("#efc36b"), 3, 4, 4))
	card.add_theme_stylebox_override("focus", _flat(Color("#24362fff"), Color("#e0b45b"), 3, 4, 4))
	card.focus_mode = Control.FOCUS_ALL

	var icon := TextureRect.new()
	icon.name = "ItemIcon"
	icon.position = Vector2(10, 16)
	icon.size = Vector2(106, 142)
	icon.texture = load(_icon_path(entry)) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(icon)

	var name_label := Label.new()
	name_label.name = "ItemName"
	name_label.position = Vector2(6, 170)
	name_label.size = Vector2(114, 36)
	name_label.text = str(entry["name"])
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color("#e7dcc3"))
	name_label.add_theme_color_override("font_shadow_color", Color("#000000cc"))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_label)

	var quantity := Label.new()
	quantity.name = "QuantityBadge"
	quantity.position = Vector2(76, 132)
	quantity.size = Vector2(42, 28)
	quantity.text = "×%d" % int(entry["quantity"])
	quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	quantity.add_theme_font_size_override("font_size", 16)
	quantity.add_theme_color_override("font_color", Color.WHITE)
	quantity.add_theme_color_override("font_outline_color", Color("#08100eff"))
	quantity.add_theme_constant_override("outline_size", 3)
	quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(quantity)

	card.pressed.connect(_select_entry.bind(entry))
	return card


func _make_empty_slot(index: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.name = "EmptySlot_%02d" % index
	slot.custom_minimum_size = Vector2(126, 220)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _flat(Color("#0b1614a6"), Color("#4f493a73"), 1, 4, 3))
	return slot


func _select_entry(entry: Dictionary) -> void:
	_selected_entry = str(entry["id"])
	for child in _grid.get_children():
		if child is Button:
			(child as Button).button_pressed = child.name == "Item_%s" % _selected_entry
	_detail_preview.texture = load(_icon_path(entry)) as Texture2D
	_detail_name.text = str(entry["name"])
	var category := str(entry["category"])
	_detail_type.text = str(CATEGORY_NAMES.get(category, "物品"))
	if str(entry["kind"]) == "blueprint":
		var ship := entry["data"] as Dictionary
		_detail_description.text = "已永久收录于水师船册。"
		_detail_use.text = "用途  前往月环船行，备齐军饷、木材与铁石后可重复建造。"
		_detail_source.text = "建造需求  军饷 %d · 木材 %d · 铁石 %d" % [int(ship["pay"]), int(ship["wood"]), int(ship["ironstone"])]
	else:
		var item := entry["data"] as Dictionary
		var details: Array = ITEM_DETAILS.get(_selected_entry, ["岭南水师收存的物资。", "可在对应玩法中使用或交易。"] ) as Array
		_detail_description.text = str(details[0])
		_detail_use.text = "用途  %s" % str(details[1])
		_detail_source.text = "来源  %s" % str(item["source"])


func _show_empty_detail() -> void:
	_detail_preview.texture = null
	_detail_name.text = "暂无物品"
	_detail_type.text = ""
	_detail_description.text = "当前分类尚无收存物品。"
	_detail_use.text = ""
	_detail_source.text = ""


func _icon_path(entry: Dictionary) -> String:
	if str(entry["kind"]) == "blueprint":
		return str(SHIP_ICONS.get(str(entry["id"]), ""))
	return str(ITEM_ICONS.get(str(entry["id"]), ""))


func _set_filter(value: String) -> void:
	_filter = value
	_update_filter_states()
	_refresh()


func _set_sort_mode(index: int) -> void:
	_sort_mode = index
	_refresh()


func _update_filter_states() -> void:
	for index in _filter_buttons.size():
		var button := _filter_buttons[index]
		var selected := str(FILTERS[index][1]) == _filter
		if selected:
			button.add_theme_stylebox_override("normal", _tab_style(Color("#1b2b27ff"), Color("#d5a94f"), 4))
			button.add_theme_stylebox_override("hover", _tab_style(Color("#21342eff"), Color("#e2b75d"), 4))
			button.add_theme_stylebox_override("pressed", _tab_style(Color("#263b34ff"), Color("#f0c56c"), 4))
			button.add_theme_stylebox_override("focus", _tab_style(Color("#1b2b27ff"), Color("#d5a94f"), 4))
		else:
			button.add_theme_stylebox_override("normal", _tab_style(Color("#101d1ad9"), Color("#564329"), 1))
			button.add_theme_stylebox_override("hover", _tab_style(Color("#1d302bee"), Color("#a77a34"), 2))
			button.add_theme_stylebox_override("pressed", _tab_style(Color("#263b34ff"), Color("#d5a94f"), 3))
			button.add_theme_stylebox_override("focus", _tab_style(Color("#1d302bee"), Color("#a77a34"), 2))


func _clear_grid() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()


func _style_ink_button(button: Button, font_size: int, horizontal_margin: float, vertical_margin: float) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("#d8cfb8"))
	button.add_theme_color_override("font_hover_color", Color("#ffe4a1"))
	button.add_theme_color_override("font_pressed_color", Color("#fff0bc"))
	button.add_theme_stylebox_override("normal", _ink_style(INK_BUTTON_NORMAL, Color.WHITE, horizontal_margin, vertical_margin))
	button.add_theme_stylebox_override("hover", _ink_style(INK_BUTTON_ACTIVE, Color.WHITE, horizontal_margin, vertical_margin))
	button.add_theme_stylebox_override("focus", _ink_style(INK_BUTTON_ACTIVE, Color.WHITE, horizontal_margin, vertical_margin))
	button.add_theme_stylebox_override("pressed", _ink_style(INK_BUTTON_ACTIVE, Color("#e9d39d"), horizontal_margin, vertical_margin))


func _ink_style(texture: Texture2D, tint: Color, horizontal_margin: float, vertical_margin: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = tint
	style.content_margin_left = horizontal_margin
	style.content_margin_right = horizontal_margin
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	return style


func _tab_style(background: Color, border: Color, bottom_width: int) -> StyleBoxFlat:
	var style := _flat(background, border, 0, 3, 6)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = bottom_width
	return style


func _flat(background: Color, border: Color, width: int, radius: int, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style
