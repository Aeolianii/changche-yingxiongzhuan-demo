extends SceneTree

const SAVE_STATE := preload("res://scripts/fubo_guling/fubo_save_state.gd")
const TRAVEL := preload("res://scripts/fubo_guling/fubo_travel_session.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	var sea_context := TRAVEL.make_context(Vector2(4260, 780), 2, 3, 14.75)
	for stable_phase in [0, 1, 3, 5]:
		var snapshot: Dictionary = SAVE_STATE.make_snapshot(Vector2(420, 820), "left", stable_phase, sea_context)
		_check(not snapshot.is_empty(), "Stable phase %d must produce a snapshot." % stable_phase)
		_check(SAVE_STATE.decode_snapshot(snapshot) == snapshot, "Stable phase %d must round-trip." % stable_phase)
		var json_value = JSON.parse_string(JSON.stringify(snapshot))
		var json_snapshot: Dictionary = SAVE_STATE.decode_snapshot(json_value)
		_check(not json_snapshot.is_empty(), "Stable phase %d must survive JSON serialization." % stable_phase)
		_check(not SAVE_STATE.sea_context_for_runtime(json_snapshot.get("sea_return_context", {})).is_empty(), "Sea-return context for phase %d must survive JSON serialization." % stable_phase)

	var drum_available: Dictionary = SAVE_STATE.make_snapshot(Vector2(420, 820), "left", 3, sea_context)
	_check(drum_available.get("fishing_completed", false) and not drum_available.get("drum_completed", true), "DRUM_AVAILABLE must encode fishing completion only.")
	var contradictory := drum_available.duplicate(true)
	contradictory["drum_completed"] = true
	_check(SAVE_STATE.decode_snapshot(contradictory).is_empty(), "Contradictory completion flags must be rejected.")

	for unstable_phase in [2, 4, 6]:
		_check(SAVE_STATE.make_snapshot(Vector2.ZERO, "down", unstable_phase, {}).is_empty(), "Unstable phase %d must not be saved." % unstable_phase)
	_check(SAVE_STATE.make_snapshot(Vector2(INF, 0), "down", 0, {}).is_empty(), "Non-finite positions must be rejected.")
	_check(SAVE_STATE.make_snapshot(Vector2.ZERO, "diagonal", 0, {}).is_empty(), "Unknown facings must be rejected.")

	var no_context: Dictionary = SAVE_STATE.make_snapshot(Vector2.ZERO, "down", 1, {"bad": true})
	_check(no_context.get("sea_return_context", {"bad": true}).is_empty(), "Invalid optional sea context must normalize to an empty dictionary.")
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Fubo save-state codec verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
