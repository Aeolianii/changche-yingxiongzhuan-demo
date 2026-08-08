extends Node2D

const EVENT_SHIPS_ATLAS := preload("res://assets/sprites/sea_overworld/event_ships_atlas_v2.png")
const LOADING_TRANSITION_SCENE := preload("res://scenes/ui/scene_loading_transition.tscn")
const BASE_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_map_v2_hd.png")
const EAST_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_east_sea_expansion_v1.png")
const C_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_zone_c_v2.png")
const D_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_zone_d_v2.png")
const MAP_CHUNK_BLEND_SHADER := preload("res://shaders/map_chunk_blend.gdshader")
const MAP_CHUNK_SIZE := Vector2(2508, 1412)
const MAP_CHUNK_OVERLAP := 120.0
const EAST_MAP_ORIGIN := Vector2(MAP_CHUNK_SIZE.x - MAP_CHUNK_OVERLAP, 0)
const C_MAP_ORIGIN := Vector2(0, MAP_CHUNK_SIZE.y - MAP_CHUNK_OVERLAP)
const D_MAP_ORIGIN := Vector2(EAST_MAP_ORIGIN.x, C_MAP_ORIGIN.y)
const MAP_SIZE := D_MAP_ORIGIN + MAP_CHUNK_SIZE
const PLAYER_LAYER := 1
const SCENE_TWO_ENTRY_META := "sea_overworld_from_scene_two"
const RETURN_TO_SCENE_TWO_META := "scene_two_return_from_sea_overworld"
const SCENE_TWO_PATH := "res://scenes/Scene2.tscn"
const SOUTH_SEA_HARBOR_SPAWN := Vector2(1230, 900)
const LUNAR_DAY_META := "sea_overworld_lunar_day"
const SECONDS_PER_LUNAR_DAY := 2.0

const PAPER := Color(0.95, 0.9, 0.75, 1.0)

@onready var player: CharacterBody2D = $World/Player
@onready var camera: Camera2D = $World/Player/Camera2D
@onready var world_collision: StaticBody2D = $World/WorldCollision
@onready var world_markers: Node2D = $World/WorldMarkers
@onready var exploration_hud: Control = $UI/ExplorationHUD
@onready var interaction_prompt: Control = $UI/Root/InteractionPrompt
@onready var location_name_label: Label = $UI/Root/InteractionPrompt/LocationName
@onready var enter_button: BaseButton = $UI/Root/InteractionPrompt/EnterButton

var _active_location_name := ""
var _active_location_message := "该地点即将开放"
var _active_location_area: Area2D
var _floating_visuals: Array[CanvasItem] = []
var _float_elapsed := 0.0
var _exploration_stage := 0
var _entered_from_scene_two := false
var _transitioning := false
var _loading_transition: SceneLoadingTransition
var _lunar_day := 0.0


func _ready() -> void:
	_entered_from_scene_two = _consume_scene_two_entry_flag()
	_build_background_chunks()
	_configure_world_bounds()
	_build_world_collisions()
	_build_locations()
	_build_auto_triggers()
	player.connect("sailed", _on_player_sailed)
	enter_button.pressed.connect(_enter_active_location)
	exploration_hud.connect("menu_visibility_changed", _on_hud_menu_visibility_changed)
	exploration_hud.call("set_quest_context", &"sea_overworld")
	_configure_sea_map_hud()
	_lunar_day = float(get_tree().root.get_meta(LUNAR_DAY_META, 0.0))
	exploration_hud.call("set_lunar_day", _lunar_day)
	_refresh_exploration_task()
	exploration_hud.call("set_exploration_visible", true)
	interaction_prompt.hide()
	_loading_transition = LOADING_TRANSITION_SCENE.instantiate() as SceneLoadingTransition
	$UI.add_child(_loading_transition)
	if _entered_from_scene_two:
		player.global_position = SOUTH_SEA_HARBOR_SPAWN
		_activate_south_sea_harbor_spawn()


func _process(delta: float) -> void:
	_float_elapsed += delta
	for index in range(_floating_visuals.size()):
		var visual := _floating_visuals[index]
		if is_instance_valid(visual):
			visual.position.y = sin(_float_elapsed * 2.1 + index * 0.9) * 2.0


func _on_player_sailed(delta: float) -> void:
	if _transitioning or not player.controls_enabled or bool(exploration_hud.call("is_menu_open")):
		return
	if _exploration_stage == 0:
		_advance_exploration_stage(1)
	_lunar_day += delta / SECONDS_PER_LUNAR_DAY
	get_tree().root.set_meta(LUNAR_DAY_META, _lunar_day)
	exploration_hud.call("set_lunar_day", _lunar_day)


func _unhandled_key_input(event: InputEvent) -> void:
	if _transitioning:
		return
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
	_add_circle_blocker(Vector2(3245, 414), 190.0)
	_add_circle_blocker(Vector2(4328, 345), 285.0)
	_add_circle_blocker(Vector2(4115, 345), 155.0)
	_add_circle_blocker(Vector2(4540, 345), 155.0)
	_add_circle_blocker(Vector2(4417, 1078), 270.0)
	_add_circle_blocker(Vector2(4235, 1078), 150.0)
	_add_circle_blocker(Vector2(4595, 1078), 150.0)
	_add_circle_blocker(Vector2(405, 1682), 170.0)
	_add_circle_blocker(Vector2(295, 1682), 95.0)
	_add_circle_blocker(Vector2(515, 1682), 95.0)
	_add_circle_blocker(Vector2(1560, 1862), 200.0)
	_add_circle_blocker(Vector2(1410, 1862), 110.0)
	_add_circle_blocker(Vector2(1710, 1862), 110.0)
	_add_circle_blocker(Vector2(428, 2267), 190.0)
	_add_circle_blocker(Vector2(288, 2267), 100.0)
	_add_circle_blocker(Vector2(568, 2267), 100.0)
	_add_circle_blocker(Vector2(1605, 2432), 220.0)
	_add_circle_blocker(Vector2(1435, 2432), 115.0)
	_add_circle_blocker(Vector2(1775, 2432), 115.0)
	_add_circle_blocker(Vector2(3258, 1682), 175.0)
	_add_circle_blocker(Vector2(3143, 1682), 95.0)
	_add_circle_blocker(Vector2(3373, 1682), 95.0)
	_add_circle_blocker(Vector2(4173, 1697), 185.0)
	_add_circle_blocker(Vector2(4038, 1697), 105.0)
	_add_circle_blocker(Vector2(4308, 1697), 105.0)
	_add_circle_blocker(Vector2(3213, 2057), 190.0)
	_add_circle_blocker(Vector2(3058, 2082), 110.0)
	_add_circle_blocker(Vector2(3368, 2032), 110.0)
	_add_circle_blocker(Vector2(4278, 2140), 180.0)
	_add_circle_blocker(Vector2(4118, 2105), 110.0)
	_add_circle_blocker(Vector2(4438, 2175), 110.0)
	_add_circle_blocker(Vector2(3633, 2432), 155.0)
	_add_circle_blocker(Vector2(3408, 2397), 100.0)
	_add_circle_blocker(Vector2(3858, 2467), 100.0)
	_add_circle_blocker(Vector2(4661, 1817), 120.0)
	_add_circle_blocker(Vector2(4766, 2057), 95.0)

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
	_build_location("红湾卫所", Vector2(3245, 414), 270.0, Vector2.ZERO, Vector2.ZERO, "该岛屿即将开放")
	_build_location("南澳商港", Vector2(4328, 345), 380.0, Vector2.ZERO, Vector2.ZERO, "该岛屿即将开放")
	_build_location("东极秘岛", Vector2(4417, 1078), 340.0, Vector2.ZERO, Vector2.ZERO, "该岛屿即将开放")
	_build_location("澄海灯岛", Vector2(405, 1682), 220.0, Vector2.ZERO, Vector2.ZERO, "该岛屿即将开放")
	_build_location("龙门海寨", Vector2(1560, 1862), 250.0, Vector2.ZERO, Vector2.ZERO, "该岛屿即将开放")
	_build_location("白沙渔岛", Vector2(428, 2267), 240.0, Vector2.ZERO, Vector2.ZERO, "该岛屿即将开放")
	_build_location("玄潮古屿", Vector2(1605, 2432), 270.0, Vector2.ZERO, Vector2.ZERO, "该岛屿即将开放")
	_build_location("沧门礁堡", Vector2(3258, 1682), 230.0, Vector2(360, 110), Vector2(0, -230), "该岛屿即将开放")
	_build_location("月环商港", Vector2(4173, 1697), 250.0, Vector2(440, 110), Vector2(0, -245), "该岛屿即将开放")
	_build_location("雾岚群岛", Vector2(3213, 2057), 270.0, Vector2(420, 110), Vector2(0, 245), "该岛屿即将开放")
	_build_location("伏波古岭", Vector2(4278, 2140), 270.0, Vector2(460, 110), Vector2(0, 235), "该岛屿即将开放")
	_build_location("珊湾渔链", Vector2(3633, 2432), 280.0, Vector2.ZERO, Vector2.ZERO, "该岛屿即将开放")


func _build_auto_triggers() -> void:
	_build_ship_trigger("近海渔船", Vector2(940, 1040), 0)
	_build_ship_trigger("岭南商船", Vector2(1700, 930), 1)
	_build_event_trigger("漂流木箱", Vector2(820, 810))


func _configure_sea_map_hud() -> void:
	var map_locations: Array[Dictionary] = []
	for location_node in world_markers.get_children():
		if not location_node.has_meta("location_name"):
			continue
		map_locations.append({
			"name": str(location_node.get_meta("location_name", "未知地点")),
			"position": (location_node as Node2D).position,
		})
	var map_chunks: Array[Dictionary] = [
		{"texture": BASE_MAP_TEXTURE, "world_rect": Rect2(Vector2.ZERO, MAP_CHUNK_SIZE)},
		{"texture": EAST_MAP_TEXTURE, "world_rect": Rect2(EAST_MAP_ORIGIN, MAP_CHUNK_SIZE), "fade_from_left": true},
		{"texture": C_MAP_TEXTURE, "world_rect": Rect2(C_MAP_ORIGIN, MAP_CHUNK_SIZE), "fade_from_left": false, "fade_from_top": true},
		{"texture": D_MAP_TEXTURE, "world_rect": Rect2(D_MAP_ORIGIN, MAP_CHUNK_SIZE), "fade_from_left": true, "fade_from_top": true},
	]
	exploration_hud.call("configure_sea_map", player, MAP_SIZE, map_locations, map_chunks)


func _build_background_chunks() -> void:
	_configure_background_chunk("EastBackground", EAST_MAP_TEXTURE, EAST_MAP_ORIGIN, -99, true, false)
	_configure_background_chunk("CBackground", C_MAP_TEXTURE, C_MAP_ORIGIN, -98, false, true)
	_configure_background_chunk("DBackground", D_MAP_TEXTURE, D_MAP_ORIGIN, -97, true, true)


func _configure_background_chunk(node_name: String, texture: Texture2D, origin: Vector2, draw_order: int, fade_from_left: bool, fade_from_top: bool) -> void:
	var background := $World.get_node_or_null(node_name) as Sprite2D
	if background == null:
		background = Sprite2D.new()
		background.name = node_name
		$World.add_child(background)
	background.position = origin
	background.z_index = draw_order
	background.centered = false
	background.texture = texture
	background.scale = Vector2(0.75, 0.75)
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var blend_material := ShaderMaterial.new()
	blend_material.shader = MAP_CHUNK_BLEND_SHADER
	blend_material.set_shader_parameter("fade_from_left", fade_from_left)
	blend_material.set_shader_parameter("fade_from_top", fade_from_top)
	background.material = blend_material


func _configure_world_bounds() -> void:
	player.movement_bounds = Rect2(Vector2(34, 34), MAP_SIZE - Vector2(68, 68))
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = roundi(MAP_SIZE.x)
	camera.limit_bottom = roundi(MAP_SIZE.y)


func _activate_south_sea_harbor_spawn() -> void:
	for location_node in world_markers.get_children():
		if str(location_node.get_meta("location_name", "")) != "南海军港":
			continue
		var area := location_node as Area2D
		_on_location_body_entered(player, area)
		return


func _build_location(
	location_name: String,
	at: Vector2,
	trigger_radius: float,
	front_trigger_size: Vector2 = Vector2.ZERO,
	front_trigger_offset: Vector2 = Vector2.ZERO,
	entry_message: String = "该地点即将开放"
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
	area.set_meta("entry_message", entry_message)
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

	area.body_entered.connect(_on_location_body_entered.bind(area))
	area.body_exited.connect(_on_location_body_exited.bind(area))


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


func _on_location_body_entered(body: Node2D, area: Area2D) -> void:
	if body != player:
		return
	_active_location_area = area
	_active_location_name = str(area.get_meta("location_name", ""))
	_active_location_message = str(area.get_meta("entry_message", "该地点即将开放"))
	location_name_label.text = "【%s】" % _active_location_name
	if not bool(exploration_hud.call("is_menu_open")):
		interaction_prompt.show()
	_advance_exploration_stage(2)


func _on_location_body_exited(body: Node2D, area: Area2D) -> void:
	if body != player:
		return
	if _active_location_area == area:
		_active_location_area = null
		_active_location_name = ""
		_active_location_message = "该地点即将开放"
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
	if _active_location_name == "南海军港" and _entered_from_scene_two:
		_return_to_scene_two()
		return
	_show_toast("%s · %s" % [_active_location_name, _active_location_message])
	_advance_exploration_stage(3)


func _return_to_scene_two() -> void:
	if _transitioning:
		return
	_transitioning = true
	player.controls_enabled = false
	interaction_prompt.hide()
	exploration_hud.call("set_exploration_visible", false)
	var root := get_tree().root
	root.set_meta(RETURN_TO_SCENE_TWO_META, true)
	await _loading_transition.play_loading("正在进入南海军港")
	var change_error := get_tree().change_scene_to_file(SCENE_TWO_PATH)
	if change_error == OK:
		return
	root.remove_meta(RETURN_TO_SCENE_TWO_META)
	_loading_transition.reset_loading()
	_transitioning = false
	player.controls_enabled = true
	exploration_hud.call("set_exploration_visible", true)
	interaction_prompt.visible = not _active_location_name.is_empty()


func _consume_scene_two_entry_flag() -> bool:
	var root := get_tree().root
	if not root.has_meta(SCENE_TWO_ENTRY_META):
		return false
	root.remove_meta(SCENE_TWO_ENTRY_META)
	return true


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
