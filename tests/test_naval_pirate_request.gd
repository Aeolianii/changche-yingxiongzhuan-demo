extends SceneTree

# CHG-20260817：海盗战请求 → NavalDemo 集成冒烟——场景根写海盗战请求 meta 后，
# NavalDeploymentController 消费并生成对应难度随机遭遇、登记海盗会话；
# 返回上下文保留发起方字段并补结算结果。headless 运行：
# godot --headless --script res://tests/test_naval_pirate_request.gd

const NAVAL_SCENE := preload("res://scenes/naval/NavalDemo.tscn")
const REQUEST_META := "sea_pirate_battle_request"
const RETURN_META := "sea_pirate_battle_return_context"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.remove_meta(REQUEST_META)
	root.remove_meta(RETURN_META)
	root.set_meta(REQUEST_META, {
		"pirate_id": "PirateShip4",
		"difficulty": 3,
		"player_position": [3000.0, 1500.0],
		"lunar_day": 6.5,
	})
	var demo := NAVAL_SCENE.instantiate()
	root.add_child(demo)
	current_scene = demo
	await process_frame
	await physics_frame

	var deploy := demo.get_node("Deployment")
	var controller := demo.get_node("Battle/BattleController")
	_check(bool(controller.call("PirateBattleActive")), "The pirate request meta must activate the pirate battle session.")
	_check(bool(deploy.call("RandomEncounterActive")), "The pirate battle must build a random encounter.")
	_check(int(deploy.call("RandomEncounterDifficulty")) == 3, "The encounter difficulty must match the request (expected 3).")
	_check(deploy.call("RandomEncounterPlayerFleetCount") > 0, "The encounter must carry a player fleet.")

	# 返回上下文：保留发起方字段（玩家位置/农历日/海盗 id）并补结算结果（未结算默认平局 outcome=2）。
	var context: Dictionary = controller.call("BuildPirateReturnContext")
	_check(str(context.get("pirate_id", "")) == "PirateShip4", "Return context must carry the pirate id.")
	_check(context.get("player_position") is Array, "Return context must preserve the pre-battle player position.")
	_check(is_equal_approx(float(context.get("lunar_day", -1.0)), 6.5), "Return context must preserve the lunar day.")
	_check(int(context.get("outcome", -1)) == 2, "Return context must default outcome to draw before a result is set.")

	_finish(demo)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(scene: Node) -> void:
	current_scene = null
	if is_instance_valid(scene):
		scene.queue_free()
	if failures.is_empty():
		print("Naval pirate request integration verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
