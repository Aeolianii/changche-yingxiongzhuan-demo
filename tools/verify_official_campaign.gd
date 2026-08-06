extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var state_script := load("res://scripts/campaign/official_campaign_state.gd")
	_check(state_script != null, "campaign state script exists")
	if state_script == null:
		_finish()
		return
	_test_state(state_script)
	_test_injection(state_script)
	await _test_battle_controller(state_script)
	await _test_campaign_scene()
	_finish()


func _test_state(state_script) -> void:
	var state = state_script.new()
	_check(state.rank_id == "trainee" and state.rank_name() == "见习水勇", "fresh career starts at the official trainee rank")
	_check(state.pay == 180 and state.merit == 0 and state.orders().size() == 3, "fresh career exposes exact resources and three orders")
	_check(state.ships["player_1"].hp == 50 and state.ships["player_2"].hp == 70, "official ships use exact class durability")
	_check(not state.ships["player_1"].has("hull") and state.ships["player_1"].durability_level == 0, "campaign persists one durability pool")
	_check(state.select_order("coast_patrol").get("ok", false), "valid order can be selected")
	_check(not state.select_order("missing").get("ok", true) and state.active_order_id == "coast_patrol", "invalid order is rejected atomically")
	var exported: Dictionary = state.battle_fleet_state()
	exported["player_1"].hp = 1
	_check(state.ships["player_1"].hp == 50, "battle export is a deep copy")
	var battle_ships: Dictionary = state.battle_fleet_state()
	battle_ships["player_1"].hp = 31
	battle_ships["player_2"].hp = 52
	var victory: Dictionary = state.resolve_battle("victory", battle_ships)
	_check(victory.get("pay_awarded", 0) == 90 and victory.get("merit_awarded", 0) == 10, "victory awards the selected order")
	_check(state.ships["player_1"].hp == 31 and state.ships["player_2"].hp == 52, "victory carries durability damage home")

	var defeated = state_script.new()
	defeated.select_order("coast_patrol")
	var sunk: Dictionary = defeated.battle_fleet_state()
	sunk["player_1"].hp = 0
	sunk["player_2"].hp = 0
	defeated.resolve_battle("defeat", sunk)
	_check(defeated.pay == 225 and defeated.ships["player_1"].hp == 25 and defeated.ships["player_2"].hp == 35, "defeat grants emergency pay and half durability")

	var repair_state = state_script.new()
	repair_state.ships["player_1"].hp = 39
	_check(repair_state.repair_quote("player_1") == 6, "repair quote is half missing durability rounded up")
	repair_state.pay = 6
	_check(repair_state.repair_ship("player_1").get("ok", false) and repair_state.ships["player_1"].hp == 50 and repair_state.pay == 0, "repair restores durability for the exact quote")

	var upgraded = state_script.new()
	upgraded.pay = 300
	_check(upgraded.upgrade_ship("player_1", "durability").get("ok", false) and upgraded.ships["player_1"].max_hp == 56, "durability upgrade adds six HP")
	_check(upgraded.upgrade_ship("player_1", "weapon").get("ok", false) and upgraded.ships["player_1"].weapon_level == 1, "weapon upgrade records one level")
	var pay_before: int = int(upgraded.pay)
	_check(not upgraded.upgrade_ship("player_1", "weapon").get("ok", true) and upgraded.pay == pay_before, "repeat upgrade spends nothing")
	_check(not upgraded.upgrade_ship("player_1", "hull").get("ok", true), "removed module upgrade is rejected")

	var promoted = state_script.new()
	for _index in 3:
		promoted.select_order("coast_patrol")
		promoted.resolve_battle("victory", promoted.battle_fleet_state())
	_check(promoted.merit == 30 and promoted.rank_id == "squad_leader", "thirty merit promotes the player")

	upgraded.select_order("beacon_defense")
	upgraded.ships["player_1"].hp = 43
	var save_data: Dictionary = upgraded.to_save_data()
	var loaded = state_script.new()
	_check(save_data.version == 2 and loaded.load_save_data(save_data).get("ok", false), "version-two save round-trip succeeds")
	_check(loaded.ships == upgraded.ships and typeof(loaded.ships["player_1"].hp) == TYPE_INT, "save restores exact integer durability state")
	var snapshot: Dictionary = loaded.to_save_data()
	_check(not loaded.load_save_data({"version": 1}).get("ok", true) and loaded.to_save_data() == snapshot, "old module save is rejected without mutation")


func _test_injection(state_script) -> void:
	var battle_script := load("res://scripts/tactics/tactics_battle.gd")
	_check(battle_script != null, "battle script remains available")
	if battle_script == null:
		return
	var state = state_script.new()
	state.pay = 300
	state.upgrade_ship("player_1", "durability")
	state.upgrade_ship("player_1", "weapon")
	state.upgrade_ship("player_2", "weapon")
	state.ships["player_1"].hp = 37
	state.ships["player_2"].hp = 48
	var battle = battle_script.new()
	var enemy_before: Dictionary = battle.get_ship("enemy_1").duplicate(true)
	_check(battle.apply_player_fleet_state(state.battle_fleet_state()).get("ok", false), "battle accepts campaign fleet state")
	_check(battle.get_ship("player_1").max_hp == 56 and battle.get_ship("player_1").hp == 37, "battle receives upgraded persistent durability")
	_check(battle.get_ship("player_1").disrupt_damage == 10 and battle.get_ship("player_2").broadside_damage == 20, "weapon upgrades affect class-owned damage")
	_check(battle.get_ship("enemy_1") == enemy_before, "campaign injection leaves enemy baseline untouched")


func _test_battle_controller(state_script) -> void:
	var scene: PackedScene = load("res://scenes/naval_tactics.tscn")
	_check(scene != null, "naval tactics scene loads")
	if scene == null:
		return
	var controller = scene.instantiate()
	root.add_child(controller)
	await process_frame
	var state = state_script.new()
	state.ships["player_1"].hp = 41
	_check(controller.start_campaign_mission("beacon", state.battle_fleet_state()).get("ok", false), "campaign battle starts")
	_check(controller.battle.get_ship("player_1").hp == 41 and not controller.mission_panel.visible, "campaign injects durability and bypasses picker")
	controller.selected_ship_id = "player_2"
	controller.action_mode = "port"
	var range_cells: Dictionary = controller._attack_range_cells()
	_check(not range_cells.is_empty(), "attack action exposes a visible theoretical range")
	controller._handle_cell_click(Vector2i(4, 4))
	_check("没有敌船" in controller._feedback_text, "empty attack click explains why nothing happened")
	var payloads: Array[Dictionary] = []
	controller.campaign_battle_finished.connect(func(payload: Dictionary) -> void: payloads.append(payload))
	controller.battle.result = "victory"
	controller._sync_all()
	await process_frame
	await process_frame
	_check(payloads.size() == 1 and payloads[0]["ships"].size() == 2, "campaign emits one player-only settlement payload")
	controller.queue_free()
	await process_frame


func _test_campaign_scene() -> void:
	_check(ProjectSettings.get_setting("application/run/main_scene", "") == "res://scenes/official_campaign.tscn", "official campaign is startup scene")
	var scene: PackedScene = load("res://scenes/official_campaign.tscn")
	_check(scene != null, "official campaign scene exists")
	if scene == null:
		return
	var campaign = scene.instantiate()
	campaign.disable_save_for_test = true
	root.add_child(campaign)
	await process_frame
	_check(campaign.facility_buttons.size() == 3 and campaign.ship_cards.size() == 2, "water camp exposes three facilities and two ships")
	_check(_tree_contains_text(campaign, "耐久") and not _tree_contains_text(campaign, "船帆"), "water camp uses one durability presentation")
	campaign.show_facility_for_test("shipyard")
	_check(_tree_contains_text(campaign, "耐久 +6") and _tree_contains_text(campaign, "武备 +2"), "shipyard exposes only durability and weapon growth")
	campaign.show_facility_for_test("command")
	campaign.select_order_for_test("coast_patrol")
	var battle_node = campaign.launch_selected_order_for_test()
	_check(battle_node != null and battle_node.campaign_mode, "departure creates campaign battle")
	battle_node.battle.ships["player_1"].hp = 33
	battle_node.battle.result = "victory"
	battle_node._sync_all()
	await process_frame
	await process_frame
	_check(campaign.active_battle == null and campaign.state.ships["player_1"].hp == 33, "settlement returns persistent durability to camp")
	campaign.queue_free()
	await process_frame


func _tree_contains_text(node: Node, wanted: String) -> bool:
	if node is Label or node is Button or node is RichTextLabel:
		if wanted in str(node.get("text")):
			return true
	for child in node.get_children():
		if _tree_contains_text(child, wanted):
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures.append(label)
		printerr("FAIL: %s" % label)


func _finish() -> void:
	print("VERIFY_FAILURES=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)
