extends Node2D

const EVENT_SHIPS_ATLAS := preload("res://assets/sprites/sea_overworld/event_ships_atlas_v2.png")
const DRIFTING_CRATE_TEXTURE := preload("res://assets/sprites/sea_overworld/drifting_supply_crate_v1.png")
const SOLDIER_PORTRAIT := preload("res://assets/characters/soldier/picture.png")
const TEA_MERCHANT_PORTRAIT := preload("res://assets/sea_overworld/portraits/大地图茶叶商人.png")
const SALT_MERCHANT_PORTRAIT := preload("res://assets/sea_overworld/portraits/大地图私盐商人.png")
const FIELD_EVENT_DIALOGUE_SCENE := preload("res://scenes/ui/field_event_dialogue.tscn")
const LOADING_TRANSITION_SCENE := preload("res://scenes/ui/scene_loading_transition.tscn")
const SEA_FOG_OF_WAR_SCRIPT := preload("res://scripts/sea_fog_of_war.gd")
const A_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_zone_a_v3.png")
const B_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_zone_b_v3.png")
const C_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_zone_c_v3.png")
const D_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_zone_d_v3.png")
const FUBO_TRAVEL := preload("res://scripts/fubo_guling/fubo_travel_session.gd")
const MAP_CHUNK_BLEND_SHADER := preload("res://shaders/map_chunk_blend.gdshader")
const SEA_FLOW_TEXTURE := preload("res://assets/textures/water/sea_ink_pixel.png")
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
const SOUTH_SEA_HARBOR_SPAWN := Vector2(1300, 850)
const LUNAR_DAY_META := "sea_overworld_lunar_day"
const SECONDS_PER_LUNAR_DAY := 2.0

@onready var player: SeaOverworldPlayer = $World/Player
@onready var camera: Camera2D = $World/Player/Camera2D
@onready var world_collision: StaticBody2D = $World/WorldCollision
@onready var world_markers: Node2D = $World/WorldMarkers
var exploration_hud: Control
var _exploration_ui: Node
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
var _fubo_return_context: Dictionary = {}
var _returning_from_fubo := false
var _event_dialogue: FieldEventDialogue
var _active_drifting_crate: Area2D
var _crate_event_resolved := false
var _active_tea_merchant_ship: Area2D
var _tea_merchant_event_resolved := false
var _active_salt_merchant_ship: Area2D
var _salt_merchant_event_resolved := false
var _fog_of_war: Node2D


func _ready() -> void:
	_exploration_ui = get_node("/root/ExplorationUI")
	exploration_hud = _exploration_ui.call("acquire", self, &"sea_overworld") as Control
	_saved_scene_state = _consume_saved_scene_state()
	_fubo_return_context = _consume_fubo_return()
	if _saved_scene_state.is_empty() and not _returning_from_fubo:
		_entered_from_scene_two = _consume_scene_two_entry_flag()
	_build_background_chunks()
	_configure_world_bounds()
	_build_world_collisions()
	_build_locations()
	_build_auto_triggers()
	_event_dialogue = FIELD_EVENT_DIALOGUE_SCENE.instantiate() as FieldEventDialogue
	$UI.add_child(_event_dialogue)
	_event_dialogue.option_selected.connect(_on_event_dialogue_option_selected)
	_event_dialogue.visibility_changed.connect(_on_event_dialogue_visibility_changed)
	player.connect("sailed", _on_player_sailed)
	enter_button.pressed.connect(_enter_active_location)
	_connect_global_hud_signals()
	exploration_hud.call("set_quest_context", &"sea_overworld")
	_on_event_dialogue_visibility_changed()
	if not _saved_scene_state.is_empty():
		_restore_saved_scene_state(_saved_scene_state)
		_saved_scene_state.clear()
	elif _returning_from_fubo:
		_restore_fubo_return(_fubo_return_context)
		_fubo_return_context.clear()
	else:
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
	camera.reset_smoothing()
	_build_fog_of_war()
	_configure_sea_map_hud()


func _exit_tree() -> void:
	if _exploration_ui == null:
		return
	_disconnect_global_hud_signals()
	_exploration_ui.call("release", self)


func _connect_global_hud_signals() -> void:
	for binding in [
		[&"menu_visibility_changed", Callable(self, "_on_hud_menu_visibility_changed")],
		[&"save_requested", Callable(self, "_on_save_requested")],
		[&"load_requested", Callable(self, "_on_load_requested")],
		[&"return_title_requested", Callable(self, "_on_return_title_requested")],
	]:
		if not _exploration_ui.is_connected(binding[0], binding[1]):
			_exploration_ui.connect(binding[0], binding[1])


func _disconnect_global_hud_signals() -> void:
	for binding in [
		[&"menu_visibility_changed", Callable(self, "_on_hud_menu_visibility_changed")],
		[&"save_requested", Callable(self, "_on_save_requested")],
		[&"load_requested", Callable(self, "_on_load_requested")],
		[&"return_title_requested", Callable(self, "_on_return_title_requested")],
	]:
		if _exploration_ui.is_connected(binding[0], binding[1]):
			_exploration_ui.disconnect(binding[0], binding[1])


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

func _build_world_collisions() -> void:
	# Northwest mainland follows the visible shoreline while leaving every dock approach in water.
	_add_polygon_blocker("NorthwestCoast", PackedVector2Array([
		Vector2(0, 0), Vector2(1810, 0), Vector2(1780, 100), Vector2(1650, 145),
		Vector2(1530, 205), Vector2(1470, 310), Vector2(1510, 430), Vector2(1650, 520),
		Vector2(1710, 610), Vector2(1600, 675), Vector2(1450, 650), Vector2(1320, 720),
		Vector2(1180, 690), Vector2(1040, 735), Vector2(880, 725), Vector2(720, 770),
		Vector2(570, 800), Vector2(470, 880), Vector2(445, 970), Vector2(330, 1040),
		Vector2(180, 1030), Vector2(0, 1090),
	]))

	# A-zone crescent village: short round segments preserve the open basin and southern landing water.
	_add_circle_blocker("ChuanshanWestRock", Vector2(350, 1020), 105.0)
	_add_circle_blocker("ChuanshanNorthwestWall", Vector2(500, 925), 120.0)
	_add_circle_blocker("ChuanshanNorthWall", Vector2(700, 885), 115.0)
	_add_circle_blocker("ChuanshanNortheastWall", Vector2(930, 900), 125.0)
	_add_circle_blocker("ChuanshanEastWall", Vector2(1160, 985), 145.0)
	_add_circle_blocker("ChuanshanEastRock", Vector2(1360, 1090), 115.0)

	_add_polygon_blocker("EastBaySandbar", PackedVector2Array([
		Vector2(1710, 620), Vector2(1830, 565), Vector2(2010, 590), Vector2(2135, 670),
		Vector2(2040, 715), Vector2(1830, 705),
	]))
	_add_polygon_blocker("QingyuPagodaIsland", PackedVector2Array([
		Vector2(2260, 495), Vector2(2380, 425), Vector2(2490, 475), Vector2(2515, 600),
		Vector2(2420, 650), Vector2(2290, 610),
	]))

	# B-zone landmarks use separate hulls so the moon harbor and central water gate remain open.
	_add_polygon_blocker("CangmenFortress", PackedVector2Array([
		Vector2(2490, 1050), Vector2(2630, 950), Vector2(2860, 945), Vector2(2995, 1040),
		Vector2(3010, 1195), Vector2(2900, 1280), Vector2(2660, 1280), Vector2(2500, 1190),
	]))
	_add_polygon_blocker("CangmenDock", PackedVector2Array([
		Vector2(2370, 1165), Vector2(2525, 1095), Vector2(2580, 1160), Vector2(2450, 1230),
	]))
	_add_circle_blocker("MoonHarborNorthwest", Vector2(3380, 400), 120.0)
	_add_circle_blocker("MoonHarborNorth", Vector2(3500, 300), 110.0)
	_add_circle_blocker("MoonHarborCrown", Vector2(3650, 285), 120.0)
	_add_circle_blocker("MoonHarborEast", Vector2(3780, 365), 130.0)
	_add_circle_blocker("MoonHarborSoutheast", Vector2(3810, 510), 125.0)
	_add_circle_blocker("MoonHarborSouth", Vector2(3690, 600), 105.0)
	_add_polygon_blocker("WulanVillageIsland", PackedVector2Array([
		Vector2(3185, 700), Vector2(3290, 650), Vector2(3430, 680), Vector2(3500, 760),
		Vector2(3410, 825), Vector2(3240, 800),
	]))
	_add_polygon_blocker("FuboRidge", PackedVector2Array([
		Vector2(3860, 735), Vector2(3970, 665), Vector2(4170, 700), Vector2(4390, 820),
		Vector2(4710, 935), Vector2(4780, 1035), Vector2(4560, 1080), Vector2(4350, 1010),
		Vector2(4140, 950), Vector2(3950, 895),
	]))
	_add_polygon_blocker("ShanwanMountain", PackedVector2Array([
		Vector2(3260, 1040), Vector2(3440, 940), Vector2(3620, 1020), Vector2(3810, 1180),
		Vector2(3700, 1330), Vector2(3440, 1390), Vector2(3230, 1290),
	]))

	# C-zone silhouettes are inset from foam and docks to keep landings reachable.
	_add_polygon_blocker("ChenghaiLighthouse", PackedVector2Array([
		Vector2(500, 1510), Vector2(640, 1460), Vector2(760, 1570), Vector2(785, 1790),
		Vector2(680, 1880), Vector2(520, 1850), Vector2(440, 1700),
	]))
	_add_polygon_blocker("LongmenStronghold", PackedVector2Array([
		Vector2(540, 2150), Vector2(720, 2070), Vector2(980, 2090), Vector2(1175, 2230),
		Vector2(1120, 2390), Vector2(850, 2440), Vector2(580, 2340),
	]))
	_add_polygon_blocker("BaishaSandbar", PackedVector2Array([
		Vector2(1360, 2370), Vector2(1550, 2270), Vector2(1810, 2260), Vector2(1990, 2375),
		Vector2(1890, 2490), Vector2(1590, 2535), Vector2(1380, 2475),
	]))
	_add_circle_blocker("XuanchaoWestReef", Vector2(1980, 2395), 38.0)
	_add_circle_blocker("XuanchaoMainReef", Vector2(2220, 2340), 58.0)
	_add_circle_blocker("XuanchaoSouthReef", Vector2(2130, 2460), 34.0)

	# D-zone keeps the western approach and south-facing final-port basin clear.
	_add_polygon_blocker("RedBayMountain", PackedVector2Array([
		Vector2(2820, 1800), Vector2(2990, 1710), Vector2(3170, 1780), Vector2(3370, 1970),
		Vector2(3310, 2160), Vector2(3140, 2240), Vector2(2920, 2190), Vector2(2740, 2040),
	]))
	_add_polygon_blocker("NanaoWestWall", PackedVector2Array([
		Vector2(3510, 2260), Vector2(3680, 2140), Vector2(3790, 2280), Vector2(3650, 2410),
		Vector2(3510, 2440),
	]))
	_add_polygon_blocker("NanaoCitadel", PackedVector2Array([
		Vector2(3690, 2080), Vector2(3860, 1920), Vector2(4250, 1820), Vector2(4540, 1940),
		Vector2(4720, 2160), Vector2(4680, 2360), Vector2(4550, 2480), Vector2(4250, 2460),
		Vector2(4130, 2350), Vector2(4000, 2350), Vector2(3900, 2270), Vector2(3730, 2300),
	]))

	# Only visually solid micro-reefs block movement; the central wreck is intentionally decorative.
	_add_circle_blocker("CentralNorthReef", Vector2(1950, 1585), 38.0)
	_add_circle_blocker("CentralEastReef", Vector2(2310, 1840), 34.0)
	_add_circle_blocker("ShanwanOuterReef", Vector2(3970, 1240), 46.0)


func _build_locations() -> void:
	_build_location("南海军港", Vector2(1080, 650), 238.0, Vector2(480, 130), Vector2(0, 250))
	_build_location("川山渔村", Vector2(480, 1040), 170.0, Vector2(320, 110), Vector2(0, 160))
	_build_location("东湾水寨", Vector2(2040, 520), 225.0, Vector2(440, 120), Vector2(0, 180))
	_build_location("青屿秘境", Vector2(2380, 540), 145.0, Vector2(260, 100), Vector2(0, 170), "该地点即将开放", Vector2(420, -140))

	_build_location("沧门礁堡", Vector2(2780, 1080), 190.0, Vector2(320, 120), Vector2(-360, 140), "该岛屿即将开放")
	_build_location("月环商港", Vector2(3650, 360), 250.0, Vector2(480, 150), Vector2(-300, 80), "该岛屿即将开放")
	_build_location("雾岚群岛", Vector2(3070, 850), 165.0, Vector2.ZERO, Vector2.ZERO, "该岛屿即将开放")
	_build_location("伏波古岭", Vector2(4260, 780), 220.0, Vector2(440, 120), Vector2(0, 175), "进入伏波古岭", Vector2.ZERO, FUBO_TRAVEL.FUBO_SCENE_PATH)
	_build_location("珊湾渔链", Vector2(3670, 1150), 155.0, Vector2(260, 100), Vector2(250, 160), "该岛屿即将开放")

	_build_location("澄海灯岛", Vector2(480, 1680), 155.0, Vector2.ZERO, Vector2.ZERO, "该岛屿即将开放")
	_build_location("龙门海寨", Vector2(860, 2260), 210.0, Vector2(400, 120), Vector2(0, 190), "该岛屿即将开放")
	_build_location("白沙渔岛", Vector2(1460, 2460), 180.0, Vector2(360, 110), Vector2(0, 135), "该岛屿即将开放")
	_build_location("玄潮古屿", Vector2(2100, 2240), 155.0, Vector2.ZERO, Vector2.ZERO, "该岛屿即将开放")

	_build_location("红湾卫所", Vector2(2980, 1760), 190.0, Vector2(360, 120), Vector2(-160, 170), "该岛屿即将开放")
	_build_location("南澳商港", Vector2(4380, 2460), 280.0, Vector2(560, 150), Vector2(-100, 180), "该岛屿即将开放")


func _build_auto_triggers() -> void:
	_build_ship_trigger("茶叶商船", Vector2(1370, 760), 0)
	_build_ship_trigger("岭南商船", Vector2(2600, 760), 1)
	_build_ship_trigger("私盐商船", Vector2(2180, 1400), 0, "SaltMerchantShip", 48.0)
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
	_fog_of_war.call("reveal_at", player.global_position)
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
	var distortion_noise := _create_water_noise_texture(0.025, 3, 0.5)
	_configure_background_chunk("Background", A_MAP_TEXTURE, Vector2.ZERO, -100, false, false, distortion_noise)
	_configure_background_chunk("EastBackground", B_MAP_TEXTURE, B_MAP_ORIGIN, -99, true, false, distortion_noise)
	_configure_background_chunk("CBackground", C_MAP_TEXTURE, C_MAP_ORIGIN, -98, false, true, distortion_noise)
	_configure_background_chunk("DBackground", D_MAP_TEXTURE, D_MAP_ORIGIN, -97, true, true, distortion_noise)


func _create_water_noise_texture(frequency: float, octaves: int, gain: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	noise.fractal_gain = gain
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.noise = noise
	texture.seamless = true
	return texture


func _configure_background_chunk(node_name: String, texture: Texture2D, origin: Vector2, draw_order: int, fade_from_left: bool, fade_from_top: bool, distortion_noise: Texture2D) -> void:
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
	blend_material.set_shader_parameter("waterNoise", distortion_noise)
	blend_material.set_shader_parameter("waterFlowTexture", SEA_FLOW_TEXTURE)
	blend_material.set_shader_parameter("waterDistortionNoise", distortion_noise)
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
	target_scene_path: String = ""
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
	area.set_meta("target_scene_path", target_scene_path)
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


func _build_ship_trigger(ship_name: String, at: Vector2, atlas_column: int, node_name: String = "", trigger_radius: float = 82.0) -> void:
	var trigger_name := node_name if not node_name.is_empty() else "ShipTrigger%d" % atlas_column
	var area := _make_auto_trigger(trigger_name, at, ship_name, "ship", trigger_radius)
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


func _make_auto_trigger(node_name: String, at: Vector2, display_name: String, trigger_kind: String, trigger_radius: float = 82.0) -> Area2D:
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
	shape.radius = trigger_radius
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
	if trigger_kind == "ship" and display_name == "私盐商船":
		_open_salt_merchant_event(area)
		return
	if trigger_kind == "ship" and display_name == "茶叶商船":
		_open_tea_merchant_event(area)
		return
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


func _open_tea_merchant_event(area: Area2D) -> void:
	if _tea_merchant_event_resolved or (_event_dialogue != null and _event_dialogue.visible):
		return
	_active_tea_merchant_ship = area
	area.set_deferred("monitoring", false)
	player.controls_enabled = false
	interaction_prompt.hide()
	_event_dialogue.present(
		"茶叶商人",
		"将军，这是姑苏新产的龙井茶。我们沿途遭遇风暴，船只受损，急需银钱修缮。还望将军购买一些茶叶，助我们渡过难关。",
		TEA_MERCHANT_PORTRAIT,
		[
			{"id": &"buy_longjing_tea", "text": "购买龙井茶"},
			{"id": &"decline_longjing_tea", "text": "不购买"},
		]
	)


func _open_salt_merchant_event(area: Area2D) -> void:
	if _salt_merchant_event_resolved or (_event_dialogue != null and _event_dialogue.visible):
		return
	_active_salt_merchant_ship = area
	area.set_deferred("monitoring", false)
	player.controls_enabled = false
	interaction_prompt.hide()
	_event_dialogue.present(
		"私盐商人",
		"将军，小船只是寻常行商，装的都是沿海急需的盐货。若将军肯通融，我们愿奉上一份薄礼……",
		SALT_MERCHANT_PORTRAIT,
		[
			{"id": &"seize_private_salt", "text": "查扣私盐"},
			{"id": &"accept_salt_bribe", "text": "收下贿赂"},
			{"id": &"release_salt_ship", "text": "放行商船"},
		]
	)


func _on_event_dialogue_option_selected(option_id: StringName) -> void:
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
		&"buy_longjing_tea":
			_event_dialogue.present(
				"茶叶商人",
				"多谢将军相助！",
				TEA_MERCHANT_PORTRAIT,
				[{"id": &"finish_tea_trade", "text": "收下龙井茶，继续航行"}],
				"银钱 -1000　　获得商品：[color=#f2c45c]龙井茶[/color]"
			)
		&"decline_longjing_tea", &"finish_tea_trade":
			_finish_tea_merchant_event()
		&"seize_private_salt":
			_event_dialogue.present(
				"私盐商人",
				"官爷饶命！这些盐货都交由水师处置。",
				SALT_MERCHANT_PORTRAIT,
				[{"id": &"finish_salt_event", "text": "收缴货物，继续航行"}],
				"查获物品：[color=#f2c45c]私盐[/color]"
			)
		&"accept_salt_bribe":
			_event_dialogue.present(
				"私盐商人",
				"多谢将军高抬贵手，这点薄礼还请笑纳。",
				SALT_MERCHANT_PORTRAIT,
				[{"id": &"finish_salt_event", "text": "收下银钱，继续航行"}],
				"银钱 +800"
			)
		&"release_salt_ship":
			_event_dialogue.present(
				"私盐商人",
				"多谢将军通融，我们这便离开。",
				SALT_MERCHANT_PORTRAIT,
				[{"id": &"finish_salt_event", "text": "继续航行"}],
				"商船离开，无事发生"
			)
		&"finish_salt_event":
			_finish_salt_merchant_event()


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


func _finish_tea_merchant_event() -> void:
	_event_dialogue.hide_dialogue()
	_resolve_tea_merchant_event()
	_restore_controls_after_event()


func _resolve_tea_merchant_event() -> void:
	if _tea_merchant_event_resolved:
		return
	_tea_merchant_event_resolved = true
	_remove_tea_merchant_ship()
	_advance_exploration_stage(4)


func _remove_tea_merchant_ship() -> void:
	var merchant_ship := _active_tea_merchant_ship
	if not is_instance_valid(merchant_ship):
		merchant_ship = world_markers.get_node_or_null("ShipTrigger0") as Area2D
	if is_instance_valid(merchant_ship):
		merchant_ship.queue_free()
	_active_tea_merchant_ship = null


func _finish_salt_merchant_event() -> void:
	_event_dialogue.hide_dialogue()
	_resolve_salt_merchant_event()
	_restore_controls_after_event()


func _resolve_salt_merchant_event() -> void:
	if _salt_merchant_event_resolved:
		return
	_salt_merchant_event_resolved = true
	_remove_salt_merchant_ship()
	_advance_exploration_stage(4)


func _remove_salt_merchant_ship() -> void:
	var merchant_ship := _active_salt_merchant_ship
	if not is_instance_valid(merchant_ship):
		merchant_ship = world_markers.get_node_or_null("SaltMerchantShip") as Area2D
	if is_instance_valid(merchant_ship):
		merchant_ship.queue_free()
	_active_salt_merchant_ship = null


func _close_crate_dialogue() -> void:
	_event_dialogue.hide_dialogue()
	_restore_controls_after_event()


func _restore_controls_after_event() -> void:
	player.controls_enabled = not bool(exploration_hud.call("is_menu_open"))
	interaction_prompt.visible = player.controls_enabled and not _active_location_name.is_empty()


func _on_event_dialogue_visibility_changed() -> void:
	if _event_dialogue == null:
		return
	exploration_hud.call("set_sea_map_button_visible", not _event_dialogue.visible)


func _enter_active_location() -> void:
	if _active_location_name.is_empty() or _transitioning:
		return
	if _active_location_name == "南海军港" and _entered_from_scene_two:
		_return_to_scene_two()
		return
	var target_scene_path := "" if _active_location_area == null else str(_active_location_area.get_meta("target_scene_path", ""))
	if not target_scene_path.is_empty():
		_advance_exploration_stage(3)
		_enter_location_scene(target_scene_path, "正在登陆%s" % _active_location_name)
		return
	_show_toast("%s · %s" % [_active_location_name, _active_location_message])
	_advance_exploration_stage(3)


func _enter_location_scene(scene_path: String, loading_text: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	_store_fog_state()
	var scene_root := get_tree().root
	scene_root.set_meta(FUBO_TRAVEL.RETURN_CONTEXT_META, FUBO_TRAVEL.make_context(
		player.global_position,
		int(player.call("save_facing_index")),
		_exploration_stage,
		_lunar_day,
		_current_event_state()
	))
	player.controls_enabled = false
	interaction_prompt.hide()
	exploration_hud.call("set_exploration_visible", false)
	await _loading_transition.play_loading(loading_text)
	var change_error := get_tree().change_scene_to_file(scene_path)
	if change_error == OK:
		return
	scene_root.remove_meta(FUBO_TRAVEL.RETURN_CONTEXT_META)
	_loading_transition.reset_loading()
	_transitioning = false
	player.controls_enabled = true
	exploration_hud.call("set_exploration_visible", true)
	interaction_prompt.visible = not _active_location_name.is_empty()


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


func _consume_fubo_return() -> Dictionary:
	var scene_root := get_tree().root
	_returning_from_fubo = scene_root.has_meta(FUBO_TRAVEL.RETURN_REQUEST_META)
	if not _returning_from_fubo:
		return {}
	scene_root.remove_meta(FUBO_TRAVEL.RETURN_REQUEST_META)
	var raw_context: Variant = scene_root.get_meta(FUBO_TRAVEL.RETURN_CONTEXT_META, {})
	if scene_root.has_meta(FUBO_TRAVEL.RETURN_CONTEXT_META):
		scene_root.remove_meta(FUBO_TRAVEL.RETURN_CONTEXT_META)
	return FUBO_TRAVEL.decode_context(raw_context)


func _restore_fubo_return(context: Dictionary) -> void:
	var restored := FUBO_TRAVEL.decode_context(context)
	if restored.is_empty():
		player.global_position = FUBO_TRAVEL.FALLBACK_SEA_POSITION.clamp(player.movement_bounds.position, player.movement_bounds.end)
		_lunar_day = maxf(0.0, float(get_tree().root.get_meta(LUNAR_DAY_META, _lunar_day)))
	else:
		player.global_position = (restored["ship_position"] as Vector2).clamp(player.movement_bounds.position, player.movement_bounds.end)
		player.call("restore_facing_index", int(restored["facing_index"]))
		_exploration_stage = int(restored["exploration_stage"])
		_lunar_day = float(restored["lunar_day"])
		_restore_event_state(restored.get("sea_event_state", {}))
	get_tree().root.set_meta(LUNAR_DAY_META, _lunar_day)


func _current_event_state() -> Dictionary:
	return {
		"crate_event_resolved": _crate_event_resolved,
		"tea_merchant_event_resolved": _tea_merchant_event_resolved,
		"salt_merchant_event_resolved": _salt_merchant_event_resolved,
	}


func _restore_event_state(value: Variant) -> void:
	if not value is Dictionary:
		return
	var state := value as Dictionary
	_crate_event_resolved = bool(state.get("crate_event_resolved", false))
	_tea_merchant_event_resolved = bool(state.get("tea_merchant_event_resolved", false))
	_salt_merchant_event_resolved = bool(state.get("salt_merchant_event_resolved", false))
	if _crate_event_resolved:
		_remove_drifting_crate()
	if _tea_merchant_event_resolved:
		_remove_tea_merchant_ship()
	if _salt_merchant_event_resolved:
		_remove_salt_merchant_ship()


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
	if _exploration_ui.call("current_owner") != self:
		return
	var dialogue_open := _event_dialogue != null and _event_dialogue.visible
	player.controls_enabled = not is_open and not dialogue_open
	interaction_prompt.visible = not is_open and not dialogue_open and not _active_location_name.is_empty()


func _on_save_requested() -> void:
	if _exploration_ui.call("current_owner") != self:
		return
	if _transitioning or (_event_dialogue != null and _event_dialogue.visible):
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
		"tea_merchant_event_resolved": _tea_merchant_event_resolved,
		"salt_merchant_event_resolved": _salt_merchant_event_resolved,
	}
	var result: Dictionary = game_state.call("save_game", SCENE_PATH, snapshot)
	_show_save_message(bool(result.get("ok", false)), str(result.get("reason", "")))


func _on_load_requested() -> void:
	if _exploration_ui.call("current_owner") != self:
		return
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
	if _exploration_ui.call("current_owner") != self:
		return
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
	_restore_event_state(snapshot)
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


func _add_polygon_blocker(node_name: String, points: PackedVector2Array) -> void:
	var shape_node := CollisionPolygon2D.new()
	shape_node.name = node_name
	shape_node.polygon = points
	world_collision.add_child(shape_node)


func _add_circle_blocker(node_name: String, at: Vector2, radius: float) -> void:
	var shape_node := CollisionShape2D.new()
	shape_node.name = node_name
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
