extends Node2D

enum PatrolTaskStage {
	TALK_TO_SOLDIERS = 0,
	REPORT_TO_OFFICER = 2,
	MEET_MAGISTRATE = 3,
	DRILL_UNLOCKED = 4,
	EXPLORE_LINGNAN = 5,
}

const PLAYER_SPEED := 210.0
const CLICK_STOP_DISTANCE := 6.0
const CLICK_STUCK_TIMEOUT := 0.5
const CLICK_PROGRESS_EPSILON := 0.2
const SCENE_PATH := "res://scenes/Scene2.tscn"
const TITLE_SCENE_PATH := "res://scenes/ui/title_screen.tscn"
const ASSET_ROOT := "res://assets/characters"
const DIALOGUE_BACKGROUND_PATH := "res://assets/ui/dialogue/ink_dialogue_backdrop.png"
const DIALOGUE_NAMEPLATE_PATH := "res://assets/ui/dialogue/ink_speaker_nameplate.png"
const CHAPTER_ENTRY_META := "chapter_transition_from_scene_one"
const RETURN_FROM_SEA_META := "scene_two_return_from_sea_overworld"
const SEA_OVERWORLD_ENTRY_META := "sea_overworld_from_scene_two"
const SEA_OVERWORLD_SCENE := "res://scenes/sea_overworld/sea_overworld.tscn"
const LOADING_TRANSITION_SCENE := preload("res://scenes/ui/scene_loading_transition.tscn")
const SEA_FLOW_TEXTURE := preload("res://assets/textures/water/sea_ink_pixel.png")
const LEFT_SOLDIER_ROLE := "patrol_soldier_left"
const RIGHT_SOLDIER_ROLE := "patrol_soldier_right"
const OFFICER_ROLE := "patrol_officer"
const MAGISTRATE_ROLE := "magistrate"

var _player: CharacterBody2D
var _player_sprite: AnimatedSprite2D
var _interaction_panel: Control
var _exploration_hud: Control
var _dialogue_panel: Control
var _portrait_box: ColorRect
var _portrait_label: Label
var _portrait_image: TextureRect
var _name_plate: PanelContainer
var _paper_panel: PanelContainer
var _dialogue_margin: MarginContainer
var _speaker_label: Label
var _dialogue_label: Label
var _option_box: VBoxContainer
var _next_dialogue_button: Button
var _drill_button: Button
var _drill_overlay: Control
var _loading_transition: SceneLoadingTransition

var _patrol_guards: Array[Dictionary] = []
var _interactable_npcs: Array[Dictionary] = []
var _ambient_clouds: Array[Dictionary] = []
var _heard_soldier_reports: Dictionary = {}

var _arrival_dialogue_active := false
var _should_play_arrival_dialogue := false
var _returning_from_sea := false
var _transitioning := false
var _arrival_dialogue_index := 0
var _dialogue_index := 0
var _patrol_task_stage: PatrolTaskStage = PatrolTaskStage.TALK_TO_SOLDIERS
var _active_scripted_dialogues: Array = []
var _scripted_dialogue_completion := Callable()
var _last_direction := "down"
var _has_move_target := false
var _move_target := Vector2.ZERO
var _click_stuck_elapsed := 0.0
var _current_target: Variant = null
var _active_npc: Variant = null
var _saved_scene_state: Dictionary = {}

var _magistrate_dialogues: Array = [
	["广州县令", "将军有所不知，南疆水师多年未操练，沿海海域情况未明，旧有海图也多有缺漏。"],
	["水师主帅", "海防不可只凭旧闻。本帅先检阅诸营操练，随后亲自出海巡视，查明港湾、岛屿与航道。"],
	["广州县令", "下官已备妥粮草、工匠与船材。待操练结束，还请将军从南海军港启程，探索海域，完善海图。"],
]

var _arrival_dialogues: Array = [
	["水师副将", "末将恭迎元帅！南疆水师诸营已按旨整备，请元帅先行巡视中军楼船与周边泊位。"],
	["水师主帅", "传令各营照常操练。本帅先巡中军楼船，查验官兵值守与舰船战备。"],
]


func _ready() -> void:
	_saved_scene_state = _consume_saved_scene_state()
	if _saved_scene_state.is_empty():
		_returning_from_sea = _consume_scene_entry_flag(RETURN_FROM_SEA_META)
		var entered_from_chapter_one := _consume_scene_entry_flag(CHAPTER_ENTRY_META)
		_should_play_arrival_dialogue = not _returning_from_sea and entered_from_chapter_one
	_build_scene()
	_build_ui()


func _physics_process(delta: float) -> void:
	_update_ambient_background(delta)
	_refresh_exploration_hud()

	if _transitioning or _dialogue_panel.visible or _drill_overlay.visible or _is_menu_open():
		cancel_player_move_target()
		_player.velocity = Vector2.ZERO
		_player_sprite.play("idle_%s" % _last_direction)
		_update_patrol_guards(delta)
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector.length_squared() > 0.01:
		cancel_player_move_target()
	elif _has_move_target:
		if _player.global_position.distance_to(_move_target) <= CLICK_STOP_DISTANCE:
			cancel_player_move_target()
		else:
			input_vector = _player.global_position.direction_to(_move_target)
	_player.velocity = input_vector * PLAYER_SPEED
	var distance_before_move := _player.global_position.distance_to(_move_target) if _has_move_target else 0.0
	_player.move_and_slide()
	_update_click_move_progress(distance_before_move, delta)
	if input_vector.length_squared() > 0.01 and not _has_move_target and _player.velocity.is_zero_approx():
		input_vector = Vector2.ZERO
	_update_player_animation(input_vector)
	_update_patrol_guards(delta)
	_update_interaction_target()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		and not _transitioning
		and not _dialogue_panel.visible
		and not _drill_overlay.visible
		and not _is_menu_open()
	):
		var mouse_event := event as InputEventMouseButton
		var world_position := get_viewport().get_canvas_transform().affine_inverse() * mouse_event.position
		request_player_move_to(world_position)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		if event is InputEventKey and (event as InputEventKey).echo:
			return
		if (
			_dialogue_panel.visible
			and _next_dialogue_button.visible
			and not _transitioning
			and not _drill_overlay.visible
		):
			get_viewport().set_input_as_handled()
			_advance_dialogue()
			return
	if (
		event.is_action_pressed("interact")
		and not _transitioning
		and _current_target != null
		and not _dialogue_panel.visible
		and not _drill_overlay.visible
		and not _is_menu_open()
	):
		_open_npc_dialogue(_current_target)


func request_player_move_to(world_position: Vector2) -> void:
	_move_target = world_position
	_has_move_target = _player != null and _player.global_position.distance_to(_move_target) > CLICK_STOP_DISTANCE
	_click_stuck_elapsed = 0.0


func cancel_player_move_target() -> void:
	_has_move_target = false
	_click_stuck_elapsed = 0.0


func has_player_move_target() -> bool:
	return _has_move_target


func player_move_target() -> Vector2:
	return _move_target


func _update_click_move_progress(distance_before_move: float, delta: float) -> void:
	if not _has_move_target:
		return
	var distance_after_move := _player.global_position.distance_to(_move_target)
	if distance_after_move <= CLICK_STOP_DISTANCE:
		cancel_player_move_target()
		_player.velocity = Vector2.ZERO
		return
	if distance_before_move - distance_after_move > CLICK_PROGRESS_EPSILON:
		_click_stuck_elapsed = 0.0
		return
	_click_stuck_elapsed += delta
	if _click_stuck_elapsed >= CLICK_STUCK_TIMEOUT:
		cancel_player_move_target()
		_player.velocity = Vector2.ZERO


func _build_scene() -> void:
	_initialize_world_nodes()
	_add_scene_soldiers()
	_add_magistrate()
	_add_commander()
	_add_player()


func _initialize_world_nodes() -> void:
	var water_material := _create_water_material()
	var water_texture := _create_sea_water_texture()
	_apply_water_surface(get_node("World/Water"), water_material, water_texture)

	_ambient_clouds.clear()
	_register_ambient_cloud("World/DistantBackdrop/Clouds/CloudLeftHigh", 7.0, -210.0, 470.0)
	_register_ambient_cloud("World/DistantBackdrop/Clouds/CloudLeftLow", 4.5, -180.0, 430.0)
	_register_ambient_cloud("World/DistantBackdrop/Clouds/CloudRightHigh", 6.2, 930.0, 1500.0)
	_register_ambient_cloud("World/DistantBackdrop/Clouds/CloudRightLow", 3.8, 900.0, 1500.0)


func _register_ambient_cloud(path: NodePath, speed: float, reset_x: float, wrap_x: float) -> void:
	_ambient_clouds.append({
		"node": get_node(path) as Node2D,
		"speed": speed,
		"reset_x": reset_x,
		"wrap_x": wrap_x,
	})


func _update_ambient_background(delta: float) -> void:
	for cloud in _ambient_clouds:
		var cloud_node := cloud["node"] as Node2D
		cloud_node.position += Vector2(float(cloud["speed"]) * delta, 0.0)
		if cloud_node.position.x > float(cloud["wrap_x"]):
			cloud_node.position.x = float(cloud["reset_x"])


func _create_water_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/water_2d_distortion.gdshader") as Shader
	material.set_shader_parameter("waterDistortionNoise", _create_noise_texture(0.025, 3, 0.5))
	material.set_shader_parameter("waterColor", Color(0.12, 0.55, 0.76, 1.0))
	material.set_shader_parameter("colorCorection", 0.28)
	material.set_shader_parameter("flow_speed", 0.014)
	material.set_shader_parameter("warp_strength", 0.052)
	material.set_shader_parameter("caustic_strength", 0.24)
	material.set_shader_parameter("tiling", Vector2(1.35, 1.0))
	material.set_shader_parameter("refraction_strength", 0.004)
	return material


func _create_sea_water_texture() -> Texture2D:
	return SEA_FLOW_TEXTURE


func _create_noise_texture(frequency: float, octaves: int, gain: float) -> NoiseTexture2D:
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


func _apply_water_surface(node: Node, material: Material, texture: Texture2D) -> void:
	if node is Polygon2D:
		var polygon := node as Polygon2D
		polygon.texture = texture
		polygon.texture_scale = Vector2(0.55, 0.55)
		polygon.texture_offset = Vector2(-80.0, -40.0)
		polygon.color = Color.WHITE
		polygon.material = material

	for child in node.get_children():
		_apply_water_surface(child, material, texture)


func _add_scene_soldiers() -> void:
	_add_patrol_guard("LeftPatrolSoldier", "right", [
		Vector2(190, 310), Vector2(274, 310), Vector2(274, 430), Vector2(190, 430),
	])
	_add_patrol_guard("RightPatrolSoldier", "left", [
		Vector2(1154, 310), Vector2(1070, 310), Vector2(1070, 430), Vector2(1154, 430),
	])

	var soldier_dir := "%s/soldier" % ASSET_ROOT
	var soldier_portrait := _find_image_in_asset_directory(soldier_dir, "picture.png")
	var left_guard := _add_standing_actor(
		"MagistrateLeftGuard", soldier_dir, Vector2(560, 600), "right", 1.15,
		Color(1, 1, 1, 0.98)
	)
	_register_interactable(
		left_guard, "左舷值守士兵", "兵", soldier_portrait, LEFT_SOLDIER_ROLE,
		"左舷岗哨一切如常，末将随时听候查问。"
	)

	var right_guard := _add_standing_actor(
		"MagistrateRightGuard", soldier_dir, Vector2(784, 600), "left", 1.15,
		Color(1, 1, 1, 0.98)
	)
	_register_interactable(
		right_guard, "右舷值守士兵", "兵", soldier_portrait, RIGHT_SOLDIER_ROLE,
		"右舷船械已逐项点验，末将随时听候查问。"
	)


func _add_patrol_guard(name_value: String, initial_direction: String, patrol_points: Array) -> Node2D:
	var actor := _add_standing_actor(
		name_value, "%s/soldier" % ASSET_ROOT, patrol_points[0], initial_direction, 1.15,
		Color(1, 1, 1, 0.98)
	)
	var sprite := actor.get_node("Sprite") as AnimatedSprite2D
	sprite.play("walk_%s" % initial_direction)
	_patrol_guards.append({
		"actor": actor,
		"sprite": sprite,
		"points": patrol_points,
		"target_index": 1,
		"speed": 48.0,
	})
	return actor


func _update_patrol_guards(delta: float) -> void:
	for guard in _patrol_guards:
		var actor := guard["actor"] as Node2D
		var points := guard["points"] as Array
		var target_index := int(guard["target_index"])
		var target := points[target_index] as Vector2
		var to_target := target - actor.position
		var step := float(guard["speed"]) * delta

		if to_target.length() <= step:
			actor.position = target
			target_index = (target_index + 1) % points.size()
			guard["target_index"] = target_index
			target = points[target_index]
			to_target = target - actor.position
		else:
			actor.position += to_target.normalized() * step

		var direction := _get_direction_from_vector(to_target)
		(guard["sprite"] as AnimatedSprite2D).play("walk_%s" % direction)
		actor.z_index = int(actor.position.y)


func _get_direction_from_vector(movement: Vector2) -> String:
	if absf(movement.x) > absf(movement.y):
		return "right" if movement.x >= 0.0 else "left"
	return "down" if movement.y >= 0.0 else "up"


func _register_interactable(
	actor: Node2D,
	display_name: String,
	portrait_text: String,
	portrait_path: String,
	role: String,
	dialogue_line := ""
) -> void:
	var sprite := actor.get_node("Sprite") as AnimatedSprite2D
	_interactable_npcs.append({
		"actor": actor,
		"sprite": sprite,
		"display_name": display_name,
		"portrait_text": portrait_text,
		"portrait_path": portrait_path,
		"dialogue_line": dialogue_line if not dialogue_line.is_empty() else "我是%s" % display_name,
		"role": role,
		"normal_modulate": sprite.modulate,
		"normal_scale": sprite.scale,
	})


func _update_interaction_target() -> void:
	const INTERACT_RADIUS := 92.0
	var nearest: Variant = null
	var nearest_distance := INTERACT_RADIUS

	for npc in _interactable_npcs:
		var distance := _player.global_position.distance_to((npc["actor"] as Node2D).global_position)
		if distance < nearest_distance:
			nearest = npc
			nearest_distance = distance

	if _current_target == nearest:
		return
	_clear_target_highlight(_current_target)
	_current_target = nearest
	_apply_target_highlight(_current_target)


func _apply_target_highlight(npc: Variant) -> void:
	if npc == null:
		return
	var sprite := npc["sprite"] as AnimatedSprite2D
	var normal_modulate := npc["normal_modulate"] as Color
	sprite.modulate = Color(1.35, 1.22, 0.72, normal_modulate.a)
	sprite.scale = (npc["normal_scale"] as Vector2) * 1.08


func _clear_target_highlight(npc: Variant) -> void:
	if npc == null:
		return
	var sprite := npc["sprite"] as AnimatedSprite2D
	sprite.modulate = npc["normal_modulate"]
	sprite.scale = npc["normal_scale"]


func _add_magistrate() -> void:
	var magistrate_dir := _find_asset_directory("magistrate")
	var magistrate := _add_standing_actor(
		"GuangzhouCountyMagistrate", magistrate_dir, Vector2(672, 585), "down", 1.25, Color.WHITE
	)
	_register_interactable(
		magistrate, "广州县令", "县", _find_image_in_asset_directory(magistrate_dir, "picture.png"),
		MAGISTRATE_ROLE, "下官已将岭南粮草与工匠名册带来，请元帅示下。"
	)


func _add_commander() -> void:
	var soldier_dir := "%s/soldier" % ASSET_ROOT
	var commander := _add_standing_actor(
		"FleetCommander", soldier_dir, Vector2(672, 425), "down", 1.35, Color(0.9, 1, 1)
	)
	_register_interactable(
		commander, "中军军官", "官", _find_image_in_asset_directory(soldier_dir, "picture.png"),
		OFFICER_ROLE, "末将在中军楼船候命，请元帅示下。"
	)


func _add_standing_actor(
	name_value: String,
	asset_dir: String,
	position_value: Vector2,
	direction: String,
	scale_value: float,
	modulate_value: Color
) -> Node2D:
	var actor := _get_existing_actor(name_value)
	if actor == null:
		actor = _create_runtime_standing_actor(name_value, position_value)
	actor.z_index = int(actor.position.y)

	var sprite := actor.get_node_or_null("Sprite") as AnimatedSprite2D
	if sprite == null:
		sprite = AnimatedSprite2D.new()
		sprite.name = "Sprite"
		sprite.scale = Vector2(scale_value, scale_value)
		sprite.modulate = modulate_value
		actor.add_child(sprite)

	sprite.sprite_frames = _build_sprite_frames(asset_dir)
	sprite.play("idle_%s" % direction)
	_ensure_standing_actor_collision(actor)
	return actor


func _get_existing_actor(name_value: String) -> Node2D:
	var actor := get_node_or_null("World/Actors/PatrolGuards/%s" % name_value) as Node2D
	if actor == null:
		actor = get_node_or_null("World/Actors/Npcs/%s" % name_value) as Node2D
	return actor


func _create_runtime_standing_actor(name_value: String, position_value: Vector2) -> Node2D:
	var actor := Node2D.new()
	actor.name = name_value
	actor.position = position_value
	var npc_root := get_node_or_null("World/Actors/Npcs") as Node2D
	if npc_root != null:
		npc_root.add_child(actor)
	if actor.get_parent() == null:
		add_child(actor)
	return actor


func _ensure_standing_actor_collision(actor: Node2D) -> void:
	var body := actor.get_node_or_null("Body") as StaticBody2D
	if body == null:
		body = StaticBody2D.new()
		body.name = "Body"
		body.collision_layer = 1
		actor.add_child(body)

	if body.get_node_or_null("Collision") == null:
		var collision := CollisionShape2D.new()
		collision.name = "Collision"
		var shape := CircleShape2D.new()
		shape.radius = 12.0
		collision.shape = shape
		body.add_child(collision)


func _add_player() -> void:
	_player = get_node_or_null("World/Actors/Player") as CharacterBody2D
	if _player == null:
		_player = CharacterBody2D.new()
		_player.name = "Player"
		_player.position = Vector2(672, 760)
		_player.collision_layer = 2
		_player.collision_mask = 1
		_player.z_index = 760
		var actors_root := get_node_or_null("World/Actors") as Node2D
		if actors_root != null:
			actors_root.add_child(_player)
		if _player.get_parent() == null:
			add_child(_player)

	_player.z_index = int(_player.position.y)
	_player_sprite = _player.get_node_or_null("Sprite") as AnimatedSprite2D
	if _player_sprite == null:
		_player_sprite = AnimatedSprite2D.new()
		_player_sprite.name = "Sprite"
		_player_sprite.scale = Vector2(1.25, 1.25)
		_player.add_child(_player_sprite)

	_player_sprite.sprite_frames = _build_sprite_frames("%s/protagonist" % ASSET_ROOT)
	_player_sprite.play("idle_down")

	if _player.get_node_or_null("Collision") == null:
		var collision := CollisionShape2D.new()
		collision.name = "Collision"
		var shape := CircleShape2D.new()
		shape.radius = 18.0
		collision.shape = shape
		collision.position = Vector2(0, 12)
		_player.add_child(collision)

	_initialize_player_camera()


func _initialize_player_camera() -> void:
	var camera := _player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		camera.zoom = Vector2(1.3, 1.3)
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 6.0
		_player.add_child(camera)

	camera.enabled = true
	camera.make_current()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1344
	camera.limit_bottom = 896


func _build_sprite_frames(asset_dir: String) -> SpriteFrames:
	var frames := SpriteFrames.new()
	for default_animation in frames.get_animation_names():
		frames.remove_animation(default_animation)

	for direction in ["down", "left", "right", "up"]:
		_add_animation_frames(frames, "idle_%s" % direction, "%s/standard/idle/%s" % [asset_dir, direction], 2, 2.5)
		_add_animation_frames(frames, "walk_%s" % direction, "%s/standard/walk/%s" % [asset_dir, direction], 9, 10.0)
	return frames


func _add_animation_frames(
	sprite_frames: SpriteFrames,
	animation: StringName,
	folder: String,
	max_frames: int,
	fps: float
) -> void:
	sprite_frames.add_animation(animation)
	sprite_frames.set_animation_loop(animation, true)
	sprite_frames.set_animation_speed(animation, fps)
	for frame_index in range(1, max_frames + 1):
		var path := "%s/%d.png" % [folder, frame_index]
		if FileAccess.file_exists(path):
			sprite_frames.add_frame(animation, _load_texture_from_file(path))


func _load_texture_from_file(resource_path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(resource_path))
	if error != OK:
		push_error("Failed to load image '%s': %s" % [resource_path, error_string(error)])
		var placeholder := PlaceholderTexture2D.new()
		placeholder.size = Vector2(32, 32)
		return placeholder
	return ImageTexture.create_from_image(image)


func _find_asset_directory(normalized_needle: String) -> String:
	var directory := DirAccess.open(ASSET_ROOT)
	if directory != null:
		for child in directory.get_directories():
			var normalized := _normalize_directory_name(child)
			if normalized.to_lower().contains(normalized_needle.to_lower()):
				return "%s/%s" % [ASSET_ROOT, child]
	push_warning("Could not find asset directory containing '%s', falling back to protagonist." % normalized_needle)
	return "%s/protagonist" % ASSET_ROOT


func _find_image_in_asset_directory(asset_dir: String, normalized_file_name: String) -> String:
	var directory := DirAccess.open(asset_dir)
	if directory == null:
		return "%s/%s" % [asset_dir, normalized_file_name]
	var normalized_target := _normalize_directory_name(normalized_file_name)
	for file_name in directory.get_files():
		if _normalize_directory_name(file_name) == normalized_target:
			return "%s/%s" % [asset_dir, file_name]
	return "%s/%s" % [asset_dir, normalized_file_name]


func _normalize_directory_name(value: String) -> String:
	return value.replace(String.chr(0x200C), "").replace(String.chr(0x200D), "").replace(String.chr(0xFEFF), "").strip_edges()


func _update_player_animation(input_vector: Vector2) -> void:
	_player.z_index = int(_player.global_position.y)
	if input_vector == Vector2.ZERO:
		_player_sprite.play("idle_%s" % _last_direction)
		return

	if absf(input_vector.x) > absf(input_vector.y):
		_last_direction = "right" if input_vector.x > 0 else "left"
	else:
		_last_direction = "down" if input_vector.y > 0 else "up"
	_player_sprite.play("walk_%s" % _last_direction)


func _build_ui() -> void:
	var canvas := get_node("UI") as CanvasLayer
	_exploration_hud = get_node("UI/ExplorationHUD") as Control
	_interaction_panel = _create_interaction_panel()
	canvas.add_child(_interaction_panel)
	_initialize_dialogue_panel()
	_drill_overlay = _create_drill_overlay()
	canvas.add_child(_drill_overlay)
	_loading_transition = LOADING_TRANSITION_SCENE.instantiate() as SceneLoadingTransition
	canvas.add_child(_loading_transition)
	_exploration_hud.connect("save_requested", _on_save_requested)
	_exploration_hud.connect("load_requested", _on_load_requested)
	_exploration_hud.connect("return_title_requested", _on_return_title_requested)

	if not _saved_scene_state.is_empty():
		_restore_saved_scene_state(_saved_scene_state)
		_saved_scene_state.clear()
	elif _returning_from_sea:
		_restore_post_drill_state()
		_refresh_exploration_hud()
	elif _should_play_arrival_dialogue:
		_start_arrival_dialogue()
	else:
		_activate_arrival_task()
		_refresh_exploration_hud()


func _initialize_dialogue_panel() -> void:
	_dialogue_panel = get_node("UI/DialoguePanel") as Control
	_paper_panel = get_node("UI/DialoguePanel/FullWidthPaperDialogueBox") as PanelContainer
	_dialogue_margin = get_node("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin") as MarginContainer
	_dialogue_label = get_node("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label
	_option_box = get_node("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/OptionBox") as VBoxContainer
	_next_dialogue_button = get_node("UI/DialoguePanel/FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/NextDialogueButton") as Button
	_portrait_image = get_node("UI/DialoguePanel/LargeTransparentPortrait") as TextureRect
	_portrait_box = get_node("UI/DialoguePanel/PortraitBox") as ColorRect
	_portrait_label = get_node("UI/DialoguePanel/PortraitLabel") as Label
	_name_plate = get_node("UI/DialoguePanel/NamePlate") as PanelContainer
	_speaker_label = get_node("UI/DialoguePanel/NamePlate/SpeakerLabel") as Label

	_apply_dialogue_panel_styles()
	_next_dialogue_button.pressed.connect(_advance_dialogue)
	_apply_dialogue_side(false)
	_dialogue_panel.hide()


func _apply_dialogue_panel_styles() -> void:
	var paper_style := StyleBoxTexture.new()
	paper_style.texture = load(DIALOGUE_BACKGROUND_PATH) as Texture2D
	paper_style.content_margin_left = 24
	paper_style.content_margin_right = 24
	paper_style.content_margin_top = 18
	paper_style.content_margin_bottom = 18
	_paper_panel.add_theme_stylebox_override("panel", paper_style)

	var name_style := StyleBoxTexture.new()
	name_style.texture = load(DIALOGUE_NAMEPLATE_PATH) as Texture2D
	name_style.content_margin_left = 18
	name_style.content_margin_right = 18
	name_style.content_margin_top = 7
	name_style.content_margin_bottom = 7
	_name_plate.add_theme_stylebox_override("panel", name_style)

	_next_dialogue_button.add_theme_stylebox_override("normal", _create_option_style(Color.TRANSPARENT))
	_next_dialogue_button.add_theme_stylebox_override("hover", _create_option_style(Color(0.08, 0.16, 0.13, 0.34)))
	_next_dialogue_button.add_theme_stylebox_override("pressed", _create_option_style(Color(0.03, 0.08, 0.06, 0.46)))


func _create_interaction_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "InteractionPanel"
	panel.position = Vector2(548, 650)
	panel.size = Vector2(250, 92)
	panel.visible = false

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(250, 92)
	panel.add_child(box)

	var meet_button := Button.new()
	meet_button.text = "拜见"
	meet_button.custom_minimum_size = Vector2(220, 40)
	meet_button.pressed.connect(_start_dialogue)
	box.add_child(meet_button)

	_drill_button = Button.new()
	_drill_button.text = "操练"
	_drill_button.custom_minimum_size = Vector2(220, 40)
	_drill_button.visible = false
	_drill_button.pressed.connect(_show_drill)
	box.add_child(_drill_button)
	return panel


func _create_drill_overlay() -> Control:
	var root := Control.new()
	root.name = "DrillOverlay"
	root.visible = false
	root.size = Vector2(1344, 896)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.08, 0.72)
	dim.size = Vector2(1344, 896)
	root.add_child(dim)

	var title := Label.new()
	title.text = "水师操练"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 96)
	title.size = Vector2(1344, 70)
	title.add_theme_font_size_override("font_size", 48)
	root.add_child(title)

	var body := Label.new()
	body.text = "战鼓既发，左右舷师列阵。弓弩、火炮、登舷诸队依令操演，旗帜在甲板上传令往复，南疆水师初具军容。"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.position = Vector2(220, 180)
	body.size = Vector2(904, 120)
	body.add_theme_font_size_override("font_size", 28)
	root.add_child(body)

	var note := Label.new()
	note.text = "备注：有待完善，可以用 CG 来代替演示。"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.position = Vector2(220, 258)
	note.size = Vector2(904, 42)
	note.add_theme_font_size_override("font_size", 22)
	note.add_theme_color_override("font_color", Color(0.88, 0.84, 0.72))
	root.add_child(note)

	_add_drill_ship(root, Vector2(410, 500), -9)
	_add_drill_ship(root, Vector2(672, 430), 0)
	_add_drill_ship(root, Vector2(934, 500), 9)

	var close_button := Button.new()
	close_button.name = "ReturnButton"
	close_button.text = "返回甲板"
	close_button.position = Vector2(572, 760)
	close_button.size = Vector2(200, 52)
	close_button.pressed.connect(_close_drill_overlay)
	root.add_child(close_button)
	return root


func _add_drill_ship(root: Control, position_value: Vector2, rotation_degrees_value: float) -> void:
	var ship := Polygon2D.new()
	ship.position = position_value
	ship.rotation_degrees = rotation_degrees_value
	ship.polygon = PackedVector2Array([
		Vector2(0, -88), Vector2(48, -48), Vector2(38, 88),
		Vector2(0, 118), Vector2(-38, 88), Vector2(-48, -48),
	])
	ship.color = Color(0.55, 0.33, 0.18)
	root.add_child(ship)

	var sail := Polygon2D.new()
	sail.position = position_value + Vector2(0, -12)
	sail.rotation_degrees = rotation_degrees_value
	sail.polygon = PackedVector2Array([Vector2(-8, -66), Vector2(45, 20), Vector2(-8, 72)])
	sail.color = Color(0.86, 0.78, 0.55)
	root.add_child(sail)


func _open_npc_dialogue(npc: Dictionary) -> void:
	_active_npc = npc
	_interaction_panel.hide()
	_dialogue_panel.show()
	_refresh_exploration_hud()
	_option_box.show()
	_next_dialogue_button.hide()

	_speaker_label.text = npc["display_name"]
	_dialogue_label.text = npc["dialogue_line"]
	_portrait_label.text = npc["portrait_text"]
	_set_portrait(npc["portrait_path"], npc["portrait_text"], false)
	_clear_option_buttons()

	match npc["role"]:
		LEFT_SOLDIER_ROLE, RIGHT_SOLDIER_ROLE:
			_configure_soldier_dialogue(npc)
		OFFICER_ROLE:
			_configure_officer_dialogue()
		MAGISTRATE_ROLE:
			_configure_magistrate_dialogue()
		_:
			_add_dialogue_option("无事。", _close_npc_dialogue)


func _configure_soldier_dialogue(soldier: Dictionary) -> void:
	var role := str(soldier["role"])
	if _heard_soldier_reports.has(role):
		_dialogue_label.text = "属下方才所报句句属实，若有异动，定即刻呈报中军。"
		_add_dialogue_option("知道了。", _close_npc_dialogue)
		return

	if _patrol_task_stage != PatrolTaskStage.TALK_TO_SOLDIERS:
		_dialogue_label.text = "属下继续在此值守，请元帅放心。"
		_add_dialogue_option("继续当值。", _close_npc_dialogue)
		return

	_dialogue_label.text = (
		"禀元帅，左舷岗哨与泊位缆索均已查验，有一处旧缆磨损，正待更换。"
		if role == LEFT_SOLDIER_ROLE
		else "禀元帅，右舷船炮与救火水桶已经点齐，夜巡两班皆按时换岗。"
	)
	_add_dialogue_option("详细说来。", _start_soldier_report_dialogue.bind(soldier))
	_add_dialogue_option("稍后再问。", _close_npc_dialogue)


func _configure_officer_dialogue() -> void:
	if _patrol_task_stage == PatrolTaskStage.TALK_TO_SOLDIERS:
		_dialogue_label.text = "请元帅先听取左右两舷值守士兵的汇报，末将随后汇总军令。"
		_add_dialogue_option("本帅先去巡视。", _close_npc_dialogue)
		return

	if _patrol_task_stage == PatrolTaskStage.REPORT_TO_OFFICER:
		_dialogue_label.text = "两舷值守士兵已经呈报完毕，请元帅训示，末将即刻传令整顿。"
		_add_dialogue_option("汇总巡视情况。", _start_officer_report_dialogue)
		_add_dialogue_option("稍后复命。", _close_npc_dialogue)
		return

	_dialogue_label.text = "巡视军令已经传至各岗。末将督促诸营整改，不敢懈怠。"
	_add_dialogue_option("严加督办。", _close_npc_dialogue)


func _configure_magistrate_dialogue() -> void:
	if _patrol_task_stage < PatrolTaskStage.MEET_MAGISTRATE:
		_dialogue_label.text = "军务为先。请元帅先完成驻地巡视，下官在此静候召见。"
		_add_dialogue_option("稍候片刻。", _close_npc_dialogue)
		return

	if _patrol_task_stage == PatrolTaskStage.MEET_MAGISTRATE:
		_dialogue_label.text = "下官已将岭南粮草、工匠与船材名册带来，愿与元帅共议水师操练。"
		_add_dialogue_option("商议水师操练。", _start_dialogue)
		_add_dialogue_option("稍后再议。", _close_npc_dialogue)
		return

	if _patrol_task_stage == PatrolTaskStage.EXPLORE_LINGNAN:
		_dialogue_label.text = "将军是否要巡视一下岭南海域？"
		_add_dialogue_option("立即出发", _depart_to_sea_overworld)
		_add_dialogue_option("稍后再说", _close_npc_dialogue)
		return

	_dialogue_label.text = "地方所需粮草与工匠，下官会依议定之数按期送至军港。"
	_add_dialogue_option("有劳县令。", _close_npc_dialogue)


func _add_dialogue_option(text_value: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(620, 28)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.94, 0.91, 0.82))
	var highlight_color := Color(1, 0.86, 0.54)
	button.add_theme_color_override("font_hover_color", highlight_color)
	button.add_theme_color_override("font_pressed_color", highlight_color)
	button.add_theme_color_override("font_hover_pressed_color", highlight_color)
	button.add_theme_color_override("font_focus_color", highlight_color)
	button.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.018, 0.96))
	button.add_theme_constant_override("outline_size", 4)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		button.add_theme_stylebox_override(state, _create_option_style(Color.TRANSPARENT))
	button.pressed.connect(action)
	_option_box.add_child(button)


func _create_option_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.content_margin_left = 18
	style.content_margin_right = 12
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


func _clear_option_buttons() -> void:
	for child in _option_box.get_children():
		_option_box.remove_child(child)
		child.queue_free()


func _set_portrait(portrait_path: String, fallback_text: String, show_on_left: bool) -> void:
	_apply_dialogue_side(show_on_left)
	if not portrait_path.is_empty() and FileAccess.file_exists(portrait_path):
		_portrait_image.texture = _load_texture_from_file(portrait_path)
		_portrait_image.show()
		_portrait_box.hide()
		_portrait_label.hide()
		return

	_portrait_image.texture = null
	_portrait_image.hide()
	_portrait_box.show()
	_portrait_box.position = Vector2(48, 492) if show_on_left else Vector2(1076, 492)
	_portrait_label.text = fallback_text
	_portrait_label.position = _portrait_box.position
	_portrait_label.show()


func _apply_dialogue_side(portrait_on_left: bool) -> void:
	if portrait_on_left:
		_portrait_image.position = Vector2(-20, 410)
		_name_plate.position = Vector2(24, 830)
		_set_dialogue_margins(426, 240, 76, 18)
		_dialogue_label.custom_minimum_size = Vector2(630, 62)
		_option_box.custom_minimum_size = Vector2(630, 50)
	else:
		_portrait_image.position = Vector2(884, 410)
		_name_plate.position = Vector2(1060, 830)
		_set_dialogue_margins(206, 440, 76, 18)
		_dialogue_label.custom_minimum_size = Vector2(650, 62)
		_option_box.custom_minimum_size = Vector2(650, 50)


func _set_dialogue_margins(left: int, right: int, top: int, bottom: int) -> void:
	_dialogue_margin.add_theme_constant_override("margin_left", left)
	_dialogue_margin.add_theme_constant_override("margin_right", right)
	_dialogue_margin.add_theme_constant_override("margin_top", top)
	_dialogue_margin.add_theme_constant_override("margin_bottom", bottom)


func _close_npc_dialogue() -> void:
	_dialogue_panel.hide()
	_active_npc = null
	_clear_option_buttons()
	_refresh_exploration_hud()


func _depart_to_sea_overworld() -> void:
	if _transitioning or _patrol_task_stage != PatrolTaskStage.EXPLORE_LINGNAN:
		return
	_transitioning = true
	_close_npc_dialogue()
	_exploration_hud.call("set_exploration_visible", false)
	var root := get_tree().root
	root.set_meta(SEA_OVERWORLD_ENTRY_META, true)
	await _loading_transition.play_loading("正在进入大地图")
	var change_error := get_tree().change_scene_to_file(SEA_OVERWORLD_SCENE)
	if change_error == OK:
		return
	root.remove_meta(SEA_OVERWORLD_ENTRY_META)
	_loading_transition.reset_loading()
	_transitioning = false
	_refresh_exploration_hud()


func _start_dialogue() -> void:
	if _patrol_task_stage != PatrolTaskStage.MEET_MAGISTRATE:
		return
	_begin_scripted_dialogue(_magistrate_dialogues, _complete_magistrate_briefing)


func _start_soldier_report_dialogue(soldier: Dictionary) -> void:
	var report: Array
	if soldier["role"] == LEFT_SOLDIER_ROLE:
		report = [
			[soldier["display_name"], "左舷昼夜各设两岗，泊位缆索大多完好，唯三号旧缆磨损，尚未领到替换麻索。"],
			["水师主帅", "记下旧缆所在。继续轮值，未换新缆前加派一人看守。"],
		]
	else:
		report = [
			[soldier["display_name"], "右舷船炮、火药桶与救火水具已经点齐，夜巡换岗无误，只是新兵口令还不够熟练。"],
			["水师主帅", "今夜加练口令与火警应对，不得惊扰正常值守。"],
		]
	_begin_scripted_dialogue(report, _complete_soldier_report.bind(soldier["role"]))


func _start_officer_report_dialogue() -> void:
	var report: Array = [
		["水师主帅", "两舷岗哨轮值无误，船炮与救火水具齐备；但左舷三号旧缆磨损，右舷新兵口令仍需加练。"],
		["中军军官", "末将领命。即刻从库中补发麻索，今夜增设口令与火警操练，明日再呈查验结果。"],
		["水师主帅", "驻地巡视至此完成。诸营照令整顿，本帅随后与广州县令商议军需和操练。"],
	]
	_begin_scripted_dialogue(report, _complete_officer_report)


func _begin_scripted_dialogue(dialogue: Array, completion: Callable) -> void:
	_active_scripted_dialogues = dialogue
	_scripted_dialogue_completion = completion
	_interaction_panel.hide()
	_option_box.hide()
	_next_dialogue_button.show()
	_dialogue_index = 0
	_show_dialogue_line()
	_dialogue_panel.show()
	_refresh_exploration_hud()


func _advance_dialogue() -> void:
	if _arrival_dialogue_active:
		_advance_arrival_dialogue()
		return

	_dialogue_index += 1
	if _dialogue_index >= _active_scripted_dialogues.size():
		_dialogue_panel.hide()
		_option_box.show()
		_active_npc = null
		_clear_option_buttons()
		var completion := _scripted_dialogue_completion
		_scripted_dialogue_completion = Callable()
		_active_scripted_dialogues = []
		if completion.is_valid():
			completion.call()
		_refresh_exploration_hud()
		return
	_show_dialogue_line()


func _show_dialogue_line() -> void:
	var line := _active_scripted_dialogues[_dialogue_index] as Array
	var speaker := str(line[0])
	var text_value := str(line[1])
	var is_commander := speaker == "水师主帅"
	var is_magistrate := speaker == "广州县令"
	var fallback := "帅" if is_commander else ("县" if is_magistrate else ("官" if speaker == "中军军官" else "兵"))
	var portrait_path: String
	if is_commander:
		portrait_path = _find_image_in_asset_directory("%s/protagonist" % ASSET_ROOT, "picture.png")
	elif is_magistrate:
		portrait_path = _find_image_in_asset_directory(_find_asset_directory("magistrate"), "picture.png")
	else:
		portrait_path = _find_image_in_asset_directory("%s/soldier" % ASSET_ROOT, "picture.png")

	_speaker_label.text = speaker
	_dialogue_label.text = text_value
	_portrait_label.text = fallback
	_set_portrait(portrait_path, fallback, is_commander)
	_next_dialogue_button.text = "结束" if _dialogue_index == _active_scripted_dialogues.size() - 1 else "继续"


func _consume_scene_entry_flag(meta_name: StringName) -> bool:
	var root := get_tree().root
	if not root.has_meta(meta_name):
		return false
	root.remove_meta(meta_name)
	return true


func _start_arrival_dialogue() -> void:
	_arrival_dialogue_active = true
	_arrival_dialogue_index = 0
	_interaction_panel.hide()
	_option_box.hide()
	_next_dialogue_button.show()
	_dialogue_panel.show()
	_show_arrival_dialogue_line()
	_refresh_exploration_hud()


func _advance_arrival_dialogue() -> void:
	_arrival_dialogue_index += 1
	if _arrival_dialogue_index < _arrival_dialogues.size():
		_show_arrival_dialogue_line()
		return

	_arrival_dialogue_active = false
	_dialogue_panel.hide()
	_option_box.show()
	_activate_arrival_task()
	_refresh_exploration_hud()


func _show_arrival_dialogue_line() -> void:
	var line := _arrival_dialogues[_arrival_dialogue_index] as Array
	var speaker := str(line[0])
	var is_commander := speaker == "水师主帅"
	_speaker_label.text = speaker
	_dialogue_label.text = str(line[1])
	_portrait_label.text = "帅" if is_commander else "副"
	var portrait_dir := "protagonist" if is_commander else "soldier"
	var portrait_path := _find_image_in_asset_directory("%s/%s" % [ASSET_ROOT, portrait_dir], "picture.png")
	_set_portrait(portrait_path, "帅" if is_commander else "副", is_commander)
	_next_dialogue_button.text = "开始巡视" if _arrival_dialogue_index == _arrival_dialogues.size() - 1 else "继续"


func _activate_arrival_task() -> void:
	_heard_soldier_reports.clear()
	_patrol_task_stage = PatrolTaskStage.TALK_TO_SOLDIERS
	_update_task_hud()


func _restore_post_drill_state() -> void:
	_heard_soldier_reports[LEFT_SOLDIER_ROLE] = true
	_heard_soldier_reports[RIGHT_SOLDIER_ROLE] = true
	_patrol_task_stage = PatrolTaskStage.EXPLORE_LINGNAN
	_update_task_hud()


func _complete_soldier_report(soldier_role: String) -> void:
	if _patrol_task_stage != PatrolTaskStage.TALK_TO_SOLDIERS or _heard_soldier_reports.has(soldier_role):
		return
	_heard_soldier_reports[soldier_role] = true
	if _heard_soldier_reports.size() >= 2:
		_patrol_task_stage = PatrolTaskStage.REPORT_TO_OFFICER
	_update_task_hud()


func _complete_officer_report() -> void:
	if _patrol_task_stage != PatrolTaskStage.REPORT_TO_OFFICER:
		return
	_patrol_task_stage = PatrolTaskStage.MEET_MAGISTRATE
	_update_task_hud()


func _complete_magistrate_briefing() -> void:
	if _patrol_task_stage != PatrolTaskStage.MEET_MAGISTRATE:
		return
	_patrol_task_stage = PatrolTaskStage.DRILL_UNLOCKED
	_update_task_hud()
	_show_drill()


func _update_task_hud() -> void:
	var task_title: String
	var objective: String
	var progress_stage: int
	match _patrol_task_stage:
		PatrolTaskStage.TALK_TO_SOLDIERS:
			task_title = "巡视水师驻地"
			objective = "与甲板值守士兵交谈（%d/2）" % _heard_soldier_reports.size()
			progress_stage = _heard_soldier_reports.size()
		PatrolTaskStage.REPORT_TO_OFFICER:
			task_title = "巡视水师驻地"
			objective = "士兵汇报已齐（2/2），向中军军官复命"
			progress_stage = _patrol_task_stage
		PatrolTaskStage.MEET_MAGISTRATE:
			task_title = "筹备水师操练"
			objective = "与广州县令交谈"
			progress_stage = _patrol_task_stage
		PatrolTaskStage.DRILL_UNLOCKED:
			task_title = "参加水师操练"
			objective = "检阅水师操练"
			progress_stage = _patrol_task_stage
		_:
			task_title = "探索海域，完善海图"
			objective = "与广州县令交谈，选择是否立即出发"
			progress_stage = _patrol_task_stage
	_exploration_hud.call("set_main_task_progress", task_title, objective, progress_stage)


func _show_drill() -> void:
	_interaction_panel.hide()
	_drill_overlay.show()
	_refresh_exploration_hud()


func _close_drill_overlay() -> void:
	_drill_overlay.hide()
	if _patrol_task_stage == PatrolTaskStage.DRILL_UNLOCKED:
		_patrol_task_stage = PatrolTaskStage.EXPLORE_LINGNAN
		_update_task_hud()
	_refresh_exploration_hud()


func _refresh_exploration_hud() -> void:
	if _exploration_hud == null or _dialogue_panel == null or _drill_overlay == null:
		return
	var is_free_exploration := not _dialogue_panel.visible and not _drill_overlay.visible
	_exploration_hud.call("set_exploration_visible", is_free_exploration)


func _is_menu_open() -> bool:
	return _exploration_hud != null and bool(_exploration_hud.call("is_menu_open"))


func _on_save_requested() -> void:
	if _transitioning or _dialogue_panel.visible or _drill_overlay.visible:
		_show_save_message(false, "unstable_scene")
		return
	var game_state := _game_state()
	if game_state == null:
		_show_save_message(false, "write_failed")
		return
	var heard_roles: Array[String] = []
	for role in _heard_soldier_reports:
		if bool(_heard_soldier_reports[role]):
			heard_roles.append(str(role))
	heard_roles.sort()
	var snapshot := {
		"patrol_task_stage": int(_patrol_task_stage),
		"heard_soldier_roles": heard_roles,
		"player_position": _vector_to_save(_player.global_position),
		"last_direction": _last_direction,
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
	var restored_stage := int(snapshot.get("patrol_task_stage", PatrolTaskStage.TALK_TO_SOLDIERS))
	if restored_stage not in [
		PatrolTaskStage.TALK_TO_SOLDIERS,
		PatrolTaskStage.REPORT_TO_OFFICER,
		PatrolTaskStage.MEET_MAGISTRATE,
		PatrolTaskStage.DRILL_UNLOCKED,
		PatrolTaskStage.EXPLORE_LINGNAN,
	]:
		restored_stage = PatrolTaskStage.TALK_TO_SOLDIERS
	if restored_stage == PatrolTaskStage.DRILL_UNLOCKED:
		restored_stage = PatrolTaskStage.EXPLORE_LINGNAN
	_patrol_task_stage = restored_stage
	_heard_soldier_reports.clear()
	var heard_roles = snapshot.get("heard_soldier_roles", [])
	if heard_roles is Array:
		for role_value in heard_roles:
			var role := str(role_value)
			if role in [LEFT_SOLDIER_ROLE, RIGHT_SOLDIER_ROLE]:
				_heard_soldier_reports[role] = true
	_last_direction = str(snapshot.get("last_direction", "down"))
	if _last_direction not in ["up", "down", "left", "right"]:
		_last_direction = "down"
	_player.global_position = _vector_from_save(snapshot.get("player_position"), _player.global_position)
	_player_sprite.play("idle_%s" % _last_direction)
	_dialogue_panel.hide()
	_drill_overlay.hide()
	_interaction_panel.hide()
	_update_task_hud()
	_refresh_exploration_hud()


func _show_save_message(success: bool, reason: String) -> void:
	if success:
		_exploration_hud.call("show_toast", "进度已保存")
		return
	var game_state := _game_state()
	var message := "存档操作失败。" if game_state == null else str(game_state.call("error_message", reason))
	_exploration_hud.call("show_toast", message)


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func _vector_to_save(value: Vector2) -> Array:
	return [value.x, value.y]


func _vector_from_save(value: Variant, fallback: Vector2) -> Vector2:
	if not value is Array or value.size() != 2:
		return fallback
	var restored := Vector2(float(value[0]), float(value[1]))
	return restored if is_finite(restored.x) and is_finite(restored.y) else fallback
