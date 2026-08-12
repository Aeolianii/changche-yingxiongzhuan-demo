extends SceneTree

const FISHING_SCRIPT := preload("res://scripts/fubo_guling/fubo_fishing_game.gd")
const DRUM_SCRIPT := preload("res://scripts/fubo_guling/fubo_drum_memory.gd")
const FUBO_SCENE := preload("res://scenes/fubo_guling/fubo_guling.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_fishing_loop()
	_test_drum_random_constraints()
	await _test_scene_contract()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("Fubo Guling skeleton verification passed.")
	quit(0)


func _test_fishing_loop() -> void:
	var fishing = FISHING_SCRIPT.new(20260811)
	fishing.place_item_on_hook_path_for_test(0, 100.0, "small_fish")
	_check(fishing.cast_hook(), "Fishing hook must launch from its swinging state.")
	for _step in 500:
		fishing.step(0.016)
		if fishing.get_state() == FISHING_SCRIPT.State.SWINGING:
			break
	_check(fishing.get_score() == 55, "Fishing must award the caught fish value and resume swinging.")


func _test_drum_random_constraints() -> void:
	var signatures: Array[String] = []
	for seed_value in [11, 22, 33]:
		var drum = DRUM_SCRIPT.new(seed_value)
		var sequences: Array[PackedInt32Array] = drum.get_sequences_for_test()
		var tempos: PackedFloat32Array = drum.get_round_tempos_for_test()
		_check(sequences.size() == 3, "Drum must generate three rounds.")
		_check(tempos.size() == 3, "Drum must generate one tempo per round.")
		for round_index in sequences.size():
			_check(sequences[round_index].size() == [4, 5, 6][round_index], "Drum round length mismatch.")
			for index in range(1, sequences[round_index].size()):
				_check(sequences[round_index][index] != sequences[round_index][index - 1], "Drum sequence cannot repeat an adjacent flag.")
		var third_round := sequences[2]
		_check(third_round.has(0) and third_round.has(1) and third_round.has(2), "Third drum round must contain all flag colors.")
		signatures.append(str(sequences) + str(tempos))
	var repeated = DRUM_SCRIPT.new(11)
	_check(str(repeated.get_sequences_for_test()) + str(repeated.get_round_tempos_for_test()) == signatures[0], "Identical drum seeds must reproduce the same challenge.")
	_check(signatures[0] != signatures[1] or signatures[1] != signatures[2], "Different drum seeds should produce varied challenges.")
	var mistake = DRUM_SCRIPT.new(44)
	mistake.start()
	var answer := mistake.get_current_sequence()
	var tempo := mistake.get_current_tempo()
	var wrong := (answer[0] + 1) % 3
	_check(mistake.submit(wrong) == DRUM_SCRIPT.SUBMIT_MISTAKE, "Wrong drum input must report a mistake.")
	_check(mistake.get_input_index() == 0, "Wrong drum input must reset only the current input cursor.")
	_check(mistake.get_current_sequence() == answer and is_equal_approx(mistake.get_current_tempo(), tempo), "Drum replay must retain the current answer and tempo.")


func _test_scene_contract() -> void:
	var level = FUBO_SCENE.instantiate()
	root.add_child(level)
	await process_frame
	_check(level.get_phase_for_test() == level.Phase.FISHING_AVAILABLE, "Fubo scene must start with coastal fishing already available.")
	_check(level.is_school_locked_for_test(), "The decorative school fence must retain its local physical collision.")
	_check(level.get_node("World/WorldObjects/SchoolBarrier").visible, "The decorative school fence must be visible from initial scene load.")
	_check(not level.has_node("World/WorldObjects/ViewpointBarrier") and not level.has_node("World/Collision/ViewpointBlocker"), "The ladder-side viewpoint fence and its invisible collision must be removed.")
	_check(level.get_node("World/WorldObjects").y_sort_enabled, "Dynamic characters must retain Y sorting.")
	var camera: Camera2D = level.get_node("World/WorldObjects/Player/Camera2D")
	_check(camera.limit_right == 1536, "Camera right limit must match the approved background width.")
	_check(camera.limit_bottom == 1024, "Camera bottom limit must match the approved background height.")
	_check(camera.zoom == Vector2(1.15, 1.15), "Camera zoom must provide limited follow without exposing the image edges.")
	var background: Sprite2D = level.get_node("World/Ground/Background")
	_check(background.texture != null, "The approved complete background must be imported.")
	_check(background.texture.resource_path == "res://assets/fubo_guling/backgrounds/fubo_guling_complete.png", "Fubo must use the owner-approved complete background.")
	_check(not background.centered and background.position == Vector2.ZERO, "The complete background must align to world coordinates from its top-left corner.")
	_check(not level.has_node("World/Ground/BackgroundPlates"), "The four-plate composition must be removed.")
	var blocked_regions := level.get_node("World/Collision/BlockedRegions")
	_check(blocked_regions.get_child_count() == 1, "The owner annotation must be implemented as one closed walkable boundary.")
	var boundary: CollisionPolygon2D = level.get_node("World/Collision/BlockedRegions/WalkableBoundary/Boundary")
	_check(boundary.build_mode == 1 and boundary.polygon.size() >= 20, "The walkable boundary must use closed segment collision around the marked route.")
	_check(level.get_node("World/WorldObjects/Player").position == Vector2(220, 868), "The player must spawn at the owner-marked dock cross.")
	for dock_vertex in [Vector2(550, 768), Vector2(420, 823), Vector2(200, 943), Vector2(95, 868), Vector2(250, 788), Vector2(380, 688)]:
		_check(boundary.polygon.has(dock_vertex), "The dock boundary must include approved vertex %s." % dock_vertex)
	_check(not boundary.polygon.has(Vector2(260, 966)), "The old dock-tip boundary vertex must be removed.")
	_check(level.get_node("World/WorldObjects/Keeper").position == Vector2(450, 475), "The keeper must stand at the house-front X.")
	var prop_source := FileAccess.get_file_as_string("res://scripts/fubo_guling/fubo_world_prop.gd")
	_check("ffe07a" not in prop_source, "The keeper interaction focus must not draw the rejected yellow ring.")
	var keeper := level.get_node("World/WorldObjects/Keeper") as Node2D
	var keeper_sprite := keeper.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_check(keeper_sprite != null and keeper_sprite.is_playing() and keeper_sprite.animation == &"idle_down", "The keeper must reuse the soldier idle-down animation.")
	if keeper_sprite != null:
		_check(keeper_sprite.sprite_frames.get_frame_count(&"idle_down") == 2 and is_equal_approx(keeper_sprite.sprite_frames.get_animation_speed(&"idle_down"), 4.0), "The keeper idle must reuse both soldier frames at the shared four FPS speed.")
		_check(keeper_sprite.sprite_frames.get_frame_texture(&"idle_down", 0).resource_path == "res://assets/characters/soldier/standard/idle/down/1.png" and keeper_sprite.sprite_frames.get_frame_texture(&"idle_down", 1).resource_path == "res://assets/characters/soldier/standard/idle/down/2.png", "The keeper idle must use the existing soldier textures without duplicated art.")
		_check(keeper_sprite.use_parent_material, "The animated keeper sprite must inherit the shared proximity outline.")
	var keeper_normal_modulate := keeper.modulate
	var keeper_normal_scale := keeper.scale
	level.call("_set_keeper_focus", true)
	_check(level.get_node("Interface/HUD/PromptPanel").visible and "守岭人" in (level.get_node("Interface/HUD/PromptPanel/Prompt") as Label).text, "Removing the ring must preserve the keeper interaction prompt.")
	_check(keeper.modulate.is_equal_approx(keeper_normal_modulate), "Keeper outline must preserve the original character colors.")
	_check(keeper.scale.is_equal_approx(keeper_normal_scale), "Keeper outline must not resize the character.")
	_check(keeper.material is ShaderMaterial, "Keeper proximity must apply the shared silhouette outline.")
	level.call("_set_keeper_focus", false)
	_check(keeper.modulate.is_equal_approx(keeper_normal_modulate) and keeper.scale.is_equal_approx(keeper_normal_scale) and keeper.material == null, "Leaving keeper range must restore its exact visual state.")
	var fishing_station := level.get_node("World/WorldObjects/FishingStation") as Node2D
	_check(fishing_station.position == Vector2(585, 835), "The fishing station must sit on the coast beside the dock.")
	var fishing_sprite := fishing_station.get_node("Sprite") as Sprite2D
	_check(fishing_sprite.texture != null and fishing_sprite.texture.resource_path == "res://assets/fubo_guling/generated/fishing_station_v1.png", "The coastal fishing station must use the generated rod-and-bucket art.")
	var fishing_body := level.get_node("World/Collision/FishingStationBody") as StaticBody2D
	var fishing_body_shape := (fishing_body.get_node("Shape") as CollisionShape2D).shape as CircleShape2D
	_check(fishing_body.position == Vector2(585, 810) and is_equal_approx(fishing_body_shape.radius, 47.0), "The fishing station must retain the owner-adjusted circular collision body.")
	var collision_probe_player := level.get_node("World/WorldObjects/Player") as CharacterBody2D
	collision_probe_player.global_position = Vector2(650, 810)
	var fishing_collision := collision_probe_player.move_and_collide(Vector2(-80, 0))
	_check(fishing_collision != null and fishing_collision.get_collider() == fishing_body, "The rough fishing-station circle must physically block the player.")
	var drum_body := level.get_node_or_null("World/Collision/DrumBody") as StaticBody2D
	var drum_shape := (drum_body.get_node("Shape") as CollisionShape2D).shape as CircleShape2D
	_check(drum_body.position == Vector2(1132, 247) and is_equal_approx(drum_shape.radius, 32.0), "The baked drum must have a rough editable circular collision body.")
	collision_probe_player.global_position = Vector2(1132, 300)
	var drum_collision := collision_probe_player.move_and_collide(Vector2(0, -80))
	_check(drum_collision != null and drum_collision.get_collider() == drum_body, "The rough drum circle must physically block the player.")
	var school_blocker := level.get_node("World/Collision/SchoolBlocker") as StaticBody2D
	var school_normal := Vector2(-sin(school_blocker.rotation), cos(school_blocker.rotation))
	collision_probe_player.global_position = school_blocker.global_position + school_normal * 70.0
	var school_collision := collision_probe_player.move_and_collide(-school_normal * 120.0)
	_check(school_collision != null and school_collision.get_collider() == school_blocker, "The decorative school fence must retain collision while allowing the player to walk around it.")
	collision_probe_player.global_position = Vector2(220, 868)
	_check(level.get_node("World/Triggers/FishingTrigger").position == fishing_body.position, "The fishing trigger must surround the coastal fishing collision body.")
	_check(level.get_node("World/Triggers/SchoolTrigger").position == Vector2(1110, 330), "The drum trigger must sit below the drum at the annotated X.")
	_check(level.get_node("World/Triggers/FishingTrigger/Shape").shape is CircleShape2D, "Fishing gameplay must be entered through a trigger area.")
	var fishing_trigger_shape := (level.get_node("World/Triggers/FishingTrigger/Shape") as CollisionShape2D).shape as CircleShape2D
	_check(is_equal_approx(fishing_trigger_shape.radius, 91.0) and fishing_trigger_shape.radius > fishing_body_shape.radius, "The fishing interaction range must retain the owner-adjusted ring around the prop collision.")
	_check(level.get_node("World/Triggers/SchoolTrigger/Shape").shape is CircleShape2D, "School gameplay must be entered through a trigger area.")
	var sea_return := level.get_node_or_null("World/Triggers/SeaReturnTrigger") as Area2D
	_check(sea_return != null, "The dock must expose a sea-map return trigger.")
	if sea_return != null:
		_check(sea_return.position == Vector2(235, 835), "The sea return trigger must sit at the approved dock tip.")
		var sea_return_shape := (sea_return.get_node("Shape") as CollisionShape2D).shape as CircleShape2D
		_check(sea_return_shape != null and is_equal_approx(sea_return_shape.radius, 55.0), "The sea return trigger must use the approved radius 55.")
		var fishing_shape := (level.get_node("World/Triggers/FishingTrigger/Shape") as CollisionShape2D).shape as CircleShape2D
		_check(sea_return.position.distance_to(level.get_node("World/Triggers/FishingTrigger").position) > sea_return_shape.radius + fishing_shape.radius, "Sea return and fishing triggers must not overlap.")
		_check(level.has_method("_on_sea_return_body_entered") and level.has_method("_return_to_sea_overworld"), "Fubo must implement explicit dock return behavior.")
		if level.has_method("_on_sea_return_body_entered"):
			level.call("_on_sea_return_body_entered", level.get_node("World/WorldObjects/Player"))
			_check(str(level.get("_pending_trigger")) == "sea_return", "Entering the dock return trigger must only arm the return action.")
			_check(level.get_node("Interface/HUD/PromptPanel").visible and "返回海图" in (level.get_node("Interface/HUD/PromptPanel/Prompt") as Label).text, "The dock return trigger must show a clear confirmation prompt.")
			level.call("_on_trigger_body_exited", level.get_node("World/WorldObjects/Player"), "sea_return")
	var prompt_button := level.get_node("Interface/HUD/PromptPanel") as TextureButton
	_check(prompt_button.texture_normal.resource_path == "res://assets/ui/sea_overworld/interaction_button_ink_v1.png", "Fubo interaction must reuse the scene-one/two normal ink button.")
	_check(prompt_button.texture_pressed.resource_path == "res://assets/ui/sea_overworld/interaction_button_ink_active_v1.png", "Fubo interaction must reuse the scene-one/two active ink button.")
	_check(prompt_button.size.is_equal_approx(Vector2(300.0, 74.0)), "Fubo interaction button must match the scene-one/two button size.")
	var early_host := level.get_node("Interface/MinigameHost")
	_check(early_host is Control, "Map needs a full-screen minigame host.")
	_check(level.get_node("Interface/MinigameHost").process_mode == Node.PROCESS_MODE_ALWAYS, "Minigame host must process input without pausing the SceneTree.")
	_check(fishing_station.call("is_available_for_test"), "The fishing rod must sparkle and accept interaction from initial scene load.")
	_check(level.trigger_fishing_for_test(), "Fishing must open before the player speaks to the keeper.")
	_check(early_host.active_minigame != null and early_host.active_minigame.game_id == "fishing", "Initial fishing access must open the real fishing minigame.")
	if early_host.active_minigame != null:
		early_host.active_minigame.exit_requested.emit()
		await process_frame
	level.call("_on_trigger_body_exited", collision_probe_player, "fishing")
	collision_probe_player.global_position = Vector2(450, 540)
	await physics_frame
	await process_frame
	level.call("_on_trigger_body_exited", collision_probe_player, "sea_return")
	_check(level.get_phase_for_test() == level.Phase.FISHING_AVAILABLE and early_host.active_minigame == null, "Leaving early fishing must preserve its always-available state.")
	_check(level.get_node("World/WorldObjects").get_child_count() <= 5, "Only the player, keeper and story barriers may remain as separate world objects.")
	for baked_prop_name in ["House", "Storage", "TreeCourtyard", "TreePath", "TreeCanal", "CanalMarker", "Drum", "FlagYellow", "FlagRed", "FlagBlue", "Stele"]:
		_check(not level.has_node("World/WorldObjects/" + baked_prop_name), "%s must be baked into the complete background." % baked_prop_name)
	level.finish_keeper_dialogue_for_test()
	_check(level.get_phase_for_test() == level.Phase.FISHING_AVAILABLE and level.is_keeper_intro_completed_for_test(), "Keeper dialogue must only mark its hint as heard without unlocking fishing.")
	level.call("_set_keeper_focus", true)
	level.call("_handle_interaction")
	var keeper_dialogue := level.get_node("Interface/KeeperDialogue") as FieldEventDialogue
	var keeper_dialogue_text := keeper_dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label
	var keeper_options := keeper_dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/OptionBox") as VBoxContainer
	_check(keeper_dialogue.visible and "倭患一日未靖" in keeper_dialogue_text.text and "伏波岛" in keeper_dialogue_text.text, "Keeper must remain interactable with an in-character fixed line after the story dialogue.")
	_check(keeper_options.get_child_count() == 1 and (keeper_options.get_child(0) as Button).text == "无事  ▶", "Repeated keeper dialogue must provide one arrow-marked 无事 exit option.")
	(keeper_options.get_child(0) as Button).pressed.emit()
	_check(not keeper_dialogue.visible and level.get_node("World/WorldObjects/Player").controls_enabled, "Choosing 无事 must close the repeated keeper dialogue and restore control.")
	_check(fishing_station.call("is_available_for_test"), "The fishing rod must sparkle once fishing becomes available.")
	var player := level.get_node("World/WorldObjects/Player") as CharacterBody2D
	player.global_position = Vector2(650, 810)
	player.velocity = Vector2.ZERO
	await physics_frame
	await process_frame
	level.call("_on_fishing_body_entered", player)
	_check(str(level.get("_pending_trigger")) == "fishing" and level.get_node("Interface/HUD/PromptPanel").visible, "Entering the physical interaction ring must arm coastal fishing.")
	_check(fishing_station.call("is_highlighted_for_test"), "Approaching the fishing rod must apply the shared interaction highlight.")
	_check(fishing_sprite.modulate.is_equal_approx(Color(1.35, 1.22, 0.72, 1.0)), "Fishing interaction must retain its gold highlight.")
	_check(fishing_sprite.scale.is_equal_approx(Vector2.ONE), "Fishing interaction highlight must never enlarge the rod-and-bucket art.")
	level.call("_on_trigger_body_exited", player, "fishing")
	_check(not fishing_station.call("is_highlighted_for_test"), "Leaving the fishing station must clear its highlight.")
	_check(level.get_node("Interface/MinigameHost").active_minigame == null, "Keeper dialogue must not open fishing directly.")
	level.call("_on_fishing_body_entered", player)
	prompt_button.pressed.emit()
	var host = level.get_node("Interface/MinigameHost")
	_check(host.active_minigame != null and host.active_minigame.game_id == "fishing", "The shared interaction button must open coastal fishing.")
	_check(host.active_minigame.can_process() and host.active_minigame.get_node("ExitButton").can_process(), "Hosted fishing controls must receive real input.")
	host.active_minigame.completed.emit({"game_id": "fishing", "completed": true, "rating": "渔获丰足", "mistakes": 0, "duration_ms": 1000})
	await process_frame
	_check(level.get_phase_for_test() == level.Phase.DRUM_AVAILABLE and host.active_minigame == null, "Fishing completion must restore the map and unlock the school.")
	_check(level.is_school_locked_for_test() and level.get_node("World/WorldObjects/SchoolBarrier").visible, "Completing fishing must keep both the decorative school fence and its local collision unchanged.")
	_check("渔获满舱，收竿归岸" in FileAccess.get_file_as_string("res://scripts/fubo_guling/fubo_guling.gd") and "渔获满舱，可以前往古校场" not in FileAccess.get_file_as_string("res://scripts/fubo_guling/fubo_guling.gd"), "Every fishing completion notice must only report the catch and return ashore.")
	var repeat_fishing_position := Vector2(720, 805)
	player.global_position = repeat_fishing_position
	_check(level.trigger_fishing_for_test(), "Fishing must remain available after its first story completion.")
	_check(host.active_minigame != null and host.active_minigame.game_id == "fishing", "Repeat fishing must open the real fishing minigame.")
	host.active_minigame.exit_requested.emit()
	await process_frame
	_check(level.get_phase_for_test() == level.Phase.DRUM_AVAILABLE and host.active_minigame == null, "Leaving repeat fishing must preserve the current story phase.")
	_check(player.global_position == repeat_fishing_position, "Leaving repeat fishing must restore the position used to enter it.")
	var drum_entry_position := Vector2(1095, 370)
	(level.get_node("World/WorldObjects/Player") as CharacterBody2D).global_position = drum_entry_position
	level.call("_on_school_body_entered", player)
	_check((level.get_node("Interface/HUD/PromptPanel/Prompt") as Label).text == "按 E / 空格 进入听令回鼓", "School interaction prompt must omit the redundant leave instruction.")
	level.trigger_drum_for_test()
	_check(host.active_minigame != null and host.active_minigame.game_id == "drum", "School trigger must open the drum minigame.")
	host.active_minigame.exit_requested.emit()
	await process_frame
	_check(level.get_phase_for_test() == level.Phase.DRUM_AVAILABLE and host.active_minigame == null, "Leaving the drum minigame must restore its available phase.")
	_check((level.get_node("World/WorldObjects/Player") as CharacterBody2D).global_position == drum_entry_position, "Leaving the drum minigame must restore the position used to enter it.")
	level.trigger_drum_for_test()
	host.active_minigame.completed.emit({"game_id": "drum", "completed": true, "rating": "鼓点稳健", "mistakes": 1, "duration_ms": 1000})
	await process_frame
	_check(level.get_phase_for_test() == level.Phase.VIEWPOINT_OPEN and host.active_minigame == null, "Drum completion must restore the map and open the viewpoint.")
	_check(not level.has_node("World/WorldObjects/ViewpointBarrier") and not level.has_node("World/Collision/ViewpointBlocker"), "Drum completion must not recreate the removed ladder-side fence.")
	level.free()
	await process_frame
	await create_timer(0.55).timeout


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
