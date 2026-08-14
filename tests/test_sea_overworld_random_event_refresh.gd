extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const EVENT_TEA := &"tea_merchant"
const EVENT_SALT := &"salt_merchant"
const EVENT_CRATE := &"drifting_crate"
const EVENT_SEA_MONSTER := &"sea_monster_mist"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := SEA_SCENE.instantiate()
	scene.set("_random_event_seed_override", 1)
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	_verify_initial_slots(scene)
	await _verify_salt_patrol_and_refill(scene)
	_verify_entry_reroll_and_tea_completion(scene)

	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("Sea overworld random-event refresh verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_initial_slots(scene: Node) -> void:
	var events := _active_events(scene)
	var ids := _event_ids(events)
	_expect(events.size() == 3, "A fresh sea map must contain exactly three active random events when three types are available.")
	_expect(ids.has(EVENT_SALT) and ids.has(EVENT_CRATE) and ids.has(EVENT_SEA_MONSTER), "The deterministic seed must choose salt, crate, and sea monster as three ordinary candidates.")
	_expect(not ids.has(EVENT_TEA), "An unfinished tea merchant must not receive a guaranteed or priority slot.")
	_expect(_has_unique_ids(events), "The three initial event slots must use distinct event types.")


func _verify_salt_patrol_and_refill(scene: Node) -> void:
	var salt_ship := scene.get_node_or_null("World/WorldMarkers/SaltMerchantShip") as Area2D
	_expect(salt_ship != null, "Salt merchant must exist for patrol verification.")
	if salt_ship == null:
		return
	var spawn_origin: Vector2 = salt_ship.get_meta("spawn_origin", Vector2.ZERO)
	for _step in range(30):
		scene.call("_update_salt_merchant_movement", 0.1)
		if not salt_ship.position.is_equal_approx(spawn_origin):
			break
	_expect(not salt_ship.position.is_equal_approx(spawn_origin), "Salt merchant must move within its local patrol area.")
	_expect(salt_ship.position.distance_to(spawn_origin) <= 240.0, "Salt merchant must never leave its pirate-matched 240-unit patrol radius.")
	scene.call("_start_salt_merchant_rest")
	var rest_position := salt_ship.position
	scene.call("_update_salt_merchant_movement", 0.4)
	_expect(salt_ship.position.is_equal_approx(rest_position) and StringName(scene.get("_salt_merchant_behavior")) == &"rest", "Salt merchant must stop during its pirate-matched rest phase.")

	var player := scene.get_node("World/Player") as CharacterBody2D
	var camera := scene.get_node("World/Player/Camera2D") as Camera2D
	var dialogue := scene.get_node("UI/FieldEventDialogue") as Control
	player.global_position = salt_ship.global_position
	camera.reset_smoothing()
	for _frame in range(3):
		await physics_frame
	_expect(dialogue.visible, "Reaching the moving salt merchant must still open its event dialogue.")
	var paused_position := salt_ship.position
	scene.call("_update_salt_merchant_movement", 2.0)
	_expect(salt_ship.position.is_equal_approx(paused_position), "Salt merchant patrol must pause while its dialogue is open.")

	var option_box := _option_box(dialogue)
	if option_box.get_child_count() != 3:
		_expect(false, "Salt merchant dialogue must expose all three choices before refill verification.")
		return
	(option_box.get_child(2) as Button).pressed.emit()
	await process_frame
	option_box = _option_box(dialogue)
	if option_box.get_child_count() != 1:
		_expect(false, "Salt merchant result must expose one finish choice.")
		return
	(option_box.get_child(0) as Button).pressed.emit()
	await process_frame
	await process_frame
	await physics_frame

	var events := _active_events(scene)
	var ids := _event_ids(events)
	_expect(events.size() == 3, "Completing one event must refill the active slots back to three while an unseen type remains.")
	_expect(_has_unique_ids(events), "Refilling must not create duplicate event types.")
	_expect(ids.has(EVENT_TEA) and ids.has(EVENT_CRATE) and ids.has(EVENT_SEA_MONSTER), "Completing salt must fill the free slot with the only unseen event type.")
	_expect(not ids.has(EVENT_SALT), "A completed salt event must not return during the same sea-map session.")
	_expect((scene.get("_resolved_random_event_ids") as Dictionary).has(EVENT_SALT), "Completing salt must record its type in the current session.")
	var replacement := scene.call("_find_random_event", EVENT_TEA) as Area2D
	if replacement != null:
		var view_rect: Rect2 = scene.call("_player_view_world_rect")
		_expect(not view_rect.has_point(replacement.global_position), "Replacement event must spawn outside the player's current camera view.")

	var crate := scene.call("_find_random_event", EVENT_CRATE) as Area2D
	scene.call("_mark_random_event_resolved", EVENT_CRATE, crate)
	await process_frame
	scene.call("_refill_random_event_slots")
	await process_frame
	var exhausted_ids := _event_ids(_active_events(scene))
	_expect(exhausted_ids.size() == 2, "Active slots must shrink when every remaining event type is already active or resolved.")
	_expect(not exhausted_ids.has(EVENT_SALT) and not exhausted_ids.has(EVENT_CRATE), "Resolved event types must never refill again in the same session.")
	scene.call("_refill_random_event_slots")
	_expect(_event_ids(_active_events(scene)) == exhausted_ids, "Repeated refill requests must not resurrect already resolved event types.")


func _verify_entry_reroll_and_tea_completion(scene: Node) -> void:
	var before := _event_positions(scene)
	var state: Dictionary = scene.call("_current_event_state")
	scene.set("_random_event_seed_override", 2)
	scene.call("_restore_event_state", state)
	var after := _event_positions(scene)
	_expect(after.size() == 3 and after != before, "Entering through state restoration must reroll three event types or positions instead of restoring old slots.")
	_expect((scene.get("_resolved_random_event_ids") as Dictionary).is_empty(), "A new sea-map entry must clear the previous session's resolved event types.")
	var game_state := root.get_node("GameState")
	game_state.call("set_tea_merchant_event_completed", true)
	scene.set("_random_event_seed_override", 0)
	scene.call("_initialize_random_events")
	var completed_ids := _event_ids(_active_events(scene))
	_expect(completed_ids.size() == 3 and not completed_ids.has(EVENT_TEA), "A completed tea event must leave the later-entry pool while the other three types fill all slots.")


func _active_events(scene: Node) -> Array:
	return scene.call("_active_random_events") as Array


func _event_ids(events: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for area in events:
		result.append(StringName((area as Area2D).get_meta("random_event_id", &"")))
	return result


func _event_positions(scene: Node) -> Dictionary:
	var result := {}
	for area in _active_events(scene):
		var event_area := area as Area2D
		result[String(event_area.get_meta("random_event_id", &""))] = event_area.global_position
	return result


func _has_unique_ids(events: Array) -> bool:
	var ids := _event_ids(events)
	var unique := {}
	for event_id in ids:
		unique[event_id] = true
	return unique.size() == ids.size()


func _option_box(dialogue: Control) -> VBoxContainer:
	return dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/OptionBox") as VBoxContainer


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
