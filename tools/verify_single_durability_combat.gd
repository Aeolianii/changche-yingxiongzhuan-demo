extends SceneTree

var failures := 0


func _init() -> void:
	var battle_script = load("res://scripts/tactics/tactics_battle.gd")
	_check(battle_script != null, "battle script loads")
	if battle_script != null:
		var battle = battle_script.new()
		var fast: Dictionary = battle.get_ship("player_1")
		var gunship: Dictionary = battle.get_ship("player_2")
		_check(fast.has("hp") and fast.has("max_hp"), "fast ship exposes one durability pool")
		_check(gunship.has("hp") and gunship.has("max_hp"), "gunship exposes one durability pool")
		_check(not fast.has("hull") and not fast.has("sail") and not fast.has("rudder"), "legacy module health is absent")
		_check(int(fast.get("hp", -1)) == 50 and int(gunship.get("hp", -1)) == 70, "class durability values are exact")
		_check(_max_path_length(battle.legal_sailing_paths("player_1")) == 3, "fast ship moves three cells")
		_check(_max_path_length(battle.legal_sailing_paths("player_2")) == 2, "gunship moves two cells")
		_check(battle.available_actions("player_1").has("disrupt"), "fast ship owns disrupt shot")
		_check(not battle.available_actions("player_1").has("chain"), "chain-shot action name is retired")
		_check(battle.has_method("can_disrupt") and battle.has_method("fire_disrupt"), "battle exposes disrupt-shot commands")
		if battle.has_method("can_disrupt"):
			battle.ships["player_1"]["cell"] = Vector2i(4, 4)
			battle.ships["player_1"]["facing"] = 0
			battle.ships["enemy_1"]["cell"] = Vector2i(4, 2)
			var disrupt: Dictionary = battle.fire_disrupt("player_1", "enemy_1")
			_check(disrupt.get("ok", false) and int(disrupt.get("damage", 0)) == 8, "disrupt shot deals eight durability damage")
			_check(int(battle.get_ship("enemy_1").get("hp", 0)) == 42, "disrupt shot changes only durability")
		battle.reset()
		battle.ships["player_2"]["cell"] = Vector2i(4, 4)
		battle.ships["player_2"]["facing"] = 0
		battle.ships["enemy_1"]["cell"] = Vector2i(4, 2)
		var broadside: Dictionary = battle.fire("player_2", "enemy_1", "port")
		_check(broadside.get("ok", false) and int(broadside.get("damage", 0)) == 18, "ordinary broadside deals eighteen durability damage")
		_check(int(battle.get_ship("enemy_1").get("hp", 0)) == 32, "broadside changes only durability")

	var state_script = load("res://scripts/campaign/official_campaign_state.gd")
	_check(state_script != null, "campaign state loads")
	if state_script != null:
		var state = state_script.new()
		var ship: Dictionary = state.ships.get("player_1", {})
		_check(ship.has("hp") and ship.has("max_hp"), "campaign ship persists one durability pool")
		_check(ship.has("durability_level") and ship.has("weapon_level"), "campaign exposes exactly the two upgrade tracks")
		_check(not ship.has("hull") and not ship.has("sail") and not ship.has("rudder"), "campaign removes legacy module health")
		_check(int(state.to_save_data().get("version", 0)) == 2, "single-durability save schema is version two")

	print("VERIFY_FAILURES=%d" % failures)
	quit(1 if failures > 0 else 0)


func _max_path_length(paths: Array) -> int:
	var result := 0
	for path_value in paths:
		var path: Dictionary = path_value
		result = maxi(result, path.get("cells", []).size())
	return result


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		printerr("FAIL: %s" % label)
