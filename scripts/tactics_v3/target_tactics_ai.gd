class_name TargetTacticsAI
extends RefCounted


func choose_ship(battle) -> String:
	var candidates: Array[String] = battle.unactivated_ship_ids(battle.active_team)
	var best_id := ""
	var best_score := -1000000.0
	for ship_id in candidates:
		var ship: Dictionary = battle.get_ship(ship_id)
		var score := -float(_nearest_beacon_distance(battle, ship["cell"])) * 8.0
		score += _public_attack_opportunity(battle, ship_id) * 2.0
		if ship["cell"] in battle.beacons and not bool(ship.get("suppressed", false)):
			score += 20.0
		if ship["class_id"] == "fast":
			score += 8.0
		elif ship["class_id"] == "gunship" and _enemy_is_destabilized(battle, int(ship["team"])):
			score += 24.0
		elif ship["class_id"] == "escort" and _wounded_ally_nearby(battle, ship):
			score += 16.0
		if score > best_score or (is_equal_approx(score, best_score) and ship_id < best_id):
			best_score = score
			best_id = ship_id
	return best_id


func choose_maneuver(battle, ship_id: String) -> Dictionary:
	var ship: Dictionary = battle.get_ship(ship_id)
	var origin: Vector2i = ship["cell"]
	var origin_facing := int(ship["facing"])
	var original_maneuver_done: bool = battle.maneuver_done
	var best: Dictionary = {}
	var best_score := -1000000.0
	for command_value in battle.legal_maneuvers(ship_id):
		var command: Dictionary = command_value
		var cells: Array = command.get("cells", [])
		ship["cell"] = origin if cells.is_empty() else cells[-1]
		ship["facing"] = int(command["facing"])
		battle.maneuver_done = true
		var combat := choose_combat(battle, ship_id)
		var score := _position_score(battle, ship, combat)
		if score > best_score or (is_equal_approx(score, best_score) and _maneuver_key(command) < _maneuver_key(best)):
			best_score = score
			best = command.duplicate(true)
	ship["cell"] = origin
	ship["facing"] = origin_facing
	battle.maneuver_done = original_maneuver_done
	return best


func choose_combat(battle, ship_id: String) -> Dictionary:
	var ship: Dictionary = battle.get_ship(ship_id)
	var best := {"action": "end_activation", "target_id": ""}
	var best_score := 0.0
	for action_id in battle.available_combat_actions(ship_id):
		if action_id == "end_activation":
			continue
		if action_id == "brace":
			var brace_score := _incoming_threat(battle, ship_id) * 1.15
			if ship["cell"] in battle.beacons and not bool(ship.get("suppressed", false)):
				brace_score += 10.0
			if brace_score > best_score:
				best_score = brace_score
				best = {"action": "brace", "target_id": ""}
			continue
		for target_id in battle.legal_target_ids(ship_id, action_id):
			var score := _combat_score(battle, ship_id, action_id, target_id)
			var key := "%s:%s" % [action_id, target_id]
			var best_key := "%s:%s" % [best["action"], best["target_id"]]
			if score > best_score or (is_equal_approx(score, best_score) and key < best_key):
				best_score = score
				best = {"action": action_id, "target_id": target_id}
	return best


func _position_score(battle, ship: Dictionary, combat: Dictionary) -> float:
	var score := -float(_nearest_beacon_distance(battle, ship["cell"])) * 14.0
	if ship["cell"] in battle.beacons and not bool(ship.get("suppressed", false)):
		score += 62.0
	var action_id := str(combat.get("action", "end_activation"))
	var target_id := str(combat.get("target_id", ""))
	if target_id != "":
		score += _combat_score(battle, str(ship["id"]), action_id, target_id)
	elif action_id == "brace":
		score += _incoming_threat(battle, str(ship["id"]))
	score -= _incoming_threat(battle, str(ship["id"])) * 0.32
	var enemy_distance := _nearest_enemy_distance(battle, ship)
	if ship["class_id"] == "gunship":
		score -= absf(float(enemy_distance - 3)) * 5.0
	elif ship["class_id"] == "fast":
		score -= absf(float(enemy_distance - 2)) * 2.0
	return score


func _combat_score(battle, ship_id: String, action_id: String, target_id: String) -> float:
	var ship: Dictionary = battle.get_ship(ship_id)
	var target: Dictionary = battle.get_ship(target_id)
	if action_id == "guard":
		var missing_ratio := float(int(target["max_hp"]) - int(target["hp"])) / float(int(target["max_hp"]))
		return 18.0 + missing_ratio * 28.0 + _incoming_threat(battle, target_id) * 1.2
	var preview: Dictionary = battle.preview_damage(ship_id, action_id, target_id)
	if not bool(preview.get("ok", false)):
		return -1000.0
	var damage := int(preview.get("damage", 0))
	var score := float(damage) * 3.2
	if damage >= int(target["hp"]):
		score += 75.0
	if target["cell"] in battle.beacons:
		score += 28.0
	if action_id == "disrupt":
		score += 20.0
	elif action_id == "ram":
		score -= 8.0
	elif action_id.begins_with("broadside"):
		score += float(int(preview.get("stern_bonus", 0)) + int(preview.get("coordinated_bonus", 0))) * 2.0
	if ship["class_id"] == "gunship" and int(target.get("destabilized_by_team", -1)) == int(ship["team"]):
		score += 18.0
	return score


func _public_attack_opportunity(battle, ship_id: String) -> float:
	var ship: Dictionary = battle.get_ship(ship_id)
	var score := 0.0
	for target_id in battle.living_ship_ids(1 - int(ship["team"])):
		match str(ship["class_id"]):
			"fast":
				if battle._validate_side_target(ship_id, target_id, "either", 3).get("ok", false):
					score = maxf(score, 8.0)
				if battle._validate_ram(ship_id, target_id).get("ok", false):
					score = maxf(score, 12.0)
			"gunship":
				if battle._validate_side_target(ship_id, target_id, "port", 4).get("ok", false) or battle._validate_side_target(ship_id, target_id, "starboard", 4).get("ok", false):
					score = maxf(score, 18.0)
			"escort":
				if battle._validate_side_target(ship_id, target_id, "either", 2).get("ok", false):
					score = maxf(score, 12.0)
	return score


func _incoming_threat(battle, ship_id: String) -> float:
	var ship: Dictionary = battle.get_ship(ship_id)
	var threat := 0.0
	for enemy_id in battle.living_ship_ids(1 - int(ship["team"])):
		var enemy: Dictionary = battle.get_ship(enemy_id)
		match str(enemy["class_id"]):
			"fast":
				if battle._validate_side_target(enemy_id, ship_id, "either", 3).get("ok", false):
					threat += 8.0
				if battle._validate_ram(enemy_id, ship_id).get("ok", false):
					threat += 12.0
			"gunship":
				if battle._validate_side_target(enemy_id, ship_id, "port", 4).get("ok", false) or battle._validate_side_target(enemy_id, ship_id, "starboard", 4).get("ok", false):
					threat += 18.0
			"escort":
				if battle._validate_side_target(enemy_id, ship_id, "either", 2).get("ok", false):
					threat += 12.0
	return threat


func _nearest_beacon_distance(battle, cell: Vector2i) -> int:
	var result_value := 99
	for beacon in battle.beacons:
		result_value = mini(result_value, battle.grid.distance(cell, beacon))
	return result_value


func _nearest_enemy_distance(battle, ship: Dictionary) -> int:
	var result_value := 99
	for enemy_id in battle.living_ship_ids(1 - int(ship["team"])):
		result_value = mini(result_value, battle.grid.distance(ship["cell"], battle.get_ship(enemy_id)["cell"]))
	return result_value


func _enemy_is_destabilized(battle, team: int) -> bool:
	for enemy_id in battle.living_ship_ids(1 - team):
		if int(battle.get_ship(enemy_id).get("destabilized_by_team", -1)) == team:
			return true
	return false


func _wounded_ally_nearby(battle, escort: Dictionary) -> bool:
	for ally_id in battle.living_ship_ids(int(escort["team"])):
		var ally: Dictionary = battle.get_ship(ally_id)
		if ally_id != escort["id"] and int(ally["hp"]) < int(ally["max_hp"]) and battle.grid.distance(escort["cell"], ally["cell"]) <= 2:
			return true
	return false


func _maneuver_key(command: Dictionary) -> String:
	if command.is_empty():
		return "~"
	return "%s:%s:%s" % [command.get("kind", ""), command.get("cells", []), command.get("facing", -1)]
