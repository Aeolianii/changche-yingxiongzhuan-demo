class_name TargetTacticsBattle
extends RefCounted

const SquareGridScript = preload("res://scripts/tactics/square_grid.gd")
const BOARD_BOUNDS := Rect2i(0, 0, 12, 8)
const MAX_ROUNDS := 6
const SCORE_TO_WIN := 5
const COORDINATED_STRIKE_BONUS := 6
const CLASS_DATA := {
	"fast": {
		"display_name": "巡哨快船",
		"short_name": "快",
		"hp": 50,
		"move_range": 3,
		"combat_actions": ["disrupt", "ram"],
	},
	"gunship": {
		"display_name": "火炮战船",
		"short_name": "炮",
		"hp": 70,
		"move_range": 2,
		"combat_actions": ["broadside_port", "broadside_starboard"],
	},
	"escort": {
		"display_name": "护航广船",
		"short_name": "护",
		"hp": 85,
		"move_range": 2,
		"combat_actions": ["short_cannon", "guard"],
	},
}

var grid := SquareGridScript.new()
var ships: Dictionary = {}
var islands: Dictionary = {}
var beacons: Array[Vector2i] = []
var beacon_score := {0: 0, 1: 0}
var round_number := 1
var active_team := 0
var active_ship_id := ""
var maneuver_done := false
var result := ""
var last_event: Dictionary = {}


func _init() -> void:
	reset()


func reset() -> void:
	round_number = 1
	active_team = 0
	active_ship_id = ""
	maneuver_done = false
	result = ""
	last_event = {}
	beacon_score = {0: 0, 1: 0}
	beacons = [Vector2i(5, 2), Vector2i(6, 5)]
	islands = {
		Vector2i(5, 3): true,
		Vector2i(6, 4): true,
	}
	ships = {
		"player_fast": _make_ship("player_fast", 0, "巡海一号", "fast", Vector2i(1, 1), 0),
		"player_gunship": _make_ship("player_gunship", 0, "镇涛号", "gunship", Vector2i(1, 3), 0),
		"player_escort": _make_ship("player_escort", 0, "安澜号", "escort", Vector2i(1, 6), 0),
		"enemy_fast": _make_ship("enemy_fast", 1, "飞鲨艇", "fast", Vector2i(10, 6), 4),
		"enemy_gunship": _make_ship("enemy_gunship", 1, "赤潮炮舰", "gunship", Vector2i(10, 4), 4),
		"enemy_escort": _make_ship("enemy_escort", 1, "黑帆护舰", "escort", Vector2i(10, 1), 4),
	}


func get_ship(ship_id: String) -> Dictionary:
	return ships.get(ship_id, {})


func living_ship_ids(team: int) -> Array[String]:
	var ids: Array[String] = []
	for ship_id_value in ships:
		var ship_id := str(ship_id_value)
		var ship: Dictionary = ships[ship_id]
		if int(ship["team"]) == team and bool(ship["alive"]):
			ids.append(ship_id)
	ids.sort()
	return ids


func unactivated_ship_ids(team: int) -> Array[String]:
	var ids: Array[String] = []
	for ship_id in living_ship_ids(team):
		if not bool(ships[ship_id]["activated"]):
			ids.append(ship_id)
	return ids


func can_begin_activation(ship_id: String) -> Dictionary:
	if result != "":
		return _reject("battle_over")
	if active_ship_id != "":
		return _reject("activation_in_progress")
	var ship := get_ship(ship_id)
	if ship.is_empty() or not bool(ship.get("alive", false)):
		return _reject("invalid_ship")
	if int(ship["team"]) != active_team:
		return _reject("wrong_team")
	if bool(ship["activated"]):
		return _reject("already_activated")
	return {"ok": true, "reason": ""}


func begin_activation(ship_id: String) -> Dictionary:
	var validation := can_begin_activation(ship_id)
	if not bool(validation["ok"]):
		return validation
	var ship: Dictionary = ships[ship_id]
	ship["braced"] = false
	_clear_guards_from_source(ship_id)
	active_ship_id = ship_id
	maneuver_done = false
	last_event = {
		"type": "begin_activation",
		"ship_id": ship_id,
		"team": int(ship["team"]),
	}
	return {"ok": true, "reason": "", "ship_id": ship_id}


func legal_maneuvers(ship_id: String) -> Array[Dictionary]:
	var ship := get_ship(ship_id)
	if ship.is_empty() or not bool(ship.get("alive", false)):
		return []
	var result_value: Array[Dictionary] = []
	var seen: Dictionary = {}
	_append_maneuver(result_value, seen, {
		"kind": "wait",
		"cells": [],
		"facing": int(ship["facing"]),
	})
	for delta in [-2, -1, 1, 2]:
		_append_maneuver(result_value, seen, {
			"kind": "turn",
			"cells": [],
			"facing": posmod(int(ship["facing"]) + delta, 8),
			"turn_delta": delta,
		})

	var blocked := _blocked_cells(ship_id)
	var reverse_cell: Vector2i = ship["cell"] - grid.DIRECTIONS[int(ship["facing"])]
	if BOARD_BOUNDS.has_point(reverse_cell) and not blocked.has(reverse_cell):
		_append_maneuver(result_value, seen, {
			"kind": "reverse",
			"cells": [reverse_cell],
			"facing": int(ship["facing"]),
		})

	var max_steps := int(ship["move_range"])
	var start: Vector2i = ship["cell"]
	var starting_facing := int(ship["facing"])
	for distance in range(1, max_steps + 1):
		var straight_cells: Array[Vector2i] = []
		var straight_cursor := start
		var straight_valid := true
		for _step in distance:
			straight_cursor += grid.DIRECTIONS[starting_facing]
			if not BOARD_BOUNDS.has_point(straight_cursor) or blocked.has(straight_cursor):
				straight_valid = false
				break
			straight_cells.append(straight_cursor)
		if straight_valid:
			_append_maneuver(result_value, seen, {
				"kind": "sail",
				"cells": straight_cells,
				"facing": starting_facing,
			})

		if distance < 2:
			continue
		for turn_delta in [-1, 1]:
			var turned_facing: int = posmod(starting_facing + turn_delta, 8)
			for straight_steps in range(1, distance):
				var cells: Array[Vector2i] = []
				var cursor := start
				var valid := true
				for step in distance:
					var direction := starting_facing if step < straight_steps else turned_facing
					cursor += grid.DIRECTIONS[direction]
					if not BOARD_BOUNDS.has_point(cursor) or blocked.has(cursor):
						valid = false
						break
					cells.append(cursor)
				if valid:
					_append_maneuver(result_value, seen, {
						"kind": "sail_turn",
						"cells": cells,
						"facing": turned_facing,
						"turn_delta": turn_delta,
					})
	return result_value


func can_execute_maneuver(ship_id: String, command: Dictionary) -> Dictionary:
	var active_check := _validate_active_ship(ship_id)
	if not bool(active_check["ok"]):
		return active_check
	if maneuver_done:
		return _reject("maneuver_already_done")
	for legal in legal_maneuvers(ship_id):
		if _same_maneuver(legal, command):
			return {"ok": true, "reason": "", "command": legal}
	return _reject("invalid_maneuver")


func execute_maneuver(ship_id: String, command: Dictionary) -> Dictionary:
	var validation := can_execute_maneuver(ship_id, command)
	if not bool(validation["ok"]):
		return validation
	var accepted: Dictionary = validation["command"]
	var ship: Dictionary = ships[ship_id]
	var origin: Vector2i = ship["cell"]
	var cells: Array = accepted.get("cells", [])
	if not cells.is_empty():
		ship["cell"] = cells[-1]
	ship["facing"] = int(accepted["facing"])
	maneuver_done = true
	last_event = {
		"type": "maneuver",
		"ship_id": ship_id,
		"kind": str(accepted["kind"]),
		"origin": origin,
		"destination": ship["cell"],
		"facing": int(ship["facing"]),
	}
	return {
		"ok": true,
		"reason": "",
		"ship_id": ship_id,
		"kind": str(accepted["kind"]),
		"origin": origin,
		"destination": ship["cell"],
		"facing": int(ship["facing"]),
	}


func available_combat_actions(ship_id: String) -> Array[String]:
	var ship := get_ship(ship_id)
	if ship.is_empty() or not CLASS_DATA.has(str(ship.get("class_id", ""))):
		return []
	var actions: Array[String] = []
	for action_value in CLASS_DATA[str(ship["class_id"])]["combat_actions"]:
		actions.append(str(action_value))
	actions.append("brace")
	actions.append("end_activation")
	return actions


func legal_target_ids(ship_id: String, action_id: String) -> Array[String]:
	var ids: Array[String] = []
	var ship := get_ship(ship_id)
	if ship.is_empty():
		return ids
	var candidate_team := int(ship["team"]) if action_id == "guard" else 1 - int(ship["team"])
	for target_id in living_ship_ids(candidate_team):
		if bool(can_combat_action(ship_id, action_id, target_id).get("ok", false)):
			ids.append(target_id)
	return ids


func can_combat_action(ship_id: String, action_id: String, target_id: String = "") -> Dictionary:
	var active_check := _validate_active_ship(ship_id)
	if not bool(active_check["ok"]):
		return active_check
	if not maneuver_done:
		return _reject("maneuver_required")
	if action_id not in available_combat_actions(ship_id):
		return _reject("wrong_class_action")
	if action_id in ["brace", "end_activation"]:
		return {"ok": true, "reason": ""}
	if target_id == "":
		return _reject("target_required")
	var ship: Dictionary = ships[ship_id]
	match action_id:
		"disrupt":
			return _validate_side_target(ship_id, target_id, "either", 3)
		"ram":
			return _validate_ram(ship_id, target_id)
		"broadside_port":
			return _validate_side_target(ship_id, target_id, "port", 4)
		"broadside_starboard":
			return _validate_side_target(ship_id, target_id, "starboard", 4)
		"short_cannon":
			return _validate_side_target(ship_id, target_id, "either", 2)
		"guard":
			var target := get_ship(target_id)
			if target.is_empty() or not bool(target.get("alive", false)):
				return _reject("invalid_target")
			if target_id == ship_id or int(target["team"]) != int(ship["team"]):
				return _reject("guard_requires_ally")
			if grid.distance(ship["cell"], target["cell"]) > 2:
				return _reject("out_of_range")
			if str(target.get("guard_source", "")) != "":
				return _reject("already_guarded")
			return {"ok": true, "reason": ""}
	return _reject("unknown_action")


func preview_damage(ship_id: String, action_id: String, target_id: String) -> Dictionary:
	var validation := can_combat_action(ship_id, action_id, target_id)
	if not bool(validation["ok"]):
		return validation
	var ship: Dictionary = ships[ship_id]
	var target: Dictionary = ships[target_id]
	var raw_damage := 0
	var stern_bonus := 0
	var coordinated_bonus := 0
	match action_id:
		"disrupt":
			raw_damage = 8
		"ram":
			raw_damage = 12
		"broadside_port", "broadside_starboard":
			raw_damage = 18
			if _is_stern_hit(ship["cell"], target):
				stern_bonus = 6
			if int(target.get("destabilized_by_team", -1)) == int(ship["team"]):
				coordinated_bonus = COORDINATED_STRIKE_BONUS
			raw_damage += stern_bonus + coordinated_bonus
		"short_cannon":
			raw_damage = 12
	var reduction := maxi(6 if bool(target.get("braced", false)) else 0, 8 if str(target.get("guard_source", "")) != "" else 0)
	return {
		"ok": true,
		"reason": "",
		"raw_damage": raw_damage,
		"reduction": reduction,
		"damage": maxi(1, raw_damage - reduction),
		"stern_bonus": stern_bonus,
		"coordinated_bonus": coordinated_bonus,
	}


func execute_combat_action(ship_id: String, action_id: String, target_id: String = "") -> Dictionary:
	var validation := can_combat_action(ship_id, action_id, target_id)
	if not bool(validation["ok"]):
		return validation
	var actor: Dictionary = ships[ship_id]
	var outcome: Dictionary = {
		"ok": true,
		"reason": "",
		"type": "combat",
		"ship_id": ship_id,
		"action": action_id,
		"target_id": target_id,
	}
	match action_id:
		"end_activation":
			outcome["type"] = "end_activation"
		"brace":
			actor["braced"] = true
		"guard":
			ships[target_id]["guard_source"] = ship_id
		"disrupt":
			var hit := _deal_damage(target_id, 8)
			outcome.merge(hit, true)
			if bool(ships[target_id]["alive"]):
				ships[target_id]["destabilized_by_team"] = int(actor["team"])
				outcome["applied_destabilized"] = true
		"short_cannon":
			outcome.merge(_deal_damage(target_id, 12), true)
		"broadside_port", "broadside_starboard":
			var preview := preview_damage(ship_id, action_id, target_id)
			outcome["stern_bonus"] = int(preview["stern_bonus"])
			outcome["coordinated_bonus"] = int(preview["coordinated_bonus"])
			outcome.merge(_deal_damage(target_id, int(preview["raw_damage"])), true)
			if int(preview["coordinated_bonus"]) > 0:
				ships[target_id]["destabilized_by_team"] = -1
		"ram":
			outcome.merge(_resolve_ram(ship_id, target_id), true)
	last_event = outcome.duplicate(true)
	var transition := _finish_active_ship()
	outcome["next_team"] = int(transition.get("next_team", active_team))
	outcome["round_ended"] = bool(transition.get("round_ended", false))
	outcome["result"] = result
	return outcome


func theoretical_range_cells(ship_id: String, action_id: String) -> Dictionary:
	var cells: Dictionary = {}
	var ship := get_ship(ship_id)
	if ship.is_empty() or not bool(ship.get("alive", false)):
		return cells
	if action_id == "ram":
		var front_cell: Vector2i = ship["cell"] + grid.DIRECTIONS[int(ship["facing"])]
		if BOARD_BOUNDS.has_point(front_cell):
			cells[front_cell] = true
		return cells
	if action_id == "guard":
		for y in BOARD_BOUNDS.size.y:
			for x in BOARD_BOUNDS.size.x:
				var guard_cell := Vector2i(x, y)
				if guard_cell != ship["cell"] and grid.distance(ship["cell"], guard_cell) <= 2:
					cells[guard_cell] = true
		return cells
	var max_range: int = int({"disrupt": 3, "broadside_port": 4, "broadside_starboard": 4, "short_cannon": 2}.get(action_id, 0))
	if max_range <= 0:
		return cells
	var side := "either"
	if action_id == "broadside_port":
		side = "port"
	elif action_id == "broadside_starboard":
		side = "starboard"
	for y in BOARD_BOUNDS.size.y:
		for x in BOARD_BOUNDS.size.x:
			var cell := Vector2i(x, y)
			if cell == ship["cell"] or grid.distance(ship["cell"], cell) > max_range:
				continue
			if _cell_in_side_arc(ship, cell, side):
				cells[cell] = true
	return cells


func _finish_active_ship() -> Dictionary:
	if active_ship_id == "":
		return {"ok": false}
	var ship: Dictionary = ships[active_ship_id]
	ship["activated"] = true
	ship["ever_activated"] = true
	var completed_team := int(ship["team"])
	active_ship_id = ""
	maneuver_done = false
	_update_elimination_result()
	if result != "":
		return {"ok": true, "next_team": completed_team, "round_ended": false}

	var round_ended := unactivated_ship_ids(0).is_empty() and unactivated_ship_ids(1).is_empty()
	if round_ended:
		_finish_round()
		return {"ok": true, "next_team": active_team, "round_ended": true}
	var other_team := 1 - completed_team
	active_team = other_team if not unactivated_ship_ids(other_team).is_empty() else completed_team
	return {"ok": true, "next_team": active_team, "round_ended": false}


func _finish_round() -> void:
	for beacon in beacons:
		var controlling_teams: Dictionary = {}
		for ship_id in ships:
			var ship: Dictionary = ships[ship_id]
			if bool(ship["alive"]) and ship["cell"] == beacon and not bool(ship.get("suppressed", false)):
				controlling_teams[int(ship["team"])] = true
		if controlling_teams.size() == 1:
			var team := int(controlling_teams.keys()[0])
			beacon_score[team] = int(beacon_score[team]) + 1

	for ship_id in ships:
		ships[ship_id]["destabilized_by_team"] = -1
		ships[ship_id]["suppressed"] = false

	if int(beacon_score[0]) >= SCORE_TO_WIN or int(beacon_score[1]) >= SCORE_TO_WIN:
		_set_score_result()
		return
	if round_number >= MAX_ROUNDS:
		_set_score_result()
		return

	round_number += 1
	active_team = 0
	for ship_id in ships:
		if bool(ships[ship_id]["alive"]):
			ships[ship_id]["activated"] = false


func _set_score_result() -> void:
	if int(beacon_score[0]) > int(beacon_score[1]):
		result = "victory"
	elif int(beacon_score[1]) > int(beacon_score[0]):
		result = "defeat"
	else:
		result = "draw"


func _update_elimination_result() -> void:
	var player_alive := not living_ship_ids(0).is_empty()
	var enemy_alive := not living_ship_ids(1).is_empty()
	if player_alive and enemy_alive:
		return
	if player_alive:
		result = "victory"
	elif enemy_alive:
		result = "defeat"
	else:
		result = "draw"


func _resolve_ram(ship_id: String, target_id: String) -> Dictionary:
	var actor: Dictionary = ships[ship_id]
	var target: Dictionary = ships[target_id]
	var outcome := _deal_damage(target_id, 12)
	var self_hit := _deal_damage(ship_id, 5)
	outcome["self_damage"] = int(self_hit.get("damage", 0))
	outcome["collision_damage"] = 0
	outcome["pushed"] = false
	if not bool(target["alive"]):
		return outcome
	var push_cell: Vector2i = target["cell"] + grid.DIRECTIONS[int(actor["facing"])]
	if not BOARD_BOUNDS.has_point(push_cell) or islands.has(push_cell):
		var reef_hit := _deal_damage(target_id, 8)
		outcome["collision_damage"] = int(reef_hit.get("damage", 0))
	elif _living_ship_at(push_cell, target_id) != "":
		var collision_id := _living_ship_at(push_cell, target_id)
		var target_hit := _deal_damage(target_id, 5)
		var collision_hit := _deal_damage(collision_id, 5)
		outcome["collision_damage"] = int(target_hit.get("damage", 0))
		outcome["collision_ship_id"] = collision_id
		outcome["collision_ship_damage"] = int(collision_hit.get("damage", 0))
	else:
		target["cell"] = push_cell
		outcome["pushed"] = true
		outcome["destination"] = push_cell
	if bool(target["alive"]):
		target["destabilized_by_team"] = int(actor["team"])
		outcome["applied_destabilized"] = true
	return outcome


func _deal_damage(target_id: String, raw_damage: int) -> Dictionary:
	var target: Dictionary = ships[target_id]
	var reduction := maxi(6 if bool(target.get("braced", false)) else 0, 8 if str(target.get("guard_source", "")) != "" else 0)
	var damage := maxi(1, raw_damage - reduction)
	if reduction > 0:
		target["braced"] = false
		target["guard_source"] = ""
	target["hp"] = maxi(0, int(target["hp"]) - damage)
	var sunk := int(target["hp"]) <= 0
	if sunk:
		target["alive"] = false
		target["activated"] = true
		_clear_guards_from_source(target_id)
	else:
		target["suppressed"] = true
	return {
		"raw_damage": raw_damage,
		"reduction": reduction,
		"damage": damage,
		"target_hp": int(target["hp"]),
		"sunk": sunk,
		"applied_suppression": not sunk,
	}


func _validate_active_ship(ship_id: String) -> Dictionary:
	if result != "":
		return _reject("battle_over")
	if active_ship_id != ship_id:
		return _reject("not_active_ship")
	var ship := get_ship(ship_id)
	if ship.is_empty() or not bool(ship.get("alive", false)):
		return _reject("invalid_ship")
	return {"ok": true, "reason": ""}


func _validate_side_target(ship_id: String, target_id: String, side: String, max_range: int) -> Dictionary:
	var ship: Dictionary = ships[ship_id]
	var target := get_ship(target_id)
	if target.is_empty() or not bool(target.get("alive", false)):
		return _reject("invalid_target")
	if int(target["team"]) == int(ship["team"]):
		return _reject("friendly_target")
	if grid.distance(ship["cell"], target["cell"]) > max_range:
		return _reject("out_of_range")
	if not _cell_in_side_arc(ship, target["cell"], side):
		return _reject("outside_arc")
	if not _has_line_of_sight(ship_id, target_id):
		return _reject("blocked_line")
	return {"ok": true, "reason": ""}


func _validate_ram(ship_id: String, target_id: String) -> Dictionary:
	var ship: Dictionary = ships[ship_id]
	var target := get_ship(target_id)
	if target.is_empty() or not bool(target.get("alive", false)):
		return _reject("invalid_target")
	if int(target["team"]) == int(ship["team"]):
		return _reject("friendly_target")
	var front_cell: Vector2i = ship["cell"] + grid.DIRECTIONS[int(ship["facing"])]
	if target["cell"] != front_cell:
		return _reject("ram_requires_front")
	return {"ok": true, "reason": ""}


func _cell_in_side_arc(ship: Dictionary, cell: Vector2i, side: String) -> bool:
	var forward := Vector2(grid.DIRECTIONS[int(ship["facing"])]).normalized()
	var right := Vector2(-forward.y, forward.x)
	var relative := Vector2(cell - Vector2i(ship["cell"]))
	var forward_projection := relative.dot(forward)
	var side_projection := relative.dot(right)
	if absf(side_projection) <= 0.001 or absf(forward_projection) > absf(side_projection) + 0.001:
		return false
	if side == "port":
		return side_projection < -0.001
	if side == "starboard":
		return side_projection > 0.001
	return true


func _has_line_of_sight(ship_id: String, target_id: String) -> bool:
	var ship: Dictionary = ships[ship_id]
	var target: Dictionary = ships[target_id]
	var line_cells := grid.line(ship["cell"], target["cell"])
	for index in range(1, line_cells.size() - 1):
		var cell: Vector2i = line_cells[index]
		if islands.has(cell) or _living_ship_at(cell, ship_id) != "":
			return false
	return true


func _is_stern_hit(attacker_cell: Vector2i, target: Dictionary) -> bool:
	var forward := Vector2(grid.DIRECTIONS[int(target["facing"])]).normalized()
	var right := Vector2(-forward.y, forward.x)
	var relative := Vector2(attacker_cell - Vector2i(target["cell"]))
	var forward_projection := relative.dot(forward)
	var side_projection := relative.dot(right)
	return forward_projection < -0.001 and absf(forward_projection) + 0.001 >= absf(side_projection)


func _blocked_cells(excluded_ship_id: String) -> Dictionary:
	var blocked := islands.duplicate()
	for ship_id in ships:
		var ship: Dictionary = ships[ship_id]
		if ship_id != excluded_ship_id and bool(ship["alive"]):
			blocked[ship["cell"]] = true
	return blocked


func _living_ship_at(cell: Vector2i, excluded_ship_id: String = "") -> String:
	for ship_id_value in ships:
		var ship_id := str(ship_id_value)
		var ship: Dictionary = ships[ship_id]
		if ship_id != excluded_ship_id and bool(ship["alive"]) and ship["cell"] == cell:
			return ship_id
	return ""


func _clear_guards_from_source(source_id: String) -> void:
	for ship_id in ships:
		if str(ships[ship_id].get("guard_source", "")) == source_id:
			ships[ship_id]["guard_source"] = ""


func _append_maneuver(result_value: Array[Dictionary], seen: Dictionary, command: Dictionary) -> void:
	var key := "%s:%s:%s" % [command["kind"], command.get("cells", []), command["facing"]]
	if seen.has(key):
		return
	seen[key] = true
	result_value.append(command)


func _same_maneuver(left: Dictionary, right: Dictionary) -> bool:
	return (
		str(left.get("kind", "")) == str(right.get("kind", ""))
		and left.get("cells", []) == right.get("cells", [])
		and int(left.get("facing", -1)) == int(right.get("facing", -2))
	)


func _make_ship(ship_id: String, team: int, display_name: String, class_id: String, cell: Vector2i, facing: int) -> Dictionary:
	var class_data: Dictionary = CLASS_DATA[class_id]
	return {
		"id": ship_id,
		"team": team,
		"name": display_name,
		"class_id": class_id,
		"class_name": str(class_data["display_name"]),
		"cell": cell,
		"facing": facing,
		"hp": int(class_data["hp"]),
		"max_hp": int(class_data["hp"]),
		"move_range": int(class_data["move_range"]),
		"alive": true,
		"activated": false,
		"ever_activated": false,
		"braced": false,
		"guard_source": "",
		"destabilized_by_team": -1,
		"suppressed": false,
	}


func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
