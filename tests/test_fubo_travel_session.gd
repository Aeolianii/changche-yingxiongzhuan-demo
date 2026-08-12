extends SceneTree

const TRAVEL := preload("res://scripts/fubo_guling/fubo_travel_session.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var context := TRAVEL.make_context(Vector2(4210, 1135), 2, 3, 8.5)
	_check(TRAVEL.decode_context(context) == context, "Valid Fubo travel context must round-trip.")
	var event_context := TRAVEL.make_context(Vector2(4210, 1135), 2, 3, 8.5, {"crate_event_resolved": true})
	_check(TRAVEL.decode_context(event_context) == event_context, "Fubo travel context must preserve sea-event state.")
	_check(TRAVEL.decode_context({"ship_position": Vector2(INF, 0)}).is_empty(), "Non-finite ship positions must be rejected.")
	_check(TRAVEL.decode_context({
		"ship_position": Vector2(4210, 1135),
		"facing_index": 2,
		"exploration_stage": 3,
		"lunar_day": INF,
	}).is_empty(), "Non-finite lunar days must be rejected.")
	_check(TRAVEL.decode_context({
		"ship_position": Vector2(4210, 1135),
		"facing_index": -1,
		"exploration_stage": 3,
		"lunar_day": 8.5,
	}).is_empty(), "Negative facing indices must be rejected.")
	_check(TRAVEL.decode_context({
		"ship_position": Vector2(4210, 1135),
		"facing_index": 2,
		"exploration_stage": 9,
		"lunar_day": 8.5,
	}).is_empty(), "Out-of-range exploration stages must be rejected.")

	if _failures.is_empty():
		print("Fubo travel-session verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
