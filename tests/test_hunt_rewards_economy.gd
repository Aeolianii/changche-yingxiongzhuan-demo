extends SceneTree

# CHG-20260819（F-1 讨伐战利品进背包）：讨伐战（海怪/营寨）胜利后，金/铁/木/麻 + 专属饰品
# 写入玩家 economy_state（金→军饷、铁/木/麻→物品、饰品→accessories.owned）。headless 运行：
# godot --headless --script res://tests/test_hunt_rewards_economy.gd

const NAVAL_SCENE := preload("res://scenes/naval/NavalDemo.tscn")
const REQUEST_META := "sea_hunt_battle_request"
const RETURN_META := "sea_hunt_battle_return_context"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_runtime_world_state")
	# 营寨战（hunt_stage3）：金4000 铁8 木12 麻8 + 倭寇军旗。
	var economy: Dictionary = game_state.call("get_economy_state")
	var before_pay := int(economy.get("pay", 0))
	var before_items := economy.get("items", {}) as Dictionary
	var before_owned := (economy.get("accessories", {}) as Dictionary).get("owned", []) as Array

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
	_check(bool(controller.call("HuntBattleActive")), "The hunt request must activate the hunt battle session.")
	_check(bool(deploy.call("RandomEncounterActive")), "The hunt battle must build a random encounter.")
	# 开战：headless 下布阵不自动 Confirm（仅关卡模式自动），手动确认进入战斗。
	var confirm_err := str(deploy.call("ConfirmDeployment"))
	_check(confirm_err.is_empty(), "Confirming the hunt deployment must succeed (err: %s)." % confirm_err)
	await process_frame
	_check(not bool(controller.call("BattleEnded")), "The hunt battle must be live after deployment.")
	_check(bool(controller.call("HuntBattleActive")), "The hunt session must remain active during battle.")

	# 一键胜利：敌方 HP 置 0 → 真实终局 → HandleBattleEnded → GrantHuntRewards（玩家胜利）。
	controller.call("ForceBattleEndForDemo")
	await process_frame
	await process_frame
	_check(bool(controller.call("BattleEnded")), "Forcing a battle end must settle the hunt battle.")
	_check(int(controller.call("ResultOutcome")) == 0, "Sinking all enemies must yield a player victory.")

	# 返回上下文：outcome 0 写入（BuildHuntReturnContext）。
	var context: Dictionary = controller.call("BuildHuntReturnContext")
	_check(int(context.get("outcome", -1)) == 0, "The return context must record the player victory.")

	# 经济奖励：金 +4000；铁/木/麻 入物品；军旗饰品入背包。
	var after: Dictionary = game_state.call("get_economy_state")
	_check(int(after.get("pay", 0)) == before_pay + 4000, "Wokou stronghold victory must grant 4000 military pay (got %d)." % int(after.get("pay", 0)))
	var items := after.get("items", {}) as Dictionary
	_check(int(items.get("ironstone", 0)) == int(before_items.get("ironstone", 0)) + 8, "Victory must grant 8 ironstone.")
	_check(int(items.get("wood", 0)) == int(before_items.get("wood", 0)) + 12, "Victory must grant 12 wood.")
	_check(int(items.get("hemp", 0)) == 8, "Victory must grant 8 hemp into the item catalog.")
	var owned := (after.get("accessories", {}) as Dictionary).get("owned", []) as Array
	_check("wokou_banner" in owned and before_owned.find("wokou_banner") == -1, "Victory must add the wokou banner accessory to the backpack.")
	_check(bool(game_state.call("has_economy_accessory", "wokou_banner")), "GameState must confirm the wokou banner accessory.")

	_finish(demo, game_state)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(scene: Node, game_state: Node) -> void:
	current_scene = null
	if is_instance_valid(scene):
		scene.queue_free()
	await process_frame
	game_state.call("reset_runtime_world_state")
	if failures.is_empty():
		print("Hunt rewards economy verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
