extends Node2D

const EVENT_SHIPS_ATLAS := preload("res://assets/sprites/sea_overworld/event_ships_atlas_v2.png")
const DRIFTING_CRATE_TEXTURE := preload("res://assets/sprites/sea_overworld/drifting_supply_crate_v1.png")
const SOLDIER_PORTRAIT := preload("res://assets/characters/soldier/picture.png")
const FIELD_EVENT_DIALOGUE_SCENE := preload("res://scenes/ui/field_event_dialogue.tscn")
const LOADING_TRANSITION_SCENE := preload("res://scenes/ui/scene_loading_transition.tscn")
const SEA_FOG_OF_WAR_SCRIPT := preload("res://scripts/sea_fog_of_war.gd")
const A_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_zone_a_v3.png")
const B_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_zone_b_v3.png")
const C_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_zone_c_v3.png")
const D_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_zone_d_v3.png")
const MAP_CHUNK_BLEND_SHADER := preload("res://shaders/map_chunk_blend.gdshader")
const MAP_CHUNK_SIZE := Vector2(2508, 1412)
const MAP_CHUNK_OVERLAP := 120.0
const B_MAP_ORIGIN := Vector2(MAP_CHUNK_SIZE.x - MAP_CHUNK_OVERLAP, 0)
const C_MAP_ORIGIN := Vector2(0, MAP_CHUNK_SIZE.y - MAP_CHUNK_OVERLAP)
const D_MAP_ORIGIN := Vector2(B_MAP_ORIGIN.x, C_MAP_ORIGIN.y)
const MAP_SIZE := D_MAP_ORIGIN + MAP_CHUNK_SIZE
const PLAYER_LAYER := 1
const SCENE_PATH := "res://scenes/sea_overworld/sea_overworld.tscn"
const TITLE_SCENE_PATH := "res://scenes/ui/title_screen.tscn"
const SCENE_TWO_ENTRY_META := "sea_overworld_from_scene_two"
const RETURN_TO_SCENE_TWO_META := "scene_two_return_from_sea_overworld"
const SCENE_TWO_PATH := "res://scenes/Scene2.tscn"
const SOUTH_SEA_HARBOR_SPAWN := Vector2(760, 1130)
const LUNAR_DAY_META := "sea_overworld_lunar_day"
const SECONDS_PER_LUNAR_DAY := 2.0

@onready var player: SeaOverworldPlayer = $World/Player
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
var _saved_scene_state: Dictionary = {}
var _event_dialogue: FieldEventDialogue
var _active_drifting_crate: Area2D
var _crate_event_resolved := false
var _fog_of_war: Node2D


func _ready() -> void:
	_saved_scene_state = _consume_saved_scene_state()
	var restoring_saved_state := not _saved_scene_state.is_empty()
	if _saved_scene_state.is_empty():
		_entered_from_scene_two = _consume_scene_two_entry_flag()
	_build_background_chunks()
	_configure_world_bounds()
	_build_locations()
	_build_auto_triggers()
	_event_dialogue = FIELD_EVENT_DIALOGUE_SCENE.instantiate() as FieldEventDialogue
	$UI.add_child(_event_dialogue)
	_event_dialogue.option_selected.connect(_on_crate_dialogue_option_selected)
	player.connect("sailed", _on_player_sailed)
	enter_button.pressed.connect(_enter_active_location)
	exploration_hud.connect("menu_visibility_changed", _on_hud_menu_visibility_changed)
	exploration_hud.connect("save_requested", _on_save_requested)
	exploration_hud.connect("load_requested", _on_load_requested)
	exploration_hud.connect("return_title_requested", _on_return_title_requested)
	exploration_hud.call("set_quest_context", &"sea_overworld")
	if _saved_scene_state.is_empty():
		_lunar_day = float(get_tree().root.get_meta(LUNAR_DAY_META, 0.0))
	else:
		_restore_saved_scene_state(_saved_scene_state)
		_saved_scene_state.clear()
	exploration_hud.call("set_lunar_day", _lunar_day)
	_refresh_exploration_task()
	exploration_hud.call("set_exploration_visible", true)
	interaction_prompt.hide()
	_loading_transition = LOADING_TRANSITION_SCENE.instantiate() as SceneLoadingTransition
	$UI.add_child(_loading_transition)
	if not restoring_saved_state:
		player.global_position = SOUTH_SEA_HARBOR_SPAWN
		_activate_south_sea_harbor_spawn()
	camera.reset_smoothing()
	_build_fog_of_war()
	_configure_sea_map_hud()


func _process(delta: float) -> void:
	_float_elapsed += delta
	for index in range(_floating_visuals.size()):
		var visual := _floating_visuals[index]
		if is_instance_valid(visual):
			visual.position.y = sin(_float_elapsed * 2.1 + index * 0.9) * 2.0
	if is_instance_valid(_fog_of_war):
		_fog_of_war.call("reveal_camera_view")


func _on_player_sailed(delta: float) -> void:
	if _transitioning or not player.controls_enabled or bool(exploration_hud.call("is_menu_open")):
		return
	if _exploration_stage == 0:
		_advance_exploration_stage(1)
	if is_instance_valid(_fog_of_war):
		_fog_of_war.call("reveal_camera_view")
	_lunar_day += delta / SECONDS_PER_LUNAR_DAY
	get_tree().root.set_meta(LUNAR_DAY_META, _lunar_day)
	exploration_hud.call("set_lunar_day", _lunar_day)


func _unhandled_key_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if _event_dialogue != null and _event_dialogue.visible:
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

func _build_locations() -> void:
	_build_location(
		"南海军港",
		Vector2(480, 1040),
		110.0,
		Vector2.ZERO,
		Vector2.ZERO,
		"该地点即将开放",
		Vector2.ZERO,
		[Vector2(20, 90), Vector2(120, 20), Vector2(280, -10), Vector2(440, 30), Vector2(570, 120)]
	)
	_build_location(
		"川山渔村",
		Vector2(1080, 650),
		95.0,
		Vector2.ZERO,
		Vector2.ZERO,
		"该地点即将开放",
		Vector2(0, -220),
		[Vector2(390, 30)]
	)
	_build_location(
		"东湾水寨",
		Vector2(2040, 520),
		105.0,
		Vector2.ZERO,
		Vector2.ZERO,
		"该地点即将开放",
		Vector2.ZERO,
		[Vector2(140, 240)]
	)
	_build_location("青屿秘境", Vector2(2380, 540), 145.0, Vector2(260, 100), Vector2(0, 170), "该地点即将开放", Vector2(420, -140))

	_build_location("沧门礁堡", Vector2(2780, 1080), 190.0, Vector2(320, 120), Vector2(-360, 140), "该岛屿即将开放")
	_build_location("月环商港", Vector2(3650, 360), 250.0, Vector2(480, 150), Vector2(-300, 80), "该岛屿即将开放")
	_build_location(
		"雾岚群岛",
		Vector2(3070, 850),
		95.0,
		Vector2.ZERO,
		Vector2.ZERO,
		"该岛屿即将开放",
		Vector2.ZERO,
		[Vector2(405, -20)]
	)
	_build_location(
		"伏波古岭",
		Vector2(4260, 780),
		110.0,
		Vector2(440, 120),
		Vector2(0, 175),
		"该岛屿即将开放",
		Vector2.ZERO,
		[],
		[Vector2(460, 445)]
	)
	_build_location(
		"珊湾渔链",
		Vector2(3670, 1150),
		110.0,
		Vector2(260, 100),
		Vector2(250, 160),
		"该岛屿即将开放",
		Vector2.ZERO,
		[],
		[Vector2(-490, 220)]
	)

	_build_location(
		"澄海灯岛",
		Vector2(480, 1680),
		85.0,
		Vector2.ZERO,
		Vector2.ZERO,
		"该岛屿即将开放",
		Vector2.ZERO,
		[
			Vector2(190, -290), Vector2(390, -230), Vector2(450, 0), Vector2(420, 220),
			Vector2(180, 300), Vector2(-60, 230), Vector2(-100, 20), Vector2(-50, -200),
		]
	)
	_build_location("龙门海寨", Vector2(860, 2260), 210.0, Vector2(400, 120), Vector2(0, 190), "该岛屿即将开放")
	_build_location("白沙渔岛", Vector2(1460, 2460), 180.0, Vector2(300, 120), Vector2(180, 140), "该岛屿即将开放")
	_build_location(
		"玄潮古屿",
		Vector2(2100, 2240),
		110.0,
		Vector2.ZERO,
		Vector2.ZERO,
		"该岛屿即将开放",
		Vector2(520, 360),
		[Vector2(100, -60), Vector2(100, 360), Vector2(420, 180)]
	)

	_build_location(
		"红湾卫所",
		Vector2(2980, 1760),
		130.0,
		Vector2.ZERO,
		Vector2.ZERO,
		"该岛屿即将开放",
		Vector2.ZERO,
		[Vector2(380, 430)]
	)
	_build_location(
		"倭寇营地",
		Vector2(4380, 2460),
		120.0,
		Vector2.ZERO,
		Vector2.ZERO,
		"该岛屿即将开放",
		Vector2.ZERO,
		[Vector2(-630, 140)]
	)


func _build_auto_triggers() -> void:
	_build_ship_trigger("近海渔船", Vector2(1650, 1170), 0)
	_build_ship_trigger("岭南商船", Vector2(2600, 760), 1)
	_build_event_trigger("漂流木箱", Vector2(1300, 1700))


func _configure_sea_map_hud() -> void:
	var map_locations: Array[Dictionary] = []
	for location_node in world_markers.get_children():
		if not location_node.has_meta("location_name"):
			continue
		var map_label_offset: Vector2 = location_node.get_meta("map_label_offset", Vector2.ZERO)
		map_locations.append({
			"name": str(location_node.get_meta("location_name", "未知地点")),
			"position": (location_node as Node2D).position + map_label_offset,
		})
	var map_chunks: Array[Dictionary] = [
		{"texture": A_MAP_TEXTURE, "world_rect": Rect2(Vector2.ZERO, MAP_CHUNK_SIZE)},
		{"texture": B_MAP_TEXTURE, "world_rect": Rect2(B_MAP_ORIGIN, MAP_CHUNK_SIZE), "fade_from_left": true},
		{"texture": C_MAP_TEXTURE, "world_rect": Rect2(C_MAP_ORIGIN, MAP_CHUNK_SIZE), "fade_from_left": false, "fade_from_top": true},
		{"texture": D_MAP_TEXTURE, "world_rect": Rect2(D_MAP_ORIGIN, MAP_CHUNK_SIZE), "fade_from_left": true, "fade_from_top": true},
	]
	exploration_hud.call("configure_sea_map", player, MAP_SIZE, map_locations, map_chunks, _fog_of_war)


func _build_fog_of_war() -> void:
	_fog_of_war = SEA_FOG_OF_WAR_SCRIPT.new() as Node2D
	_fog_of_war.name = "FogOfWar"
	$World.add_child(_fog_of_war)
	var saved_fog_state: Dictionary = {}
	var game_state := _game_state()
	if game_state != null and game_state.has_method("get_sea_fog_state"):
		saved_fog_state = game_state.call("get_sea_fog_state") as Dictionary
	_fog_of_war.call("setup", MAP_SIZE, camera, saved_fog_state)
	_fog_of_war.connect("state_changed", _store_fog_state)
	_reveal_initial_known_land()
	if saved_fog_state.is_empty():
		_fog_of_war.call("reveal_at", SOUTH_SEA_HARBOR_SPAWN)
	_fog_of_war.reveal_at(player.global_position)
	_store_fog_state()


func _reveal_initial_known_land() -> void:
	var northwest_coast := world_collision.get_node_or_null("NorthwestCoast") as CollisionPolygon2D
	if northwest_coast == null:
		return
	var world := $World as Node2D
	var world_polygon := PackedVector2Array()
	for local_point in northwest_coast.polygon:
		world_polygon.append(world.to_local(northwest_coast.to_global(local_point)))
	_fog_of_war.call("reveal_polygon", world_polygon)


func _store_fog_state() -> void:
	if not is_instance_valid(_fog_of_war):
		return
	var game_state := _game_state()
	if game_state == null or not game_state.has_method("set_sea_fog_state"):
		return
	game_state.call("set_sea_fog_state", _fog_of_war.call("serialize_state"))


func _build_background_chunks() -> void:
	_configure_background_chunk("Background", A_MAP_TEXTURE, Vector2.ZERO, -100, false, false)
	_configure_background_chunk("EastBackground", B_MAP_TEXTURE, B_MAP_ORIGIN, -99, true, false)
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
	blend_material.set_shader_parameter("world_origin", origin)
	blend_material.set_shader_parameter("world_size", MAP_CHUNK_SIZE)
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
	entry_message: String = "该地点即将开放",
	map_label_offset: Vector2 = Vector2.ZERO,
	entry_trigger_offsets: Array[Vector2] = [],
	additional_entry_trigger_offsets: Array[Vector2] = []
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
	area.set_meta("map_label_offset", map_label_offset)
	area.set_meta("entry_trigger_offsets", entry_trigger_offsets)
	area.set_meta("additional_entry_trigger_offsets", additional_entry_trigger_offsets)
	area.add_to_group("sea_location")
	world_markers.add_child(area)

	if entry_trigger_offsets.is_empty():
		_add_location_entry_trigger(area, "EntryTriggerShape", trigger_radius, front_trigger_size, front_trigger_offset)
	else:
		for index in range(entry_trigger_offsets.size()):
			var shape_name := "EntryTriggerShape" if index == 0 else "EntryTriggerShape%d" % (index + 1)
			_add_location_entry_trigger(area, shape_name, trigger_radius, Vector2.ZERO, entry_trigger_offsets[index])
	for index in range(additional_entry_trigger_offsets.size()):
		var shape_index: int = maxi(1, entry_trigger_offsets.size()) + index + 1
		_add_location_entry_trigger(
			area,
			"EntryTriggerShape%d" % shape_index,
			trigger_radius,
			Vector2.ZERO,
			additional_entry_trigger_offsets[index]
		)

	area.body_entered.connect(_on_location_body_entered.bind(area))
	area.body_exited.connect(_on_location_body_exited.bind(area))


func _add_location_entry_trigger(
	area: Area2D,
	shape_name: String,
	trigger_radius: float,
	trigger_size: Vector2,
	trigger_offset: Vector2
) -> void:
	var shape_node := CollisionShape2D.new()
	shape_node.name = shape_name
	shape_node.position = trigger_offset
	if trigger_size != Vector2.ZERO:
		var front_shape := RectangleShape2D.new()
		front_shape.size = trigger_size
		shape_node.shape = front_shape
	else:
		var radial_shape := CircleShape2D.new()
		radial_shape.radius = trigger_radius
		shape_node.shape = radial_shape
	area.add_child(shape_node)


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

	var crate_sprite := Sprite2D.new()
	crate_sprite.name = "CrateSprite"
	crate_sprite.texture = DRIFTING_CRATE_TEXTURE
	crate_sprite.scale = Vector2(0.22, 0.22)
	crate_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.add_child(crate_sprite)
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
	if trigger_kind == "event" and display_name == "漂流木箱":
		_open_drifting_crate_event(area)
		return
	if trigger_kind == "ship":
		_show_toast("%s · 该船只开发中" % display_name)
	else:
		_show_toast("%s · 该事件开发中" % display_name)
	_advance_exploration_stage(4)


func _open_drifting_crate_event(area: Area2D) -> void:
	if _crate_event_resolved or (_event_dialogue != null and _event_dialogue.visible):
		return
	_active_drifting_crate = area
	area.set_deferred("monitoring", false)
	player.controls_enabled = false
	interaction_prompt.hide()
	_event_dialogue.present(
		"水师士兵",
		"禀将军！前方海面发现一只漂流而来的木箱，箱体尚且完整，是否命人打捞？",
		SOLDIER_PORTRAIT,
		[
			{"id": &"salvage", "text": "打捞上来"},
			{"id": &"ignore", "text": "置之不理"},
		]
	)


func _on_crate_dialogue_option_selected(option_id: StringName) -> void:
	match option_id:
		&"salvage":
			_resolve_drifting_crate_event()
			_event_dialogue.present(
				"水师士兵",
				"禀将军，木箱已经打捞完毕，所得物资如下：\n金石 +100　　木材 +100　　银钱 +1000",
				SOLDIER_PORTRAIT,
				[{"id": &"continue", "text": "收下物资，继续航行"}]
			)
		&"ignore":
			_resolve_drifting_crate_event()
			_close_crate_dialogue()
		&"continue":
			_close_crate_dialogue()


func _resolve_drifting_crate_event() -> void:
	if _crate_event_resolved:
		return
	_crate_event_resolved = true
	_remove_drifting_crate()
	_advance_exploration_stage(4)


func _remove_drifting_crate() -> void:
	var crate := _active_drifting_crate
	if not is_instance_valid(crate):
		crate = world_markers.get_node_or_null("DriftEvent") as Area2D
	if is_instance_valid(crate):
		crate.queue_free()
	_active_drifting_crate = null


func _close_crate_dialogue() -> void:
	_event_dialogue.hide_dialogue()
	player.controls_enabled = not bool(exploration_hud.call("is_menu_open"))
	interaction_prompt.visible = player.controls_enabled and not _active_location_name.is_empty()


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
	_store_fog_state()
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
	exploration_hud.call("set_main_task_progress", "探索海域，完善海图", objective, _exploration_stage)


func _on_hud_menu_visibility_changed(is_open: bool) -> void:
	var dialogue_open := _event_dialogue != null and _event_dialogue.visible
	player.controls_enabled = not is_open and not dialogue_open
	interaction_prompt.visible = not is_open and not dialogue_open and not _active_location_name.is_empty()


func _on_save_requested() -> void:
	if _transitioning:
		_show_save_message(false, "unstable_scene")
		return
	var game_state := _game_state()
	if game_state == null:
		_show_save_message(false, "write_failed")
		return
	_store_fog_state()
	var snapshot := {
		"player_position": _vector_to_save(player.global_position),
		"facing_index": int(player.call("save_facing_index")),
		"exploration_stage": _exploration_stage,
		"lunar_day": _lunar_day,
		"crate_event_resolved": _crate_event_resolved,
	}
	var result: Dictionary = game_state.call("save_game", SCENE_PATH, snapshot)
	_show_save_message(bool(result.get("ok", false)), str(result.get("reason", "")))


func _on_load_requested() -> void:
	var game_state := _game_state()
	if game_state == null:
		_show_save_message(false, "read_failed")
		return
	var result: Dictionary = game_state.call("load_game")
	if not result.get("ok", false):
		_show_save_message(false, str(result.get("reason", "read_failed")))
		return
	var change_error := get_tree().change_scene_to_file(str(result["scene_path"]))
	if change_error != OK:
		game_state.call("clear_pending_scene_state")
		_show_save_message(false, "scene_change_failed")


func _on_return_title_requested() -> void:
	var game_state := _game_state()
	if game_state != null:
		game_state.call("clear_pending_scene_state")
	var change_error := get_tree().change_scene_to_file(TITLE_SCENE_PATH)
	if change_error != OK:
		_show_save_message(false, "scene_change_failed")


func _consume_saved_scene_state() -> Dictionary:
	var game_state := _game_state()
	if game_state == null:
		return {}
	return game_state.call("consume_pending_scene_state", SCENE_PATH) as Dictionary


func _restore_saved_scene_state(snapshot: Dictionary) -> void:
	var restored_position := _vector_from_save(snapshot.get("player_position"), player.global_position)
	player.global_position = restored_position.clamp(player.movement_bounds.position, player.movement_bounds.end)
	player.call("restore_facing_index", int(snapshot.get("facing_index", 0)))
	_exploration_stage = clampi(int(snapshot.get("exploration_stage", 0)), 0, 4)
	_lunar_day = maxf(0.0, float(snapshot.get("lunar_day", 0.0)))
	_crate_event_resolved = bool(snapshot.get("crate_event_resolved", false))
	if _crate_event_resolved:
		_remove_drifting_crate()
	get_tree().root.set_meta(LUNAR_DAY_META, _lunar_day)


func _show_save_message(success: bool, reason: String) -> void:
	if success:
		exploration_hud.call("show_toast", "进度已保存")
		return
	var game_state := _game_state()
	var message := "存档操作失败。" if game_state == null else str(game_state.call("error_message", reason))
	exploration_hud.call("show_toast", message)


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func _vector_to_save(value: Vector2) -> Array:
	return [value.x, value.y]


func _vector_from_save(value: Variant, fallback: Vector2) -> Vector2:
	if not value is Array or value.size() != 2:
		return fallback
	var restored := Vector2(float(value[0]), float(value[1]))
	return restored if is_finite(restored.x) and is_finite(restored.y) else fallback


func _atlas_region(texture: Texture2D, columns: int, rows: int, column: int, row: int) -> AtlasTexture:
	var frame_size := Vector2(texture.get_width() / float(columns), texture.get_height() / float(rows))
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = texture
	atlas_texture.region = Rect2(Vector2(column, row) * frame_size, frame_size)
	return atlas_texture
