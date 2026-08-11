class_name FuboDrumMemory
extends RefCounted

const SUBMIT_REJECTED := -1
const SUBMIT_MISTAKE := 0
const SUBMIT_PROGRESS := 1
const SUBMIT_ROUND_COMPLETE := 2
const SUBMIT_FINISHED := 3

const ROUND_LENGTHS := [4, 5, 6]
const BPMS := [72, 84, 96]
const PERFECT_WINDOW_MS := 120
const LATE_WINDOW_MS := 520
const PASS_WINDOW_MS := LATE_WINDOW_MS
const INTERVAL_SCALES := [0.92, 1.0, 1.08]

var _rng := RandomNumberGenerator.new()
var _seed_value := 0
var _sequences: Array[PackedInt32Array] = []
var _round_bpms := PackedInt32Array()
var _round_intervals: Array[PackedInt32Array] = []
var _started := false
var _accepting := false
var _finished := false
var _round_index := 0
var _input_index := 0
var _mistakes := 0


func _init(seed_value: int = -1) -> void:
	if seed_value < 0:
		_rng.randomize()
		_seed_value = _rng.seed
	else:
		_seed_value = seed_value
		_rng.seed = seed_value
	_generate_rounds()


func start() -> void:
	_started = true
	_accepting = true
	_finished = false
	_round_index = 0
	_input_index = 0
	_mistakes = 0


func begin_input() -> void:
	if _started and not _finished:
		_accepting = true


func submit(drum_index: int, timing_error_ms: int = 0) -> int:
	if not _started or not _accepting or _finished or drum_index < 0 or drum_index > 2:
		return SUBMIT_REJECTED
	var sequence := get_current_sequence()
	if sequence.is_empty():
		return SUBMIT_REJECTED
	if drum_index != sequence[_input_index] or timing_error_ms > LATE_WINDOW_MS:
		_input_index = 0
		_mistakes += 1
		return SUBMIT_MISTAKE
	_input_index += 1
	if _input_index < sequence.size():
		return SUBMIT_PROGRESS
	_round_index += 1
	_input_index = 0
	if _round_index >= _sequences.size():
		_finished = true
		_accepting = false
		return SUBMIT_FINISHED
	return SUBMIT_ROUND_COMPLETE


func get_current_sequence() -> PackedInt32Array:
	if _round_index < 0 or _round_index >= _sequences.size():
		return PackedInt32Array()
	return _sequences[_round_index].duplicate()


func get_current_intervals_ms() -> PackedInt32Array:
	if _round_index < 0 or _round_index >= _round_intervals.size():
		return PackedInt32Array()
	return _round_intervals[_round_index].duplicate()


func get_current_bpm() -> int:
	if _round_index < 0 or _round_index >= _round_bpms.size():
		return BPMS[1]
	return _round_bpms[_round_index]


func get_sequences_for_test() -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []
	for sequence in _sequences:
		result.append(sequence.duplicate())
	return result


func get_round_bpms_for_test() -> PackedInt32Array:
	return _round_bpms.duplicate()


func get_round_intervals_for_test() -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []
	for intervals in _round_intervals:
		result.append(intervals.duplicate())
	return result


func get_round_tempos_for_test() -> PackedFloat32Array:
	var tempos := PackedFloat32Array()
	for bpm in _round_bpms:
		tempos.append(60.0 / float(bpm))
	return tempos


func get_current_tempo() -> float:
	return 60.0 / float(get_current_bpm())


func get_seed_for_test() -> int:
	return _seed_value


func get_round_index() -> int:
	return _round_index


func get_input_index() -> int:
	return _input_index


func get_mistakes() -> int:
	return _mistakes


func is_finished() -> bool:
	return _finished


func get_timing_label(timing_error_ms: int) -> String:
	if timing_error_ms < -PERFECT_WINDOW_MS:
		return "提前 · 通过"
	if timing_error_ms <= PERFECT_WINDOW_MS:
		return "正拍"
	if timing_error_ms <= LATE_WINDOW_MS:
		return "稍晚 · 通过"
	return "过晚"


func _generate_rounds() -> void:
	_sequences.clear()
	_round_bpms = PackedInt32Array()
	_round_intervals.clear()
	var previous_bpm_index := -1
	for round_index in ROUND_LENGTHS.size():
		var sequence := _generate_sequence(ROUND_LENGTHS[round_index], round_index == ROUND_LENGTHS.size() - 1)
		_sequences.append(sequence)
		var bpm_index := _rng.randi_range(0, BPMS.size() - 1)
		if bpm_index == previous_bpm_index:
			bpm_index = (bpm_index + _rng.randi_range(1, BPMS.size() - 1)) % BPMS.size()
		previous_bpm_index = bpm_index
		var bpm: int = BPMS[bpm_index]
		_round_bpms.append(bpm)
		var base_interval := 60000.0 / float(bpm)
		var intervals := PackedInt32Array()
		for _beat in sequence.size():
			var scale: float = INTERVAL_SCALES[_rng.randi_range(0, INTERVAL_SCALES.size() - 1)]
			intervals.append(roundi(base_interval * scale))
		_round_intervals.append(intervals)


func _generate_sequence(length: int, require_all_drums: bool) -> PackedInt32Array:
	for _attempt in 128:
		var sequence := PackedInt32Array()
		var previous := -1
		for _step in length:
			var next_drum := _rng.randi_range(0, 2)
			if next_drum == previous:
				next_drum = (next_drum + _rng.randi_range(1, 2)) % 3
			sequence.append(next_drum)
			previous = next_drum
		if not require_all_drums or _contains_all_drums(sequence):
			return sequence
	var fallback := PackedInt32Array([0, 1, 2, 0, 1, 2])
	fallback.resize(length)
	return fallback


func _contains_all_drums(sequence: PackedInt32Array) -> bool:
	var seen := [false, false, false]
	for drum_index in sequence:
		seen[drum_index] = true
	return seen[0] and seen[1] and seen[2]
