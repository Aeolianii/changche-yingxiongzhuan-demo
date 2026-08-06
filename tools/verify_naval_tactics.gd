extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_grid()
	_test_battle()
	_test_ai()
	await _test_presentation()
	await _test_controller()
	_finish()


func _test_grid() -> void:
	var script := load("res://scripts/tactics/square_grid.gd")
	_check(script != null, "square-grid script exists")
	if script == null:
		return
	var grid = script.new()
	_check(grid.distance(Vector2i(0, 0), Vector2i(3, 2)) == 3, "diagonal distance uses square-grid range")
	var center: Vector2 = grid.cell_to_pixel(Vector2i(2, 3), Vector2(100, 80), 64)
	_check(grid.pixel_to_cell(center, Vector2(100, 80), 64) == Vector2i(2, 3), "cell and screen conversion round-trip")
	var paths: Array = grid.sailing_paths(Vector2i(2, 2), 0, 3, true, {}, Rect2i(0, 0, 8, 8))
	_check(_max_path_length(paths) == 3, "grid generates three-cell sailing")
	_check(_contains_reverse(paths), "grid includes one-cell stern escape")


func _test_battle() -> void:
	var script := load("res://scripts/tactics/tactics_battle.gd")
	_check(script != null, "battle rules script exists")
	if script == null:
		return
	var battle = script.new()
	_check(battle.ships.size() == 4 and battle.living_ship_ids(0).size() == 2 and battle.living_ship_ids(1).size() == 2, "battle creates symmetric 2v2 fleets")
	var fast: Dictionary = battle.get_ship("player_1")
	var gunship: Dictionary = battle.get_ship("player_2")
	_check(fast.hp == 50 and gunship.hp == 70 and not fast.has("hull"), "ships expose one exact durability value")
	_check(battle.get_ship("enemy_1").hp == fast.hp and battle.get_ship("enemy_2").hp == gunship.hp, "enemy uses the same ship classes")
	_check(battle.available_actions("player_1") == ["sail", "turn", "disrupt", "ram", "undo", "end_unit"], "fast ship owns mobility disruption and ram")
	_check(battle.available_actions("player_2") == ["sail", "turn", "port", "starboard", "undo", "end_unit"], "gunship owns mobility and broadside")
	_check(_max_path_length(battle.legal_sailing_paths("player_1")) == 3 and _max_path_length(battle.legal_sailing_paths("player_2")) == 2, "classes have fixed three/two-cell movement")
	var turn: Dictionary = battle.turn("player_1", 2)
	_check(turn.get("ok", false) and battle.get_ship("player_1").facing == 2 and battle.get_ship("player_1").ap == 1, "ninety-degree tactical turn costs one AP")

	battle.reset()
	battle.islands = {}
	battle.ships["player_1"].cell = Vector2i(4, 4)
	battle.ships["player_1"].facing = 0
	battle.ships["enemy_1"].cell = Vector2i(4, 2)
	var disrupt: Dictionary = battle.fire_disrupt("player_1", "enemy_1")
	_check(disrupt.get("ok", false) and disrupt.damage == 8 and battle.get_ship("enemy_1").hp == 42, "disrupt shot deals eight durability damage")
	_check(battle.get_ship("enemy_1").destabilized_by_team == 0, "surviving disrupt target becomes destabilized")

	battle.ships["player_2"].cell = Vector2i(6, 4)
	battle.ships["player_2"].facing = 0
	battle.ships["enemy_1"].cell = Vector2i(6, 2)
	var combo: Dictionary = battle.fire("player_2", "enemy_1", "port")
	_check(combo.get("ok", false) and combo.damage == 24 and combo.consumed_destabilized, "coordinated broadside adds six damage and consumes status")

	battle.reset()
	battle.islands = {}
	battle.ships["player_2"].cell = Vector2i(4, 4)
	battle.ships["player_2"].facing = 0
	battle.ships["enemy_1"].cell = Vector2i(4, 2)
	var ordinary: Dictionary = battle.fire("player_2", "enemy_1", "port")
	_check(ordinary.get("ok", false) and ordinary.damage == 18 and battle.get_ship("enemy_1").hp == 32, "ordinary broadside deals eighteen durability damage")

	battle.reset()
	battle.islands = {}
	battle.ships["player_2"].cell = Vector2i(4, 6)
	battle.ships["player_2"].facing = 0
	battle.ships["enemy_1"].cell = Vector2i(4, 1)
	var ap_before_invalid: int = battle.get_ship("player_2").ap
	var out_of_range: Dictionary = battle.fire("player_2", "enemy_1", "port")
	_check(out_of_range.reason == "out_of_range" and battle.get_ship("player_2").ap == ap_before_invalid, "out-of-range attack explains rejection and spends no AP")
	battle.ships["enemy_1"].cell = Vector2i(6, 6)
	_check(battle.can_fire("player_2", "enemy_1", "port").reason == "outside_arc", "wrong-side target reports outside arc")
	battle.ships["enemy_1"].cell = Vector2i(4, 3)
	battle.islands[Vector2i(4, 4)] = true
	_check(battle.can_fire("player_2", "enemy_1", "port").reason == "line_blocked", "island-blocked target reports blocked line")

	battle.reset()
	battle.islands = {}
	battle.ships["player_2"].cell = Vector2i(4, 4)
	battle.ships["player_2"].facing = 0
	battle.ships["enemy_1"].cell = Vector2i(4, 2)
	battle.ships["enemy_1"].facing = 6
	var stern: Dictionary = battle.fire("player_2", "enemy_1", "port")
	_check(stern.get("ok", false) and stern.stern and stern.damage == 24, "stern hit adds six durability damage")

	battle.reset("flagship")
	battle.ships["enemy_2"].hp = 0
	battle._sink_if_needed("enemy_2")
	battle._update_result()
	_check(battle.result == "victory", "flagship mission ends when enemy flagship sinks")


func _test_ai() -> void:
	var battle_script := load("res://scripts/tactics/tactics_battle.gd")
	var ai_script := load("res://scripts/tactics/tactics_ai.gd")
	_check(ai_script != null, "tactics AI script exists")
	if battle_script == null or ai_script == null:
		return
	var battle = battle_script.new()
	var ai = ai_script.new()
	battle.phase = "enemy"
	battle.islands = {}
	battle.ships["enemy_1"].cell = Vector2i(4, 4)
	battle.ships["enemy_1"].facing = 0
	battle.ships["player_1"].cell = Vector2i(4, 2)
	var command: Dictionary = ai.choose_command(battle, "enemy_1")
	_check(command.get("type", "") == "disrupt" and command.get("target_id", "") == "player_1", "fast AI uses its legal disruption weapon")
	battle.reset()
	battle.phase = "enemy"
	var first: Dictionary = ai.choose_command(battle, "enemy_2")
	var second: Dictionary = ai.choose_command(battle, "enemy_2")
	_check(first == second, "AI command selection is deterministic")
	_check(not first.has("intent"), "AI exposes no future-intent preview")


func _test_presentation() -> void:
	var script := load("res://scripts/tactics/naval_combat_presentation.gd")
	_check(script != null, "combat presentation helper parses")
	if script == null:
		return
	var presentation = script.new()
	root.add_child(presentation)
	var attacker := Sprite2D.new()
	var target := Sprite2D.new()
	root.add_child(attacker)
	root.add_child(target)
	attacker.position = Vector2(20, 20)
	target.position = Vector2(100, 20)
	await presentation.play_broadside(attacker, target, "port", {"damage": 24, "stern_bonus": 6})
	_check("耐久 -24" in presentation.last_callouts and "船尾命中 +6" in presentation.last_callouts, "broadside callout shows one durability loss and stern bonus")
	await presentation.play_disrupt(attacker, target, {"damage": 8, "destabilized_applied": true})
	_check(presentation.last_sequence == "disrupt" and "耐久 -8" in presentation.last_callouts and "失衡" in presentation.last_callouts, "disrupt presentation names damage and status")
	await presentation.play_broadside(attacker, target, "starboard", {"damage": 24, "coordinated_bonus": 6, "applied_suppression": true})
	_check("协同齐射 +6" in presentation.last_callouts and "压制航标" in presentation.last_callouts, "shared presentation accepts V3 coordinated and suppression result fields")
	presentation.queue_free()
	attacker.queue_free()
	target.queue_free()
	await process_frame


func _test_controller() -> void:
	var scene: PackedScene = load("res://scenes/naval_tactics.tscn")
	_check(scene != null, "naval tactics scene loads")
	if scene == null:
		return
	var controller = scene.instantiate()
	root.add_child(controller)
	await process_frame
	controller.start_mission_for_test("elimination")
	_check(controller.action_buttons.has("disrupt") and not controller.action_buttons.has("port"), "fast selection shows only fast-ship commands")
	controller.selected_ship_id = "player_2"
	controller._sync_all()
	_check(controller.action_buttons.has("port") and not controller.action_buttons.has("disrupt"), "gunship selection shows only broadside commands")
	_check("耐久" in controller.inspector_label.text and "船帆" not in controller.inspector_label.text, "ship inspector presents one durability value")
	controller._on_action_pressed("port")
	var range_cells: Dictionary = controller._attack_range_cells()
	_check(not range_cells.is_empty(), "attack mode exposes its full theoretical range")
	_check(controller._valid_target_cells().size() <= range_cells.size(), "legal targets are a stronger subset of visible range")
	controller._handle_cell_click(Vector2i(4, 4))
	_check("没有敌船" in controller._feedback_text, "empty range click gives immediate feedback")
	controller._handle_cell_click(controller.battle.get_ship("player_1").cell)
	_check("不能攻击我方" in controller._feedback_text, "friendly attack click gives immediate feedback")
	controller.action_mode = "port"
	controller._perform_player_fire("enemy_1", "port")
	_check(controller._feedback_text != "", "invalid enemy target click gives a reason")
	controller.queue_free()
	await process_frame


func _max_path_length(paths: Array) -> int:
	var maximum := 0
	for value in paths:
		maximum = maxi(maximum, value.get("cells", []).size())
	return maximum


func _contains_reverse(paths: Array) -> bool:
	for value in paths:
		if value.get("reverse", false):
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures.append(label)
		printerr("FAIL: %s" % label)


func _finish() -> void:
	print("VERIFY_FAILURES=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)
