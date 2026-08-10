extends SceneTree

const CANAL_SCRIPT := preload("res://scripts/fubo_guling/fubo_canal_puzzle.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_seeded_rounds_are_solvable()
	_test_mistake_resets_only_current_round()
	_test_identical_seed_reproduces_challenge()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("Fubo canal game verification passed.")
	quit(0)


func _test_seeded_rounds_are_solvable() -> void:
	var game = CANAL_SCRIPT.new(20260810)
	game.start()
	_check(game.get_round_index() == 0, "Canal must start at round zero.")
	for round_index in 3:
		var target: PackedInt32Array = game.get_target()
		_check(target.size() == 3, "Every canal target must have three branches.")
		_check(target[0] + target[1] + target[2] == [3, 4, 5][round_index], "Canal round total mismatch.")
		var blocked: int = game.get_blocked_branch()
		if round_index == 0:
			_check(blocked == -1, "First canal round must not block a branch.")
		elif blocked >= 0:
			_check(target[blocked] == 0, "A blocked branch must require zero water.")
		for branch in 3:
			for _unit in target[branch]:
				game.release_to(branch)
	_check(game.is_finished(), "Following targets must complete all three rounds.")
	_check(game.get_rating() == "善治", "A mistake-free solution must receive 善治.")


func _test_mistake_resets_only_current_round() -> void:
	var game = CANAL_SCRIPT.new(77)
	game.start()
	var original_target: PackedInt32Array = game.get_target()
	var overflow_branch := 0
	for branch in 3:
		if original_target[branch] > original_target[overflow_branch]:
			overflow_branch = branch
	var result := CANAL_SCRIPT.RELEASE_REJECTED
	for _unit in original_target[overflow_branch] + 1:
		result = game.release_to(overflow_branch)
	_check(result == CANAL_SCRIPT.RELEASE_MISTAKE, "Overflow must report a mistake.")
	_check(game.get_round_index() == 0, "Mistake must retain current round.")
	_check(game.get_levels() == PackedInt32Array([0, 0, 0]), "Mistake must clear only current levels.")
	_check(game.get_target() == original_target, "Mistake must retain current target.")
	_check(game.get_mistakes() == 1, "Mistake count must increment once.")


func _test_identical_seed_reproduces_challenge() -> void:
	var first = CANAL_SCRIPT.new(99)
	var second = CANAL_SCRIPT.new(99)
	_check(first.get_targets_for_test() == second.get_targets_for_test(), "Identical seeds must reproduce canal targets.")
	_check(first.get_blocked_for_test() == second.get_blocked_for_test(), "Identical seeds must reproduce blocked branches.")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
