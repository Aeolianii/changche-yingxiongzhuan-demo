extends SceneTree

# CHG-20260817：海盗战结算返回冒烟——胜利返回移除对应海盗（数减一）并回到战斗前船位；
# 失败/逃跑返回保留全部海盗，玩家在月环商港附近复活。
# headless 运行：godot --headless --script res://tests/test_sea_overworld_pirate_return.gd

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const RETURN_META := "sea_pirate_battle_return_context"
const MOON_HARBOR := Vector2(3650, 360)

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.remove_meta(RETURN_META)
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.call("reset_runtime_world_state")

	# ---- 胜利返回：移除对应海盗 + 回到战斗前船位 ----
	root.set_meta(RETURN_META, {
		"pirate_id": "PirateShip3",
		"outcome": 0,
		"player_position": [3000.0, 1500.0],
		"lunar_day": 6.5,
	})
	var victory_scene := SEA_SCENE.instantiate() as Node2D
	root.add_child(victory_scene)
	current_scene = victory_scene
	for _frame in range(6):
		await physics_frame
	await process_frame
	_expect((victory_scene.get("_pirates") as Array).size() == 4, "Victory return must remove the named pirate (count 5 -> 4).")
	var victory_player := victory_scene.get_node("World/Player") as Node2D
	_expect(victory_player.global_position.is_equal_approx(Vector2(3000, 1500)), "Victory return must restore the pre-battle ship position (got %s)." % victory_player.global_position)

	current_scene = null
	victory_scene.queue_free()
	await process_frame

	# ---- 失败/逃跑返回：保留全部海盗 + 玩家在月环商港附近复活 ----
	root.set_meta(RETURN_META, {"pirate_id": "PirateShip2", "outcome": 1})
	var defeat_scene := SEA_SCENE.instantiate() as Node2D
	root.add_child(defeat_scene)
	current_scene = defeat_scene
	for _frame in range(6):
		await physics_frame
	await process_frame
	_expect((defeat_scene.get("_pirates") as Array).size() == 5, "Defeat return must keep all five pirates.")
	var defeat_player := defeat_scene.get_node("World/Player") as Node2D
	# 复活点 = 月环商港坐标 (3650, 360)；物理模拟可能让船轻微漂移，按「商港附近」容差断言。
	_expect(defeat_player.global_position.distance_to(MOON_HARBOR) <= 40.0, "Defeat return must respawn the player near Moon-ring harbor (got %s)." % defeat_player.global_position)

	_finish(defeat_scene)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(scene: Node) -> void:
	current_scene = null
	if is_instance_valid(scene):
		scene.queue_free()
	if failures.is_empty():
		print("Sea-overworld pirate battle return verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
