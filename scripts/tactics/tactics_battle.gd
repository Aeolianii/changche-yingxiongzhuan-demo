class_name TacticsBattle
extends RefCounted

const SquareGridScript = preload("res://scripts/tactics/square_grid.gd")
const BOARD_BOUNDS := Rect2i(0, 0, 12, 8)
const MAX_AP := 2
const COORDINATED_STRIKE_BONUS := 6
const SHIP_CLASSES := {
	"fast": {
		"display_name": "快船", "hp": 50, "move_range": 3,
		"disrupt_range": 3, "disrupt_damage": 8,
		"actions": ["sail", "turn", "disrupt", "ram", "undo", "end_unit"],
	},
	"gunship": {
		"display_name": "炮船", "hp": 70, "move_range": 2,
		"broadside_range": 4, "broadside_damage": 18, "stern_bonus": 6,
		"actions": ["sail", "turn", "port", "starboard", "undo", "end_unit"],
	},
}

var grid := SquareGridScript.new()
var ships: Dictionary = {}
var islands: Dictionary = {}
var phase := "player"
var round_number := 1
var result := ""
var undo_sail: Dictionary = {}
var mission_id := "elimination"
var flagship_ids := {0: "player_2", 1: "enemy_2"}
var beacon_cell := Vector2i(5, 4)
var beacon_score := {0: 0, 1: 0}


func _init() -> void:
	reset()


func reset(requested_mission_id: String = "elimination") -> void:
	phase = "player"
	round_number = 1
	result = ""
	undo_sail = {}
	mission_id = requested_mission_id if requested_mission_id in ["elimination", "flagship", "beacon"] else "elimination"
	flagship_ids = {0: "player_2", 1: "enemy_2"}
	beacon_score = {0: 0, 1: 0}
	islands = {
		Vector2i(5, 2): true,
		Vector2i(5, 3): true,
		Vector2i(6, 3): true,
		Vector2i(6, 4): true,
	}
	ships = {
		"player_1": _make_ship("player_1", 0, "广船一号", "fast", Vector2i(1, 2), 0),
		"player_2": _make_ship("player_2", 0, "广船二号", "gunship", Vector2i(1, 5), 0),
		"enemy_1": _make_ship("enemy_1", 1, "红旗一号", "fast", Vector2i(10, 1), 4),
		"enemy_2": _make_ship("enemy_2", 1, "红旗二号", "gunship", Vector2i(10, 6), 4),
	}


func apply_player_fleet_state(fleet_state: Dictionary) -> Dictionary:
	var patches: Dictionary = {}
	for ship_id in ["player_1", "player_2"]:
		if not fleet_state.has(ship_id) or not fleet_state[ship_id] is Dictionary:
			return _reject("missing_campaign_ship")
		var source: Dictionary = fleet_state[ship_id]
		var target: Dictionary = get_ship(ship_id)
		if target.is_empty() or str(source.get("class_id", "")) != str(target["class_id"]):
			return _reject("campaign_class_mismatch")
		var max_hp := int(source.get("max_hp", 0))
		var hp := int(source.get("hp", -1))
		var weapon_level := int(source.get("weapon_level", -1))
		if max_hp <= 0:
			return _reject("invalid_campaign_maximum")
		if hp < 0 or hp > max_hp:
			return _reject("invalid_campaign_current")
		if weapon_level < 0 or weapon_level > 1:
			return _reject("invalid_campaign_weapon")
		patches[ship_id] = {
			"name": str(source.get("name", target["name"])),
			"hp": hp,
			"max_hp": max_hp,
			"weapon_level": weapon_level,
		}
	for ship_id in patches:
		var ship: Dictionary = ships[ship_id]
		var patch: Dictionary = patches[ship_id]
		for key in ["name", "hp", "max_hp", "weapon_level"]:
			ship[key] = patch[key]
		var class_data: Dictionary = SHIP_CLASSES[ship["class_id"]]
		if ship["class_id"] == "gunship":
			ship["broadside_damage"] = int(class_data["broadside_damage"]) + 2 * int(patch["weapon_level"])
		else:
			ship["disrupt_damage"] = int(class_data["disrupt_damage"]) + 2 * int(patch["weapon_level"])
		ship["alive"] = int(ship["hp"]) > 0
		ship["ap"] = MAX_AP if bool(ship["alive"]) else 0
	return {"ok": true}


func get_ship(ship_id: String) -> Dictionary:
	return ships.get(ship_id, {})


func available_actions(ship_id: String) -> Array[String]:
	var ship := get_ship(ship_id)
	if ship.is_empty() or not SHIP_CLASSES.has(ship.get("class_id", "")):
		return []
	var result_actions: Array[String] = []
	for action_id in SHIP_CLASSES[ship["class_id"]]["actions"]:
		result_actions.append(str(action_id))
	return result_actions


func mission_title() -> String:
	return {
		"elimination": "歼灭战",
		"flagship": "旗舰决战",
		"beacon": "航标争夺",
	}.get(mission_id, "歼灭战")


func mission_summary() -> String:
	match mission_id:
		"flagship":
			return "击沉敌方炮船旗舰，同时保护我方旗舰"
		"beacon":
			return "完整回合结束时占领航标，率先获得2分"
		_:
			return "击沉全部敌船"


func living_ship_ids(team: int) -> Array[String]:
	var ids: Array[String] = []
	for ship_id in ships:
		var ship: Dictionary = ships[ship_id]
		if int(ship["team"]) == team and bool(ship["alive"]):
			ids.append(str(ship_id))
	ids.sort()
	return ids


func legal_sailing_paths(ship_id: String) -> Array:
	var ship := get_ship(ship_id)
	if ship.is_empty() or not bool(ship["alive"]):
		return []
	var max_steps: int = int(ship["move_range"])
	var can_turn := true
	return grid.sailing_paths(
		ship["cell"],
		int(ship["facing"]),
		max_steps,
		can_turn,
		_blocked_cells(ship_id),
		BOARD_BOUNDS
	)


func can_sail(ship_id: String, path: Dictionary) -> Dictionary:
	var actor_check := _validate_actor(ship_id)
	if not actor_check["ok"]:
		return actor_check
	var ship := get_ship(ship_id)
	if int(ship["ap"]) < 1:
		return _reject("no_ap")
	if path.is_empty() or not path.has("cells") or not path.has("facing"):
		return _reject("invalid_path")
	for candidate_value in legal_sailing_paths(ship_id):
		var candidate: Dictionary = candidate_value
		if candidate["cells"] == path["cells"] and int(candidate["facing"]) == int(path["facing"]):
			return {"ok": true, "reason": "", "path": candidate}
	return _reject("invalid_path")


func sail(ship_id: String, path: Dictionary) -> Dictionary:
	var validation := can_sail(ship_id, path)
	if not validation["ok"]:
		return validation
	var ship: Dictionary = ships[ship_id]
	var accepted_path: Dictionary = validation["path"]
	var cells: Array = accepted_path["cells"]
	if phase == "player":
		undo_sail = {
			"ship_id": ship_id,
			"cell": ship["cell"],
			"facing": ship["facing"],
			"ap": ship["ap"],
		}
	else:
		clear_undo()
	ship["cell"] = cells[-1]
	ship["facing"] = int(accepted_path["facing"])
	ship["ap"] = int(ship["ap"]) - 1
	return {"ok": true, "reason": "", "ship_id": ship_id, "path": accepted_path}


func legal_turn_commands(ship_id: String) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	var ship := get_ship(ship_id)
	if ship.is_empty() or not bool(ship.get("alive", false)):
		return commands
	for delta in [-2, -1, 1, 2]:
		var facing: int = posmod(int(ship["facing"]) + delta, 8)
		var validation := can_turn(ship_id, facing)
		if validation.get("ok", false):
			commands.append({"type": "turn", "ship_id": ship_id, "facing": facing})
	return commands


func can_turn(ship_id: String, facing: int) -> Dictionary:
	var actor_check := _validate_actor(ship_id)
	if not actor_check["ok"]:
		return actor_check
	if "turn" not in available_actions(ship_id):
		return _reject("action_not_available")
	var ship := get_ship(ship_id)
	if int(ship["ap"]) < 1:
		return _reject("no_ap")
	if facing < 0 or facing >= 8:
		return _reject("invalid_facing")
	var clockwise_delta: int = posmod(facing - int(ship["facing"]), 8)
	if clockwise_delta not in [1, 2, 6, 7]:
		return _reject("invalid_turn")
	return {"ok": true, "reason": "", "facing": facing, "delta": clockwise_delta}


func turn(ship_id: String, facing: int) -> Dictionary:
	var validation := can_turn(ship_id, facing)
	if not validation.get("ok", false):
		return validation
	clear_undo()
	var ship: Dictionary = ships[ship_id]
	var previous_facing: int = int(ship["facing"])
	ship["facing"] = facing
	ship["ap"] = int(ship["ap"]) - 1
	return {
		"ok": true,
		"reason": "",
		"ship_id": ship_id,
		"previous_facing": previous_facing,
		"facing": facing,
		"delta": validation["delta"],
	}


func can_fire(ship_id: String, target_id: String, side: String) -> Dictionary:
	var actor_check := _validate_actor(ship_id)
	if not actor_check["ok"]:
		return actor_check
	if side not in available_actions(ship_id):
		return _reject("action_not_available")
	var ship := get_ship(ship_id)
	if int(ship["ap"]) < 1:
		return _reject("no_ap")
	if side != "port" and side != "starboard":
		return _reject("invalid_side")
	var target := get_ship(target_id)
	if target.is_empty() or not bool(target["alive"]):
		return _reject("invalid_target")
	if int(target["team"]) == int(ship["team"]):
		return _reject("friendly_target")
	var range_value: int = grid.distance(ship["cell"], target["cell"])
	if range_value < 1 or range_value > int(ship["broadside_range"]):
		return _reject("out_of_range")
	var relative := Vector2(target["cell"] - ship["cell"])
	var forward := Vector2(SquareGridScript.DIRECTIONS[int(ship["facing"])]).normalized()
	var right := Vector2(-forward.y, forward.x)
	var forward_projection := relative.dot(forward)
	var side_projection := relative.dot(right)
	var correct_side := side_projection < -0.001 if side == "port" else side_projection > 0.001
	if not correct_side or absf(forward_projection) > absf(side_projection) + 0.001:
		return _reject("outside_arc")
	var shot_line: Array[Vector2i] = grid.line(ship["cell"], target["cell"])
	for index in range(1, shot_line.size() - 1):
		if islands.has(shot_line[index]):
			return _reject("line_blocked")
	var stern := _is_stern_hit(ship["cell"], target)
	var synergy_bonus := COORDINATED_STRIKE_BONUS if int(target.get("destabilized_by_team", -1)) == int(ship["team"]) else 0
	var stern_bonus := int(ship.get("stern_bonus", 0)) if stern else 0
	return {
		"ok": true,
		"reason": "",
		"side": side,
		"range": range_value,
		"stern": stern,
		"damage": int(ship["broadside_damage"]) + stern_bonus + synergy_bonus,
		"base_damage": int(ship["broadside_damage"]),
		"stern_bonus": stern_bonus,
		"synergy_bonus": synergy_bonus,
	}


func fire(ship_id: String, target_id: String, side: String) -> Dictionary:
	var validation := can_fire(ship_id, target_id, side)
	if not validation["ok"]:
		return validation
	var ship: Dictionary = ships[ship_id]
	var target: Dictionary = ships[target_id]
	var consumed_destabilized: bool = int(validation.get("synergy_bonus", 0)) > 0
	clear_undo()
	ship["ap"] = int(ship["ap"]) - 1
	target["hp"] = maxi(0, int(target["hp"]) - int(validation["damage"]))
	_sink_if_needed(target_id)
	if consumed_destabilized:
		target["destabilized_by_team"] = -1
	_update_result()
	var result_value := validation.duplicate(true)
	result_value["ship_id"] = ship_id
	result_value["target_id"] = target_id
	result_value["sunk"] = not bool(target["alive"])
	result_value["consumed_destabilized"] = consumed_destabilized
	return result_value


func can_disrupt(ship_id: String, target_id: String) -> Dictionary:
	var actor_check := _validate_actor(ship_id)
	if not actor_check["ok"]:
		return actor_check
	if "disrupt" not in available_actions(ship_id):
		return _reject("action_not_available")
	var ship := get_ship(ship_id)
	if int(ship["ap"]) < 1:
		return _reject("no_ap")
	for side in ["port", "starboard"]:
		var validation := _validate_side_target(ship_id, target_id, side, int(ship["disrupt_range"]))
		if validation.get("ok", false):
			validation["side"] = side
			validation["damage"] = int(ship["disrupt_damage"])
			return validation
	return _disrupt_rejection(ship_id, target_id)


func fire_disrupt(ship_id: String, target_id: String) -> Dictionary:
	var validation := can_disrupt(ship_id, target_id)
	if not validation.get("ok", false):
		return validation
	clear_undo()
	var ship: Dictionary = ships[ship_id]
	var target: Dictionary = ships[target_id]
	ship["ap"] = int(ship["ap"]) - 1
	target["hp"] = maxi(0, int(target["hp"]) - int(validation["damage"]))
	_sink_if_needed(target_id)
	var destabilized_applied: bool = bool(target["alive"])
	if destabilized_applied:
		target["destabilized_by_team"] = int(ship["team"])
	_update_result()
	var result_value := validation.duplicate(true)
	result_value["ship_id"] = ship_id
	result_value["target_id"] = target_id
	result_value["sunk"] = not bool(target["alive"])
	result_value["destabilized_applied"] = destabilized_applied
	return result_value


func can_ram(ship_id: String, target_id: String) -> Dictionary:
	var actor_check := _validate_actor(ship_id)
	if not actor_check["ok"]:
		return actor_check
	if "ram" not in available_actions(ship_id):
		return _reject("action_not_available")
	var ship := get_ship(ship_id)
	if int(ship["ap"]) < 1:
		return _reject("no_ap")
	var target := get_ship(target_id)
	if target.is_empty() or not bool(target.get("alive", false)):
		return _reject("invalid_target")
	if int(target["team"]) == int(ship["team"]):
		return _reject("friendly_target")
	var front_cell: Vector2i = ship["cell"] + SquareGridScript.DIRECTIONS[int(ship["facing"])]
	if target["cell"] != front_cell:
		return _reject("not_in_front")
	return {"ok": true, "reason": "", "target_id": target_id}


func ram(ship_id: String, target_id: String) -> Dictionary:
	var validation := can_ram(ship_id, target_id)
	if not validation.get("ok", false):
		return validation
	clear_undo()
	var ship: Dictionary = ships[ship_id]
	var target: Dictionary = ships[target_id]
	ship["ap"] = int(ship["ap"]) - 1
	ship["hp"] = maxi(0, int(ship["hp"]) - 5)
	target["hp"] = maxi(0, int(target["hp"]) - 12)
	var collision := "open"
	var blocking_ship_id := ""
	if int(target["hp"]) > 0:
		var push_cell: Vector2i = target["cell"] + SquareGridScript.DIRECTIONS[int(ship["facing"])]
		if not BOARD_BOUNDS.has_point(push_cell) or islands.has(push_cell):
			collision = "obstacle"
			target["hp"] = maxi(0, int(target["hp"]) - 8)
		else:
			blocking_ship_id = _living_ship_at(push_cell, target_id)
			if blocking_ship_id != "":
				collision = "ship"
				target["hp"] = maxi(0, int(target["hp"]) - 5)
				ships[blocking_ship_id]["hp"] = maxi(0, int(ships[blocking_ship_id]["hp"]) - 5)
			else:
				target["cell"] = push_cell
	_sink_if_needed(ship_id)
	_sink_if_needed(target_id)
	if blocking_ship_id != "":
		_sink_if_needed(blocking_ship_id)
	var destabilized_applied: bool = bool(target["alive"])
	if destabilized_applied:
		target["destabilized_by_team"] = int(ship["team"])
	_update_result()
	return {
		"ok": true,
		"reason": "",
		"ship_id": ship_id,
		"target_id": target_id,
		"collision": collision,
		"blocking_ship_id": blocking_ship_id,
		"attacker_sunk": not bool(ship["alive"]),
		"target_sunk": not bool(target["alive"]),
		"destabilized_applied": destabilized_applied,
	}


func legal_ram_commands(ship_id: String) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	var ship := get_ship(ship_id)
	if ship.is_empty():
		return commands
	for target_id in living_ship_ids(1 - int(ship["team"])):
		var validation := can_ram(ship_id, target_id)
		if validation.get("ok", false):
			commands.append({"type": "ram", "ship_id": ship_id, "target_id": target_id, "preview": validation})
	return commands


func can_undo_sail() -> bool:
	if phase != "player" or result != "" or undo_sail.is_empty():
		return false
	var ship_id := str(undo_sail.get("ship_id", ""))
	return ships.has(ship_id) and bool(ships[ship_id]["alive"])


func undo_last_sail() -> Dictionary:
	if not can_undo_sail():
		return _reject("nothing_to_undo")
	var snapshot := undo_sail.duplicate(true)
	var ship_id := str(snapshot["ship_id"])
	ships[ship_id]["cell"] = snapshot["cell"]
	ships[ship_id]["facing"] = snapshot["facing"]
	ships[ship_id]["ap"] = snapshot["ap"]
	clear_undo()
	return {"ok": true, "reason": "", "ship_id": ship_id}


func clear_undo() -> void:
	undo_sail = {}


func legal_fire_commands(ship_id: String) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	var ship := get_ship(ship_id)
	if ship.is_empty():
		return commands
	var enemy_team := 1 - int(ship["team"])
	for target_id in living_ship_ids(enemy_team):
		for side in ["port", "starboard"]:
			var validation := can_fire(ship_id, target_id, side)
			if validation["ok"]:
				commands.append({"type": "fire", "ship_id": ship_id, "target_id": target_id, "side": side, "preview": validation})
	return commands


func legal_disrupt_commands(ship_id: String) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	var ship := get_ship(ship_id)
	if ship.is_empty():
		return commands
	for target_id in living_ship_ids(1 - int(ship["team"])):
		var validation := can_disrupt(ship_id, target_id)
		if validation.get("ok", false):
			commands.append({"type": "disrupt", "ship_id": ship_id, "target_id": target_id, "side": validation["side"], "preview": validation})
	return commands


func end_player_phase() -> Dictionary:
	if result != "":
		return _reject("battle_over")
	if phase != "player":
		return _reject("wrong_phase")
	clear_undo()
	_clear_destabilized_by_team(0)
	for ship_id in living_ship_ids(0):
		ships[ship_id]["ap"] = 0
	phase = "enemy"
	_refresh_team(1)
	return {"ok": true, "reason": ""}


func begin_player_phase() -> Dictionary:
	if result != "":
		return _reject("battle_over")
	if phase != "enemy":
		return _reject("wrong_phase")
	clear_undo()
	_clear_destabilized_by_team(1)
	for ship_id in living_ship_ids(1):
		ships[ship_id]["ap"] = 0
	if mission_id == "beacon":
		_score_beacon_round()
		_update_result()
		if result != "":
			return {"ok": true, "reason": "", "scored": true}
	phase = "player"
	round_number += 1
	_refresh_team(0)
	return {"ok": true, "reason": ""}


func _make_ship(ship_id: String, team: int, display_name: String, class_id: String, cell: Vector2i, facing: int) -> Dictionary:
	var class_data: Dictionary = SHIP_CLASSES[class_id]
	return {
		"id": ship_id,
		"team": team,
		"name": display_name,
		"class_id": class_id,
		"class_name": class_data["display_name"],
		"cell": cell,
		"facing": facing,
		"ap": MAX_AP,
		"hp": class_data["hp"],
		"max_hp": class_data["hp"],
		"move_range": class_data["move_range"],
		"broadside_range": class_data.get("broadside_range", 0),
		"broadside_damage": class_data.get("broadside_damage", 0),
		"stern_bonus": class_data.get("stern_bonus", 0),
		"disrupt_range": class_data.get("disrupt_range", 0),
		"disrupt_damage": class_data.get("disrupt_damage", 0),
		"weapon_level": 0,
		"destabilized_by_team": -1,
		"alive": true,
	}


func _validate_actor(ship_id: String) -> Dictionary:
	if result != "":
		return _reject("battle_over")
	var ship := get_ship(ship_id)
	if ship.is_empty():
		return _reject("missing_ship")
	if not bool(ship["alive"]):
		return _reject("ship_sunk")
	var expected_team := 0 if phase == "player" else 1
	if int(ship["team"]) != expected_team:
		return _reject("wrong_phase")
	return {"ok": true, "reason": ""}


func _blocked_cells(excluded_ship_id: String) -> Dictionary:
	var blocked := islands.duplicate()
	for ship_id in ships:
		if ship_id == excluded_ship_id:
			continue
		var ship: Dictionary = ships[ship_id]
		if bool(ship["alive"]):
			blocked[ship["cell"]] = true
	return blocked


func _is_stern_hit(attacker_cell: Vector2i, target: Dictionary) -> bool:
	var relative := Vector2(attacker_cell - target["cell"])
	var target_forward := Vector2(SquareGridScript.DIRECTIONS[int(target["facing"])]).normalized()
	var target_right := Vector2(-target_forward.y, target_forward.x)
	var rear_projection := relative.dot(-target_forward)
	return rear_projection > 0.001 and absf(relative.dot(target_right)) <= rear_projection + 0.001


func _validate_side_target(ship_id: String, target_id: String, side: String, max_range: int) -> Dictionary:
	var ship := get_ship(ship_id)
	var target := get_ship(target_id)
	if target.is_empty() or not bool(target.get("alive", false)):
		return _reject("invalid_target")
	if int(target["team"]) == int(ship["team"]):
		return _reject("friendly_target")
	var range_value: int = grid.distance(ship["cell"], target["cell"])
	if range_value < 1 or range_value > max_range:
		return _reject("out_of_range")
	var relative := Vector2(target["cell"] - ship["cell"])
	var forward := Vector2(SquareGridScript.DIRECTIONS[int(ship["facing"])]).normalized()
	var right := Vector2(-forward.y, forward.x)
	var forward_projection := relative.dot(forward)
	var side_projection := relative.dot(right)
	var correct_side := side_projection < -0.001 if side == "port" else side_projection > 0.001
	if not correct_side or absf(forward_projection) > absf(side_projection) + 0.001:
		return _reject("outside_arc")
	var shot_line: Array[Vector2i] = grid.line(ship["cell"], target["cell"])
	for index in range(1, shot_line.size() - 1):
		if islands.has(shot_line[index]):
			return _reject("line_blocked")
	return {"ok": true, "reason": "", "range": range_value}


func _disrupt_rejection(ship_id: String, target_id: String) -> Dictionary:
	for side in ["port", "starboard"]:
		var rejection := _validate_side_target(ship_id, target_id, side, int(get_ship(ship_id).get("disrupt_range", 3)))
		if rejection.get("reason", "") != "outside_arc":
			return rejection
	return _reject("outside_arc")


func _sink_if_needed(ship_id: String) -> void:
	var ship: Dictionary = ships[ship_id]
	if int(ship["hp"]) <= 0:
		ship["hp"] = 0
		ship["alive"] = false
		ship["ap"] = 0
		ship["destabilized_by_team"] = -1


func _clear_destabilized_by_team(team: int) -> void:
	for ship_id in ships:
		if int(ships[ship_id].get("destabilized_by_team", -1)) == team:
			ships[ship_id]["destabilized_by_team"] = -1


func _living_ship_at(cell: Vector2i, excluded_ship_id: String = "") -> String:
	for ship_id in ships:
		if ship_id == excluded_ship_id:
			continue
		var ship: Dictionary = ships[ship_id]
		if bool(ship["alive"]) and ship["cell"] == cell:
			return str(ship_id)
	return ""


func _refresh_team(team: int) -> void:
	for ship_id in living_ship_ids(team):
		ships[ship_id]["ap"] = MAX_AP


func _update_result() -> void:
	var players_empty := living_ship_ids(0).is_empty()
	var enemies_empty := living_ship_ids(1).is_empty()
	if players_empty and enemies_empty:
		result = "draw"
		return
	if mission_id == "flagship":
		var player_flagship_alive: bool = bool(get_ship(flagship_ids[0]).get("alive", false))
		var enemy_flagship_alive: bool = bool(get_ship(flagship_ids[1]).get("alive", false))
		if not player_flagship_alive and not enemy_flagship_alive:
			result = "draw"
		elif not enemy_flagship_alive:
			result = "victory"
		elif not player_flagship_alive:
			result = "defeat"
		return
	if enemies_empty or (mission_id == "beacon" and int(beacon_score[0]) >= 2):
		result = "victory"
	elif players_empty or (mission_id == "beacon" and int(beacon_score[1]) >= 2):
		result = "defeat"


func _score_beacon_round() -> void:
	var occupant_id := _living_ship_at(beacon_cell)
	if occupant_id == "":
		return
	var team: int = int(ships[occupant_id]["team"])
	beacon_score[team] = int(beacon_score[team]) + 1


func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
