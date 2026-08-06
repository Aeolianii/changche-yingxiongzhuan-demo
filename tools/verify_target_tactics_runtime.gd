extends SceneTree

var failures := 0


func _init() -> void:
	_run()


func _run() -> void:
	var packed := load("res://scenes/naval_tactics_v3.tscn") as PackedScene
	_check(packed != null, "runtime target scene loads")
	if packed == null:
		_finish()
		return
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	_check(scene.action_box.get_child_count() == 7, "runtime starts with staged maneuver bar")
	scene._on_action_pressed("wait")
	_check(scene.battle.active_ship_id == "player_fast" and scene.battle.maneuver_done, "runtime wait commits one maneuver order")
	_check(scene.action_box.get_child_count() == 4, "runtime swaps to fast combat bar")
	scene._on_action_pressed("brace")
	_check(scene.battle.active_team == 1 and scene.battle.get_ship("player_fast")["activated"], "runtime brace ends friendly activation and gives enemy turn")
	var enemy_start_deadline := Time.get_ticks_msec() + 1000
	while not scene._ai_running and scene.battle.active_team == 1 and Time.get_ticks_msec() < enemy_start_deadline:
		await process_frame
	var enemy_deadline := Time.get_ticks_msec() + 5000
	while scene._ai_running and Time.get_ticks_msec() < enemy_deadline:
		await process_frame
	_check(not scene._ai_running, "one enemy activation completes without hanging")
	_check(scene.battle.active_team == 0, "runtime returns control after one enemy response")
	var enemy_activated := 0
	for ship_id in scene.battle.living_ship_ids(1):
		if bool(scene.battle.get_ship(ship_id)["activated"]):
			enemy_activated += 1
	_check(enemy_activated == 1, "enemy response activates exactly one ship")
	_check(scene.battle.active_ship_id == "", "runtime leaves no dangling active ship")
	_check(not scene.presentation.sequence_history.is_empty(), "runtime enemy response also uses completion-driven movement or combat presentation")
	scene.battle.result = "victory"
	scene._sync_all()
	_check(scene.result_panel.visible and "按 R" in scene.result_label.text, "runtime result panel exposes restart")
	scene.reset_battle()
	_check(scene.battle.round_number == 1 and scene.battle.result == "" and scene.battle.ships.size() == 6, "runtime restart restores fresh 3v3 state")
	scene.presentation.presentation_speed = 0.0
	scene._on_action_pressed("sail")
	scene._handle_cell_click(Vector2i(2, 1))
	await process_frame
	_check("sail" in scene.presentation.sequence_history, "runtime player sail invokes the restored movement presentation")
	_check(scene.ship_sprites["player_fast"].position == scene.battle.grid.cell_to_pixel(Vector2i(2, 1), scene.BOARD_ORIGIN, scene.CELL_SIZE), "runtime sail finishes with sprite and rules position synchronized")
	scene.battle.ships["enemy_fast"]["cell"] = Vector2i(2, 3)
	scene._sync_all()
	var hp_before := int(scene.battle.get_ship("enemy_fast")["hp"])
	scene._on_action_pressed("disrupt")
	scene._handle_cell_click(Vector2i(2, 3))
	await process_frame
	_check("disrupt" in scene.presentation.sequence_history, "runtime player attack invokes the restored projectile and impact presentation")
	_check(int(scene.battle.get_ship("enemy_fast")["hp"]) == hp_before - 8, "runtime presentation does not apply attack damage a second time")
	_check(not scene.presentation_busy, "runtime input lock releases after the player combat presentation")
	scene.queue_free()
	await process_frame

	var maneuver_scene = packed.instantiate()
	root.add_child(maneuver_scene)
	await process_frame
	await process_frame
	maneuver_scene.presentation.presentation_speed = 0.0
	maneuver_scene._on_action_pressed("reverse")
	_check("sail_reverse" in maneuver_scene.presentation.sequence_history and maneuver_scene.battle.get_ship("player_fast")["cell"] == Vector2i(0, 1), "runtime reverse restores the stern movement sequence")
	maneuver_scene.reset_battle()
	maneuver_scene.presentation.sequence_history.clear()
	maneuver_scene._on_action_pressed("turn_1")
	_check("turn" in maneuver_scene.presentation.sequence_history and int(maneuver_scene.battle.get_ship("player_fast")["facing"]) == 1, "runtime rudder command restores the turn and splash sequence")
	maneuver_scene.queue_free()
	await process_frame

	var broadside_scene = packed.instantiate()
	root.add_child(broadside_scene)
	await process_frame
	await process_frame
	broadside_scene.presentation.presentation_speed = 0.0
	broadside_scene.battle.ships["player_gunship"]["cell"] = Vector2i(4, 4)
	broadside_scene.battle.ships["player_gunship"]["facing"] = 0
	broadside_scene.battle.ships["enemy_fast"]["cell"] = Vector2i(4, 2)
	broadside_scene.battle.ships["enemy_fast"]["hp"] = 18
	broadside_scene._sync_all()
	broadside_scene._select_friendly("player_gunship")
	broadside_scene._on_action_pressed("wait")
	broadside_scene._on_action_pressed("broadside_port")
	broadside_scene._handle_cell_click(Vector2i(4, 2))
	_check(broadside_scene.presentation.sequence_history == ["broadside", "sink"], "runtime lethal broadside restores projectile, explosion and sink sequences")
	_check(int(broadside_scene.battle.get_ship("enemy_fast")["hp"]) == 0 and not broadside_scene.ship_sprites["enemy_fast"].visible, "runtime sink finishes at the authoritative dead state")
	broadside_scene.queue_free()
	await process_frame

	var ram_scene = packed.instantiate()
	root.add_child(ram_scene)
	await process_frame
	await process_frame
	ram_scene.presentation.presentation_speed = 0.0
	ram_scene.battle.ships["player_fast"]["cell"] = Vector2i(3, 1)
	ram_scene.battle.ships["player_fast"]["facing"] = 0
	ram_scene.battle.ships["enemy_fast"]["cell"] = Vector2i(4, 1)
	ram_scene._sync_all()
	ram_scene._on_action_pressed("wait")
	ram_scene._on_action_pressed("ram")
	ram_scene._handle_cell_click(Vector2i(4, 1))
	_check("ram" in ram_scene.presentation.sequence_history and ram_scene.battle.get_ship("enemy_fast")["cell"] == Vector2i(5, 1), "runtime ram restores collision presentation and synchronized push")
	ram_scene.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("RUNTIME_VERIFY_FAILURES=%d" % failures)
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		printerr("FAIL: %s" % label)
