extends SceneTree

# CHG-20260819（S-2 海面接入）：讨伐战（海怪/营寨）请求 → NavalDemo 集成冒烟——场景根写讨伐请求 meta 后，
# NavalDeploymentController 消费并经 HuntEncounterGenerator.CreateStage 组装 hunt_stage 固定遭遇、
# 登记讨伐会话；返回上下文保留发起方字段并补结算结果。headless 运行：
# godot --headless --script res://tests/test_naval_hunt_request.gd

const NAVAL_SCENE := preload("res://scenes/naval/NavalDemo.tscn")
const REQUEST_META := "sea_hunt_battle_request"
const RETURN_META := "sea_hunt_battle_return_context"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.remove_meta(REQUEST_META)
	root.remove_meta(RETURN_META)
	root.set_meta(REQUEST_META, {
		"stage_id": "hunt_stage3",
		"player_position": [4380.0, 2460.0],
		"lunar_day": 3.0,
	})
	var demo := NAVAL_SCENE.instantiate()
	root.add_child(demo)
	current_scene = demo
	await process_frame
	await physics_frame

	var deploy := demo.get_node("Deployment")
	var controller := demo.get_node("Battle/BattleController")
	_check(bool(controller.call("HuntBattleActive")), "The hunt request meta must activate the hunt battle session.")
	_check(str(controller.call("HuntBattleStageId")) == "hunt_stage3", "The hunt session must carry the stage id (expected hunt_stage3).")
	_check(bool(deploy.call("RandomEncounterActive")), "The hunt battle must build a random encounter.")
	_check(str(deploy.call("RandomEncounterEnemyLabel")) == "倭寇大本营", "The encounter must resolve the wokou stronghold enemy config.")
	_check(deploy.call("RandomEncounterPlayerFleetCount") > 0, "The encounter must carry a player fleet.")

	# 返回上下文：保留发起方字段（玩家位置/农历日/阶段 id）并补结算结果（未结算默认平局 outcome=2）。
	var context: Dictionary = controller.call("BuildHuntReturnContext")
	_check(str(context.get("stage_id", "")) == "hunt_stage3", "Return context must carry the hunt stage id.")
	_check(context.get("player_position") is Array, "Return context must preserve the pre-battle player position.")
	_check(is_equal_approx(float(context.get("lunar_day", -1.0)), 3.0), "Return context must preserve the lunar day.")
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
		print("Naval hunt request integration verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
