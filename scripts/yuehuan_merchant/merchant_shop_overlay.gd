class_name YuehuanMerchantShopOverlay
extends Control

signal closed

const CATALOG := preload("res://scripts/economy/item_catalog.gd")
const ITEM_ICON_DIR := "res://assets/ui/merchant_shop/items/icons/"
const SHIP_ICON_DIR := "res://assets/ui/merchant_shop/ships/"
const ICON_PATHS := {
	"wood": ITEM_ICON_DIR + "wood.png", "ironstone": ITEM_ICON_DIR + "ironstone.png",
	"yellow_croaker": ITEM_ICON_DIR + "yellow_croaker.png", "grouper": ITEM_ICON_DIR + "grouper.png",
	"green_crab": ITEM_ICON_DIR + "green_crab.png", "old_boot": ITEM_ICON_DIR + "old_boot.png",
	"longjing_tea": ITEM_ICON_DIR + "longjing_tea.png", "private_salt": ITEM_ICON_DIR + "private_salt.png",
	"patrol_boat": SHIP_ICON_DIR + "patrol_boat.png", "cannon_warship": SHIP_ICON_DIR + "cannon_warship.png",
	"escort_junk": SHIP_ICON_DIR + "escort_junk.png",
}
const COIN_ICON := "res://assets/ui/paper/PNGs/Icons/GameIcons/IconCoin.png"
const INK_BUTTON_NORMAL := preload("res://assets/ui/sea_overworld/interaction_button_ink_v1.png")
const INK_BUTTON_ACTIVE := preload("res://assets/ui/sea_overworld/interaction_button_ink_active_v1.png")
const PAPER := Color("#d9cfb2")
const PAPER_LIGHT := Color("#e7ddc2")
const INK := Color("#292720")
const MUTED := Color("#716958")
const OLD_WHITE := Color("#d8cfb8")
const GOLD := Color("#bd8b38")
const DEEP := Color("#111b1a")

var _role := ""
var _mode := "goods"
var _selected_id := "wood"
var _title_label: Label
var _header_portrait: TextureRect
var _tabs: HBoxContainer
var _shop_shelf: VBoxContainer
var _holding_label: Label
var _preview: TextureRect
var _detail_name: Label
var _detail_text: RichTextLabel
var _quantity: SpinBox
var _quantity_controls: HBoxContainer
var _buy_button: Button
var _sell_button: Button
var _sell_all_button: Button
var _total_label: Label
var _after_trade_label: Label
var _resource_blocks: HBoxContainer
var _status: Label
var _product_group: ButtonGroup


func _ready() -> void:
	_build_ui()
	hide()


func open_shop(role: String, title: String) -> void:
	_role = role
	_mode = "goods" if role == "goods" else "blueprints"
	_selected_id = "wood" if role == "goods" else "patrol_boat"
	_title_label.text = title
	_refresh_header_portrait()
	_status.text = ""
	_refresh()
	show()


func close_shop() -> void:
	if visible:
		hide()
		closed.emit()


func active_role() -> String:
	return _role if visible else ""


func icon_path_for_test(item_id: String) -> String:
	return str(ICON_PATHS.get(item_id, ""))


func shop_contains_for_test(item_id: String) -> bool:
	if _role == "goods":
		return item_id in ["wood", "ironstone"]
	if _mode == "blueprints":
		return item_id in CATALOG.SHIPS
	return item_id in (_state()["blueprints"] as Array)


func warehouse_contains_for_test(item_id: String) -> bool:
	var item := CATALOG.item(item_id)
	return _role == "goods" and not item.is_empty() and int(item.get("sell_price", 0)) > 0


func can_buy_for_test(item_id: String) -> bool:
	return _role == "goods" and item_id in ["wood", "ironstone"]


func set_shipbuilding_mode_for_test() -> void:
	_set_mode("shipyard")


func maximum_quantity_for_test(item_id: String) -> int:
	return _maximum_quantity(item_id)


func transaction_preview_for_test(item_id: String, quantity: int) -> Dictionary:
	return _transaction_preview(item_id, quantity)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#091312fa")
	add_child(backdrop)
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 20)
	frame.add_theme_stylebox_override("panel", _panel(Color("#121c1b"), Color("#665333"), 1, 2, 12))
	add_child(frame)
	var root_stack := VBoxContainer.new()
	root_stack.add_theme_constant_override("separation", 10)
	frame.add_child(root_stack)
	_build_header(root_stack)
	_tabs = HBoxContainer.new()
	_tabs.name = "ShopTabs"
	_tabs.add_theme_constant_override("separation", 8)
	root_stack.add_child(_tabs)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root_stack.add_child(body)
	body.add_child(_build_list_panel())
	body.add_child(_build_detail_panel())
	_build_resource_bar(root_stack)


func _build_header(parent: VBoxContainer) -> void:
	var header := PanelContainer.new()
	header.name = "MerchantStage"
	header.custom_minimum_size.y = 76
	header.add_theme_stylebox_override("panel", _bottom_line(Color("#00000000"), Color("#514837"), 1, 8))
	parent.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	header.add_child(row)
	_header_portrait = TextureRect.new()
	_header_portrait.name = "MerchantHeaderPortrait"
	_header_portrait.custom_minimum_size = Vector2(62, 62)
	_header_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_header_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_header_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(_header_portrait)
	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 27)
	_title_label.add_theme_color_override("font_color", OLD_WHITE)
	row.add_child(_title_label)
	var close := Button.new()
	close.name = "CloseButton"
	close.text = "关闭店铺  Esc"
	close.custom_minimum_size = Vector2(140, 44)
	_style_text_button(close)
	close.pressed.connect(close_shop)
	row.add_child(close)


func _build_list_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 610)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 4.0
	panel.add_theme_stylebox_override("panel", _right_line(Color("#00000000"), Color("#514837"), 1, 8))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	_holding_label = Label.new()
	_holding_label.name = "SelectedHolding"
	_holding_label.add_theme_font_size_override("font_size", 16)
	_holding_label.add_theme_color_override("font_color", Color("#a9a08b"))
	stack.add_child(_holding_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)
	_shop_shelf = VBoxContainer.new()
	_shop_shelf.name = "ProductList"
	_shop_shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_shelf.add_theme_constant_override("separation", 4)
	scroll.add_child(_shop_shelf)
	return panel


func _build_detail_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "TransactionStage"
	panel.custom_minimum_size = Vector2(650, 610)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 6.0
	panel.add_theme_stylebox_override("panel", _paper_panel())
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	_preview = TextureRect.new()
	_preview.name = "ItemPreview"
	_preview.custom_minimum_size = Vector2(400, 220)
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	content.add_child(_preview)
	_detail_name = Label.new()
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_name.add_theme_font_size_override("font_size", 28)
	_detail_name.add_theme_color_override("font_color", INK)
	content.add_child(_detail_name)
	_detail_text = RichTextLabel.new()
	_detail_text.bbcode_enabled = true
	_detail_text.fit_content = true
	_detail_text.custom_minimum_size.y = 72
	_detail_text.add_theme_font_size_override("normal_font_size", 17)
	_detail_text.add_theme_color_override("default_color", INK)
	content.add_child(_detail_text)
	_total_label = Label.new()
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_label.add_theme_font_size_override("font_size", 19)
	_total_label.add_theme_color_override("font_color", INK)
	content.add_child(_total_label)
	_after_trade_label = Label.new()
	_after_trade_label.name = "AfterTradePreview"
	_after_trade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_after_trade_label.add_theme_font_size_override("font_size", 16)
	_after_trade_label.add_theme_color_override("font_color", Color("#574f42"))
	content.add_child(_after_trade_label)
	_build_quantity_controls(content)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", MUTED)
	content.add_child(_status)
	return panel


func _build_quantity_controls(parent: VBoxContainer) -> void:
	_quantity_controls = HBoxContainer.new()
	_quantity_controls.name = "QuantityControls"
	_quantity_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	_quantity_controls.add_theme_constant_override("separation", 5)
	parent.add_child(_quantity_controls)
	var decrease := _small_button("−", "QuantityDecreaseButton")
	decrease.custom_minimum_size = Vector2(56, 52)
	decrease.add_theme_font_size_override("font_size", 25)
	decrease.tooltip_text = "数量减一"
	decrease.pressed.connect(_add_quantity.bind(-1))
	_quantity_controls.add_child(decrease)
	_quantity = SpinBox.new()
	_quantity.name = "QuantityInput"
	_quantity.min_value = 0
	_quantity.max_value = 9999
	_quantity.value = 1
	_quantity.update_on_text_changed = true
	_quantity.custom_minimum_size = Vector2(88, 52)
	var transparent_arrow_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	transparent_arrow_image.fill(Color.TRANSPARENT)
	_quantity.add_theme_icon_override("updown", ImageTexture.create_from_image(transparent_arrow_image))
	_quantity.value_changed.connect(_on_quantity_changed)
	_quantity_controls.add_child(_quantity)
	var quantity_edit := _quantity.get_line_edit()
	quantity_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity_edit.editable = true
	quantity_edit.focus_mode = Control.FOCUS_ALL
	quantity_edit.select_all_on_focus = true
	quantity_edit.tooltip_text = "点击后可直接输入数量"
	quantity_edit.add_theme_font_size_override("font_size", 22)
	quantity_edit.add_theme_color_override("font_color", INK)
	quantity_edit.add_theme_color_override("caret_color", GOLD)
	quantity_edit.add_theme_color_override("selection_color", Color("#9e7a3f66"))
	quantity_edit.add_theme_stylebox_override("normal", _panel(Color("#cbbd99"), Color("#8d7950"), 1, 3, 8))
	quantity_edit.add_theme_stylebox_override("focus", _panel(Color("#e1d5b6"), GOLD, 2, 3, 8))
	var increase := _small_button("+", "QuantityIncreaseButton")
	increase.custom_minimum_size = Vector2(56, 52)
	increase.add_theme_font_size_override("font_size", 24)
	increase.tooltip_text = "数量加一"
	increase.pressed.connect(_add_quantity.bind(1))
	_quantity_controls.add_child(increase)
	for data in [["+10", "Quick10Button", 10], ["+100", "Quick100Button", 100]]:
		var button := _small_button(str(data[0]), str(data[1]))
		button.pressed.connect(_add_quantity.bind(int(data[2])))
		_quantity_controls.add_child(button)
	var maximum := _small_button("最大", "MaximumButton")
	maximum.pressed.connect(_set_maximum_quantity)
	_quantity_controls.add_child(maximum)
	var clear := _small_button("清空", "ClearQuantityButton")
	clear.pressed.connect(_clear_quantity)
	_quantity_controls.add_child(clear)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	parent.add_child(actions)
	_buy_button = Button.new()
	_buy_button.name = "BuyButton"
	_buy_button.custom_minimum_size = Vector2(190, 50)
	_style_action_button(_buy_button, Color("#285b4c"))
	_buy_button.pressed.connect(_buy_action)
	actions.add_child(_buy_button)
	_sell_button = Button.new()
	_sell_button.name = "SellButton"
	_sell_button.custom_minimum_size = Vector2(170, 50)
	_style_action_button(_sell_button, Color("#6a4328"))
	_sell_button.pressed.connect(_sell_action)
	actions.add_child(_sell_button)
	_sell_all_button = Button.new()
	_sell_all_button.name = "SellAllButton"
	_sell_all_button.text = "全部出售"
	_sell_all_button.custom_minimum_size = Vector2(150, 50)
	_style_secondary_button(_sell_all_button)
	_sell_all_button.pressed.connect(_sell_all_action)
	actions.add_child(_sell_all_button)


func _build_resource_bar(parent: VBoxContainer) -> void:
	_resource_blocks = HBoxContainer.new()
	_resource_blocks.name = "ResourceBlocks"
	_resource_blocks.custom_minimum_size.y = 54
	_resource_blocks.add_theme_constant_override("separation", 4)
	parent.add_child(_resource_blocks)


func _refresh() -> void:
	var state := _state()
	_clear(_tabs)
	_clear(_shop_shelf)
	_product_group = ButtonGroup.new()
	if _role == "shipyard":
		_add_tab("造船图纸", "blueprints")
		_add_tab("船坞建造", "shipyard")
	else:
		_add_tab("购入木铁", "goods")
		_add_tab("出售货物", "sell")
	var ids: Array = []
	if _role == "goods" and _mode == "goods":
		ids = ["wood", "ironstone"]
	elif _role == "goods":
		for value in state["items"]:
			var item := CATALOG.item(str(value))
			if int(state["items"].get(value, 0)) > 0 and int(item.get("sell_price", 0)) > 0:
				ids.append(str(value))
	elif _mode == "blueprints":
		ids = CATALOG.SHIPS.keys()
	else:
		ids = (state["blueprints"] as Array).duplicate()
	for id in ids:
		_shop_shelf.add_child(_make_product_row(str(id), state))
	if ids.is_empty():
		var empty := Label.new()
		empty.text = "尚无可交易货物" if _role == "goods" else "尚无可建造船型\n请先购买造船图纸"
		empty.custom_minimum_size.y = 90
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color("#918875"))
		_shop_shelf.add_child(empty)
	_buy_button.text = "购入货物" if _mode == "goods" else ("买下图纸" if _mode == "blueprints" else "建造一艘")
	_quantity.visible = _role == "goods"
	_quantity_controls.visible = _role == "goods"
	_refresh_resources(state)
	_select(_selected_id)


func _make_product_row(id: String, state: Dictionary) -> Button:
	var data := CATALOG.item(id) if _role == "goods" else CATALOG.ship(id)
	var row := Button.new()
	row.custom_minimum_size = Vector2(450, 76)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.toggle_mode = true
	row.button_group = _product_group
	row.button_pressed = id == _selected_id
	row.add_theme_stylebox_override("normal", _bottom_line(Color("#00000000"), Color("#4c4639"), 1, 6))
	row.add_theme_stylebox_override("hover", _left_mark(Color("#202d2a"), Color("#8a7044"), 2, 6))
	row.add_theme_stylebox_override("pressed", _left_mark(Color("#30403a"), GOLD, 4, 6))
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(58, 58)
	icon.texture = _icon(id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(icon)
	var name_label := Label.new()
	name_label.text = str(data.get("name", id))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", OLD_WHITE)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(name_label)
	var price := Label.new()
	price.text = _product_price_text(id, data, state)
	price.custom_minimum_size.x = 150
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.add_theme_font_size_override("font_size", 17)
	price.add_theme_color_override("font_color", GOLD)
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(price)
	row.pressed.connect(_select.bind(id))
	return row


func _product_price_text(id: String, data: Dictionary, state: Dictionary) -> String:
	if _role == "goods":
		return "%d 军饷" % (data["buy_price"] if _mode == "goods" else data["sell_price"])
	if _mode == "blueprints":
		return "已拥有" if id in state["blueprints"] else "%d 军饷" % data["blueprint_price"]
	return "%d饷 · %d木 · %d铁" % [data["pay"], data["wood"], data["ironstone"]]


func _add_tab(text_value: String, mode_value: String) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(190, 44)
	button.toggle_mode = true
	button.button_pressed = _mode == mode_value
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", OLD_WHITE)
	button.add_theme_color_override("font_hover_color", Color("#ffe4a1"))
	button.add_theme_color_override("font_focus_color", Color("#ffe4a1"))
	button.add_theme_color_override("font_pressed_color", Color("#fff0bc"))
	button.add_theme_stylebox_override("normal", _ink_button_style(INK_BUTTON_NORMAL, Color("#ffffffd9"), 18.0, 7.0))
	button.add_theme_stylebox_override("hover", _ink_button_style(INK_BUTTON_ACTIVE, Color.WHITE, 18.0, 7.0))
	button.add_theme_stylebox_override("focus", _ink_button_style(INK_BUTTON_ACTIVE, Color.WHITE, 18.0, 7.0))
	button.add_theme_stylebox_override("pressed", _ink_button_style(INK_BUTTON_ACTIVE, Color("#e9d39d"), 18.0, 7.0))
	button.pressed.connect(_set_mode.bind(mode_value))
	_tabs.add_child(button)


func _set_mode(value: String) -> void:
	_mode = value
	_selected_id = "wood" if _role == "goods" else "patrol_boat"
	_quantity.value = 1
	_status.text = ""
	_refresh()


func _select(id: String) -> void:
	_selected_id = id
	var item := CATALOG.item(id)
	var ship := CATALOG.ship(id)
	var state := _state()
	_preview.texture = _icon(id)
	_holding_label.text = "当前持有　%d" % int(state["items"].get(id, 0)) if not item.is_empty() else "现役舰船　%d 艘" % (state["ships"] as Array).size()
	if not item.is_empty():
		var price := int(item["buy_price"] if _mode == "goods" else item["sell_price"])
		_detail_name.text = str(item["name"])
		_detail_text.text = "[color=#716958]持有[/color]　[color=#8a5a18][font_size=20]%d[/font_size][/color]　　 [color=#716958]单价[/color]　[color=#8a5a18][font_size=20]%d 军饷[/font_size][/color]" % [state["items"].get(id, 0), price]
	else:
		_detail_name.text = str(ship.get("name", ""))
		_detail_text.text = "[color=#716958]%s[/color]\n[color=#8a5a18][font_size=20]%d 军饷　·　%d 木材　·　%d 铁石[/font_size][/color]" % ["永久解锁图纸" if _mode == "blueprints" else "建造所需", ship.get("pay", 0), ship.get("wood", 0), ship.get("ironstone", 0)]
	_buy_button.visible = _role == "shipyard" or (_mode == "goods" and id in ["wood", "ironstone"])
	_sell_button.visible = _role == "goods" and _mode == "sell" and not item.is_empty()
	_sell_all_button.visible = _sell_button.visible
	_update_total()


func _on_quantity_changed(_value: float) -> void:
	_update_total()


func _add_quantity(amount: int) -> void:
	_quantity.value = clampi(int(_quantity.value) + amount, int(_quantity.min_value), int(_quantity.max_value))


func _set_maximum_quantity() -> void:
	_quantity.value = _maximum_quantity(_selected_id)


func _clear_quantity() -> void:
	_quantity.value = 0


func _maximum_quantity(id: String) -> int:
	var item := CATALOG.item(id)
	if item.is_empty() or _role != "goods":
		return 1
	var state := _state()
	if _mode == "goods":
		return int(state["pay"]) / maxi(1, int(item["buy_price"]))
	return int(state["items"].get(id, 0))


func _transaction_preview(id: String, quantity: int) -> Dictionary:
	var state := _state()
	var item := CATALOG.item(id)
	var held := int(state["items"].get(id, 0))
	if item.is_empty():
		return {"pay_after": int(state["pay"]), "held_after": held, "valid": true}
	var price := int(item["buy_price"] if _mode == "goods" else item["sell_price"])
	var pay_after := int(state["pay"]) + (-price * quantity if _mode == "goods" else price * quantity)
	var held_after := held + (quantity if _mode == "goods" else -quantity)
	return {"pay_after": pay_after, "held_after": held_after, "valid": quantity > 0 and pay_after >= 0 and held_after >= 0}


func _update_total() -> void:
	var item := CATALOG.item(_selected_id)
	var state := _state()
	if not item.is_empty() and _role == "goods":
		var quantity := int(_quantity.value)
		var price := int(item["buy_price"] if _mode == "goods" else item["sell_price"])
		var preview := _transaction_preview(_selected_id, quantity)
		_total_label.text = "购入合计　%d 军饷" % (price * quantity) if _mode == "goods" else "出售可得　%d 军饷" % (price * quantity)
		_after_trade_label.text = "交易后军饷　%d　　 交易后持有　%d" % [preview["pay_after"], preview["held_after"]]
		_buy_button.disabled = _buy_button.visible and not bool(preview["valid"])
		_sell_button.disabled = _sell_button.visible and not bool(preview["valid"])
		_sell_all_button.disabled = int(state["items"].get(_selected_id, 0)) <= 0
	else:
		_total_label.text = "图纸永久解锁 · 舰船可重复建造"
		_after_trade_label.text = ""
		_buy_button.disabled = not _can_use_ship_action(_selected_id, state)


func _can_use_ship_action(id: String, state: Dictionary) -> bool:
	var ship := CATALOG.ship(id)
	if ship.is_empty():
		return false
	if _mode == "blueprints":
		return id not in state["blueprints"] and int(state["pay"]) >= int(ship["blueprint_price"])
	return id in state["blueprints"] and int(state["pay"]) >= int(ship["pay"]) and int(state["items"].get("wood", 0)) >= int(ship["wood"]) and int(state["items"].get("ironstone", 0)) >= int(ship["ironstone"])


func _buy_action() -> void:
	var result: Dictionary
	if _mode == "goods":
		result = _game_state().call("buy_economy_item", _selected_id, int(_quantity.value))
	elif _mode == "blueprints":
		result = _game_state().call("buy_economy_blueprint", _selected_id)
	else:
		result = _game_state().call("build_economy_ship", _selected_id)
	_status.text = "交易完成" if result.get("ok", false) else _reason(str(result.get("reason", "failed")))
	_refresh()


func _sell_action() -> void:
	var result := _game_state().call("sell_economy_item", _selected_id, int(_quantity.value)) as Dictionary
	_status.text = "出售完成" if result.get("ok", false) else _reason(str(result.get("reason", "failed")))
	_refresh()


func _sell_all_action() -> void:
	_quantity.value = _maximum_quantity(_selected_id)
	_sell_action()


func _refresh_resources(state: Dictionary) -> void:
	_clear(_resource_blocks)
	var resources := [
		[COIN_ICON, "军饷", int(state["pay"])],
		[ICON_PATHS["wood"], "木材", int(state["items"].get("wood", 0))],
		[ICON_PATHS["ironstone"], "铁石", int(state["items"].get("ironstone", 0))],
		[ICON_PATHS["patrol_boat"], "舰队", "%d 艘" % (state["ships"] as Array).size()],
	]
	for data in resources:
		var block := HBoxContainer.new()
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.alignment = BoxContainer.ALIGNMENT_CENTER
		block.add_theme_constant_override("separation", 8)
		block.add_theme_stylebox_override("panel", _top_line(Color("#00000000"), Color("#514837"), 1, 8))
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.texture = load(str(data[0]))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		block.add_child(icon)
		var label := Label.new()
		label.text = "%s　%s" % [data[1], data[2]]
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", OLD_WHITE)
		block.add_child(label)
		_resource_blocks.add_child(block)


func _refresh_header_portrait() -> void:
	_header_portrait.texture = load("res://assets/ui/merchant_shop/merchants/liang_trader.png") if _role == "goods" else load("res://assets/ui/merchant_shop/merchants/shen_shipwright.png")


func _icon(id: String) -> Texture2D:
	var path := str(ICON_PATHS.get(id, ""))
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else null


func _state() -> Dictionary:
	return _game_state().call("get_economy_state") as Dictionary


func _game_state() -> Node:
	return get_node("/root/GameState")


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _small_button(text_value: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text_value
	button.custom_minimum_size = Vector2(86, 46)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", OLD_WHITE)
	button.add_theme_color_override("font_hover_color", Color("#ffe4a1"))
	button.add_theme_color_override("font_focus_color", Color("#ffe4a1"))
	button.add_theme_color_override("font_pressed_color", Color("#fff0bc"))
	button.add_theme_stylebox_override("normal", _ink_button_style(INK_BUTTON_NORMAL, Color("#ffffffd1"), 12.0, 5.0))
	button.add_theme_stylebox_override("hover", _ink_button_style(INK_BUTTON_ACTIVE, Color.WHITE, 12.0, 5.0))
	button.add_theme_stylebox_override("focus", _ink_button_style(INK_BUTTON_ACTIVE, Color.WHITE, 12.0, 5.0))
	button.add_theme_stylebox_override("pressed", _ink_button_style(INK_BUTTON_ACTIVE, Color("#e9d39d"), 12.0, 5.0))
	return button


func _style_action_button(button: Button, _color: Color) -> void:
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", OLD_WHITE)
	button.add_theme_color_override("font_hover_color", Color("#ffe4a1"))
	button.add_theme_color_override("font_focus_color", Color("#ffe4a1"))
	button.add_theme_color_override("font_pressed_color", Color("#fff0bc"))
	button.add_theme_color_override("font_disabled_color", Color("#766f60"))
	button.add_theme_stylebox_override("normal", _ink_button_style(INK_BUTTON_NORMAL, Color.WHITE, 24.0, 9.0))
	button.add_theme_stylebox_override("hover", _ink_button_style(INK_BUTTON_ACTIVE, Color.WHITE, 24.0, 9.0))
	button.add_theme_stylebox_override("focus", _ink_button_style(INK_BUTTON_ACTIVE, Color.WHITE, 24.0, 9.0))
	button.add_theme_stylebox_override("pressed", _ink_button_style(INK_BUTTON_ACTIVE, Color("#dfc88f"), 24.0, 9.0))
	button.add_theme_stylebox_override("disabled", _ink_button_style(INK_BUTTON_NORMAL, Color("#77736c66"), 24.0, 9.0))


func _style_secondary_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", OLD_WHITE)
	button.add_theme_color_override("font_hover_color", Color("#ffe4a1"))
	button.add_theme_color_override("font_focus_color", Color("#ffe4a1"))
	button.add_theme_color_override("font_pressed_color", Color("#fff0bc"))
	button.add_theme_color_override("font_disabled_color", Color("#8b8374"))
	button.add_theme_stylebox_override("normal", _ink_button_style(INK_BUTTON_NORMAL, Color("#ffffffd1"), 20.0, 8.0))
	button.add_theme_stylebox_override("hover", _ink_button_style(INK_BUTTON_ACTIVE, Color.WHITE, 20.0, 8.0))
	button.add_theme_stylebox_override("focus", _ink_button_style(INK_BUTTON_ACTIVE, Color.WHITE, 20.0, 8.0))
	button.add_theme_stylebox_override("pressed", _ink_button_style(INK_BUTTON_ACTIVE, Color("#dfc88f"), 20.0, 8.0))
	button.add_theme_stylebox_override("disabled", _ink_button_style(INK_BUTTON_NORMAL, Color("#77736c66"), 20.0, 8.0))


func _style_text_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", OLD_WHITE)
	button.add_theme_color_override("font_hover_color", Color("#ffe4a1"))
	button.add_theme_color_override("font_focus_color", Color("#ffe4a1"))
	button.add_theme_color_override("font_pressed_color", Color("#fff0bc"))
	button.add_theme_stylebox_override("normal", _ink_button_style(INK_BUTTON_NORMAL, Color("#ffffffd1"), 18.0, 7.0))
	button.add_theme_stylebox_override("hover", _ink_button_style(INK_BUTTON_ACTIVE, Color.WHITE, 18.0, 7.0))
	button.add_theme_stylebox_override("focus", _ink_button_style(INK_BUTTON_ACTIVE, Color.WHITE, 18.0, 7.0))
	button.add_theme_stylebox_override("pressed", _ink_button_style(INK_BUTTON_ACTIVE, Color("#dfc88f"), 18.0, 7.0))


func _ink_button_style(texture: Texture2D, modulate: Color, horizontal_content_margin: float, vertical_content_margin: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.modulate_color = modulate
	style.content_margin_left = horizontal_content_margin
	style.content_margin_right = horizontal_content_margin
	style.content_margin_top = vertical_content_margin
	style.content_margin_bottom = vertical_content_margin
	return style


func _paper_panel() -> StyleBoxFlat:
	var style := _panel(PAPER, Color("#927b4e"), 1, 3, 14)
	style.shadow_color = Color("#00000045")
	style.shadow_size = 4
	return style


func _panel(bg: Color, border: Color, width: int, radius: int, margin: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style


func _bottom_line(bg: Color, line: Color, width: int, margin: float) -> StyleBoxFlat:
	var style := _panel(bg, line, 0, 0, margin)
	style.border_width_bottom = width
	return style


func _top_line(bg: Color, line: Color, width: int, margin: float) -> StyleBoxFlat:
	var style := _panel(bg, line, 0, 0, margin)
	style.border_width_top = width
	return style


func _right_line(bg: Color, line: Color, width: int, margin: float) -> StyleBoxFlat:
	var style := _panel(bg, line, 0, 0, margin)
	style.border_width_right = width
	return style


func _left_mark(bg: Color, line: Color, width: int, margin: float) -> StyleBoxFlat:
	var style := _panel(bg, line, 0, 0, margin)
	style.border_width_left = width
	return style


func _reason(reason: String) -> String:
	return {"insufficient_pay": "军饷不足", "insufficient_stock": "库存不足", "already_owned": "图纸已购", "blueprint_required": "尚无图纸", "insufficient_wood": "木材不足", "insufficient_ironstone": "铁石不足", "not_for_sale": "该货物只可出售"}.get(reason, "无法完成")
