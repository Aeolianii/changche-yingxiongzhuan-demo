class_name InventoryScreen
extends Control

signal close_requested
const CATALOG := preload("res://scripts/economy/item_catalog.gd")
var _grid: GridContainer
var _detail: RichTextLabel
var _pay: Label
var _fleet: Label
var _filter := "all"

func _ready() -> void:
	_build(); hide()

func show_screen() -> void:
	_refresh(); show()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new(); dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dim.color = Color(0.03, 0.04, 0.035, 0.86); add_child(dim)
	var panel := PanelContainer.new(); panel.position = Vector2(164, 90); panel.size = Vector2(1016, 716); add_child(panel)
	var style := StyleBoxFlat.new(); style.bg_color = Color("#171713"); style.border_color = Color("#b88b3f"); style.set_border_width_all(3); style.set_corner_radius_all(8); style.set_content_margin_all(24); panel.add_theme_stylebox_override("panel", style)
	var root_box := VBoxContainer.new(); root_box.add_theme_constant_override("separation", 14); panel.add_child(root_box)
	var header := HBoxContainer.new(); root_box.add_child(header)
	var title := Label.new(); title.text = "水 师 大 仓"; title.add_theme_font_size_override("font_size", 32); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; header.add_child(title)
	var close := Button.new(); close.name = "CloseButton"; close.text = "关闭"; close.custom_minimum_size = Vector2(120, 44); close.pressed.connect(close_requested.emit); header.add_child(close)
	var filters := HBoxContainer.new(); root_box.add_child(filters)
	for spec in [["全部", "all"], ["材料", "material"], ["岭南特产", "specialty"], ["海上货物", "cargo"], ["造船图纸", "blueprint"]]:
		var button := Button.new(); button.text = spec[0]; button.custom_minimum_size = Vector2(150, 40); button.pressed.connect(_set_filter.bind(spec[1])); filters.add_child(button)
	var body := HBoxContainer.new(); body.add_theme_constant_override("separation", 18); body.size_flags_vertical = Control.SIZE_EXPAND_FILL; root_box.add_child(body)
	_grid = GridContainer.new(); _grid.name = "ItemGrid"; _grid.columns = 5; _grid.custom_minimum_size = Vector2(650, 500); body.add_child(_grid)
	_detail = RichTextLabel.new(); _detail.bbcode_enabled = true; _detail.custom_minimum_size = Vector2(290, 500); body.add_child(_detail)
	var footer := HBoxContainer.new(); root_box.add_child(footer)
	_pay = Label.new(); _pay.name = "PayLabel"; _pay.add_theme_font_size_override("font_size", 23); _pay.size_flags_horizontal = Control.SIZE_EXPAND_FILL; footer.add_child(_pay)
	_fleet = Label.new(); _fleet.name = "FleetLabel"; _fleet.add_theme_font_size_override("font_size", 23); footer.add_child(_fleet)

func _refresh() -> void:
	for child in _grid.get_children(): child.queue_free()
	var state: Dictionary = get_node("/root/GameState").call("get_economy_state")
	_pay.text = "军饷  %d" % state["pay"]; _fleet.text = "舰队  %d / 10" % state["ships"].size()
	for id in state["items"]:
		var item := CATALOG.item(id)
		if _filter not in ["all", str(item["category"])]: continue
		var card := Button.new(); card.custom_minimum_size = Vector2(122, 92); card.text = "%s\n× %d" % [item["name"], state["items"][id]]; card.pressed.connect(_show_item.bind(str(id))); _grid.add_child(card)
	if _filter in ["all", "blueprint"]:
		for id in state["blueprints"]:
			var ship := CATALOG.ship(id); var card := Button.new(); card.custom_minimum_size = Vector2(122, 92); card.text = "%s\n图纸" % ship["name"]; card.pressed.connect(_show_ship.bind(str(id))); _grid.add_child(card)
	_detail.text = "[font_size=25]仓库说明[/font_size]\n\n仓库无容量和负重限制。木材、铁石用于造船；特产可在月环商港出售。"

func _show_item(id: String) -> void:
	var item := CATALOG.item(id); _detail.text = "[font_size=25][color=#e5bc67]%s[/color][/font_size]\n\n来源：%s\n\n月环商港卖价：%d 军饷" % [item["name"], item["source"], item["sell_price"]]
func _show_ship(id: String) -> void:
	var ship := CATALOG.ship(id); _detail.text = "[font_size=25][color=#e5bc67]%s图纸[/color][/font_size]\n\n已永久解锁，可在月环商港重复建造。" % ship["name"]

func _set_filter(value: String) -> void:
	_filter = value
	_refresh()
