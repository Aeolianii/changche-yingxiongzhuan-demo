class_name FuboCanalPuzzle
extends RefCounted

signal changed(states: PackedInt32Array, active_segments: int, spill_branch: int, actions: int)
signal solved(rating: String)
signal allocation_changed(target: PackedInt32Array, levels: PackedInt32Array, blocked_branch: int, round_index: int)
signal round_restarted(round_index: int)
signal round_completed(round_index: int)

enum Direction {
	LEFT,
	CENTER,
	RIGHT,
}

const RELEASE_REJECTED := -1
const RELEASE_MISTAKE := 0
const RELEASE_PROGRESS := 1
const RELEASE_ROUND_COMPLETE := 2
const RELEASE_FINISHED := 3

const INITIAL_STATES := [Direction.LEFT, Direction.RIGHT, Direction.CENTER]
const TARGET_STATES := [Direction.RIGHT, Direction.CENTER, Direction.LEFT]
const DIRECTION_NAMES := ["左引", "直通", "右引"]
const ROUND_TOTALS := [3, 4, 5]
const TARGET_POOLS := [
	[[1, 1, 1], [2, 1, 0], [1, 2, 0]],
	[[2, 2, 0], [3, 1, 0], [1, 3, 0]],
	[[2, 3, 0], [3, 2, 0], [1, 2, 2]],
]

var _rng := RandomNumberGenerator.new()
var _targets: Array[PackedInt32Array] = []
var _blocked := PackedInt32Array()
var _levels := PackedInt32Array([0, 0, 0])
var _round_index := 0
var _water_actions := 0
var _mistakes := 0
var _water_started := false
var _water_finished := false

var _states := PackedInt32Array(INITIAL_STATES)
var _actions := 0
var _completed := false
var _legacy_touched := false


func _init(seed_value: int = -1) -> void:
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	_generate_rounds()


func start() -> void:
	_round_index = 0
	_levels = PackedInt32Array([0, 0, 0])
	_water_actions = 0
	_mistakes = 0
	_water_started = true
	_water_finished = false
	_legacy_touched = false
	_emit_allocation_changed()


func release_to(branch: int) -> int:
	if not _water_started or _water_finished or branch < 0 or branch > 2:
		return RELEASE_REJECTED
	_water_actions += 1
	var target := _targets[_round_index]
	if branch == _blocked[_round_index] or _levels[branch] >= target[branch]:
		_mistakes += 1
		_levels = PackedInt32Array([0, 0, 0])
		_emit_allocation_changed()
		round_restarted.emit(_round_index)
		return RELEASE_MISTAKE
	_levels[branch] += 1
	if _sum_levels() < ROUND_TOTALS[_round_index]:
		_emit_allocation_changed()
		return RELEASE_PROGRESS
	var completed_round := _round_index
	if _round_index >= ROUND_TOTALS.size() - 1:
		_water_finished = true
		_emit_allocation_changed()
		round_completed.emit(completed_round)
		return RELEASE_FINISHED
	_round_index += 1
	_levels = PackedInt32Array([0, 0, 0])
	_emit_allocation_changed()
	round_completed.emit(completed_round)
	return RELEASE_ROUND_COMPLETE


func get_target() -> PackedInt32Array:
	if _round_index < 0 or _round_index >= _targets.size():
		return PackedInt32Array()
	return _targets[_round_index].duplicate()


func get_levels() -> PackedInt32Array:
	return _levels.duplicate()


func get_blocked_branch() -> int:
	if _round_index < 0 or _round_index >= _blocked.size():
		return -1
	return _blocked[_round_index]


func get_round_index() -> int:
	return _round_index


func get_mistakes() -> int:
	return _mistakes


func get_water_actions() -> int:
	return _water_actions


func is_finished() -> bool:
	return _water_finished


func get_targets_for_test() -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []
	for target in _targets:
		result.append(target.duplicate())
	return result


func get_blocked_for_test() -> PackedInt32Array:
	return _blocked.duplicate()


func _generate_rounds() -> void:
	_targets.clear()
	_blocked = PackedInt32Array()
	for round_index in ROUND_TOTALS.size():
		var pool: Array = TARGET_POOLS[round_index]
		var raw: Array = pool[_rng.randi_range(0, pool.size() - 1)]
		var shift := _rng.randi_range(0, 2)
		var target := PackedInt32Array()
		for branch in 3:
			target.append(int(raw[(branch - shift + 3) % 3]))
		_targets.append(target)
		_blocked.append(-1 if round_index == 0 else target.find(0))


func _sum_levels() -> int:
	return _levels[0] + _levels[1] + _levels[2]


func _emit_allocation_changed() -> void:
	allocation_changed.emit(get_target(), get_levels(), get_blocked_branch(), _round_index)


# Legacy three-gate API remains until the map integration task removes its callers.
func rotate_gate(index: int) -> bool:
	if _completed or index < 0 or index >= _states.size():
		return false
	_legacy_touched = true
	_states[index] = (_states[index] + 1) % 3
	_actions += 1
	_evaluate_legacy()
	return true


func reset() -> void:
	_legacy_touched = true
	_states = PackedInt32Array(INITIAL_STATES)
	_actions = 0
	_completed = false
	_emit_legacy_changed()


func set_states_for_test(states: PackedInt32Array, actions: int = 0) -> void:
	if states.size() != 3:
		return
	for state in states:
		if state < Direction.LEFT or state > Direction.RIGHT:
			return
	_legacy_touched = true
	_states = states.duplicate()
	_actions = maxi(0, actions)
	_completed = false
	_evaluate_legacy()


func get_states() -> PackedInt32Array:
	return _states.duplicate()


func get_active_segments() -> int:
	var active := 0
	for index in TARGET_STATES.size():
		if _states[index] != TARGET_STATES[index]:
			break
		active += 1
	return active


func get_spill_branch() -> int:
	var active := get_active_segments()
	if active >= _states.size():
		return -1
	return _states[active]


func get_actions() -> int:
	return _actions


func is_completed() -> bool:
	return _completed


func get_rating() -> String:
	if _legacy_touched:
		if _actions <= 6:
			return "善治"
		if _actions <= 9:
			return "通达"
		return "疏浚"
	if _water_actions <= 12:
		return "善治"
	if _water_actions <= 15:
		return "通达"
	return "疏浚"


func get_direction_name(direction: int) -> String:
	if direction < 0 or direction >= DIRECTION_NAMES.size():
		return "未知"
	return DIRECTION_NAMES[direction]


func _evaluate_legacy() -> void:
	_completed = get_active_segments() == TARGET_STATES.size()
	_emit_legacy_changed()
	if _completed:
		solved.emit(get_rating())


func _emit_legacy_changed() -> void:
	changed.emit(get_states(), get_active_segments(), get_spill_branch(), _actions)
