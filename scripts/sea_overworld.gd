extends Node2D

const EVENT_SHIPS_ATLAS := preload("res://assets/sprites/sea_overworld/event_ships_atlas_v2.png")
const MAP_SIZE := Vector2(2508, 1412)
const PLAYER_LAYER := 1

const GOLD_BRIGHT := Color(1.0, 0.86, 0.48, 1.0)
const PAPER := Color(0.95, 0.9, 0.75, 1.0)

@onready var player: CharacterBody2D = $World/Player
@onready var world_collision: StaticBody2D = $World/WorldCollision
@onready var world_markers: Node2D = $World/WorldMarkers
@onready var exploration_hud: Control = $UI/ExplorationHUD
@onready var interaction_prompt: Control = $UI/Root/InteractionPrompt
@onready var location_name_label: Label = $UI/Root/InteractionPrompt/LocationName
@onready var enter_button: BaseButton = $UI/Root/InteractionPrompt/EnterButton

var _active_location_name := ""
var _active_location_area: Area2D
var _active_location_label: Label
var _floating_visuals: Array[CanvasItem] = []
var _float_elapsed := 0.0
var _exploration_stage := 0


func _ready() -> void:
	_build_world_collisions()
	_build_locations()
	_build_auto_triggers()
	enter_button.pressed.connect(_enter_active_location)
	exploration_hud.connect("menu_visibility_changed", _on_hud_menu_visibility_changed)
	exploration_hud.call("set_quest_context", &"sea_overworld")
	_refresh_exploration_task()
	exploration_hud.call("set_exploration_visible", true)
	interaction_prompt.hide()


func _process(delta: float) -> void:
	if _exploration_stage == 0 and player.velocity.length_squared() > 0.01:
		_advance_exploration_stage(1)
	_float_elapsed += delta
	for index in range(_floating_visuals.size()):
		var visual := _floating_visuals[index]
		if is_instance_valid(visual):
			visual.position.y = sin(_float_elapsed * 2.1 + index * 0.9) * 2.0


func _unhandled_key_input(event: InputEvent) -> void:
	if bool(exploration_hud.call("is_menu_open")):
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_E or key_event.keycode == KEY_E:
		if not _active_location_name.is_empty():
			_enter_active_location()
			get_viewport().set_input_as_handled()

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
	_build_location("南海军港", Vector2(1230, 682), 238.0)
	_build_location("川山渔村", Vector2(518, 982), 205.0)
	_build_location("东湾水寨", Vector2(2050, 322), 225.0, Vector2(680, 170), Vector2(0, 210))
	_build_location("青屿秘境", Vector2(1995, 742), 232.0, Vector2(480, 160), Vector2(0, 215))


func _build_auto_triggers() -> void:
	_build_ship_trigger("近海渔船", Vector2(940, 1040), 0)
	_build_ship_trigger("岭南商船", Vector2(1700, 930), 1)
	_build_event_trigger("漂流木箱", Vector2(820, 810))


func _build_location(
	location_name: String,
	at: Vector2,
	trigger_radius: float,
	front_trigger_size: Vector2 = Vector2.ZERO,
	front_trigger_offset: Vector2 = Vector2.ZERO
) -> void:
	var area := Area2D.new()
	area.name = "Location%d" % world_markers.get_child_count()
	area.position = at
	area.collision_layer = 0
	area.collision_mask = PLAYER_LAYER
	area.set_meta("location_name", location_name)
	area.set_meta("trigger_radius", trigger_radius)
	area.set_meta("front_trigger_size", front_trigger_size)
	area.set_meta("front_trigger_offset", front_trigger_offset)
	area.add_to_group("sea_location")
	world_markers.add_child(area)

	var shape_node := CollisionShape2D.new()
	shape_node.name = "EntryTriggerShape"
	if front_trigger_size != Vector2.ZERO:
		var front_shape := RectangleShape2D.new()
		front_shape.size = front_trigger_size
		shape_node.position = front_trigger_offset
		shape_node.shape = front_shape
	else:
		var radial_shape := CircleShape2D.new()
		radial_shape.radius = trigger_radius
		shape_node.shape = radial_shape
	area.add_child(shape_node)

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

	area.body_entered.connect(_on_location_body_entered.bind(area, label))
	area.body_exited.connect(_on_location_body_exited.bind(area, label))


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


func _on_location_body_entered(body: Node2D, area: Area2D, label: Label) -> void:
	if body != player:
		return
	_clear_active_location_visuals()
	_active_location_area = area
	_active_location_label = label
	_active_location_name = str(area.get_meta("location_name", ""))
	label.show()
	location_name_label.text = "【%s】" % _active_location_name
	if not bool(exploration_hud.call("is_menu_open")):
		interaction_prompt.show()
	_advance_exploration_stage(2)


func _on_location_body_exited(body: Node2D, area: Area2D, label: Label) -> void:
	if body != player:
		return
	label.hide()
	if _active_location_area == area:
		_active_location_area = null
		_active_location_label = null
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
	_advance_exploration_stage(4)


func _enter_active_location() -> void:
	if _active_location_name.is_empty():
		return
	_show_toast("%s · 该地点即将开放" % _active_location_name)
	_advance_exploration_stage(3)


func _show_toast(message: String) -> void:
	exploration_hud.call("show_toast", message)


func _advance_exploration_stage(next_stage: int) -> void:
	if next_stage <= _exploration_stage:
		return
	_exploration_stage = next_stage
	_refresh_exploration_task()


func _refresh_exploration_task() -> void:
	var objective := "使用WASD或方向键驾驶船只"
	match _exploration_stage:
		1:
			objective = "靠近任意岛屿，查看地点名称"
		2:
			objective = "点击进入按钮或按E尝试进入地点"
		3:
			objective = "接触海上的船只或漂流事件"
		4:
			objective = "继续探索岭南海域"
	exploration_hud.call("set_main_task_progress", "探索大地图", objective, _exploration_stage)


func _on_hud_menu_visibility_changed(is_open: bool) -> void:
	player.controls_enabled = not is_open
	interaction_prompt.visible = not is_open and not _active_location_name.is_empty()


func _clear_active_location_visuals() -> void:
	if is_instance_valid(_active_location_label):
		_active_location_label.hide()


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
