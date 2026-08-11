class_name FuboFishingGame
extends RefCounted

signal catch_landed(kind: String, value: int)
signal empty_hook_returned

enum State {
	SWINGING,
	EXTENDING,
	RETRACTING,
	FINISHED,
	FAILED,
}

const TARGET_SCORE := 500
const ROUND_SECONDS := 60.0
const PIVOT := Vector2(420, 48)
const REST_LENGTH := 52.0
const MAX_LENGTH := 455.0
const MIN_ANGLE := deg_to_rad(-66.0)
const MAX_ANGLE := deg_to_rad(66.0)
const SWING_SPEED := 1.42
const EXTEND_SPEED := 520.0
const RETRACT_SPEED := 430.0
const ITEM_KINDS := [
	"small_fish", "small_fish", "small_fish", "small_fish",
	"big_fish", "big_fish", "crab", "crab", "boot", "boot",
]
const ITEM_DATA := {
	"small_fish": {"value": 55, "weight": 1.0, "radius": 20.0, "speed": 34.0},
	"big_fish": {"value": 130, "weight": 2.7, "radius": 30.0, "speed": 22.0},
	"crab": {"value": 85, "weight": 1.8, "radius": 23.0, "speed": 16.0},
	"boot": {"value": 10, "weight": 3.2, "radius": 21.0, "speed": 10.0},
}

var _rng := RandomNumberGenerator.new()
var _state := State.SWINGING
var _angle := 0.0
var _swing_direction := 1.0
var _rope_length := REST_LENGTH
var _score := 0
var _time_left := ROUND_SECONDS
var _caught_index := -1
var _empty_casts := 0
var _items: Array[Dictionary] = []


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	restart()


func restart() -> void:
	_state = State.SWINGING
	_angle = 0.0
	_swing_direction = 1.0
	_rope_length = REST_LENGTH
	_score = 0
	_time_left = ROUND_SECONDS
	_caught_index = -1
	_empty_casts = 0
	_items.clear()
	for kind in ITEM_KINDS:
		_items.append(_make_item(String(kind)))


func step(delta: float) -> void:
	if delta <= 0.0 or _state == State.FINISHED or _state == State.FAILED:
		return
	_time_left = maxf(0.0, _time_left - delta)
	_update_items(delta)
	match _state:
		State.SWINGING:
			_angle += _swing_direction * SWING_SPEED * delta
			if _angle >= MAX_ANGLE:
				_angle = MAX_ANGLE
				_swing_direction = -1.0
			elif _angle <= MIN_ANGLE:
				_angle = MIN_ANGLE
				_swing_direction = 1.0
		State.EXTENDING:
			_rope_length = minf(MAX_LENGTH, _rope_length + EXTEND_SPEED * delta)
			_check_hook_collision()
			if _state == State.EXTENDING and _rope_length >= MAX_LENGTH:
				_state = State.RETRACTING
		State.RETRACTING:
			var weight := 1.0
			if _caught_index >= 0:
				weight = float(_items[_caught_index]["weight"])
				_items[_caught_index]["position"] = get_hook_position()
			_rope_length = maxf(REST_LENGTH, _rope_length - RETRACT_SPEED / sqrt(weight) * delta)
			if _rope_length <= REST_LENGTH:
				_finish_retract()
	if _time_left <= 0.0 and _state != State.FINISHED:
		_state = State.FAILED


func cast_hook() -> bool:
	if _state != State.SWINGING:
		return false
	_state = State.EXTENDING
	_caught_index = -1
	return true


func get_hook_position() -> Vector2:
	return PIVOT + Vector2(sin(_angle), cos(_angle)) * _rope_length


func get_state() -> int:
	return _state


func get_angle() -> float:
	return _angle


func get_rope_length() -> float:
	return _rope_length


func get_score() -> int:
	return _score


func get_time_left() -> float:
	return _time_left


func get_items() -> Array[Dictionary]:
	return _items.duplicate(true)


func get_caught_index() -> int:
	return _caught_index


func get_empty_casts() -> int:
	return _empty_casts


func get_rating() -> String:
	if _time_left >= 25.0:
		return "满舱而归"
	if _time_left >= 10.0:
		return "渔获丰足"
	return "顺利收竿"


func set_time_left_for_test(value: float) -> void:
	_time_left = maxf(0.0, value)


func place_item_on_hook_path_for_test(index: int, distance: float, kind: String = "small_fish") -> void:
	if index < 0 or index >= _items.size() or not ITEM_DATA.has(kind):
		return
	var item := _make_item(kind)
	item["position"] = PIVOT + Vector2(sin(_angle), cos(_angle)) * distance
	item["velocity"] = Vector2.ZERO
	_items[index] = item


func _check_hook_collision() -> void:
	var hook_position := get_hook_position()
	for index in _items.size():
		var item := _items[index]
		if not bool(item["active"]):
			continue
		if hook_position.distance_to(Vector2(item["position"])) <= float(item["radius"]) + 12.0:
			_caught_index = index
			item["caught"] = true
			item["position"] = hook_position
			_state = State.RETRACTING
			return


func _finish_retract() -> void:
	if _caught_index >= 0:
		var caught := _items[_caught_index]
		var kind := String(caught["kind"])
		var value := int(caught["value"])
		_score += value
		_items[_caught_index] = _make_item(kind)
		catch_landed.emit(kind, value)
	else:
		_empty_casts += 1
		empty_hook_returned.emit()
	_caught_index = -1
	_rope_length = REST_LENGTH
	if _score >= TARGET_SCORE:
		_state = State.FINISHED
	else:
		_state = State.SWINGING


func _update_items(delta: float) -> void:
	for index in _items.size():
		if index == _caught_index:
			continue
		var item := _items[index]
		if not bool(item["active"]):
			continue
		var position := Vector2(item["position"]) + Vector2(item["velocity"]) * delta
		var radius := float(item["radius"])
		if position.x < 48.0 - radius:
			position.x = 792.0 + radius
		elif position.x > 792.0 + radius:
			position.x = 48.0 - radius
		item["position"] = position


func _make_item(kind: String) -> Dictionary:
	var data: Dictionary = ITEM_DATA[kind]
	var direction := -1.0 if _rng.randi() % 2 == 0 else 1.0
	return {
		"kind": kind,
		"value": int(data["value"]),
		"weight": float(data["weight"]),
		"radius": float(data["radius"]),
		"position": Vector2(_rng.randf_range(75.0, 765.0), _rng.randf_range(165.0, 485.0)),
		"velocity": Vector2(float(data["speed"]) * direction, 0.0),
		"active": true,
		"caught": false,
	}
