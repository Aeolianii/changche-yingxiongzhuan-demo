extends SceneTree

const PALACE_SCENE := preload("res://scenes/palace/palace_demo.tscn")
const SCENE_TWO := preload("res://scenes/Scene2.tscn")
const FUBO_SCENE := preload("res://scenes/fubo_guling/fubo_guling.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _verify_palace_dialogue_locks_player()
	await _verify_scene_two_dialogue_locks_player()
	await _verify_fubo_dialogue_locks_player()
	Input.action_release("move_right")
	if failures.is_empty():
		print("Global dialogue player-movement lock verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_palace_dialogue_locks_player() -> void:
	var palace := PALACE_SCENE.instantiate()
	root.add_child(palace)
	await process_frame
	await physics_frame
	var player := palace.get_node("YSortedCharacters/Player") as CharacterBody2D
	var start_position := player.global_position
	player.call("request_move_to", start_position + Vector2(120.0, 0.0))
	Input.action_press("move_right")
	await _wait_physics_frames(4)
	Input.action_release("move_right")
	_expect(not bool(player.get("controls_enabled")), "Palace dialogue must disable player controls.")
	_expect(not bool(player.call("has_move_target")), "Palace dialogue must clear the player's click-move target.")
	_expect(player.global_position.distance_to(start_position) < 0.5, "Palace dialogue must keep the player stationary.")

	palace.set("story_state", 2)
	palace.call("_hide_dialogue")
	await process_frame
	_expect(bool(player.get("controls_enabled")), "Palace controls must return after dialogue closes in free exploration.")
	palace.queue_free()
	await process_frame


func _verify_scene_two_dialogue_locks_player() -> void:
	var scene_two := SCENE_TWO.instantiate()
	root.add_child(scene_two)
	await process_frame
	await physics_frame
	var player := scene_two.get_node("World/Actors/Player") as CharacterBody2D
	var start_position := player.global_position
	scene_two.call("request_player_move_to", start_position + Vector2(120.0, 0.0))
	scene_two.call("_begin_scripted_dialogue", [["测试", "玩家在对白中应保持不动。"]], Callable())
	Input.action_press("move_right")
	await _wait_physics_frames(4)
	Input.action_release("move_right")
	_expect(not bool(scene_two.call("has_player_move_target")), "Scene2 dialogue must clear the player's click-move target.")
	_expect(player.global_position.distance_to(start_position) < 0.5, "Scene2 dialogue must keep the player stationary.")
	scene_two.queue_free()
	await process_frame


func _verify_fubo_dialogue_locks_player() -> void:
	var fubo := FUBO_SCENE.instantiate()
	root.add_child(fubo)
	await process_frame
	await physics_frame
	var player := fubo.get_node("World/WorldObjects/Player") as CharacterBody2D
	var start_position := player.global_position
	player.call("request_move_to", start_position + Vector2(120.0, 0.0))
	fubo.call("_start_dialogue")
	Input.action_press("move_right")
	await _wait_physics_frames(4)
	Input.action_release("move_right")
	_expect(not bool(player.get("controls_enabled")), "Fubo dialogue must disable player controls.")
	_expect(not bool(player.call("has_move_target")), "Fubo dialogue must clear the player's click-move target.")
	_expect(player.global_position.distance_to(start_position) < 0.5, "Fubo dialogue must keep the player stationary.")
	fubo.queue_free()
	await process_frame


func _wait_physics_frames(count: int) -> void:
	for _index in count:
		await physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
