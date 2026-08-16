extends SceneTree

const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const SCENE_TWO := preload("res://scenes/Scene2.tscn")
const FUBO_SCENE := preload("res://scenes/fubo_guling/fubo_guling.tscn")
const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _verify_palace_player_click_move()
	await _verify_scene_two_click_move()
	await _verify_fubo_click_move()
	await _verify_sea_overworld_click_move()
	if failures.is_empty():
		print("Click-to-move runtime verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_palace_player_click_move() -> void:
	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	root.add_child(player)
	player.global_position = Vector2(420.0, 420.0)
	await process_frame

	var target := player.global_position + Vector2(90.0, 0.0)
	_send_world_click(player, target)
	_expect(bool(player.call("has_move_target")), "Palace player must accept a left-click move target.")
	_expect((player.call("move_target") as Vector2).distance_to(target) < 0.5, "Palace click coordinates must map to the intended world position.")
	await _wait_physics_frames(45)
	_expect(player.global_position.distance_to(target) <= 7.0, "Palace player must walk to an unobstructed click target.")
	_expect(not bool(player.call("has_move_target")), "Palace player must clear the target after arrival.")

	player.call("request_move_to", player.global_position + Vector2(160.0, 0.0))
	Input.action_press("move_left")
	await physics_frame
	Input.action_release("move_left")
	_expect(not bool(player.call("has_move_target")), "Keyboard movement must cancel the palace click target.")

	var locked_position := player.global_position
	player.call("request_move_to", locked_position + Vector2(100.0, 0.0))
	player.set("controls_enabled", false)
	await physics_frame
	_expect(not bool(player.call("has_move_target")), "Disabling palace controls must clear the click target.")
	_expect(player.global_position.distance_to(locked_position) < 0.5, "Disabled palace controls must prevent click movement.")

	player.set("controls_enabled", true)
	player.global_position = Vector2(300.0, 300.0)
	var wall := StaticBody2D.new()
	wall.position = Vector2(335.0, 300.0)
	var wall_collision := CollisionShape2D.new()
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(10.0, 90.0)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	root.add_child(wall)
	player.call("request_move_to", Vector2(410.0, 300.0))
	await _wait_physics_frames(55)
	_expect(player.global_position.x < wall.global_position.x, "Click movement must not pass through an existing collision body.")
	_expect(not bool(player.call("has_move_target")), "A persistently blocked click target must be cleared.")
	wall.queue_free()
	player.queue_free()
	await process_frame


func _verify_scene_two_click_move() -> void:
	var scene_two := SCENE_TWO.instantiate()
	root.add_child(scene_two)
	await process_frame
	await physics_frame
	var player := scene_two.get_node("World/Actors/Player") as CharacterBody2D
	var target := player.global_position + Vector2(90.0, 0.0)
	_send_world_click(scene_two, target)
	_expect(bool(scene_two.call("has_player_move_target")), "Scene2 must accept a left-click move target during free exploration.")
	_expect((scene_two.call("player_move_target") as Vector2).distance_to(target) < 0.5, "Scene2 click coordinates must map to the intended world position.")
	await _wait_physics_frames(40)
	_expect(player.global_position.distance_to(target) <= 7.0, "Scene2 player must walk to an unobstructed click target.")
	_expect(not bool(scene_two.call("has_player_move_target")), "Scene2 must clear the target after arrival.")

	scene_two.call("request_player_move_to", player.global_position + Vector2(120.0, 0.0))
	var menu_button := root.get_node("ExplorationUI/HUD/FunctionButtons/MenuButtonSlot/MenuButton") as BaseButton
	menu_button.pressed.emit()
	await physics_frame
	_expect(not bool(scene_two.call("has_player_move_target")), "Opening the Scene2 system menu must clear the click target.")
	scene_two.queue_free()
	await process_frame


func _verify_fubo_click_move() -> void:
	var fubo := FUBO_SCENE.instantiate()
	root.add_child(fubo)
	await process_frame
	await physics_frame
	var player := fubo.get_node("World/WorldObjects/Player") as CharacterBody2D
	var target := player.global_position + Vector2(90.0, 0.0)
	_send_world_click(fubo, target)
	_expect(bool(player.call("has_move_target")), "Fubo must accept a left-click move target during free exploration.")
	_expect((player.call("move_target") as Vector2).distance_to(target) < 0.5, "Fubo click coordinates must map to the intended world position.")
	await _wait_physics_frames(40)
	_expect(player.global_position.distance_to(target) <= 7.0, "Fubo player must walk to an unobstructed click target.")
	_expect(not bool(player.call("has_move_target")), "Fubo must clear the target after arrival.")

	player.call("request_move_to", player.global_position + Vector2(120.0, 0.0))
	var menu_button := root.get_node("ExplorationUI/HUD/FunctionButtons/MenuButtonSlot/MenuButton") as BaseButton
	menu_button.pressed.emit()
	await physics_frame
	_expect(not bool(player.call("has_move_target")), "Opening the Fubo system menu must clear the click target.")
	fubo.queue_free()
	await process_frame


func _verify_sea_overworld_click_move() -> void:
	var sea := SEA_SCENE.instantiate()
	root.add_child(sea)
	await process_frame
	await physics_frame
	var player := sea.get_node("World/Player") as CharacterBody2D
	var has_contract := (
		player.has_method("request_move_to")
		and player.has_method("cancel_move_target")
		and player.has_method("has_move_target")
		and player.has_method("move_target")
	)
	_expect(has_contract, "Sea-overworld ship must expose the shared click-move target contract.")
	if not has_contract:
		sea.queue_free()
		await process_frame
		return

	player.global_position = Vector2(1800.0, 1200.0)
	var target := player.global_position + Vector2(90.0, 0.0)
	_send_world_click(player, target)
	_expect(bool(player.call("has_move_target")), "Sea-overworld ship must accept a left-click move target on open water.")
	_expect((player.call("move_target") as Vector2).distance_to(target) < 0.5, "Sea-overworld click coordinates must map to the intended world position.")
	await _wait_physics_frames(45)
	_expect(player.global_position.distance_to(target) <= 7.0, "Sea-overworld ship must sail to an unobstructed click target.")
	_expect(not bool(player.call("has_move_target")), "Sea-overworld ship must clear the target after arrival.")

	player.call("request_move_to", player.global_position + Vector2(160.0, 0.0))
	Input.action_press("move_left")
	await physics_frame
	Input.action_release("move_left")
	_expect(not bool(player.call("has_move_target")), "Keyboard sailing must cancel the sea-overworld click target.")

	var locked_position := player.global_position
	player.call("request_move_to", locked_position + Vector2(100.0, 0.0))
	player.set("controls_enabled", false)
	await physics_frame
	_expect(not bool(player.call("has_move_target")), "Disabling sea-overworld controls must clear the click target.")
	_expect(player.global_position.distance_to(locked_position) < 0.5, "Disabled sea-overworld controls must prevent click movement.")

	player.set("controls_enabled", true)
	player.global_position = Vector2(1800.0, 1200.0)
	var wall := StaticBody2D.new()
	wall.position = Vector2(1835.0, 1200.0)
	var wall_collision := CollisionShape2D.new()
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(10.0, 100.0)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	sea.add_child(wall)
	player.call("request_move_to", Vector2(1910.0, 1200.0))
	await _wait_physics_frames(55)
	_expect(player.global_position.x < wall.global_position.x, "Sea-overworld click movement must not pass through collision bodies.")
	_expect(not bool(player.call("has_move_target")), "A persistently blocked sea-overworld click target must be cleared.")
	sea.queue_free()
	await process_frame


func _send_world_click(receiver: Node, world_position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = root.get_viewport().get_canvas_transform() * world_position
	receiver.call("_unhandled_input", event)


func _wait_physics_frames(count: int) -> void:
	for _index in count:
		await physics_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
