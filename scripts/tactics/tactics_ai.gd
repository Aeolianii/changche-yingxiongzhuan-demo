class_name TacticsAI
extends RefCounted


func choose_command(battle, ship_id: String, context: Dictionary = {}) -> Dictionary:
	var ship: Dictionary = battle.get_ship(ship_id)
	if ship.is_empty() or not bool(ship.get("alive", false)) or int(ship.get("ap", 0)) <= 0:
		return {"type": "end", "ship_id": ship_id}
	var ordered_targets := _ordered_targets(battle, ship_id)
	for command in battle.legal_ram_commands(ship_id):
		if _ram_is_decisive(battle, command):
			return command
	for target_id in ordered_targets:
		for side in ["port", "starboard"]:
			var sinking_check: Dictionary = battle.can_fire(ship_id, target_id, side)
			if sinking_check.get("ok", false) and int(battle.get_ship(target_id)["hp"]) <= int(sinking_check["damage"]):
				return {"type": "fire", "ship_id": ship_id, "target_id": target_id, "side": side, "preview": sinking_check}
	var coordinated_setup := _coordinated_disrupt_setup(battle, ship_id, ordered_targets)
	if not coordinated_setup.is_empty():
		return coordinated_setup
	for target_id in ordered_targets:
		for side in ["port", "starboard"]:
			var fire_check: Dictionary = battle.can_fire(ship_id, target_id, side)
			if fire_check.get("ok", false):
				return {"type": "fire", "ship_id": ship_id, "target_id": target_id, "side": side, "preview": fire_check}
	for target_id in ordered_targets:
		var disrupt_check: Dictionary = battle.can_disrupt(ship_id, target_id)
		if disrupt_check.get("ok", false):
			return {"type": "disrupt", "ship_id": ship_id, "target_id": target_id, "side": disrupt_check["side"], "preview": disrupt_check}
	var objective_ram := _objective_ram_command(battle, ship_id)
	if not objective_ram.is_empty():
		return objective_ram
	var turn_command := _immediate_attack_turn(battle, ship_id)
	if not turn_command.is_empty():
		return turn_command

	var paths: Array = battle.legal_sailing_paths(ship_id)
	if paths.is_empty():
		return {"type": "end", "ship_id": ship_id}
	var original_cell: Vector2i = ship["cell"]
	var original_facing: int = int(ship["facing"])
	var visited_cells: Dictionary = context.get("visited_cells", {})
	var has_unvisited_forward := false
	for path_value in paths:
		var candidate: Dictionary = path_value
		var candidate_cells: Array = candidate["cells"]
		if not visited_cells.has(candidate_cells[-1]) and not candidate.get("reverse", false):
			has_unvisited_forward = true
			break
	var best_path: Dictionary = {}
	var best_score := -1000000
	var best_key := ""
	var hold_score := _position_score(battle, ship_id, ordered_targets, original_cell, 0)
	for path_value in paths:
		var path: Dictionary = path_value
		var cells: Array = path["cells"]
		var destination: Vector2i = cells[-1]
		if visited_cells.has(destination):
			continue
		ship["cell"] = cells[-1]
		ship["facing"] = int(path["facing"])
		var opportunity_score := _class_opportunity_score(battle, ship_id)
		var beacon_improvement: bool = battle.mission_id == "beacon" and battle.grid.distance(ship["cell"], battle.beacon_cell) < battle.grid.distance(original_cell, battle.beacon_cell)
		var score := _position_score(battle, ship_id, ordered_targets, original_cell, cells.size())
		if path.get("reverse", false) and has_unvisited_forward and opportunity_score == 0 and not beacon_improvement:
			score -= 80
		var key := "%03d:%03d:%d:%s" % [destination.x, destination.y, int(path["facing"]), cells]
		if score > best_score or (score == best_score and (best_key == "" or key < best_key)):
			best_score = score
			best_key = key
			best_path = path
	ship["cell"] = original_cell
	ship["facing"] = original_facing
	if best_path.is_empty():
		return {"type": "end", "ship_id": ship_id}
	if has_unvisited_forward and best_score <= hold_score:
		return {"type": "end", "ship_id": ship_id}
	return {"type": "sail", "ship_id": ship_id, "path": best_path, "score": best_score}


func run_activation(battle, ship_id: String) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var start_ship: Dictionary = battle.get_ship(ship_id)
	var visited_cells := {}
	if not start_ship.is_empty():
		visited_cells[start_ship["cell"]] = true
	for _step in 2:
		var ship: Dictionary = battle.get_ship(ship_id)
		if ship.is_empty() or not bool(ship.get("alive", false)) or int(ship.get("ap", 0)) <= 0 or battle.result != "":
			break
		var command := choose_command(battle, ship_id, {"visited_cells": visited_cells})
		var action_result: Dictionary
		match command.get("type", "end"):
			"fire":
				action_result = battle.fire(ship_id, command["target_id"], command["side"])
			"disrupt":
				action_result = battle.fire_disrupt(ship_id, command["target_id"])
			"ram":
				action_result = battle.ram(ship_id, command["target_id"])
			"sail":
				action_result = battle.sail(ship_id, command["path"])
			"turn":
				action_result = battle.turn(ship_id, int(command["facing"]))
			_:
				break
		if not action_result.get("ok", false):
			break
		var record := command.duplicate(true)
		record["result"] = action_result
		actions.append(record)
		if command.get("type", "") == "sail":
			visited_cells[battle.get_ship(ship_id)["cell"]] = true
	return actions


func _immediate_attack_turn(battle, ship_id: String) -> Dictionary:
	var ship: Dictionary = battle.get_ship(ship_id)
	var original_facing: int = int(ship.get("facing", 0))
	var best_command: Dictionary = {}
	var best_score := 0
	for command_value in battle.legal_turn_commands(ship_id):
		var command: Dictionary = command_value
		ship["facing"] = int(command["facing"])
		var score := 0
		if ship.get("class_id", "") == "fast":
			score = battle.legal_disrupt_commands(ship_id).size() * 100 + battle.legal_ram_commands(ship_id).size() * 120
		else:
			for fire_command in battle.legal_fire_commands(ship_id):
				score += 100
				var target: Dictionary = battle.get_ship(fire_command["target_id"])
				if int(target.get("hp", 0)) <= int(fire_command.get("preview", {}).get("damage", 0)):
					score += 1000
			if score > 0 and posmod(int(command["facing"]) - original_facing, 8) in [2, 6]:
				score += 10
		ship["facing"] = original_facing
		var key := int(command["facing"])
		if score > best_score or (score == best_score and score > 0 and (best_command.is_empty() or key < int(best_command["facing"]))):
			best_score = score
			best_command = command.duplicate(true)
	ship["facing"] = original_facing
	return best_command


func _position_score(battle, ship_id: String, ordered_targets: Array[String], movement_origin: Vector2i, path_length: int) -> int:
	var ship: Dictionary = battle.get_ship(ship_id)
	var score := 0
	if battle.mission_id == "beacon":
		var before_beacon: int = battle.grid.distance(movement_origin, battle.beacon_cell)
		var after_beacon: int = battle.grid.distance(ship["cell"], battle.beacon_cell)
		score += (before_beacon - after_beacon) * 40
		if ship["cell"] == battle.beacon_cell:
			score += 160
	score += _class_opportunity_score(battle, ship_id)
	if _count_player_threats(battle, ship_id) == 0:
		score += 30
	if not ordered_targets.is_empty():
		var target: Dictionary = battle.get_ship(ordered_targets[0])
		var distance_value: int = battle.grid.distance(ship["cell"], target["cell"])
		if distance_value >= 2 and distance_value <= 3:
			score += 20
		else:
			score -= absi(distance_value - 2) * 3
	return score - path_length


func _class_opportunity_score(battle, ship_id: String) -> int:
	var ship: Dictionary = battle.get_ship(ship_id)
	if ship.get("class_id", "") == "fast":
		if not battle.legal_disrupt_commands(ship_id).is_empty():
			return 110
		if not _objective_ram_command(battle, ship_id).is_empty():
			return 90
		return 0
	return 100 if not battle.legal_fire_commands(ship_id).is_empty() else 0


func _objective_ram_command(battle, ship_id: String) -> Dictionary:
	if battle.mission_id != "beacon":
		return {}
	for command in battle.legal_ram_commands(ship_id):
		var target: Dictionary = battle.get_ship(command["target_id"])
		if target.get("cell", Vector2i(-1, -1)) == battle.beacon_cell:
			return command
	return {}


func _ordered_targets(battle, ship_id: String) -> Array[String]:
	var actor: Dictionary = battle.get_ship(ship_id)
	if actor.is_empty():
		return []
	var ids: Array[String] = battle.living_ship_ids(1 - int(actor["team"]))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ship_a: Dictionary = battle.get_ship(a)
		var ship_b: Dictionary = battle.get_ship(b)
		var actor_team: int = int(actor["team"])
		var a_destabilized: bool = int(ship_a.get("destabilized_by_team", -1)) == actor_team
		var b_destabilized: bool = int(ship_b.get("destabilized_by_team", -1)) == actor_team
		if a_destabilized != b_destabilized:
			return a_destabilized
		if battle.mission_id == "flagship":
			var flagship_id := str(battle.flagship_ids[1 - int(actor["team"])])
			if a == flagship_id and b != flagship_id:
				return true
			if b == flagship_id and a != flagship_id:
				return false
		if int(ship_a["hp"]) != int(ship_b["hp"]):
			return int(ship_a["hp"]) < int(ship_b["hp"])
		var distance_a: int = battle.grid.distance(actor["cell"], ship_a["cell"])
		var distance_b: int = battle.grid.distance(actor["cell"], ship_b["cell"])
		if distance_a != distance_b:
			return distance_a < distance_b
		return a < b
	)
	return ids


func _coordinated_disrupt_setup(battle, ship_id: String, ordered_targets: Array[String]) -> Dictionary:
	var actor: Dictionary = battle.get_ship(ship_id)
	if actor.get("class_id", "") != "fast":
		return {}
	var friendly_gunships: Array[String] = []
	for friendly_id in battle.living_ship_ids(int(actor["team"])):
		var friendly: Dictionary = battle.get_ship(friendly_id)
		if friendly.get("class_id", "") == "gunship" and int(friendly.get("ap", 0)) > 0:
			friendly_gunships.append(friendly_id)
	for target_id in ordered_targets:
		var disrupt_check: Dictionary = battle.can_disrupt(ship_id, target_id)
		if not disrupt_check.get("ok", false):
			continue
		for gunship_id in friendly_gunships:
			for side in ["port", "starboard"]:
				if battle.can_fire(gunship_id, target_id, side).get("ok", false):
					return {"type": "disrupt", "ship_id": ship_id, "target_id": target_id, "side": disrupt_check["side"], "preview": disrupt_check}
	return {}


func _ram_is_decisive(battle, command: Dictionary) -> bool:
	var actor: Dictionary = battle.get_ship(command["ship_id"])
	var target: Dictionary = battle.get_ship(command["target_id"])
	if int(target.get("hp", 0)) <= 12:
		return true
	var push_cell: Vector2i = target["cell"] + battle.grid.DIRECTIONS[int(actor["facing"])]
	if not battle.BOARD_BOUNDS.has_point(push_cell) or battle.islands.has(push_cell):
		return true
	for other_id in battle.ships:
		if other_id == command["target_id"]:
			continue
		var other: Dictionary = battle.ships[other_id]
		if bool(other["alive"]) and other["cell"] == push_cell:
			return true
	return false


func _count_player_threats(battle, target_id: String) -> int:
	var saved_phase: String = battle.phase
	var saved_ap := {}
	battle.phase = "player"
	var threats := 0
	for player_id in battle.living_ship_ids(0):
		var player: Dictionary = battle.get_ship(player_id)
		saved_ap[player_id] = int(player["ap"])
		player["ap"] = 1
		for side in ["port", "starboard"]:
			if battle.can_fire(player_id, target_id, side).get("ok", false):
				threats += 1
				break
	for player_id in saved_ap:
		battle.ships[player_id]["ap"] = saved_ap[player_id]
	battle.phase = saved_phase
	return threats
