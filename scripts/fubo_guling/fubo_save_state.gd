class_name FuboSaveState
extends RefCounted

const FUBO_TRAVEL := preload("res://scripts/fubo_guling/fubo_travel_session.gd")
const STABLE_PHASES := [0, 1, 3, 5]
const FACINGS := ["up", "left", "down", "right"]


static func make_snapshot(player_position: Vector2, player_facing: String, phase: int, sea_return_context: Dictionary) -> Dictionary:
	if not _is_finite_position(player_position) or player_facing not in FACINGS or phase not in STABLE_PHASES:
		return {}
	var completion := completion_for_phase(phase)
	return {
		"player_position": [player_position.x, player_position.y],
		"player_facing": player_facing,
		"phase": phase,
		"fishing_completed": completion[0],
		"drum_completed": completion[1],
		"sea_return_context": _encode_sea_context(sea_return_context),
	}


static func decode_snapshot(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var snapshot := value as Dictionary
	for key in ["player_position", "player_facing", "phase", "fishing_completed", "drum_completed"]:
		if not snapshot.has(key):
			return {}
	var player_position := _decode_position(snapshot["player_position"])
	if not _is_finite_position(player_position):
		return {}
	if typeof(snapshot["player_facing"]) != TYPE_STRING or str(snapshot["player_facing"]) not in FACINGS:
		return {}
	if not _is_whole_number(snapshot["phase"]):
		return {}
	var phase := int(snapshot["phase"])
	if phase not in STABLE_PHASES:
		return {}
	if typeof(snapshot["fishing_completed"]) != TYPE_BOOL or typeof(snapshot["drum_completed"]) != TYPE_BOOL:
		return {}
	var completion := completion_for_phase(phase)
	if bool(snapshot["fishing_completed"]) != completion[0] or bool(snapshot["drum_completed"]) != completion[1]:
		return {}
	return {
		"player_position": [player_position.x, player_position.y],
		"player_facing": str(snapshot["player_facing"]),
		"phase": phase,
		"fishing_completed": completion[0],
		"drum_completed": completion[1],
		"sea_return_context": _decode_and_encode_sea_context(snapshot.get("sea_return_context", {})),
	}


static func completion_for_phase(phase: int) -> Array[bool]:
	return [phase >= 3, phase >= 5]


static func _decode_position(value: Variant) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if not value is Array or (value as Array).size() != 2:
		return Vector2(INF, INF)
	var values := value as Array
	if not _is_number(values[0]) or not _is_number(values[1]):
		return Vector2(INF, INF)
	return Vector2(float(values[0]), float(values[1]))


static func _encode_sea_context(value: Variant) -> Dictionary:
	var decoded := FUBO_TRAVEL.decode_context(value)
	if decoded.is_empty():
		return _decode_and_encode_sea_context(value)
	return _context_to_storage(decoded)


static func _decode_and_encode_sea_context(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var candidate := (value as Dictionary).duplicate(true)
	if candidate.has("ship_position"):
		var ship_position := _decode_position(candidate["ship_position"])
		if _is_finite_position(ship_position):
			candidate["ship_position"] = ship_position
	for integer_key in ["facing_index", "exploration_stage"]:
		if candidate.has(integer_key) and _is_whole_number(candidate[integer_key]):
			candidate[integer_key] = int(candidate[integer_key])
	var decoded := FUBO_TRAVEL.decode_context(candidate)
	return {} if decoded.is_empty() else _context_to_storage(decoded)


static func _context_to_storage(context: Dictionary) -> Dictionary:
	var ship_position := context["ship_position"] as Vector2
	return {
		"ship_position": [ship_position.x, ship_position.y],
		"facing_index": int(context["facing_index"]),
		"exploration_stage": int(context["exploration_stage"]),
		"lunar_day": float(context["lunar_day"]),
	}


static func sea_context_for_runtime(value: Variant) -> Dictionary:
	var stored := _decode_and_encode_sea_context(value)
	if stored.is_empty():
		return {}
	var runtime := stored.duplicate(true)
	runtime["ship_position"] = _decode_position(runtime["ship_position"])
	return FUBO_TRAVEL.decode_context(runtime)


static func _is_finite_position(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)


static func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _is_whole_number(value: Variant) -> bool:
	return _is_number(value) and is_equal_approx(float(value), round(float(value)))
