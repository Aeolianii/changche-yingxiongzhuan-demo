extends Node2D

const EVENT_SHIPS_ATLAS := preload("res://assets/sprites/sea_overworld/event_ships_atlas_v2.png")
const MAP_SIZE := Vector2(2508, 1412)
const PLAYER_LAYER := 1

const INK := Color(0.035, 0.06, 0.065, 0.94)
const INK_SOFT := Color(0.055, 0.1, 0.105, 0.9)
const GOLD := Color(0.82, 0.65, 0.3, 1.0)
const GOLD_BRIGHT := Color(1.0, 0.86, 0.48, 1.0)
const PAPER := Color(0.95, 0.9, 0.75, 1.0)
const JADE := Color(0.12, 0.35, 0.34, 1.0)

@onready var player: CharacterBody2D = $World/Player
@onready var world_collision: StaticBody2D = $World/WorldCollision
@onready var world_markers: Node2D = $World/WorldMarkers
@onready var interaction_prompt: PanelContainer = $UI/Root/InteractionPrompt
@onready var location_name_label: Label = $UI/Root/InteractionPrompt/PromptMargin/PromptRow/LocationName
@onready var enter_button: Button = $UI/Root/InteractionPrompt/PromptMargin/PromptRow/EnterButton
@onready var toast_panel: PanelContainer = $UI/Root/ToastPanel
@onready var toast_label: Label = $UI/Root/ToastPanel/ToastMargin/ToastLabel
@onready var toast_timer: Timer = $ToastTimer
@onready var title_panel: PanelContainer = $UI/Root/TitlePanel
@onready var help_panel: PanelContainer = $UI/Root/HelpPanel

var _active_location_name := ""
var _active_location_area: Area2D
var _active_location_label: Label
var _active_location_outline: Line2D
var _floating_visuals: Array[CanvasItem] = []
var _float_elapsed := 0.0


func _ready() -> void:
	_configure_ui()
	_build_world_collisions()
	_build_locations()
	_build_auto_triggers()
	enter_button.pressed.connect(_enter_active_location)
	toast_timer.timeout.connect(toast_panel.hide)
	interaction_prompt.hide()
	toast_panel.hide()


func _process(delta: float) -> void:
	_float_elapsed += delta
	for index in range(_floating_visuals.size()):
		var visual := _floating_visuals[index]
		if is_instance_valid(visual):
			visual.position.y = sin(_float_elapsed * 2.1 + index * 0.9) * 2.0


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_E or key_event.keycode == KEY_E:
		if not _active_location_name.is_empty():
			_enter_active_location()
			get_viewport().set_input_as_handled()


func _configure_ui() -> void:
	title_panel.add_theme_stylebox_override("panel", _panel_style(INK, GOLD, 2, 7))
	help_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.06, 0.065, 0.88), Color(GOLD.r, GOLD.g, GOLD.b, 0.55), 1, 6))
	interaction_prompt.add_theme_stylebox_override("panel", _panel_style(INK, GOLD_BRIGHT, 2, 7))
	toast_panel.add_theme_stylebox_override("panel", _panel_style(INK_SOFT, GOLD, 2, 7))
	enter_button.add_theme_stylebox_override("normal", _panel_style(JADE, GOLD, 1, 5))
	enter_button.add_theme_stylebox_override("hover", _panel_style(Color(0.17, 0.45, 0.42, 1.0), GOLD_BRIGHT, 2, 5))
	enter_button.add_theme_stylebox_override("pressed", _panel_style(Color(0.08, 0.24, 0.23, 1.0), GOLD_BRIGHT, 2, 5))
	enter_button.add_theme_color_override("font_color", PAPER)
	enter_button.add_theme_color_override("font_hover_color", Color.WHITE)
	enter_button.add_theme_color_override("font_pressed_color", GOLD_BRIGHT)


func _build_world_collisions() -> void:
	_add_circle_blocker(Vector2(1230, 682), 185.0)
	_add_circle_blocker(Vector2(518, 982), 154.0)
	_add_circle_blocker(Vector2(2050, 322), 160.0)
	_add_circle_blocker(Vector2(1995, 742), 180.0)
	_add_circle_blocker(Vector2(1300, 1240), 72.0)
	_add_circle_blocker(Vector2(1515, 1195), 70.0)
	_add_circle_blocker(Vector2(1875, 1195), 72.0)
	_add_circle_blocker(Vector2(2180, 1195), 70.0)

	var coast := CollisionPolygon2D.new()
	coast.name = "NorthwestCoast"
	coast.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(1120, 0), Vector2(1090, 170), Vector2(980, 245),
		Vector2(950, 345), Vector2(820, 430), Vector2(675, 485), Vector2(540, 585),
		Vector2(390, 665), Vector2(230, 735), Vector2(0, 760)
	])
	world_collision.add_child(coast)


func _build_locations() -> void:
	_build_location("南海军港", Vector2(1230, 682), 238.0, PackedVector2Array([
		Vector2(-246, -10), Vector2(-226, -70), Vector2(-190, -112), Vector2(-132, -143),
		Vector2(-70, -160), Vector2(0, -166), Vector2(75, -156), Vector2(136, -136),
		Vector2(190, -104), Vector2(226, -61), Vector2(252, -15), Vector2(241, 27),
		Vector2(216, 56), Vector2(193, 71), Vector2(205, 96), Vector2(170, 112),
		Vector2(133, 101), Vector2(104, 123), Vector2(73, 120), Vector2(56, 146),
		Vector2(24, 133), Vector2(-4, 149), Vector2(-34, 132), Vector2(-72, 139),
		Vector2(-92, 117), Vector2(-129, 121), Vector2(-149, 97), Vector2(-184, 96),
		Vector2(-201, 70), Vector2(-232, 55)
	]))
	_build_location("川山渔村", Vector2(518, 982), 205.0, PackedVector2Array([
		Vector2(-180, -25), Vector2(-161, -77), Vector2(-119, -114), Vector2(-66, -132),
		Vector2(-8, -139), Vector2(52, -128), Vector2(106, -102), Vector2(149, -66),
		Vector2(171, -20), Vector2(163, 25), Vector2(140, 55), Vector2(151, 78),
		Vector2(113, 94), Vector2(75, 91), Vector2(48, 111), Vector2(8, 102),
		Vector2(-24, 114), Vector2(-56, 98), Vector2(-102, 100), Vector2(-123, 74),
		Vector2(-157, 61), Vector2(-170, 24)
	]))
	_build_location("东湾水寨", Vector2(2050, 322), 210.0, PackedVector2Array([
		Vector2(-181, -28), Vector2(-159, -82), Vector2(-113, -119), Vector2(-58, -139),
		Vector2(4, -145), Vector2(66, -134), Vector2(120, -108), Vector2(158, -72),
		Vector2(178, -28), Vector2(169, 20), Vector2(146, 54), Vector2(155, 76),
		Vector2(119, 92), Vector2(77, 89), Vector2(47, 108), Vector2(6, 101),
		Vector2(-30, 111), Vector2(-63, 96), Vector2(-108, 98), Vector2(-130, 72),
		Vector2(-164, 58), Vector2(-174, 20)
	]))
	_build_location("青屿秘境", Vector2(1995, 742), 232.0, PackedVector2Array([
		Vector2(-210, -18), Vector2(-189, -78), Vector2(-146, -119), Vector2(-89, -145),
		Vector2(-27, -154), Vector2(40, -147), Vector2(101, -126), Vector2(151, -91),
		Vector2(188, -50), Vector2(205, 3), Vector2(194, 53), Vector2(166, 82),
		Vector2(176, 105), Vector2(136, 121), Vector2(95, 112), Vector2(62, 136),
		Vector2(21, 128), Vector2(-15, 142), Vector2(-50, 125), Vector2(-95, 130),
		Vector2(-119, 102), Vector2(-161, 98), Vector2(-180, 68), Vector2(-201, 43)
	]))


func _build_auto_triggers() -> void:
	_build_ship_trigger("近海渔船", Vector2(940, 1040), 0)
	_build_ship_trigger("岭南商船", Vector2(1700, 930), 1)
	_build_event_trigger("漂流木箱", Vector2(820, 810))


func _build_location(location_name: String, at: Vector2, trigger_radius: float, island_outline: PackedVector2Array) -> void:
	var area := Area2D.new()
	area.name = "Location%d" % world_markers.get_child_count()
	area.position = at
	area.collision_layer = 0
	area.collision_mask = PLAYER_LAYER
	area.set_meta("location_name", location_name)
	area.set_meta("trigger_radius", trigger_radius)
	area.add_to_group("sea_location")
	world_markers.add_child(area)

	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = trigger_radius
	shape_node.shape = shape
	area.add_child(shape_node)

	var outline := Line2D.new()
	outline.name = "IslandOutline"
	outline.points = island_outline
	outline.closed = true
	outline.width = 2.0
	outline.default_color = Color(GOLD_BRIGHT.r, GOLD_BRIGHT.g, GOLD_BRIGHT.b, 0.92)
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	outline.z_index = 30
	outline.hide()
	area.add_child(outline)

	var label := Label.new()
	label.name = "HighlightedName"
	label.text = "【%s】" % location_name
	label.position = Vector2(-150, -34)
	label.size = Vector2(300, 48)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", GOLD_BRIGHT)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.025, 0.028, 0.98))
	label.add_theme_constant_override("outline_size", 7)
	label.z_index = 32
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.hide()
	area.add_child(label)

	area.body_entered.connect(_on_location_body_entered.bind(area, label, outline))
	area.body_exited.connect(_on_location_body_exited.bind(area, label, outline))


func _build_ship_trigger(ship_name: String, at: Vector2, atlas_column: int) -> void:
	var area := _make_auto_trigger("ShipTrigger%d" % atlas_column, at, ship_name, "ship")
	var sprite := Sprite2D.new()
	sprite.name = "ShipSprite"
	sprite.texture = _atlas_region(EVENT_SHIPS_ATLAS, 4, 1, atlas_column, 0)
	sprite.scale = Vector2(0.27, 0.27)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 18
	area.add_child(sprite)
	_floating_visuals.append(sprite)


func _build_event_trigger(event_name: String, at: Vector2) -> void:
	var area := _make_auto_trigger("DriftEvent", at, event_name, "event")
	var visual := Node2D.new()
	visual.name = "EventVisual"
	visual.z_index = 18
	area.add_child(visual)

	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([Vector2(0, -15), Vector2(18, 0), Vector2(0, 15), Vector2(-18, 0)])
	diamond.color = Color(0.82, 0.57, 0.2, 0.96)
	visual.add_child(diamond)

	var center := Polygon2D.new()
	center.polygon = PackedVector2Array([Vector2(-8, -6), Vector2(8, -6), Vector2(8, 6), Vector2(-8, 6)])
	center.color = Color(0.31, 0.18, 0.08, 1.0)
	visual.add_child(center)

	var label := Label.new()
	label.text = event_name
	label.position = Vector2(-72, 22)
	label.size = Vector2(144, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", PAPER)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.02, 0.96))
	label.add_theme_constant_override("outline_size", 5)
	visual.add_child(label)
	_floating_visuals.append(visual)


func _make_auto_trigger(node_name: String, at: Vector2, display_name: String, trigger_kind: String) -> Area2D:
	var area := Area2D.new()
	area.name = node_name
	area.position = at
	area.collision_layer = 0
	area.collision_mask = PLAYER_LAYER
	area.set_meta("display_name", display_name)
	area.set_meta("trigger_kind", trigger_kind)
	area.add_to_group("sea_auto_trigger")
	world_markers.add_child(area)

	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 82.0
	shape_node.shape = shape
	area.add_child(shape_node)
	area.body_entered.connect(_on_auto_trigger_body_entered.bind(area))
	return area


func _on_location_body_entered(body: Node2D, area: Area2D, label: Label, outline: Line2D) -> void:
	if body != player:
		return
	_clear_active_location_visuals()
	_active_location_area = area
	_active_location_label = label
	_active_location_outline = outline
	_active_location_name = str(area.get_meta("location_name", ""))
	label.show()
	outline.show()
	location_name_label.text = "【%s】" % _active_location_name
	interaction_prompt.show()


func _on_location_body_exited(body: Node2D, area: Area2D, label: Label, outline: Line2D) -> void:
	if body != player:
		return
	label.hide()
	outline.hide()
	if _active_location_area == area:
		_active_location_area = null
		_active_location_label = null
		_active_location_outline = null
		_active_location_name = ""
		interaction_prompt.hide()


func _on_auto_trigger_body_entered(body: Node2D, area: Area2D) -> void:
	if body != player:
		return
	var display_name := str(area.get_meta("display_name", "海上目标"))
	var trigger_kind := str(area.get_meta("trigger_kind", "event"))
	if trigger_kind == "ship":
		_show_toast("%s · 该船只开发中" % display_name)
	else:
		_show_toast("%s · 该事件开发中" % display_name)


func _enter_active_location() -> void:
	if _active_location_name.is_empty():
		return
	_show_toast("%s · 该地点即将开放" % _active_location_name)


func _show_toast(message: String) -> void:
	toast_label.text = message
	toast_panel.show()
	toast_timer.start()


func _clear_active_location_visuals() -> void:
	if is_instance_valid(_active_location_label):
		_active_location_label.hide()
	if is_instance_valid(_active_location_outline):
		_active_location_outline.hide()


func _add_circle_blocker(at: Vector2, radius: float) -> void:
	var shape_node := CollisionShape2D.new()
	shape_node.position = at
	var shape := CircleShape2D.new()
	shape.radius = radius
	shape_node.shape = shape
	world_collision.add_child(shape_node)


func _atlas_region(texture: Texture2D, columns: int, rows: int, column: int, row: int) -> AtlasTexture:
	var frame_size := Vector2(texture.get_width() / float(columns), texture.get_height() / float(rows))
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = texture
	atlas_texture.region = Rect2(Vector2(column, row) * frame_size, frame_size)
	return atlas_texture


func _panel_style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_top = 7.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 7.0
	return style
