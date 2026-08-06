extends SceneTree

const BattleScript = preload("res://scripts/tactics_v3/target_tactics_battle.gd")
const AIScript = preload("res://scripts/tactics_v3/target_tactics_ai.gd")

var failures := 0


func _init() -> void:
	_verify_setup_and_maneuvers()
	_verify_activation_order()
	_verify_class_actions()
	_verify_protection_and_ram()
	_verify_objective_and_results()
	_verify_ai_full_match()
	_verify_scene_contract()
	_verify_controller_interaction()
	print("VERIFY_FAILURES=%d" % failures)
	quit(1 if failures > 0 else 0)


func _verify_setup_and_maneuvers() -> void:
	var battle = BattleScript.new()
	_check(battle.ships.size() == 6, "target battle creates symmetric 3v3 fleets")
	_check(battle.living_ship_ids(0).size() == 3 and battle.living_ship_ids(1).size() == 3, "both teams start with three living ships")
	_check(battle.beacons == [Vector2i(5, 2), Vector2i(6, 5)], "double-beacon cells are exact")
	for class_id in ["fast", "gunship", "escort"]:
		var player: Dictionary = battle.get_ship("player_%s" % class_id)
		var enemy: Dictionary = battle.get_ship("enemy_%s" % class_id)
		_check(player["class_id"] == enemy["class_id"], "%s class is shared by both factions" % class_id)
		_check(player["hp"] == enemy["hp"] and player["move_range"] == enemy["move_range"], "%s stats are symmetric" % class_id)
	_check(int(battle.get_ship("player_fast")["hp"]) == 50 and int(battle.get_ship("player_fast")["move_range"]) == 3, "fast baseline is 50 HP and move three")
	_check(int(battle.get_ship("player_gunship")["hp"]) == 70 and int(battle.get_ship("player_gunship")["move_range"]) == 2, "gunship baseline is 70 HP and move two")
	_check(int(battle.get_ship("player_escort")["hp"]) == 85 and int(battle.get_ship("player_escort")["move_range"]) == 2, "escort baseline is 85 HP and move two")
	var maneuvers := battle.legal_maneuvers("player_fast")
	_check(_has_maneuver_kind(maneuvers, "wait"), "maneuvers include steady wait")
	_check(_has_maneuver_kind(maneuvers, "turn"), "maneuvers include 45/90-degree pivots")
	_check(_has_maneuver_kind(maneuvers, "reverse"), "maneuvers include one-cell reverse")
	_check(_has_maneuver_kind(maneuvers, "sail_turn"), "maneuvers include one 45-degree sailing turn")
	_check(_max_path_length(maneuvers) == 3, "fast legal sailing reaches exactly three cells")


func _verify_activation_order() -> void:
	var battle = BattleScript.new()
	_check(battle.active_team == 0, "official fleet is public first side")
	_check(battle.begin_activation("player_fast").get("ok", false), "player can begin one unactivated ship")
	_check(not battle.begin_activation("player_gunship").get("ok", false), "second friendly ship cannot begin during an activation")
	_check(_execute_wait(battle, "player_fast"), "active ship can commit wait maneuver")
	var first_end: Dictionary = battle.execute_combat_action("player_fast", "end_activation")
	_check(first_end.get("ok", false) and battle.active_team == 1, "ending friendly activation hands control to enemy")
	_check(not battle.execute_combat_action("player_fast", "brace").get("ok", false), "completed ship cannot use a second combat order")
	_check(battle.begin_activation("enemy_fast").get("ok", false), "enemy begins exactly one responding activation")
	_check(_execute_wait(battle, "enemy_fast"), "enemy commits its maneuver through same interface")
	battle.execute_combat_action("enemy_fast", "end_activation")
	_check(battle.active_team == 0, "control returns after one enemy activation")

	for ship_id in ["player_gunship", "enemy_gunship", "player_escort", "enemy_escort"]:
		_check(battle.begin_activation(ship_id).get("ok", false), "%s activates in alternating order" % ship_id)
		_check(_execute_wait(battle, ship_id), "%s can wait" % ship_id)
		battle.execute_combat_action(ship_id, "end_activation")
	_check(battle.round_number == 2 and battle.active_team == 0, "new round increments and restores official first side")
	_check(battle.unactivated_ship_ids(0).size() == 3 and battle.unactivated_ship_ids(1).size() == 3, "new round refreshes all living activations")


func _verify_class_actions() -> void:
	var battle = BattleScript.new()
	_check(battle.available_combat_actions("player_fast").has("disrupt") and battle.available_combat_actions("player_fast").has("ram"), "fast ship owns disrupt and ram")
	_check(battle.available_combat_actions("player_gunship").has("broadside_port") and battle.available_combat_actions("player_gunship").has("broadside_starboard"), "gunship owns explicit port and starboard broadsides")
	_check(battle.available_combat_actions("player_escort").has("short_cannon") and battle.available_combat_actions("player_escort").has("guard"), "escort owns short cannon and guard")

	battle.ships["player_fast"]["cell"] = Vector2i(4, 4)
	battle.ships["player_fast"]["facing"] = 0
	battle.ships["enemy_fast"]["cell"] = Vector2i(4, 2)
	battle.begin_activation("player_fast")
	_execute_wait(battle, "player_fast")
	var disrupt: Dictionary = battle.execute_combat_action("player_fast", "disrupt", "enemy_fast")
	_check(disrupt.get("ok", false) and int(disrupt.get("damage", 0)) == 8, "disrupt deals exact eight damage")
	_check(int(battle.get_ship("enemy_fast")["destabilized_by_team"]) == 0, "surviving disrupt target is destabilized for attacker team")
	_check(bool(battle.get_ship("enemy_fast").get("suppressed", false)), "effective damage suppresses a surviving target for beacon scoring")

	battle = BattleScript.new()
	battle.ships["player_gunship"]["cell"] = Vector2i(4, 4)
	battle.ships["player_gunship"]["facing"] = 0
	battle.ships["enemy_fast"]["cell"] = Vector2i(4, 2)
	battle.ships["enemy_fast"]["destabilized_by_team"] = 0
	battle.begin_activation("player_gunship")
	_execute_wait(battle, "player_gunship")
	var coordinated: Dictionary = battle.execute_combat_action("player_gunship", "broadside_port", "enemy_fast")
	_check(coordinated.get("ok", false) and int(coordinated.get("damage", 0)) == 24, "coordinated broadside deals 18 plus six")
	_check(int(battle.get_ship("enemy_fast")["destabilized_by_team"]) == -1, "coordinated broadside consumes destabilized")

	battle = BattleScript.new()
	battle.ships["player_gunship"]["cell"] = Vector2i(4, 4)
	battle.ships["player_gunship"]["facing"] = 0
	battle.ships["enemy_fast"]["cell"] = Vector2i(4, 2)
	battle.ships["enemy_fast"]["facing"] = 6
	battle.begin_activation("player_gunship")
	_execute_wait(battle, "player_gunship")
	var stern: Dictionary = battle.execute_combat_action("player_gunship", "broadside_port", "enemy_fast")
	_check(stern.get("ok", false) and int(stern.get("damage", 0)) == 24 and int(stern.get("stern_bonus", 0)) == 6, "stern broadside adds exact six damage")

	battle = BattleScript.new()
	battle.ships["player_escort"]["cell"] = Vector2i(4, 4)
	battle.ships["player_escort"]["facing"] = 0
	battle.ships["enemy_fast"]["cell"] = Vector2i(4, 2)
	battle.begin_activation("player_escort")
	_execute_wait(battle, "player_escort")
	var short_hit: Dictionary = battle.execute_combat_action("player_escort", "short_cannon", "enemy_fast")
	_check(short_hit.get("ok", false) and int(short_hit.get("damage", 0)) == 12, "escort short cannon deals exact twelve damage")
	_check(battle.theoretical_range_cells("player_gunship", "broadside_port").size() > 0, "battle exposes theoretical broadside range cells")


func _verify_protection_and_ram() -> void:
	var battle = BattleScript.new()
	battle.ships["player_escort"]["cell"] = Vector2i(2, 3)
	battle.ships["player_fast"]["cell"] = Vector2i(3, 3)
	battle.ships["enemy_gunship"]["cell"] = Vector2i(3, 1)
	battle.ships["enemy_gunship"]["facing"] = 4
	battle.begin_activation("player_escort")
	_execute_wait(battle, "player_escort")
	var guard: Dictionary = battle.execute_combat_action("player_escort", "guard", "player_fast")
	_check(guard.get("ok", false) and battle.get_ship("player_fast")["guard_source"] == "player_escort", "escort applies guard to nearby ally")
	battle.begin_activation("enemy_gunship")
	_execute_wait(battle, "enemy_gunship")
	var guarded_hit: Dictionary = battle.execute_combat_action("enemy_gunship", "broadside_port", "player_fast")
	_check(guarded_hit.get("ok", false) and int(guarded_hit.get("reduction", 0)) == 8 and int(guarded_hit.get("damage", 0)) == 10, "guard reduces one broadside by eight")
	_check(str(battle.get_ship("player_fast")["guard_source"]) == "", "guard is consumed by protected hit")

	battle = BattleScript.new()
	battle.ships["player_fast"]["cell"] = Vector2i(3, 1)
	battle.ships["player_fast"]["facing"] = 0
	battle.ships["enemy_fast"]["cell"] = Vector2i(4, 1)
	battle.begin_activation("player_fast")
	_execute_wait(battle, "player_fast")
	var ram: Dictionary = battle.execute_combat_action("player_fast", "ram", "enemy_fast")
	_check(ram.get("ok", false) and int(ram.get("damage", 0)) == 12 and int(ram.get("self_damage", 0)) == 5, "ram deals twelve target and five self damage")
	_check(battle.get_ship("enemy_fast")["cell"] == Vector2i(5, 1), "ram pushes target one open cell")


func _verify_objective_and_results() -> void:
	var battle = BattleScript.new()
	battle.ships["player_fast"]["cell"] = battle.beacons[0]
	battle.ships["enemy_fast"]["cell"] = battle.beacons[1]
	battle._finish_round()
	_check(battle.beacon_score == {0: 1, 1: 1}, "each solely occupied beacon scores exactly one")
	_check(battle.round_number == 2 and battle.active_team == 0, "scored round advances with official first side")

	battle = BattleScript.new()
	battle.ships["player_fast"]["cell"] = battle.beacons[0]
	battle.ships["player_fast"]["suppressed"] = true
	battle.ships["enemy_fast"]["cell"] = battle.beacons[1]
	battle._finish_round()
	_check(battle.beacon_score == {0: 0, 1: 1}, "suppressed beacon occupant contributes no score")
	_check(not bool(battle.get_ship("player_fast").get("suppressed", true)), "beacon suppression clears after round scoring")

	battle = BattleScript.new()
	battle.beacon_score = {0: 4, 1: 2}
	battle.ships["player_fast"]["cell"] = battle.beacons[0]
	battle._finish_round()
	_check(battle.result == "victory" and int(battle.beacon_score[0]) == 5, "first side reaching five beacon points wins")

	battle = BattleScript.new()
	battle.round_number = 6
	battle.beacon_score = {0: 2, 1: 2}
	battle._finish_round()
	_check(battle.result == "draw", "equal score after round six draws")


func _verify_ai_full_match() -> void:
	var first := _run_public_ai_match()
	var second := _run_public_ai_match()
	_check(first == second, "public-state AI match is deterministic")
	_check(str(first.get("result", "")) in ["victory", "defeat", "draw"], "AI-versus-AI target match reaches a legal result")
	_check(int(first.get("activations", 0)) <= 36, "full target match respects six rounds and six activations per round")
	var battle = BattleScript.new()
	var ai = AIScript.new()
	var fast: Dictionary = battle.get_ship("enemy_fast")
	fast["cell"] = battle.beacons[0]
	var unsuppressed_score := ai._position_score(battle, fast, {"action": "end_activation", "target_id": ""})
	fast["suppressed"] = true
	var suppressed_score := ai._position_score(battle, fast, {"action": "end_activation", "target_id": ""})
	_check(suppressed_score < unsuppressed_score, "public-state AI does not value a suppressed beacon occupant as scoring control")
	_check(not AIScript.new().get_property_list().any(func(property: Dictionary) -> bool: return "intent" in str(property.get("name", "")).to_lower()), "AI exposes no intent property")


func _verify_scene_contract() -> void:
	var scene_script = load("res://scripts/tactics_v3/target_tactics_controller.gd")
	var ai_script = load("res://scripts/tactics_v3/target_tactics_ai.gd")
	var packed = load("res://scenes/naval_tactics_v3.tscn") as PackedScene
	var water_texture := load("res://assets/sprites/naval_tactics/water_tile.png") as Texture2D
	var controller_source := FileAccess.get_file_as_string("res://scripts/tactics_v3/target_tactics_controller.gd")
	_check(scene_script != null, "target tactics controller script loads")
	_check(ai_script != null, "target tactics AI script loads")
	_check(packed != null, "target tactics scene loads")
	_check(water_texture != null, "target scene owns the selected Kenney water tile")
	_check("WATER_TEXTURE" in controller_source and "draw_texture_rect(WATER_TEXTURE" in controller_source, "target controller draws authored water below tactical overlays")
	if packed != null:
		var scene = packed.instantiate()
		root.add_child(scene)
		if scene.friendly_entries.is_empty():
			scene._ready()
		_check(scene.battle.ships.size() == 6, "target scene owns six-ship battle model")
		_check(scene.get_node_or_null("NavalCombatPresentation") != null, "target scene restores the shared naval combat presentation helper")
		_check(scene.has_method("reset_battle") and scene.has_method("perform_player_wait_for_test"), "target scene exposes restart and focused test helper")
		_check(scene.friendly_entries.size() == 3 and scene.enemy_entries.size() == 3, "target HUD separates three friendly and three enemy cards")
		_check(scene.action_box.get_child_count() == 7, "fresh friendly selection shows seven maneuver choices")
		scene.battle.ships["player_fast"]["suppressed"] = true
		_check("受压制" in scene._status_text(scene.battle.get_ship("player_fast")), "target HUD names public beacon suppression on ship status")
		_check("受压制" in scene.objective_label.text, "objective summary explains suppression scoring rule")
		scene.queue_free()


func _verify_controller_interaction() -> void:
	var packed = load("res://scenes/naval_tactics_v3.tscn") as PackedScene
	if packed == null:
		_check(false, "controller interaction scene is available")
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	if scene.friendly_entries.is_empty():
		scene._ready()
	# This focused contract test is intentionally synchronous. Runtime coverage
	# below verifies the real completion-driven animation and input lock.
	scene.presentation.presentation_speed = 0.0
	scene._on_action_pressed("sail")
	_check(scene.action_mode == "sail" and scene._reachable_destinations("player_fast").size() > 0, "sail button enters reachable-cell preview")
	scene._handle_cell_click(Vector2i(2, 1))
	_check(scene.battle.active_ship_id == "player_fast" and scene.battle.maneuver_done, "clicking reachable cell commits player maneuver")
	_check(scene.battle.get_ship("player_fast")["cell"] == Vector2i(2, 1), "controller sends exact destination to battle model")
	_check(scene.action_box.get_child_count() == 4, "completed fast maneuver switches bar to two class actions, brace, and end")
	scene._on_action_pressed("disrupt")
	_check(scene.action_mode == "disrupt" and scene.battle.theoretical_range_cells("player_fast", "disrupt").size() > 0, "disrupt button exposes theoretical range")
	scene._handle_cell_click(Vector2i(3, 2))
	_check("没有" in scene._feedback_text and scene.battle.active_ship_id == "player_fast", "empty attack click explains rejection without ending activation")
	scene.reset_battle()
	scene._inspect_enemy("enemy_fast")
	_check(scene.action_box.get_child_count() == 0, "enemy inspection exposes no command ownership")
	scene._select_friendly("player_escort")
	_check(scene.action_box.get_child_count() == 7, "returning to friendly selection restores maneuver choices")
	scene.queue_free()


func _run_public_ai_match() -> Dictionary:
	var battle = BattleScript.new()
	var ai = AIScript.new()
	var activations := 0
	while battle.result == "" and activations < 40:
		var ship_id: String = ai.choose_ship(battle)
		if ship_id == "" or not battle.begin_activation(ship_id).get("ok", false):
			break
		var maneuver: Dictionary = ai.choose_maneuver(battle, ship_id)
		if not battle.execute_maneuver(ship_id, maneuver).get("ok", false):
			break
		var combat: Dictionary = ai.choose_combat(battle, ship_id)
		battle.execute_combat_action(ship_id, str(combat.get("action", "end_activation")), str(combat.get("target_id", "")))
		activations += 1
	var hp := {0: 0, 1: 0}
	for ship_id in battle.ships:
		var ship: Dictionary = battle.get_ship(ship_id)
		hp[int(ship["team"])] = int(hp[int(ship["team"])]) + int(ship["hp"])
	return {
		"result": battle.result,
		"score": battle.beacon_score.duplicate(),
		"round": battle.round_number,
		"hp": hp,
		"activations": activations,
	}


func _execute_wait(battle, ship_id: String) -> bool:
	for command_value in battle.legal_maneuvers(ship_id):
		var command: Dictionary = command_value
		if command.get("kind", "") == "wait":
			return bool(battle.execute_maneuver(ship_id, command).get("ok", false))
	return false


func _has_maneuver_kind(maneuvers: Array, kind: String) -> bool:
	for maneuver_value in maneuvers:
		if str(maneuver_value.get("kind", "")) == kind:
			return true
	return false


func _max_path_length(maneuvers: Array) -> int:
	var result_value := 0
	for maneuver_value in maneuvers:
		result_value = maxi(result_value, maneuver_value.get("cells", []).size())
	return result_value


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		printerr("FAIL: %s" % label)
