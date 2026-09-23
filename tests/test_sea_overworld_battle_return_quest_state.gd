extends SceneTree

# 已确认倭寇营地警告后，海盗战和海怪讨伐战切场返回都不能重播该对话。
# godot --headless --script res://tests/test_sea_overworld_battle_return_quest_state.gd

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const PIRATE_RETURN_META := "sea_pirate_battle_return_context"
const HUNT_RETURN_META := "sea_hunt_battle_return_context"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_runtime_world_state")
	var cases: Array[Dictionary] = [
		{"name": "pirate victory", "meta": PIRATE_RETURN_META, "context": {
			"pirate_id": "PirateShip3", "outcome": 0, "player_position": [3000.0, 1500.0],
		}},
		{"name": "pirate defeat", "meta": PIRATE_RETURN_META, "context": {
			"pirate_id": "PirateShip2", "outcome": 1,
		}},
		{"name": "sea monster defeat", "meta": HUNT_RETURN_META, "context": {
			"stage_id": "hunt_stage1", "outcome": 1,
		}},
	]
	for battle_case in cases:
		root.remove_meta(PIRATE_RETURN_META)
		root.remove_meta(HUNT_RETURN_META)
		game_state.call("set_sea_main_quest_state", 4, true, false)
		root.set_meta(str(battle_case["meta"]), battle_case["context"])
		var scene := SEA_SCENE.instantiate() as Node2D
		root.add_child(scene)
		current_scene = scene
		await process_frame
		await physics_frame
		var label := str(battle_case["name"])
		_expect(bool(scene.get("_wokou_warning_acknowledged")), "%s must retain the acknowledged warning." % label)
		_expect(scene.get_node_or_null("World/WorldMarkers/WokouStrongholdWarningTrigger") == null, "%s must remove the used warning trigger." % label)
		var state := game_state.call("get_sea_main_quest_state") as Dictionary
		_expect(bool(state.get("wokou_warning_acknowledged", false)), "%s must not overwrite the saved warning flag." % label)
		_expect(not bool(state.get("wokou_battle_completed", false)), "%s must not complete the Wokou battle." % label)
		var hud := root.get_node("ExplorationUI/HUD") as Control
		var task_name := hud.get_node("QuestTracker/MainQuest/TaskName") as Label
		_expect(task_name.text == "讨伐倭寇", "%s must retain the campaign task." % label)
		scene.call("_open_wokou_warning_dialogue")
		var dialogue := scene.get("_event_dialogue") as FieldEventDialogue
		_expect("前方已近倭寇营地" not in dialogue.dialogue_label.text, "%s must not replay the Wokou warning dialogue." % label)
		current_scene = null
		scene.queue_free()
		await process_frame
	root.remove_meta(PIRATE_RETURN_META)
	root.remove_meta(HUNT_RETURN_META)
	if failures.is_empty():
		print("Sea-overworld battle return quest-state verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
