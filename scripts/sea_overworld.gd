extends Node2D

const EVENT_SHIPS_ATLAS := preload("res://assets/sprites/sea_overworld/event_ships_atlas_v2.png")
const DRIFTING_CRATE_TEXTURE := preload("res://assets/sprites/sea_overworld/drifting_supply_crate_v1.png")
const SEA_MONSTER_SHADOW_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/sea_overworld/random_events/海怪水下影1_v2.png"),
	preload("res://assets/sprites/sea_overworld/random_events/海怪水下影2_v2.png"),
	preload("res://assets/sprites/sea_overworld/random_events/海怪水下影3_v2.png"),
]
const SEA_MONSTER_SURFACE_MIST_TEXTURE := preload("res://assets/sprites/sea_overworld/random_events/海怪贴海薄雾_v2.png")
const SOLDIER_PORTRAIT := preload("res://assets/characters/soldier/picture.png")
const PROTAGONIST_PORTRAIT := preload("res://assets/characters/protagonist/picture.png")
const TEA_MERCHANT_PORTRAIT := preload("res://assets/sea_overworld/portraits/大地图茶叶商人.png")
const SALT_MERCHANT_PORTRAIT := preload("res://assets/sea_overworld/portraits/大地图私盐商人.png")
const HAIBATIAN_PORTRAIT := preload("res://assets/sea_overworld/portraits/倭寇头目海霸天.png")
const SEA_MONSTER_PORTRAITS: Array[Texture2D] = [
	preload("res://assets/sea_overworld/portraits/海怪1.png"),
	preload("res://assets/sea_overworld/portraits/海怪2.png"),
	preload("res://assets/sea_overworld/portraits/海怪3.png"),
]
const FIELD_EVENT_DIALOGUE_SCENE := preload("res://scenes/ui/field_event_dialogue.tscn")
const LOADING_TRANSITION_SCENE := preload("res://scenes/ui/scene_loading_transition.tscn")
const WOKOU_VICTORY_CUTSCENE_SCENE := preload("res://scenes/sea_overworld/wokou_victory_cutscene.tscn")
const PIRATE_SCENE := preload("res://scenes/sea_overworld/sea_overworld_pirate.tscn")
const SEA_FOG_OF_WAR_SCRIPT := preload("res://scripts/sea_fog_of_war.gd")
const A_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_zone_a_v3.png")
const B_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_zone_b_v3.png")
const C_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_zone_c_v3.png")
const D_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_zone_d_v3.png")
const FUBO_TRAVEL := preload("res://scripts/fubo_guling/fubo_travel_session.gd")
const MAP_CHUNK_BLEND_SHADER := preload("res://shaders/map_chunk_blend.gdshader")
const SEA_EVENT_VIGNETTE_SHADER := preload("res://shaders/sea_event_vignette.gdshader")
const SEA_MONSTER_SHADOW_SHADER := preload("res://shaders/sea_monster_shadow.gdshader")
const SEA_MONSTER_RIPPLE_SHADER := preload("res://shaders/sea_monster_ripple.gdshader")
const SEA_FLOW_TEXTURE := preload("res://assets/textures/water/sea_ink_pixel_seamless_v2.png")
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
const SOUTH_SEA_HARBOR_SPAWN := Vector2(880, 1170)
const LUNAR_DAY_META := "sea_overworld_lunar_day"
const SECONDS_PER_LUNAR_DAY := 2.0
const FUBO_QUEST_TRIGGER_POSITION := Vector2(4260, 780)
const FUBO_QUEST_TRIGGER_RADIUS := 760.0
const WOKOU_STRONGHOLD_POSITION := Vector2(4380, 2460)
const WOKOU_WARNING_TRIGGER_RADIUS := 1200.0
const PIRATE_COUNT := 5
const PIRATE_HARBOR_SAFE_RADIUS := 1100.0
const PIRATE_PLAYER_SAFE_RADIUS := 480.0
const PIRATE_SEPARATION := 460.0
const PIRATE_SPAWN_EDGE_MARGIN := 120.0
const PIRATE_SPAWN_CLEARANCE := 48.0
const MAX_ACTIVE_RANDOM_EVENTS := 3
const RANDOM_EVENT_TEA := &"tea_merchant"
const RANDOM_EVENT_SALT := &"salt_merchant"
const RANDOM_EVENT_CRATE := &"drifting_crate"
const RANDOM_EVENT_SEA_MONSTER := &"sea_monster_mist"
const RANDOM_EVENT_TYPES: Array[StringName] = [RANDOM_EVENT_TEA, RANDOM_EVENT_SALT, RANDOM_EVENT_CRATE, RANDOM_EVENT_SEA_MONSTER]
const RANDOM_EVENT_SPAWN_POINTS := {
	RANDOM_EVENT_TEA: Vector2(1370, 760),
	RANDOM_EVENT_SALT: Vector2(2200, 1500),
	RANDOM_EVENT_CRATE: Vector2(1300, 1700),
}
const RANDOM_EVENT_SPAWN_CLEARANCE := 82.0
const SEA_MONSTER_DEEP_WATER_SPAWN_POINTS: Array[Vector2] = [
	Vector2(1600, 1900),
	Vector2(4580, 250),
	Vector2(4580, 1530),
]
const SEA_MONSTER_SPAWN_CLEARANCE := 220.0
const RANDOM_EVENT_SPAWN_SEPARATION := 360.0
const RANDOM_EVENT_VIEW_MARGIN := 96.0
const SALT_MERCHANT_MOVE_SPEED := 210.0
const SALT_MERCHANT_PATROL_RADIUS := 240.0
const SALT_MERCHANT_WANDER_DURATION_RANGE := Vector2(1.5, 3.5)
const SALT_MERCHANT_REST_DURATION_RANGE := Vector2(0.8, 1.8)
const SEA_MONSTER_REWARD_WOOD := 500
const SEA_MONSTER_REWARD_IRONSTONE := 500

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
var _active_sea_monster_event: Area2D
var _sea_monster_event_resolved := false
var _active_sea_monster_variant := 0
var _fubo_quest_dialogue_open := false
var _wokou_warning_acknowledged := false
var _wokou_battle_completed := false
var _wokou_victory_cutscene: WokouVictoryCutscene
var _fog_of_war: Node2D
var _pirates: Array[SeaOverworldPirate] = []
var _active_battle_pirate: SeaOverworldPirate
var _pirate_spawn_rng := RandomNumberGenerator.new()
var _random_event_rng := RandomNumberGenerator.new()
var _random_event_seed_override := -1
var _sea_monster_variant_override := -1
var _pending_random_event_refill := false
var _resolved_random_event_ids: Dictionary = {}
var _salt_merchant_wander_origin := Vector2.ZERO
var _salt_merchant_wander_target := Vector2.ZERO
var _salt_merchant_behavior := &"rest"
var _salt_merchant_behavior_time_left := 0.0


func _ready() -> void:
	_exploration_ui = get_node("/root/ExplorationUI")
	exploration_hud = _exploration_ui.call("acquire", self, &"sea_overworld") as Control
	_saved_scene_state = _consume_saved_scene_state()
	_fubo_return_context = _consume_fubo_return()
	var restoring_saved_state := not _saved_scene_state.is_empty()
	if _saved_scene_state.is_empty() and not _returning_from_fubo:
		_entered_from_scene_two = _consume_scene_two_entry_flag()
	_build_background_chunks()
	_configure_world_bounds()
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
	_wokou_victory_cutscene = WOKOU_VICTORY_CUTSCENE_SCENE.instantiate() as WokouVictoryCutscene
	$UI.add_child(_wokou_victory_cutscene)
	_wokou_victory_cutscene.connect("cutscene_finished", _on_wokou_victory_cutscene_finished)
	if not restoring_saved_state and not _returning_from_fubo:
		player.global_position = SOUTH_SEA_HARBOR_SPAWN
		_activate_south_sea_harbor_spawn()
	camera.reset_smoothing()
	_build_fog_of_war()
	_configure_sea_map_hud()
	_spawn_pirates_deferred.call_deferred()


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
		[&"side_quest_tracked", Callable(self, "_on_side_quest_tracked")],
	]:
		if not _exploration_ui.is_connected(binding[0], binding[1]):
			_exploration_ui.connect(binding[0], binding[1])


func _disconnect_global_hud_signals() -> void:
	for binding in [
		[&"menu_visibility_changed", Callable(self, "_on_hud_menu_visibility_changed")],
		[&"save_requested", Callable(self, "_on_save_requested")],
		[&"load_requested", Callable(self, "_on_load_requested")],
		[&"return_title_requested", Callable(self, "_on_return_title_requested")],
		[&"side_quest_tracked", Callable(self, "_on_side_quest_tracked")],
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
	_update_salt_merchant_movement(delta)


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
	_build_location("月环商港", Vector2(3650, 360), 250.0, Vector2(480, 150), Vector2(-300, 80), "进入商港", Vector2.ZERO, [], [], "res://scenes/yuehuan_merchant_harbor/yuehuan_merchant_harbor.tscn")
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
		Vector2.ZERO,
		Vector2.ZERO,
		"进入伏波古岭",
		Vector2.ZERO,
		[Vector2(48, 289)],
		[],
		FUBO_TRAVEL.FUBO_SCENE_PATH
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
		WOKOU_STRONGHOLD_POSITION,
		120.0,
		Vector2.ZERO,
		Vector2.ZERO,
		"讨伐倭寇营地",
		Vector2.ZERO,
		[Vector2(-630, 140)]
	)


func _build_auto_triggers() -> void:
	_build_ship_trigger("岭南商船", Vector2(2600, 760), 1)
	var fubo_quest_trigger := _make_auto_trigger(
		"FuboQuestTrigger",
		FUBO_QUEST_TRIGGER_POSITION,
		"伏波古岭军情",
		"fubo_quest",
		FUBO_QUEST_TRIGGER_RADIUS
	)
	fubo_quest_trigger.remove_from_group("sea_auto_trigger")
	var wokou_warning_trigger := _make_auto_trigger(
		"WokouStrongholdWarningTrigger",
		WOKOU_STRONGHOLD_POSITION,
		"倭寇营地军情",
		"wokou_warning",
		WOKOU_WARNING_TRIGGER_RADIUS
	)
	wokou_warning_trigger.remove_from_group("sea_auto_trigger")
	_initialize_random_events()


func _initialize_random_events() -> void:
	_clear_random_events_immediate()
	_resolved_random_event_ids.clear()
	_tea_merchant_event_resolved = _is_tea_merchant_event_completed()
	_crate_event_resolved = false
	_salt_merchant_event_resolved = false
	_sea_monster_event_resolved = false
	if _random_event_seed_override >= 0:
		_random_event_rng.seed = _random_event_seed_override
	else:
		_random_event_rng.randomize()
	var candidates := _available_random_event_types()
	while _active_random_events().size() < MAX_ACTIVE_RANDOM_EVENTS and not candidates.is_empty():
		var candidate_index := _random_event_rng.randi_range(0, candidates.size() - 1)
		if _random_event_seed_override >= 0:
			candidate_index = posmod(_random_event_seed_override + _active_random_events().size(), candidates.size())
		var event_id: StringName = candidates.pop_at(candidate_index)
		_spawn_random_event_at_random_position(event_id)
	_pending_random_event_refill = _active_random_events().size() < MAX_ACTIVE_RANDOM_EVENTS and not _available_random_event_types().is_empty()


func _spawn_random_event_at_random_position(event_id: StringName) -> Area2D:
	var spawn_position := (
		_find_sea_monster_spawn_position()
		if event_id == RANDOM_EVENT_SEA_MONSTER
		else _find_random_event_spawn_position()
	)
	if not is_finite(spawn_position.x) or not is_finite(spawn_position.y):
		if event_id == RANDOM_EVENT_SEA_MONSTER:
			push_warning("Could not find an available deep-water sea-monster spawn point.")
			return null
		spawn_position = RANDOM_EVENT_SPAWN_POINTS[event_id]
	return _spawn_random_event(event_id, spawn_position)


func _spawn_random_event(event_id: StringName, at: Vector2) -> Area2D:
	if _resolved_random_event_ids.has(event_id) or _find_random_event(event_id) != null:
		return null
	if event_id == RANDOM_EVENT_TEA and _tea_merchant_event_resolved:
		return null
	var area: Area2D
	match event_id:
		RANDOM_EVENT_TEA:
			area = _build_ship_trigger("茶叶商船", at, 0)
			_tea_merchant_event_resolved = false
		RANDOM_EVENT_SALT:
			area = _build_ship_trigger("私盐商船", at, 0, "SaltMerchantShip", 48.0)
			_salt_merchant_event_resolved = false
			_salt_merchant_wander_origin = at
			_start_salt_merchant_wander()
		RANDOM_EVENT_CRATE:
			area = _build_event_trigger("漂流木箱", at)
			_crate_event_resolved = false
		RANDOM_EVENT_SEA_MONSTER:
			_active_sea_monster_variant = (
				_sea_monster_variant_override
				if _sea_monster_variant_override >= 0
				else _random_event_rng.randi_range(0, SEA_MONSTER_SHADOW_TEXTURES.size() - 1)
			)
			_active_sea_monster_variant = posmod(_active_sea_monster_variant, SEA_MONSTER_SHADOW_TEXTURES.size())
			area = _build_sea_monster_event_trigger(at, _active_sea_monster_variant)
			_active_sea_monster_event = area
			_sea_monster_event_resolved = false
		_:
			push_warning("Unknown sea random event type: %s" % event_id)
			return null
	area.set_meta("random_event_id", event_id)
	area.set_meta("spawn_origin", at)
	area.add_to_group("sea_random_event")
	return area


func _active_random_events() -> Array[Area2D]:
	var result: Array[Area2D] = []
	for child in world_markers.get_children():
		var area := child as Area2D
		if area != null and area.is_in_group("sea_random_event") and not area.is_queued_for_deletion():
			result.append(area)
	return result


func _find_random_event(event_id: StringName) -> Area2D:
	for area in _active_random_events():
		if StringName(area.get_meta("random_event_id", &"")) == event_id:
			return area
	return null


func _mark_random_event_resolved(event_id: StringName, area: Area2D) -> void:
	_resolved_random_event_ids[event_id] = true
	match event_id:
		RANDOM_EVENT_TEA:
			_tea_merchant_event_resolved = true
		RANDOM_EVENT_SALT:
			_salt_merchant_event_resolved = true
		RANDOM_EVENT_CRATE:
			_crate_event_resolved = true
		RANDOM_EVENT_SEA_MONSTER:
			_sea_monster_event_resolved = true
	if is_instance_valid(area):
		area.remove_from_group("sea_random_event")
		area.set_deferred("monitoring", false)
		area.queue_free()
	_pending_random_event_refill = true


func _refill_random_event_slots() -> void:
	if not _pending_random_event_refill and _active_random_events().size() >= MAX_ACTIVE_RANDOM_EVENTS:
		return
	while _active_random_events().size() < MAX_ACTIVE_RANDOM_EVENTS:
		var candidates: Array[StringName] = []
		for event_id in _available_random_event_types():
			if _find_random_event(event_id) == null:
				candidates.append(event_id)
		if candidates.is_empty():
			break
		var chosen_id := candidates[_random_event_rng.randi_range(0, candidates.size() - 1)]
		var spawn_position := Vector2(INF, INF)
		if chosen_id == RANDOM_EVENT_SEA_MONSTER:
			spawn_position = _find_sea_monster_spawn_position()
		else:
			spawn_position = RANDOM_EVENT_SPAWN_POINTS[chosen_id]
			if not _is_random_event_spawn_valid(spawn_position):
				spawn_position = _find_random_event_spawn_position()
		if not is_finite(spawn_position.x) or not is_finite(spawn_position.y):
			push_warning("Could not find an off-screen random-event spawn point.")
			break
		_spawn_random_event(chosen_id, spawn_position)
	_pending_random_event_refill = false


func _available_random_event_types() -> Array[StringName]:
	var result: Array[StringName] = []
	for event_id in RANDOM_EVENT_TYPES:
		if _resolved_random_event_ids.has(event_id):
			continue
		if event_id == RANDOM_EVENT_TEA and _tea_merchant_event_resolved:
			continue
		result.append(event_id)
	return result


func _is_random_event_spawn_valid(candidate: Vector2) -> bool:
	if _player_view_world_rect().grow(RANDOM_EVENT_VIEW_MARGIN).has_point(candidate):
		return false
	for active_event in _active_random_events():
		if candidate.distance_to(active_event.global_position) < RANDOM_EVENT_SPAWN_SEPARATION:
			return false
	for child in world_markers.get_children():
		var existing_area := child as Area2D
		if existing_area == null or existing_area.is_in_group("sea_random_event"):
			continue
		var trigger_kind := str(existing_area.get_meta("trigger_kind", ""))
		if trigger_kind not in ["fubo_quest", "wokou_warning", "ship"]:
			continue
		var trigger_clearance := RANDOM_EVENT_SPAWN_CLEARANCE
		for shape_node in existing_area.find_children("*", "CollisionShape2D", false, false):
			var circle := (shape_node as CollisionShape2D).shape as CircleShape2D
			if circle != null:
				trigger_clearance = maxf(trigger_clearance, circle.radius + RANDOM_EVENT_SPAWN_CLEARANCE)
		if candidate.distance_to(existing_area.global_position) < trigger_clearance:
			return false
	return _is_open_water_for_random_event(candidate)


func _find_sea_monster_spawn_position() -> Vector2:
	var candidates: Array[Vector2] = SEA_MONSTER_DEEP_WATER_SPAWN_POINTS.duplicate()
	while not candidates.is_empty():
		var candidate_index := _random_event_rng.randi_range(0, candidates.size() - 1)
		var candidate: Vector2 = candidates.pop_at(candidate_index)
		if _is_sea_monster_spawn_valid(candidate):
			return candidate
	return Vector2(INF, INF)


func _is_sea_monster_spawn_valid(candidate: Vector2) -> bool:
	if _player_view_world_rect().grow(RANDOM_EVENT_VIEW_MARGIN).has_point(candidate):
		return false
	for active_event in _active_random_events():
		if candidate.distance_to(active_event.global_position) < RANDOM_EVENT_SPAWN_SEPARATION:
			return false
	return _is_open_water_for_random_event(candidate, SEA_MONSTER_SPAWN_CLEARANCE)


func _find_random_event_spawn_position() -> Vector2:
	var spawn_bounds := player.movement_bounds.grow(-PIRATE_SPAWN_EDGE_MARGIN)
	for _attempt in range(240):
		var candidate := Vector2(
			_random_event_rng.randf_range(spawn_bounds.position.x, spawn_bounds.end.x),
			_random_event_rng.randf_range(spawn_bounds.position.y, spawn_bounds.end.y)
		)
		if _is_random_event_spawn_valid(candidate):
			return candidate
	return Vector2(INF, INF)


func _player_view_world_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var safe_zoom := Vector2(maxf(camera.zoom.x, 0.001), maxf(camera.zoom.y, 0.001))
	var world_size := Vector2(viewport_size.x / safe_zoom.x, viewport_size.y / safe_zoom.y)
	return Rect2(camera.get_screen_center_position() - world_size * 0.5, world_size)


func _is_open_water_for_random_event(candidate: Vector2, clearance := RANDOM_EVENT_SPAWN_CLEARANCE) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var clearance_shape := CircleShape2D.new()
	clearance_shape.radius = clearance
	query.shape = clearance_shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = PLAYER_LAYER
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _update_salt_merchant_movement(delta: float) -> void:
	var salt_ship := _find_random_event(RANDOM_EVENT_SALT)
	if (
		salt_ship == null
		or _transitioning
		or (_event_dialogue != null and _event_dialogue.visible)
		or (_exploration_ui != null and bool(exploration_hud.call("is_menu_open")))
	):
		return
	_salt_merchant_behavior_time_left -= delta
	if _salt_merchant_behavior == &"rest":
		if _salt_merchant_behavior_time_left <= 0.0:
			_start_salt_merchant_wander()
		return
	if _salt_merchant_behavior_time_left <= 0.0 or salt_ship.position.distance_to(_salt_merchant_wander_target) <= 18.0:
		_start_salt_merchant_rest()
		return
	var candidate := salt_ship.position.move_toward(_salt_merchant_wander_target, SALT_MERCHANT_MOVE_SPEED * delta)
	var offset := candidate - _salt_merchant_wander_origin
	if offset.length() > SALT_MERCHANT_PATROL_RADIUS:
		candidate = _salt_merchant_wander_origin + offset.normalized() * SALT_MERCHANT_PATROL_RADIUS
	if _is_open_water_for_random_event(candidate, 48.0):
		salt_ship.position = candidate
	else:
		_start_salt_merchant_rest()


func _start_salt_merchant_wander() -> void:
	_salt_merchant_behavior = &"wander"
	_salt_merchant_behavior_time_left = _random_event_rng.randf_range(
		SALT_MERCHANT_WANDER_DURATION_RANGE.x,
		SALT_MERCHANT_WANDER_DURATION_RANGE.y
	)
	for _attempt in range(16):
		var angle := _random_event_rng.randf_range(0.0, TAU)
		var radius := _random_event_rng.randf_range(SALT_MERCHANT_PATROL_RADIUS * 0.35, SALT_MERCHANT_PATROL_RADIUS)
		var candidate := _salt_merchant_wander_origin + Vector2.from_angle(angle) * radius
		candidate = candidate.clamp(player.movement_bounds.position, player.movement_bounds.end)
		if _is_open_water_for_random_event(candidate, 48.0):
			_salt_merchant_wander_target = candidate
			return
	_start_salt_merchant_rest()


func _start_salt_merchant_rest() -> void:
	_salt_merchant_behavior = &"rest"
	_salt_merchant_behavior_time_left = _random_event_rng.randf_range(
		SALT_MERCHANT_REST_DURATION_RANGE.x,
		SALT_MERCHANT_REST_DURATION_RANGE.y
	)


func _is_tea_merchant_event_completed() -> bool:
	var game_state := _game_state()
	return game_state != null and game_state.has_method("is_tea_merchant_event_completed") and bool(game_state.call("is_tea_merchant_event_completed"))


func _spawn_pirates_deferred() -> void:
	await get_tree().physics_frame
	if not is_inside_tree() or _transitioning:
		return
	_pirate_spawn_rng.randomize()
	for pirate_index in range(PIRATE_COUNT):
		var spawn_position := _find_random_pirate_spawn()
		if not is_finite(spawn_position.x) or not is_finite(spawn_position.y):
			push_warning("Could not find a collision-free pirate spawn point.")
			continue
		var pirate := PIRATE_SCENE.instantiate() as SeaOverworldPirate
		pirate.name = "PirateShip%d" % (pirate_index + 1)
		world_markers.add_child(pirate)
		pirate.setup(player, spawn_position, _pirate_spawn_rng.randi(), player.movement_bounds)
		pirate.battle_requested.connect(_on_pirate_battle_requested)
		_pirates.append(pirate)
		pirate.set_navigation_enabled(
			not _transitioning
			and not (_event_dialogue != null and _event_dialogue.visible)
			and not bool(exploration_hud.call("is_menu_open"))
		)


func _find_random_pirate_spawn() -> Vector2:
	var spawn_bounds := player.movement_bounds.grow(-PIRATE_SPAWN_EDGE_MARGIN)
	for _attempt in range(240):
		var candidate := Vector2(
			_pirate_spawn_rng.randf_range(spawn_bounds.position.x, spawn_bounds.end.x),
			_pirate_spawn_rng.randf_range(spawn_bounds.position.y, spawn_bounds.end.y)
		)
		if candidate.distance_to(SOUTH_SEA_HARBOR_SPAWN) < PIRATE_HARBOR_SAFE_RADIUS:
			continue
		if candidate.distance_to(player.global_position) < PIRATE_PLAYER_SAFE_RADIUS:
			continue
		var too_close_to_pirate := false
		for pirate in _pirates:
			if is_instance_valid(pirate) and candidate.distance_to(pirate.global_position) < PIRATE_SEPARATION:
				too_close_to_pirate = true
				break
		if too_close_to_pirate or not _is_open_water_for_pirate(candidate):
			continue
		return candidate
	return Vector2(INF, INF)


func _is_open_water_for_pirate(candidate: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var clearance_shape := CircleShape2D.new()
	clearance_shape.radius = PIRATE_SPAWN_CLEARANCE
	query.shape = clearance_shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = PLAYER_LAYER
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _set_pirates_navigation_enabled(value: bool) -> void:
	for pirate in _pirates:
		if is_instance_valid(pirate):
			pirate.set_navigation_enabled(value)


func _on_pirate_battle_requested(pirate: SeaOverworldPirate) -> void:
	if _transitioning or not is_instance_valid(pirate):
		return
	_active_battle_pirate = pirate
	player.controls_enabled = false
	interaction_prompt.hide()
	_set_pirates_navigation_enabled(false)
	_event_dialogue.present(
		"水师士兵",
		"前方海盗船已逼近我军，双方即将接战！",
		SOLDIER_PORTRAIT,
		[{"id": &"finish_pirate_placeholder", "text": "海战界面即将开放"}],
		"当前版本暂不进入正式海战"
	)


func _finish_pirate_placeholder() -> void:
	_event_dialogue.hide_dialogue()
	if is_instance_valid(_active_battle_pirate):
		_pirates.erase(_active_battle_pirate)
		_active_battle_pirate.queue_free()
	_active_battle_pirate = null
	player.controls_enabled = not _transitioning and not bool(exploration_hud.call("is_menu_open"))
	_set_pirates_navigation_enabled(player.controls_enabled)
	interaction_prompt.visible = player.controls_enabled and not _active_location_name.is_empty()
	_advance_exploration_stage(4)


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
		_fog_of_war.call("reveal_at", SOUTH_SEA_HARBOR_SPAWN, true)
	_fog_of_war.call("reveal_at", player.global_position, true)
	_store_fog_state()


func _reveal_initial_known_land() -> void:
	var northwest_coast := world_collision.get_node_or_null("NorthwestCoast") as CollisionPolygon2D
	if northwest_coast == null:
		return
	var world := $World as Node2D
	var world_polygon := PackedVector2Array()
	for local_point in northwest_coast.polygon:
		world_polygon.append(world.to_local(northwest_coast.to_global(local_point)))
	_fog_of_war.call("reveal_polygon", world_polygon, true)


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
	entry_trigger_offsets: Array[Vector2] = [],
	additional_entry_trigger_offsets: Array[Vector2] = [],
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
	area.set_meta("entry_trigger_offsets", entry_trigger_offsets)
	area.set_meta("additional_entry_trigger_offsets", additional_entry_trigger_offsets)
	area.set_meta("target_scene_path", target_scene_path)
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


func _build_ship_trigger(ship_name: String, at: Vector2, atlas_column: int, node_name: String = "", trigger_radius: float = 82.0) -> Area2D:
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
	return area


func _build_event_trigger(event_name: String, at: Vector2) -> Area2D:
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
	return area


func _build_sea_monster_event_trigger(at: Vector2, variant: int) -> Area2D:
	var area := _make_auto_trigger("SeaMonsterMistEvent", at, "雾中可疑身影", "event", 96.0)
	area.set_meta("sea_monster_variant", variant)
	var visual := Node2D.new()
	visual.name = "EventVisual"
	visual.z_index = 17
	area.add_child(visual)

	var ripple := ColorRect.new()
	ripple.name = "SurfaceRipple"
	ripple.position = Vector2(-190.0, -112.0)
	ripple.size = Vector2(380.0, 224.0)
	ripple.color = Color.WHITE
	ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ripple.z_index = 0
	var ripple_material := ShaderMaterial.new()
	ripple_material.shader = SEA_MONSTER_RIPPLE_SHADER
	ripple_material.set_shader_parameter("phase_offset", float(variant) * 0.19)
	ripple.material = ripple_material
	visual.add_child(ripple)

	var shadow_sprite := Sprite2D.new()
	shadow_sprite.name = "MonsterShadow"
	shadow_sprite.texture = SEA_MONSTER_SHADOW_TEXTURES[variant]
	shadow_sprite.position = Vector2(0.0, 7.0)
	shadow_sprite.scale = Vector2(0.25, 0.205)
	shadow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow_sprite.z_index = 1
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = SEA_MONSTER_SHADOW_SHADER
	shadow_material.set_shader_parameter("flow_phase", float(variant) * 1.73)
	shadow_sprite.material = shadow_material
	visual.add_child(shadow_sprite)

	var mist_sprite := Sprite2D.new()
	mist_sprite.name = "MistSprite"
	mist_sprite.texture = SEA_MONSTER_SURFACE_MIST_TEXTURE
	mist_sprite.position = Vector2(0.0, -4.0)
	mist_sprite.scale = Vector2(0.27, 0.22)
	mist_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mist_sprite.z_index = 2
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = SEA_EVENT_VIGNETTE_SHADER
	vignette_material.set_shader_parameter("fog_motion_speed", 0.026)
	vignette_material.set_shader_parameter("fog_opacity_variation", 0.16)
	vignette_material.set_shader_parameter("fog_brightness_variation", 0.045)
	mist_sprite.material = vignette_material
	visual.add_child(mist_sprite)

	visual.modulate.a = 0.0
	visual.scale = Vector2(0.94, 0.94)
	var reveal_tween := visual.create_tween().set_parallel(true)
	reveal_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_property(visual, "modulate:a", 1.0, 1.25)
	reveal_tween.tween_property(visual, "scale", Vector2.ONE, 1.6)
	_floating_visuals.append(visual)
	return area


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
	if trigger_kind == "fubo_quest":
		_open_fubo_quest_dialogue()
		return
	if trigger_kind == "wokou_warning":
		_open_wokou_warning_dialogue()
		return
	if trigger_kind == "ship" and display_name == "私盐商船":
		_open_salt_merchant_event(area)
		return
	if trigger_kind == "ship" and display_name == "茶叶商船":
		_open_tea_merchant_event(area)
		return
	if trigger_kind == "event" and display_name == "漂流木箱":
		_open_drifting_crate_event(area)
		return
	if trigger_kind == "event" and display_name == "雾中可疑身影":
		_open_sea_monster_event(area)
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
		"将军，这是姑苏新产的龙井茶。我们沿途遭遇风暴，船只受损，急需军饷修缮。还望将军购买一些茶叶，助我们渡过难关。",
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


func _open_sea_monster_event(area: Area2D) -> void:
	if _sea_monster_event_resolved or (_event_dialogue != null and _event_dialogue.visible):
		return
	_active_sea_monster_event = area
	_active_sea_monster_variant = int(area.get_meta("sea_monster_variant", 0))
	area.set_deferred("monitoring", false)
	player.controls_enabled = false
	interaction_prompt.hide()
	_event_dialogue.present(
		"水师士兵",
		"将军，前方海面忽然漫起青灰薄雾，雾下似有一个庞大的黑影正随暗流缓缓移动……",
		SOLDIER_PORTRAIT,
		[
			{"id": &"inspect_sea_monster", "text": "靠近查看"},
			{"id": &"avoid_sea_monster", "text": "绕行"},
		]
	)


func _on_event_dialogue_option_selected(option_id: StringName) -> void:
	match option_id:
		&"finish_pirate_placeholder":
			_finish_pirate_placeholder()
		&"accept_fubo_quest":
			_accept_fubo_side_quest()
		&"acknowledge_wokou_warning":
			_acknowledge_wokou_warning()
		&"confront_haibatian":
			_show_haibatian_reply()
		&"fight_haibatian":
			_resolve_wokou_battle()
		&"inspect_sea_monster":
			_event_dialogue.present(
				"海中异兽",
				"舰队靠近后，雾中的黑影骤然翻涌而出——竟是一头从未见过的海怪！",
				SEA_MONSTER_PORTRAITS[_active_sea_monster_variant],
				[{
					"id": &"fight_sea_monster_placeholder",
					"text": "迎战海怪（战斗系统尚未接入，此战默认获胜）",
				}],
				"",
				false,
				0.88,
				true
			)
		&"avoid_sea_monster":
			_resolve_sea_monster_event()
			_close_sea_monster_dialogue()
		&"fight_sea_monster_placeholder":
			var game_state := _game_state()
			if game_state != null:
				game_state.call("add_economy_item", "wood", SEA_MONSTER_REWARD_WOOD)
				game_state.call("add_economy_item", "ironstone", SEA_MONSTER_REWARD_IRONSTONE)
			_resolve_sea_monster_event()
			_event_dialogue.present(
				"水师士兵",
				"将军神勇！我军已战胜海怪，并从它盘踞的海域打捞出大量材料。",
				SOLDIER_PORTRAIT,
				[{"id": &"finish_sea_monster_event", "text": "收下材料，继续航行"}],
				"木材 +%d　　铁石 +%d" % [SEA_MONSTER_REWARD_WOOD, SEA_MONSTER_REWARD_IRONSTONE]
			)
		&"finish_sea_monster_event":
			_close_sea_monster_dialogue()
		&"salvage":
			var game_state := _game_state()
			if game_state != null:
				game_state.call("add_military_pay", 1000)
				game_state.call("add_economy_item", "wood", 100)
				game_state.call("add_economy_item", "ironstone", 100)
			_resolve_drifting_crate_event()
			_event_dialogue.present(
				"水师士兵",
				"禀将军，木箱已经打捞完毕，所得物资如下：\n铁石 +100　　木材 +100　　军饷 +1000",
				SOLDIER_PORTRAIT,
				[{"id": &"continue", "text": "收下物资，继续航行"}]
			)
		&"ignore":
			_resolve_drifting_crate_event()
			_close_crate_dialogue()
		&"continue":
			_close_crate_dialogue()
		&"buy_longjing_tea":
			var game_state := _game_state()
			if game_state != null and game_state.call("spend_military_pay", 100):
				game_state.call("add_economy_item", "longjing_tea", 1)
			else:
				_event_dialogue.present(
					"茶叶商人",
					"将军军饷不足，小商不敢强求。",
					TEA_MERCHANT_PORTRAIT,
					[{"id": &"finish_tea_trade", "text": "继续航行"}],
					"需要军饷 100"
				)
				return
			_event_dialogue.present(
				"茶叶商人",
				"多谢将军相助！",
				TEA_MERCHANT_PORTRAIT,
				[{"id": &"finish_tea_trade", "text": "收下龙井茶，继续航行"}],
				"军饷 -100　　获得商品：[color=#f2c45c]龙井茶[/color]"
			)
		&"decline_longjing_tea", &"finish_tea_trade":
			_finish_tea_merchant_event()
		&"seize_private_salt":
			var game_state := _game_state()
			if game_state != null:
				game_state.call("add_economy_item", "private_salt", 1)
			_event_dialogue.present(
				"私盐商人",
				"官爷饶命！这些盐货都交由水师处置。",
				SALT_MERCHANT_PORTRAIT,
				[{"id": &"finish_salt_event", "text": "收缴货物，继续航行"}],
				"查获物品：[color=#f2c45c]私盐[/color]"
			)
		&"accept_salt_bribe":
			var game_state := _game_state()
			if game_state != null:
				game_state.call("add_military_pay", 800)
			_event_dialogue.present(
				"私盐商人",
				"多谢将军高抬贵手，这点薄礼还请笑纳。",
				SALT_MERCHANT_PORTRAIT,
				[{"id": &"finish_salt_event", "text": "收下军饷，继续航行"}],
				"军饷 +800"
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


func _open_fubo_quest_dialogue() -> void:
	var game_state := _game_state()
	if game_state == null or bool(game_state.call("has_fubo_side_quest")):
		return
	if _event_dialogue == null:
		_open_fubo_quest_dialogue.call_deferred()
		return
	if _event_dialogue.visible or _transitioning:
		return
	_fubo_quest_dialogue_open = true
	player.controls_enabled = false
	interaction_prompt.hide()
	_event_dialogue.present(
		"水师士兵",
		"将军，海域东北方有一座孤岛，名为伏波古岭。岛上军士扼守航道、巡查烽堠，以防倭寇乘隙侵扰。将军若得空，可登岛巡视军备，也好安定守军之心。",
		SOLDIER_PORTRAIT,
		[{"id": &"accept_fubo_quest", "text": "收到，我会前去巡视。"}]
	)


func _accept_fubo_side_quest() -> void:
	var game_state := _game_state()
	if game_state != null:
		game_state.call("accept_fubo_side_quest")
	_fubo_quest_dialogue_open = false
	_event_dialogue.hide_dialogue()
	player.controls_enabled = not bool(exploration_hud.call("is_menu_open"))
	interaction_prompt.visible = player.controls_enabled and not _active_location_name.is_empty()
	_refresh_exploration_task()
	_show_toast("已接取支线：伏波古岭")


func _open_wokou_warning_dialogue() -> void:
	if _wokou_warning_acknowledged or _wokou_battle_completed or _transitioning:
		return
	if _event_dialogue == null:
		_open_wokou_warning_dialogue.call_deferred()
		return
	if _event_dialogue.visible:
		return
	player.controls_enabled = false
	interaction_prompt.hide()
	_event_dialogue.present(
		"水师士兵",
		"将军，前方已近倭寇营地！水寨旌旗杂乱、哨船密布，贼众又据险死守，贸然突进万分凶险。还请将军传令各船收拢阵形、严守战位，切莫轻敌！",
		SOLDIER_PORTRAIT,
		[{
			"id": &"acknowledge_wokou_warning",
			"text": "传令全军戒备，列阵前进",
		}]
	)


func _acknowledge_wokou_warning() -> void:
	_wokou_warning_acknowledged = true
	_remove_wokou_warning_trigger()
	_event_dialogue.hide_dialogue()
	player.controls_enabled = not bool(exploration_hud.call("is_menu_open"))
	interaction_prompt.visible = player.controls_enabled and not _active_location_name.is_empty()
	_refresh_exploration_task()
	_show_toast("主线更新：讨伐倭寇")


func _open_wokou_confrontation() -> void:
	if _event_dialogue == null or _event_dialogue.visible or _transitioning or _wokou_battle_completed:
		return
	player.controls_enabled = false
	interaction_prompt.hide()
	_event_dialogue.present(
		"水师元帅",
		"海霸天！你纵船劫掠商旅，焚毁渔村，杀伤我厂车军民，搅得沿海不得安生。本将奉命靖海，今日兵临贼巢，便是你束手伏诛之时！",
		PROTAGONIST_PORTRAIT,
		[{"id": &"confront_haibatian", "text": "喝令贼首答话"}],
		"",
		true
	)


func _show_haibatian_reply() -> void:
	_event_dialogue.present(
		"倭寇头目·海霸天",
		"呸！狗官，少在老子面前装腔作势！老子还没领船去寻你，你倒自己送上门来了。弟兄们，抄家伙守住寨门——既敢闯我营寨，今日便叫你有来无回！",
		HAIBATIAN_PORTRAIT,
		[{
			"id": &"fight_haibatian",
			"text": "进军，一决胜负（战斗系统还未完善，此战默认获胜）",
		}],
		"",
		false,
		0.88,
		true
	)


func _resolve_wokou_battle() -> void:
	_wokou_battle_completed = true
	_wokou_warning_acknowledged = true
	_advance_exploration_stage(4)
	_remove_wokou_warning_trigger()
	_event_dialogue.hide_dialogue()
	_transitioning = true
	player.controls_enabled = false
	_set_pirates_navigation_enabled(false)
	interaction_prompt.hide()
	exploration_hud.call("set_exploration_visible", false)
	_wokou_victory_cutscene.play()


func _on_wokou_victory_cutscene_finished() -> void:
	_transitioning = false
	exploration_hud.call("set_exploration_visible", true)
	player.controls_enabled = not bool(exploration_hud.call("is_menu_open"))
	_set_pirates_navigation_enabled(player.controls_enabled)
	interaction_prompt.visible = player.controls_enabled and not _active_location_name.is_empty()
	_refresh_exploration_task()
	_show_toast("主线完成：荡平倭寇营地")


func _remove_wokou_warning_trigger() -> void:
	var trigger := world_markers.get_node_or_null("WokouStrongholdWarningTrigger")
	if is_instance_valid(trigger):
		trigger.queue_free()


func _resolve_drifting_crate_event() -> void:
	if _crate_event_resolved:
		return
	var crate := _active_drifting_crate
	if not is_instance_valid(crate):
		crate = _find_random_event(RANDOM_EVENT_CRATE)
	_mark_random_event_resolved(RANDOM_EVENT_CRATE, crate)
	_active_drifting_crate = null
	_advance_exploration_stage(4)


func _remove_drifting_crate() -> void:
	var crate := _active_drifting_crate
	if not is_instance_valid(crate):
		crate = _find_random_event(RANDOM_EVENT_CRATE)
	if is_instance_valid(crate):
		crate.remove_from_group("sea_random_event")
		crate.free()
	_active_drifting_crate = null


func _finish_tea_merchant_event() -> void:
	_resolve_tea_merchant_event()
	_event_dialogue.hide_dialogue()
	_refill_random_event_slots()
	player.controls_enabled = not bool(exploration_hud.call("is_menu_open"))
	interaction_prompt.visible = player.controls_enabled and not _active_location_name.is_empty()


func _resolve_tea_merchant_event() -> void:
	if _tea_merchant_event_resolved:
		return
	var merchant_ship := _active_tea_merchant_ship
	if not is_instance_valid(merchant_ship):
		merchant_ship = _find_random_event(RANDOM_EVENT_TEA)
	_mark_random_event_resolved(RANDOM_EVENT_TEA, merchant_ship)
	_active_tea_merchant_ship = null
	var game_state := _game_state()
	if game_state != null and game_state.has_method("set_tea_merchant_event_completed"):
		game_state.call("set_tea_merchant_event_completed", true)
	_advance_exploration_stage(4)


func _remove_tea_merchant_ship() -> void:
	var merchant_ship := _active_tea_merchant_ship
	if not is_instance_valid(merchant_ship):
		merchant_ship = _find_random_event(RANDOM_EVENT_TEA)
	if is_instance_valid(merchant_ship):
		merchant_ship.remove_from_group("sea_random_event")
		merchant_ship.free()
	_active_tea_merchant_ship = null


func _finish_salt_merchant_event() -> void:
	_resolve_salt_merchant_event()
	_event_dialogue.hide_dialogue()
	_refill_random_event_slots()
	player.controls_enabled = not bool(exploration_hud.call("is_menu_open"))
	interaction_prompt.visible = player.controls_enabled and not _active_location_name.is_empty()


func _resolve_salt_merchant_event() -> void:
	if _salt_merchant_event_resolved:
		return
	var merchant_ship := _active_salt_merchant_ship
	if not is_instance_valid(merchant_ship):
		merchant_ship = _find_random_event(RANDOM_EVENT_SALT)
	_mark_random_event_resolved(RANDOM_EVENT_SALT, merchant_ship)
	_active_salt_merchant_ship = null
	_advance_exploration_stage(4)


func _remove_salt_merchant_ship() -> void:
	var merchant_ship := _active_salt_merchant_ship
	if not is_instance_valid(merchant_ship):
		merchant_ship = _find_random_event(RANDOM_EVENT_SALT)
	if is_instance_valid(merchant_ship):
		merchant_ship.remove_from_group("sea_random_event")
		merchant_ship.free()
	_active_salt_merchant_ship = null


func _resolve_sea_monster_event() -> void:
	if _sea_monster_event_resolved:
		return
	var sea_monster_event := _active_sea_monster_event
	if not is_instance_valid(sea_monster_event):
		sea_monster_event = _find_random_event(RANDOM_EVENT_SEA_MONSTER)
	_mark_random_event_resolved(RANDOM_EVENT_SEA_MONSTER, sea_monster_event)
	_active_sea_monster_event = null
	_advance_exploration_stage(4)


func _close_sea_monster_dialogue() -> void:
	_event_dialogue.hide_dialogue()
	_refill_random_event_slots()
	player.controls_enabled = not bool(exploration_hud.call("is_menu_open"))
	interaction_prompt.visible = player.controls_enabled and not _active_location_name.is_empty()


func _close_crate_dialogue() -> void:
	_event_dialogue.hide_dialogue()
	_refill_random_event_slots()
	player.controls_enabled = not bool(exploration_hud.call("is_menu_open"))
	interaction_prompt.visible = player.controls_enabled and not _active_location_name.is_empty()


func _on_event_dialogue_visibility_changed() -> void:
	if _event_dialogue == null:
		return
	exploration_hud.call("set_sea_map_button_visible", not _event_dialogue.visible)
	_set_pirates_navigation_enabled(
		not _event_dialogue.visible
		and not _transitioning
		and not bool(exploration_hud.call("is_menu_open"))
	)


func _enter_active_location() -> void:
	if _active_location_name.is_empty() or _transitioning:
		return
	if _active_location_name == "南海军港":
		_return_to_scene_two()
		return
	if _active_location_name == "倭寇营地":
		if _wokou_battle_completed:
			_show_toast("倭寇营地 · 贼巢已平定")
		else:
			_open_wokou_confrontation()
		return
	var target_scene_path := "" if _active_location_area == null else str(_active_location_area.get_meta("target_scene_path", ""))
	if target_scene_path == FUBO_TRAVEL.FUBO_SCENE_PATH and not _has_fubo_side_quest():
		_open_fubo_quest_dialogue()
		return
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
	_set_pirates_navigation_enabled(false)
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
	_set_pirates_navigation_enabled(true)
	exploration_hud.call("set_exploration_visible", true)
	interaction_prompt.visible = not _active_location_name.is_empty()


func _return_to_scene_two() -> void:
	if _transitioning:
		return
	_transitioning = true
	_store_fog_state()
	player.controls_enabled = false
	_set_pirates_navigation_enabled(false)
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
	_set_pirates_navigation_enabled(true)
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
		"tea_merchant_event_resolved": _tea_merchant_event_resolved,
		"wokou_warning_acknowledged": _wokou_warning_acknowledged,
		"wokou_battle_completed": _wokou_battle_completed,
	}


func _restore_event_state(value: Variant) -> void:
	var state := value as Dictionary if value is Dictionary else {}
	var saved_tea_completion := bool(state.get("tea_merchant_event_resolved", false))
	var game_state := _game_state()
	if saved_tea_completion and game_state != null and game_state.has_method("set_tea_merchant_event_completed"):
		game_state.call("set_tea_merchant_event_completed", true)
	_wokou_warning_acknowledged = bool(state.get("wokou_warning_acknowledged", false))
	_wokou_battle_completed = bool(state.get("wokou_battle_completed", false))
	if _wokou_battle_completed:
		_wokou_warning_acknowledged = true
	_initialize_random_events()
	if _wokou_warning_acknowledged:
		_remove_wokou_warning_trigger()


func _clear_random_events_immediate() -> void:
	for area in _active_random_events():
		area.remove_from_group("sea_random_event")
		area.free()
	_active_drifting_crate = null
	_active_tea_merchant_ship = null
	_active_salt_merchant_ship = null
	_active_sea_monster_event = null


func _show_toast(message: String) -> void:
	exploration_hud.call("show_toast", message)


func _advance_exploration_stage(next_stage: int) -> void:
	if next_stage <= _exploration_stage:
		return
	_exploration_stage = next_stage
	_refresh_exploration_task()


func _refresh_exploration_task() -> void:
	var task_title := "探索海域，完善海图"
	var objective := "使用WASD或方向键驾驶船只"
	if _wokou_battle_completed:
		task_title = "讨伐倭寇"
		objective = "倭寇营地已平定"
	elif _wokou_warning_acknowledged:
		task_title = "讨伐倭寇"
		objective = "驶近倭寇营地，按E发起讨伐"
	else:
		match _exploration_stage:
			1:
				objective = "靠近任意岛屿，查看地点名称"
			2:
				objective = "点击进入按钮或按E尝试进入地点"
			3:
				objective = "接触海上的船只或漂流事件"
			4:
				objective = "继续探索岭南海域"
	exploration_hud.call(
		"set_main_task_progress",
		task_title,
		objective,
		_exploration_stage,
		_quest_hud_state()
	)


func _quest_hud_state() -> Dictionary:
	var game_state := _game_state()
	if game_state == null:
		return {}
	return {
		"fubo_side_quest": game_state.call("get_fubo_side_quest_state"),
		"tracked_side_quest": String(game_state.call("get_tracked_side_quest")),
	}


func _has_fubo_side_quest() -> bool:
	var game_state := _game_state()
	return game_state != null and bool(game_state.call("has_fubo_side_quest"))


func _on_side_quest_tracked(quest_id: StringName) -> void:
	if _exploration_ui.call("current_owner") != self:
		return
	var game_state := _game_state()
	if game_state != null:
		game_state.call("set_tracked_side_quest", quest_id)


func _on_hud_menu_visibility_changed(is_open: bool) -> void:
	if _exploration_ui.call("current_owner") != self:
		return
	var dialogue_open := _event_dialogue != null and _event_dialogue.visible
	player.controls_enabled = not is_open and not dialogue_open
	_set_pirates_navigation_enabled(not is_open and not dialogue_open and not _transitioning)
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
		"tea_merchant_event_resolved": _tea_merchant_event_resolved,
		"wokou_warning_acknowledged": _wokou_warning_acknowledged,
		"wokou_battle_completed": _wokou_battle_completed,
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


func _atlas_region(texture: Texture2D, columns: int, rows: int, column: int, row: int) -> AtlasTexture:
	var frame_size := Vector2(texture.get_width() / float(columns), texture.get_height() / float(rows))
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = texture
	atlas_texture.region = Rect2(Vector2(column, row) * frame_size, frame_size)
	return atlas_texture
