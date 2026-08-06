class_name TargetTacticsController
extends Node2D

const BattleScript = preload("res://scripts/tactics_v3/target_tactics_battle.gd")
const AIScript = preload("res://scripts/tactics_v3/target_tactics_ai.gd")
const PresentationScript = preload("res://scripts/tactics/naval_combat_presentation.gd")
const PLAYER_SHIP_TEXTURE = preload("res://assets/sprites/naval_tactics/player_ship.png")
const ENEMY_SHIP_TEXTURE = preload("res://assets/sprites/naval_tactics/enemy_ship.png")
const WATER_TEXTURE = preload("res://assets/sprites/naval_tactics/water_tile.png")

const CELL_SIZE := 62.0
const BOARD_ORIGIN := Vector2(246.0, 104.0)
const BOARD_SIZE := Vector2i(12, 8)
const PLAYER_COLOR := Color("39b8cf")
const ENEMY_COLOR := Color("e25b4d")
const GOLD_COLOR := Color("f2c66d")
const TEXT_COLOR := Color("edf7f4")
const MUTED_COLOR := Color("9eb8bd")
const SEA_A := Color("103e55")
const SEA_B := Color("154a62")
const WATER_TINT := Color(0.34, 0.54, 0.60, 0.72)
const GRID_COLOR := Color(0.48, 0.80, 0.84, 0.23)

var battle = BattleScript.new()
var ai = AIScript.new()
var presentation: NavalCombatPresentation
var presentation_busy := false
var selected_ship_id := "player_fast"
var action_mode := "select"
var hovered_cell := Vector2i(-1, -1)
var ship_sprites: Dictionary = {}
var friendly_entries: Dictionary = {}
var enemy_entries: Dictionary = {}
var phase_label: Label
var round_label: Label
var score_label: Label
var objective_label: Label
var inspector_label: RichTextLabel
var action_context_label: Label
var action_box: HBoxContainer
var feedback_label: Label
var result_panel: ColorRect
var result_label: Label
var _ai_running := false
var _feedback_text := "选择一艘未激活官船，先下机动令。"


func _ready() -> void:
	presentation = PresentationScript.new()
	presentation.name = "NavalCombatPresentation"
	add_child(presentation)
	var game_window := get_window()
	if game_window != null:
		game_window.title = "岭南舰影 · 3v3双航标内部原型"
	set_process(true)
	set_process_unhandled_input(true)
	_build_hud()
	_create_ship_sprites()
	_sync_all()


func _process(_delta: float) -> void:
	var local_mouse: Vector2 = get_local_mouse_position()
	var next_hover: Vector2i = battle.grid.pixel_to_cell(local_mouse, BOARD_ORIGIN, CELL_SIZE)
	if not battle.BOARD_BOUNDS.has_point(next_hover):
		next_hover = Vector2i(-1, -1)
	if next_hover != hovered_cell:
		hovered_cell = next_hover
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if presentation_busy:
			return
		reset_battle()
		get_viewport().set_input_as_handled()
		return
	if presentation_busy:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell: Vector2i = battle.grid.pixel_to_cell(event.position, BOARD_ORIGIN, CELL_SIZE)
		if battle.BOARD_BOUNDS.has_point(cell):
			_handle_cell_click(cell)
			get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("071f2b"))
	draw_rect(Rect2(BOARD_ORIGIN - Vector2(6.0, 6.0), Vector2(BOARD_SIZE) * CELL_SIZE + Vector2(12.0, 12.0)), Color("092d3d"))
	for y in BOARD_SIZE.y:
		for x in BOARD_SIZE.x:
			var cell := Vector2i(x, y)
			var rect := _cell_rect(cell)
			draw_rect(rect, SEA_A if (x + y) % 2 == 0 else SEA_B)
			draw_texture_rect(WATER_TEXTURE, rect, false, WATER_TINT)

	_draw_action_overlays()

	for y in range(BOARD_SIZE.y + 1):
		var start := BOARD_ORIGIN + Vector2(0.0, float(y) * CELL_SIZE)
		draw_line(start, start + Vector2(float(BOARD_SIZE.x) * CELL_SIZE, 0.0), GRID_COLOR, 1.0)
	for x in range(BOARD_SIZE.x + 1):
		var start := BOARD_ORIGIN + Vector2(float(x) * CELL_SIZE, 0.0)
		draw_line(start, start + Vector2(0.0, float(BOARD_SIZE.y) * CELL_SIZE), GRID_COLOR, 1.0)

	for island_cell in battle.islands:
		_draw_island(island_cell)
	for beacon_index in battle.beacons.size():
		_draw_beacon(battle.beacons[beacon_index], beacon_index)

	for ship_id in battle.ships:
		var ship: Dictionary = battle.get_ship(ship_id)
		if bool(ship["alive"]):
			_draw_ship_state(ship_id, ship)

	if hovered_cell.x >= 0:
		draw_rect(_cell_rect(hovered_cell).grow(-2.0), Color(1.0, 1.0, 1.0, 0.05), true)
		draw_rect(_cell_rect(hovered_cell).grow(-2.0), Color(0.86, 0.95, 0.96, 0.38), false, 2.0)


func reset_battle() -> void:
	battle.reset()
	ai = AIScript.new()
	selected_ship_id = "player_fast"
	action_mode = "select"
	hovered_cell = Vector2i(-1, -1)
	_ai_running = false
	presentation_busy = false
	_feedback_text = "选择一艘未激活官船，先下机动令。"
	_sync_all()


func perform_player_wait_for_test(ship_id: String) -> Dictionary:
	if battle.active_ship_id == "":
		var begin_result: Dictionary = battle.begin_activation(ship_id)
		if not bool(begin_result.get("ok", false)):
			return begin_result
	for maneuver_value in battle.legal_maneuvers(ship_id):
		var maneuver: Dictionary = maneuver_value
		if str(maneuver.get("kind", "")) == "wait":
			var outcome: Dictionary = battle.execute_maneuver(ship_id, maneuver)
			_sync_all()
			return outcome
	return {"ok": false, "reason": "wait_unavailable"}


func _handle_cell_click(cell: Vector2i) -> void:
	if _ai_running or battle.result != "":
		return
	if action_mode == "sail":
		var maneuver := _maneuver_ending_at(selected_ship_id, cell)
		if maneuver.is_empty():
			_feedback_text = "该格不在本次航行路径内。浅蓝格才可抵达。"
			_sync_all()
			return
		_commit_maneuver(maneuver)
		return
	if action_mode in ["disrupt", "ram", "broadside_port", "broadside_starboard", "short_cannon", "guard"]:
		var target_id := _ship_at_cell(cell)
		if target_id == "":
			_feedback_text = "该格没有可作为此动作目标的船只。"
			_sync_all()
			return
		_commit_combat(action_mode, target_id)
		return

	var clicked_ship_id := _ship_at_cell(cell)
	if clicked_ship_id == "":
		return
	var clicked: Dictionary = battle.get_ship(clicked_ship_id)
	if int(clicked["team"]) == 0:
		_select_friendly(clicked_ship_id)
	else:
		_inspect_enemy(clicked_ship_id)


func _select_friendly(ship_id: String) -> void:
	if battle.active_ship_id != "" and battle.active_ship_id != ship_id:
		_feedback_text = "请先完成 %s 的本次激活。" % battle.get_ship(battle.active_ship_id)["name"]
		_sync_all()
		return
	selected_ship_id = ship_id
	action_mode = "select"
	var ship: Dictionary = battle.get_ship(ship_id)
	if bool(ship["activated"]):
		_feedback_text = "%s 本回合已经激活。" % ship["name"]
	elif battle.active_team != 0:
		_feedback_text = "敌方正在行动，官船暂时不能下令。"
	else:
		_feedback_text = "已选择 %s：先决定机动令。" % ship["name"]
	_sync_all()


func _inspect_enemy(ship_id: String) -> void:
	selected_ship_id = ship_id
	action_mode = "select"
	_feedback_text = "正在查看敌船公开状态；右侧不会显示敌方下一步意图。"
	_sync_all()


func _on_action_pressed(action_id: String) -> void:
	if _ai_running or presentation_busy or battle.result != "":
		return
	if action_id == "sail":
		action_mode = "sail" if action_mode != "sail" else "select"
		_feedback_text = "点击一个浅蓝可达格确认航行；再次按航行可取消预览。" if action_mode == "sail" else "已取消航行预览。"
		_sync_all()
		return
	if action_id.begins_with("turn_"):
		var delta := int(action_id.trim_prefix("turn_"))
		var selected: Dictionary = battle.get_ship(selected_ship_id)
		var target_facing: int = posmod(int(selected["facing"]) + delta, 8)
		for maneuver_value in battle.legal_maneuvers(selected_ship_id):
			var maneuver: Dictionary = maneuver_value
			if str(maneuver.get("kind", "")) == "turn" and int(maneuver.get("facing", -1)) == target_facing:
				_commit_maneuver(maneuver)
				return
		_feedback_text = "当前不能完成该方向转舵。"
		_sync_all()
		return
	if action_id in ["reverse", "wait"]:
		for maneuver_value in battle.legal_maneuvers(selected_ship_id):
			var maneuver: Dictionary = maneuver_value
			if str(maneuver.get("kind", "")) == action_id:
				_commit_maneuver(maneuver)
				return
		_feedback_text = "船尾被阻挡，当前不能倒船。" if action_id == "reverse" else "当前不能稳舵待命。"
		_sync_all()
		return
	if action_id in ["brace", "end_activation"]:
		_commit_combat(action_id, "")
		return
	if action_id in ["disrupt", "ram", "broadside_port", "broadside_starboard", "short_cannon", "guard"]:
		action_mode = action_id if action_mode != action_id else "select"
		_feedback_text = _target_prompt(action_mode) if action_mode != "select" else "已取消目标选择。"
		_sync_all()


func _commit_maneuver(maneuver: Dictionary) -> void:
	if presentation_busy:
		return
	var selected := battle.get_ship(selected_ship_id)
	if selected.is_empty() or int(selected.get("team", 1)) != 0:
		_feedback_text = "请先从左侧选择一艘官船。"
		_sync_all()
		return
	if battle.active_ship_id == "":
		var begin_result: Dictionary = battle.begin_activation(selected_ship_id)
		if not bool(begin_result.get("ok", false)):
			_feedback_text = _reason_text(str(begin_result.get("reason", "")))
			_sync_all()
			return
	var sprite: Sprite2D = ship_sprites.get(selected_ship_id)
	var visual_start: float = sprite.rotation if is_instance_valid(sprite) else _facing_rotation(int(selected.get("facing", 0)))
	var outcome: Dictionary = battle.execute_maneuver(selected_ship_id, maneuver)
	if not bool(outcome.get("ok", false)):
		_feedback_text = _reason_text(str(outcome.get("reason", "")))
	else:
		presentation_busy = true
		_feedback_text = "%s完成%s；现在选择一份战斗令。" % [selected["name"], _maneuver_name(str(outcome["kind"]))]
	action_mode = "select"
	_sync_presentation_state()
	if bool(outcome.get("ok", false)):
		var kind := str(outcome.get("kind", "wait"))
		if kind in ["sail", "sail_turn", "reverse"]:
			var path_centers: Array[Vector2] = []
			for cell_value in maneuver.get("cells", []):
				path_centers.append(battle.grid.cell_to_pixel(cell_value, BOARD_ORIGIN, CELL_SIZE))
			await presentation.play_sail(sprite, path_centers, _facing_rotation(int(outcome["facing"])), kind == "reverse")
		elif kind == "turn":
			var canonical_rotation := _facing_rotation(int(outcome["facing"]))
			var shortest_rotation := visual_start + wrapf(canonical_rotation - visual_start, -PI, PI)
			await presentation.play_turn(sprite, shortest_rotation)
		presentation_busy = false
	_sync_all()


func _commit_combat(action_id: String, target_id: String) -> void:
	if presentation_busy:
		return
	if battle.active_ship_id == "" or battle.active_ship_id != selected_ship_id:
		_feedback_text = "必须先为当前官船完成一份机动令。"
		_sync_all()
		return
	var validation: Dictionary = battle.can_combat_action(selected_ship_id, action_id, target_id)
	if not bool(validation.get("ok", false)):
		_feedback_text = _reason_text(str(validation.get("reason", "")))
		_sync_all()
		return
	var actor_name := str(battle.get_ship(selected_ship_id)["name"])
	var target_name := str(battle.get_ship(target_id).get("name", "")) if target_id != "" else ""
	var attacker_id := selected_ship_id
	var target_before: Dictionary = battle.get_ship(target_id).duplicate(true) if target_id != "" else {}
	var outcome: Dictionary = battle.execute_combat_action(selected_ship_id, action_id, target_id)
	_feedback_text = _combat_outcome_text(actor_name, target_name, action_id, outcome)
	action_mode = "select"
	var animated_action := action_id in ["disrupt", "ram", "broadside_port", "broadside_starboard", "short_cannon"] and target_id != ""
	if animated_action:
		presentation_busy = true
		_sync_presentation_state()
		match action_id:
			"disrupt", "short_cannon":
				await presentation.play_disrupt(ship_sprites[attacker_id], ship_sprites[target_id], outcome)
			"broadside_port", "broadside_starboard":
				var side := "port" if action_id == "broadside_port" else "starboard"
				await presentation.play_broadside(ship_sprites[attacker_id], ship_sprites[target_id], side, outcome)
			"ram":
				var ram_view := outcome.duplicate(true)
				ram_view["damage"] = int(outcome.get("damage", 0)) + int(outcome.get("collision_damage", 0))
				ram_view["collision"] = "ship" if str(outcome.get("collision_ship_id", "")) != "" else ("open" if bool(outcome.get("pushed", false)) else "obstacle")
				var target_after: Dictionary = battle.get_ship(target_id)
				var movement_view := {
					"attacker_position": ship_sprites[attacker_id].position,
					"target_position": battle.grid.cell_to_pixel(target_after.get("cell", target_before.get("cell", Vector2i.ZERO)), BOARD_ORIGIN, CELL_SIZE),
				}
				await presentation.play_ram(ship_sprites[attacker_id], ship_sprites[target_id], movement_view, ram_view)
		if bool(outcome.get("sunk", false)):
			await presentation.play_sink(ship_sprites[target_id])
		presentation_busy = false
	_sync_all()
	if battle.result == "" and battle.active_team == 1:
		_run_enemy_activation.call_deferred()
	elif battle.result == "" and battle.active_team == 0:
		_select_next_player_ship()


func _run_enemy_activation() -> void:
	if _ai_running or battle.result != "" or battle.active_team != 1:
		return
	_ai_running = true
	_sync_all()
	await _presentation_pause(0.18)
	var ship_id := ai.choose_ship(battle)
	if ship_id == "":
		_ai_running = false
		return
	var begin_result: Dictionary = battle.begin_activation(ship_id)
	if not bool(begin_result.get("ok", false)):
		_ai_running = false
		_feedback_text = "敌方行动未能开始：%s" % _reason_text(str(begin_result.get("reason", "")))
		_sync_all()
		return
	var ship_name := str(battle.get_ship(ship_id)["name"])
	var maneuver := ai.choose_maneuver(battle, ship_id)
	var enemy_sprite: Sprite2D = ship_sprites.get(ship_id)
	var visual_start: float = enemy_sprite.rotation if is_instance_valid(enemy_sprite) else _facing_rotation(int(battle.get_ship(ship_id).get("facing", 0)))
	var maneuver_result: Dictionary = battle.execute_maneuver(ship_id, maneuver)
	_feedback_text = "敌方 %s 完成%s。" % [ship_name, _maneuver_name(str(maneuver_result.get("kind", "wait")))]
	var maneuver_kind := str(maneuver_result.get("kind", "wait"))
	if maneuver_kind in ["sail", "sail_turn", "reverse", "turn"]:
		presentation_busy = true
		_sync_presentation_state()
		if maneuver_kind in ["sail", "sail_turn", "reverse"]:
			var path_centers: Array[Vector2] = []
			for cell_value in maneuver.get("cells", []):
				path_centers.append(battle.grid.cell_to_pixel(cell_value, BOARD_ORIGIN, CELL_SIZE))
			await presentation.play_sail(enemy_sprite, path_centers, _facing_rotation(int(maneuver_result["facing"])), maneuver_kind == "reverse")
		else:
			var canonical_rotation := _facing_rotation(int(maneuver_result["facing"]))
			var shortest_rotation := visual_start + wrapf(canonical_rotation - visual_start, -PI, PI)
			await presentation.play_turn(enemy_sprite, shortest_rotation)
		presentation_busy = false
	_sync_all()
	await _presentation_pause(0.08)
	var combat := ai.choose_combat(battle, ship_id)
	var action_id := str(combat.get("action", "end_activation"))
	var target_id := str(combat.get("target_id", ""))
	var target_name := str(battle.get_ship(target_id).get("name", "")) if target_id != "" else ""
	var target_before: Dictionary = battle.get_ship(target_id).duplicate(true) if target_id != "" else {}
	var outcome: Dictionary = battle.execute_combat_action(ship_id, action_id, target_id)
	_feedback_text = _combat_outcome_text("敌方 %s" % ship_name, target_name, action_id, outcome)
	var animated_action := action_id in ["disrupt", "ram", "broadside_port", "broadside_starboard", "short_cannon"] and target_id != ""
	if animated_action:
		presentation_busy = true
		_sync_presentation_state()
		match action_id:
			"disrupt", "short_cannon":
				await presentation.play_disrupt(ship_sprites[ship_id], ship_sprites[target_id], outcome)
			"broadside_port", "broadside_starboard":
				var side := "port" if action_id == "broadside_port" else "starboard"
				await presentation.play_broadside(ship_sprites[ship_id], ship_sprites[target_id], side, outcome)
			"ram":
				var ram_view := outcome.duplicate(true)
				ram_view["damage"] = int(outcome.get("damage", 0)) + int(outcome.get("collision_damage", 0))
				ram_view["collision"] = "ship" if str(outcome.get("collision_ship_id", "")) != "" else ("open" if bool(outcome.get("pushed", false)) else "obstacle")
				var target_after: Dictionary = battle.get_ship(target_id)
				var movement_view := {
					"attacker_position": ship_sprites[ship_id].position,
					"target_position": battle.grid.cell_to_pixel(target_after.get("cell", target_before.get("cell", Vector2i.ZERO)), BOARD_ORIGIN, CELL_SIZE),
				}
				await presentation.play_ram(ship_sprites[ship_id], ship_sprites[target_id], movement_view, ram_view)
		if bool(outcome.get("sunk", false)):
			await presentation.play_sink(ship_sprites[target_id])
		presentation_busy = false
	_sync_all()
	await _presentation_pause(0.08)
	_ai_running = false
	if battle.result == "" and battle.active_team == 1:
		_run_enemy_activation.call_deferred()
	elif battle.result == "":
		_select_next_player_ship()
	_sync_all()


func _presentation_pause(duration: float) -> void:
	if presentation == null or presentation.presentation_speed <= 0.0:
		return
	await get_tree().create_timer(duration * presentation.presentation_speed).timeout


func _select_next_player_ship() -> void:
	var candidates := battle.unactivated_ship_ids(0)
	if candidates.is_empty():
		return
	if selected_ship_id not in candidates:
		selected_ship_id = candidates[0]
	action_mode = "select"


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(hud)

	var top_panel := _panel(Color(0.02, 0.075, 0.105, 0.97), Rect2(0.0, 0.0, 1280.0, 88.0))
	hud.add_child(top_panel)
	var title := _label("岭南舰影  ·  3v3 双航标验证版", 24, TEXT_COLOR)
	title.position = Vector2(20.0, 12.0)
	title.size = Vector2(440.0, 32.0)
	top_panel.add_child(title)
	phase_label = _label("", 17, PLAYER_COLOR)
	phase_label.position = Vector2(22.0, 51.0)
	top_panel.add_child(phase_label)
	round_label = _label("", 17, TEXT_COLOR)
	round_label.position = Vector2(174.0, 51.0)
	top_panel.add_child(round_label)
	score_label = _label("", 21, GOLD_COLOR)
	score_label.position = Vector2(338.0, 48.0)
	score_label.size = Vector2(250.0, 30.0)
	top_panel.add_child(score_label)
	objective_label = _label("双航标：未受压制者独占 +1分，先到5分；最多6回合", 15, MUTED_COLOR)
	objective_label.position = Vector2(548.0, 50.0)
	objective_label.size = Vector2(700.0, 26.0)
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_panel.add_child(objective_label)
	feedback_label = _label("", 15, Color("f6d27a"))
	feedback_label.position = Vector2(486.0, 13.0)
	feedback_label.size = Vector2(760.0, 28.0)
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feedback_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_panel.add_child(feedback_label)

	var left_panel := _panel(Color(0.02, 0.075, 0.105, 0.95), Rect2(10.0, 100.0, 224.0, 500.0))
	hud.add_child(left_panel)
	var friendly_title := _label("● 岭海水师 · 我方", 18, PLAYER_COLOR)
	friendly_title.position = Vector2(12.0, 10.0)
	left_panel.add_child(friendly_title)
	var friendly_box := VBoxContainer.new()
	friendly_box.position = Vector2(10.0, 45.0)
	friendly_box.size = Vector2(204.0, 350.0)
	friendly_box.add_theme_constant_override("separation", 8)
	left_panel.add_child(friendly_box)
	for ship_id in ["player_fast", "player_gunship", "player_escort"]:
		var entry := _roster_button(Vector2(204.0, 102.0), 13)
		entry.pressed.connect(_select_friendly.bind(ship_id))
		friendly_box.add_child(entry)
		friendly_entries[ship_id] = entry
	var order_hint := _label("每次：机动令 → 战斗令\n每船每回合只激活一次\n敌我交替，不显示敌方意图", 13, MUTED_COLOR)
	order_hint.position = Vector2(13.0, 411.0)
	order_hint.size = Vector2(198.0, 78.0)
	order_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_panel.add_child(order_hint)

	var right_panel := _panel(Color(0.02, 0.075, 0.105, 0.95), Rect2(1002.0, 100.0, 268.0, 500.0))
	hud.add_child(right_panel)
	var enemy_title := _label("◆ 海盗编队 · 敌方", 18, ENEMY_COLOR)
	enemy_title.position = Vector2(12.0, 10.0)
	right_panel.add_child(enemy_title)
	var enemy_box := VBoxContainer.new()
	enemy_box.position = Vector2(10.0, 43.0)
	enemy_box.size = Vector2(248.0, 210.0)
	enemy_box.add_theme_constant_override("separation", 6)
	right_panel.add_child(enemy_box)
	for ship_id in ["enemy_fast", "enemy_gunship", "enemy_escort"]:
		var entry := _roster_button(Vector2(248.0, 64.0), 12)
		entry.pressed.connect(_inspect_enemy.bind(ship_id))
		enemy_box.add_child(entry)
		enemy_entries[ship_id] = entry
	var divider := ColorRect.new()
	divider.color = Color(0.4, 0.68, 0.72, 0.22)
	divider.position = Vector2(12.0, 260.0)
	divider.size = Vector2(244.0, 1.0)
	right_panel.add_child(divider)
	var inspector_title := _label("公开船只状态", 16, TEXT_COLOR)
	inspector_title.position = Vector2(12.0, 270.0)
	right_panel.add_child(inspector_title)
	inspector_label = RichTextLabel.new()
	inspector_label.bbcode_enabled = true
	inspector_label.scroll_active = false
	inspector_label.position = Vector2(12.0, 302.0)
	inspector_label.size = Vector2(244.0, 187.0)
	inspector_label.add_theme_font_size_override("normal_font_size", 13)
	inspector_label.add_theme_font_size_override("bold_font_size", 15)
	inspector_label.add_theme_constant_override("line_separation", 3)
	right_panel.add_child(inspector_label)

	var bottom_panel := _panel(Color(0.02, 0.075, 0.105, 0.97), Rect2(246.0, 610.0, 744.0, 100.0))
	hud.add_child(bottom_panel)
	action_context_label = _label("", 14, TEXT_COLOR)
	action_context_label.position = Vector2(12.0, 7.0)
	action_context_label.size = Vector2(720.0, 25.0)
	bottom_panel.add_child(action_context_label)
	action_box = HBoxContainer.new()
	action_box.position = Vector2(10.0, 34.0)
	action_box.size = Vector2(724.0, 58.0)
	action_box.add_theme_constant_override("separation", 6)
	bottom_panel.add_child(action_box)

	result_panel = _panel(Color(0.01, 0.035, 0.05, 0.98), Rect2(390.0, 215.0, 500.0, 290.0))
	result_panel.visible = false
	hud.add_child(result_panel)
	result_label = _label("", 27, TEXT_COLOR)
	result_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_panel.add_child(result_label)


func _create_ship_sprites() -> void:
	for ship_id in battle.ships:
		var ship: Dictionary = battle.get_ship(ship_id)
		var sprite := Sprite2D.new()
		sprite.name = ship_id
		sprite.texture = PLAYER_SHIP_TEXTURE if int(ship["team"]) == 0 else ENEMY_SHIP_TEXTURE
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.z_index = 5
		add_child(sprite)
		ship_sprites[ship_id] = sprite


func _sync_all() -> void:
	_sync_ship_sprites()
	_sync_presentation_state()


func _sync_presentation_state() -> void:
	_sync_hud()
	_rebuild_action_bar()
	queue_redraw()


func _sync_ship_sprites() -> void:
	for ship_id in ship_sprites:
		var sprite: Sprite2D = ship_sprites[ship_id]
		var ship: Dictionary = battle.get_ship(ship_id)
		sprite.visible = not ship.is_empty() and bool(ship["alive"])
		if not sprite.visible:
			continue
		sprite.position = battle.grid.cell_to_pixel(ship["cell"], BOARD_ORIGIN, CELL_SIZE)
		sprite.rotation = _facing_rotation(int(ship["facing"]))
		var scale_value: float = float({"fast": 0.42, "gunship": 0.54, "escort": 0.64}.get(str(ship["class_id"]), 0.5))
		sprite.scale = Vector2.ONE * float(scale_value)
		var dimmed := bool(ship["activated"]) or not bool(ship["alive"])
		sprite.modulate = Color(0.48, 0.58, 0.62, 0.78) if dimmed else Color.WHITE


func _sync_hud() -> void:
	phase_label.text = "我方选择一艘船" if battle.active_team == 0 else "敌方正在激活一艘船"
	phase_label.modulate = PLAYER_COLOR if battle.active_team == 0 else ENEMY_COLOR
	round_label.text = "第 %d / %d 回合" % [battle.round_number, battle.MAX_ROUNDS]
	score_label.text = "官船 %d  :  %d 海盗" % [battle.beacon_score[0], battle.beacon_score[1]]
	feedback_label.text = _feedback_text
	for ship_id in friendly_entries:
		_sync_roster_entry(friendly_entries[ship_id], ship_id, true)
	for ship_id in enemy_entries:
		_sync_roster_entry(enemy_entries[ship_id], ship_id, false)
	_sync_inspector()
	result_panel.visible = battle.result != ""
	if battle.result == "victory":
		result_label.text = "任务完成\n\n官船控制海域\n最终航标 %d : %d\n\n按 R 重新开始" % [battle.beacon_score[0], battle.beacon_score[1]]
		result_label.modulate = Color("8fe3ba")
	elif battle.result == "defeat":
		result_label.text = "任务失败\n\n海盗突破航标防线\n最终航标 %d : %d\n\n按 R 重新开始" % [battle.beacon_score[0], battle.beacon_score[1]]
		result_label.modulate = Color("f18c7e")
	elif battle.result == "draw":
		result_label.text = "平局\n\n第六回合双方同分\n最终航标 %d : %d\n\n按 R 重新开始" % [battle.beacon_score[0], battle.beacon_score[1]]
		result_label.modulate = GOLD_COLOR


func _sync_roster_entry(entry: Button, ship_id: String, friendly: bool) -> void:
	var ship: Dictionary = battle.get_ship(ship_id)
	var state_text := "已沉没"
	if bool(ship["alive"]):
		if battle.active_ship_id == ship_id:
			state_text = "行动中"
		elif bool(ship["activated"]):
			state_text = "已激活"
		else:
			state_text = "待命"
	var emblem := "●" if friendly else "◆"
	var class_mark := str(battle.CLASS_DATA[str(ship["class_id"])]["short_name"])
	var statuses := _status_text(ship)
	entry.text = "%s [%s] %s  ·  %s\n耐久 %d/%d  %s" % [
		emblem, class_mark, ship["name"], state_text, ship["hp"], ship["max_hp"], statuses,
	]
	entry.disabled = not bool(ship["alive"])
	entry.modulate = Color.WHITE if bool(ship["alive"]) else Color(0.42, 0.46, 0.48)
	var selected := ship_id == selected_ship_id
	entry.add_theme_color_override("font_color", (PLAYER_COLOR if friendly else ENEMY_COLOR) if selected else TEXT_COLOR)


func _sync_inspector() -> void:
	var ship := battle.get_ship(selected_ship_id)
	if ship.is_empty():
		inspector_label.text = "没有选中船只"
		return
	var friendly := int(ship["team"]) == 0
	var faction := "● 岭海水师" if friendly else "◆ 海盗编队"
	var color := "#39b8cf" if friendly else "#e25b4d"
	var activation := "已沉没" if not bool(ship["alive"]) else ("行动中" if battle.active_ship_id == selected_ship_id else ("已激活" if bool(ship["activated"]) else "本回合待命"))
	var actions: Array[String] = []
	for action_id in battle.available_combat_actions(selected_ship_id):
		if action_id not in ["brace", "end_activation"]:
			actions.append(_action_short_name(action_id))
	inspector_label.text = "[font_size=16][b]%s[/b][/font_size]\n[color=%s]%s[/color] · %s\n耐久 [b]%d / %d[/b]  %s\n%s\n移动 %d格 · 朝向 %s %s\n职业令 %s\n状态 [color=#f5c86a]%s[/color]" % [
		ship["name"], color, faction, ship["class_name"], ship["hp"], ship["max_hp"], activation,
		_hp_bar(int(ship["hp"]), int(ship["max_hp"])), ship["move_range"], _facing_name(int(ship["facing"])), _facing_arrow(int(ship["facing"])),
		" / ".join(actions), _status_text(ship),
	]


func _rebuild_action_bar() -> void:
	for child in action_box.get_children():
		action_box.remove_child(child)
		child.queue_free()
	action_context_label.text = ""
	if battle.result != "":
		action_context_label.text = "本局已结束，按 R 重新开始。"
		return
	if _ai_running or battle.active_team == 1:
		action_context_label.text = "敌方每次只激活一艘船；仅展示已发生结果，不显示未来意图。"
		return
	var selected := battle.get_ship(selected_ship_id)
	if selected.is_empty() or int(selected.get("team", 1)) != 0:
		action_context_label.text = "正在查看敌船；从左侧选择一艘待命官船下令。"
		return
	if not bool(selected["alive"]):
		action_context_label.text = "该船已经沉没。"
		return
	if bool(selected["activated"]) and battle.active_ship_id != selected_ship_id:
		action_context_label.text = "%s 本回合已经激活，请选择另一艘官船。" % selected["name"]
		return
	if battle.active_ship_id != "" and battle.active_ship_id != selected_ship_id:
		action_context_label.text = "请先完成 %s 的激活。" % battle.get_ship(battle.active_ship_id)["name"]
		return
	if battle.active_ship_id == "" or not battle.maneuver_done:
		action_context_label.text = "① 机动令：选择一项；完成后才能使用战斗令。"
		var specs := [
			["sail", "航行\n1—%d格" % int(selected["move_range"])],
			["turn_-1", "左转\n45°"],
			["turn_1", "右转\n45°"],
			["turn_-2", "左转\n90°"],
			["turn_2", "右转\n90°"],
			["reverse", "倒船\n1格"],
			["wait", "稳舵\n待命"],
		]
		for spec in specs:
			var disabled := false
			if spec[0] == "reverse":
				disabled = not _has_maneuver_kind(selected_ship_id, "reverse")
			_add_action_button(spec[0], spec[1], disabled)
		return

	action_context_label.text = "② 战斗令：本次最多一项；执行后立即结束该船激活。"
	for action_id in battle.available_combat_actions(selected_ship_id):
		_add_action_button(action_id, _action_button_text(action_id), false)


func _add_action_button(action_id: String, text_value: String, disabled: bool) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(96.0, 54.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	button.focus_mode = Control.FOCUS_NONE
	button.toggle_mode = true
	button.disabled = disabled
	button.button_pressed = action_mode == action_id
	button.pressed.connect(_on_action_pressed.bind(action_id))
	action_box.add_child(button)


func _draw_action_overlays() -> void:
	if selected_ship_id == "" or battle.get_ship(selected_ship_id).is_empty():
		return
	if action_mode == "sail":
		for cell in _reachable_destinations(selected_ship_id):
			draw_rect(_cell_rect(cell).grow(-3.0), Color(0.25, 0.81, 0.91, 0.24), true)
			draw_rect(_cell_rect(cell).grow(-3.0), Color(0.39, 0.91, 0.98, 0.72), false, 2.0)
	elif action_mode in ["disrupt", "ram", "broadside_port", "broadside_starboard", "short_cannon", "guard"]:
		for cell in battle.theoretical_range_cells(selected_ship_id, action_mode):
			draw_rect(_cell_rect(cell).grow(-3.0), Color(0.93, 0.45, 0.32, 0.15), true)
		for cell in _valid_target_cells(selected_ship_id, action_mode):
			draw_rect(_cell_rect(cell).grow(-4.0), Color(1.0, 0.69, 0.24, 0.30), true)
			draw_rect(_cell_rect(cell).grow(-4.0), GOLD_COLOR, false, 3.0)
		if hovered_cell.x >= 0 and hovered_cell in _valid_target_cells(selected_ship_id, action_mode):
			var source: Vector2 = battle.grid.cell_to_pixel(battle.get_ship(selected_ship_id)["cell"], BOARD_ORIGIN, CELL_SIZE)
			var target: Vector2 = battle.grid.cell_to_pixel(hovered_cell, BOARD_ORIGIN, CELL_SIZE)
			draw_dashed_line(source, target, GOLD_COLOR, 2.0, 8.0)


func _draw_island(cell: Vector2i) -> void:
	var center: Vector2 = battle.grid.cell_to_pixel(cell, BOARD_ORIGIN, CELL_SIZE)
	draw_circle(center, 25.0, Color("896f4c"))
	draw_circle(center + Vector2(4.0, 4.0), 18.0, Color("536e50"))
	draw_circle(center - Vector2(9.0, 6.0), 7.0, Color("83a56d"))
	draw_arc(center, 27.0, 0.0, TAU, 32, Color(0.72, 0.91, 0.80, 0.45), 2.0)


func _draw_beacon(cell: Vector2i, index: int) -> void:
	var center: Vector2 = battle.grid.cell_to_pixel(cell, BOARD_ORIGIN, CELL_SIZE)
	var controller: int = _beacon_controller(cell)
	var fill: Color = Color(0.96, 0.76, 0.30, 0.16)
	if controller == 0:
		fill = Color(0.22, 0.72, 0.81, 0.28)
	elif controller == 1:
		fill = Color(0.89, 0.31, 0.25, 0.28)
	draw_circle(center, 22.0, fill)
	draw_arc(center, 23.0, 0.0, TAU, 32, GOLD_COLOR, 3.0)
	draw_circle(center, 5.0, GOLD_COLOR)
	draw_string(ThemeDB.fallback_font, center + Vector2(-17.0, -27.0), "航标%s" % ["甲", "乙"][index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, GOLD_COLOR)


func _draw_ship_state(ship_id: String, ship: Dictionary) -> void:
	var center: Vector2 = battle.grid.cell_to_pixel(ship["cell"], BOARD_ORIGIN, CELL_SIZE)
	var color: Color = PLAYER_COLOR if int(ship["team"]) == 0 else ENEMY_COLOR
	if selected_ship_id == ship_id:
		draw_arc(center, 27.0, 0.0, TAU, 36, color, 3.0)
	if battle.active_ship_id == ship_id:
		draw_arc(center, 31.0, 0.0, TAU, 36, GOLD_COLOR, 2.0)
	var bar_rect: Rect2 = Rect2(center + Vector2(-24.0, -31.0), Vector2(48.0, 5.0))
	draw_rect(bar_rect, Color(0.02, 0.05, 0.06, 0.9))
	var ratio: float = float(int(ship["hp"])) / float(int(ship["max_hp"]))
	draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * ratio, bar_rect.size.y)), color)
	draw_rect(bar_rect, Color(0.92, 0.98, 0.97, 0.45), false, 1.0)
	var badge_center: Vector2 = center + Vector2(21.0, 21.0)
	draw_circle(badge_center, 10.0, Color(0.02, 0.07, 0.09, 0.94))
	draw_arc(badge_center, 10.0, 0.0, TAU, 20, color, 2.0)
	draw_string(ThemeDB.fallback_font, badge_center + Vector2(-5.0, 5.0), str(battle.CLASS_DATA[str(ship["class_id"])]["short_name"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, TEXT_COLOR)
	var status_mark := ""
	if int(ship.get("destabilized_by_team", -1)) >= 0:
		status_mark += "失"
	if bool(ship.get("suppressed", false)):
		status_mark += "压"
	if str(ship.get("guard_source", "")) != "":
		status_mark += "护"
	if bool(ship.get("braced", false)):
		status_mark += "备"
	if status_mark != "":
		draw_string(ThemeDB.fallback_font, center + Vector2(-22.0, 33.0), status_mark, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, GOLD_COLOR)
	if bool(ship["activated"]):
		draw_string(ThemeDB.fallback_font, center + Vector2(-7.0, 5.0), "已", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.9, 0.95, 0.95, 0.8))
	if str(ship.get("guard_source", "")) != "" and battle.get_ship(str(ship["guard_source"])).get("alive", false):
		var guard_center: Vector2 = battle.grid.cell_to_pixel(battle.get_ship(str(ship["guard_source"]))["cell"], BOARD_ORIGIN, CELL_SIZE)
		draw_dashed_line(guard_center, center, Color(0.44, 0.91, 0.73, 0.65), 1.5, 6.0)


func _reachable_destinations(ship_id: String) -> Dictionary:
	var result_value: Dictionary = {}
	for maneuver_value in battle.legal_maneuvers(ship_id):
		var maneuver: Dictionary = maneuver_value
		if str(maneuver.get("kind", "")) in ["sail", "sail_turn"]:
			var cells: Array = maneuver.get("cells", [])
			if not cells.is_empty():
				result_value[cells[-1]] = true
	return result_value


func _valid_target_cells(ship_id: String, action_id: String) -> Dictionary:
	var result_value: Dictionary = {}
	for target_id in battle.legal_target_ids(ship_id, action_id):
		result_value[battle.get_ship(target_id)["cell"]] = true
	return result_value


func _maneuver_ending_at(ship_id: String, cell: Vector2i) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for maneuver_value in battle.legal_maneuvers(ship_id):
		var maneuver: Dictionary = maneuver_value
		if str(maneuver.get("kind", "")) not in ["sail", "sail_turn"]:
			continue
		var cells: Array = maneuver.get("cells", [])
		if not cells.is_empty() and cells[-1] == cell:
			candidates.append(maneuver)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_key := "%s:%s:%s" % [left.get("cells", []).size(), left.get("kind", ""), left.get("facing", -1)]
		var right_key := "%s:%s:%s" % [right.get("cells", []).size(), right.get("kind", ""), right.get("facing", -1)]
		return left_key < right_key
	)
	return candidates[0]


func _has_maneuver_kind(ship_id: String, kind: String) -> bool:
	for maneuver_value in battle.legal_maneuvers(ship_id):
		if str(maneuver_value.get("kind", "")) == kind:
			return true
	return false


func _ship_at_cell(cell: Vector2i) -> String:
	for ship_id in battle.ships:
		var ship: Dictionary = battle.get_ship(ship_id)
		if bool(ship["alive"]) and ship["cell"] == cell:
			return str(ship_id)
	return ""


func _beacon_controller(cell: Vector2i) -> int:
	var teams: Dictionary = {}
	for ship_id in battle.ships:
		var ship: Dictionary = battle.get_ship(ship_id)
		if bool(ship["alive"]) and ship["cell"] == cell and not bool(ship.get("suppressed", false)):
			teams[int(ship["team"])] = true
	return int(teams.keys()[0]) if teams.size() == 1 else -1


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(BOARD_ORIGIN + Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE)


func _panel(color: Color, rect: Rect2) -> ColorRect:
	var panel := ColorRect.new()
	panel.color = color
	panel.position = rect.position
	panel.size = rect.size
	return panel


func _label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _roster_button(minimum_size: Vector2, font_size: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = minimum_size
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", font_size)
	button.focus_mode = Control.FOCUS_NONE
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return button


func _hp_bar(value: int, maximum: int) -> String:
	var filled := clampi(roundi(float(value) / float(maximum) * 12.0), 0, 12)
	return "[color=#65d1c5]%s[/color][color=#365861]%s[/color]" % ["■".repeat(filled), "·".repeat(12 - filled)]


func _status_text(ship: Dictionary) -> String:
	var statuses: Array[String] = []
	if int(ship.get("destabilized_by_team", -1)) >= 0:
		statuses.append("失衡")
	if bool(ship.get("suppressed", false)):
		statuses.append("受压制·本轮不计航标")
	if str(ship.get("guard_source", "")) != "":
		statuses.append("护航")
	if bool(ship.get("braced", false)):
		statuses.append("戒备")
	return "正常" if statuses.is_empty() else " / ".join(statuses)


func _action_button_text(action_id: String) -> String:
	return {
		"disrupt": "扰乱射击\n8伤害+失衡",
		"ram": "冲撞\n12伤害+推动",
		"broadside_port": "左舷齐射\n18伤害",
		"broadside_starboard": "右舷齐射\n18伤害",
		"short_cannon": "短炮\n12伤害",
		"guard": "护航令\n下一击-8",
		"brace": "戒备\n下一击-6",
		"end_activation": "结束激活\n放弃战斗令",
	}.get(action_id, action_id)


func _action_short_name(action_id: String) -> String:
	return {
		"disrupt": "扰乱射击",
		"ram": "冲撞",
		"broadside_port": "左舷齐射",
		"broadside_starboard": "右舷齐射",
		"short_cannon": "短炮",
		"guard": "护航令",
	}.get(action_id, action_id)


func _target_prompt(action_id: String) -> String:
	return {
		"disrupt": "浅红格是扰乱射界；点击金框敌船。",
		"ram": "点击船首正前方相邻敌船冲撞。",
		"broadside_port": "浅红格是左舷90°理论射界；点击金框敌船。",
		"broadside_starboard": "浅红格是右舷90°理论射界；点击金框敌船。",
		"short_cannon": "点击两格内侧舷金框敌船。",
		"guard": "点击两格内一艘友船；护航不能对自己使用。",
	}.get(action_id, "选择目标。")


func _combat_outcome_text(actor_name: String, target_name: String, action_id: String, outcome: Dictionary) -> String:
	match action_id:
		"end_activation":
			return "%s 放弃战斗令并结束激活。" % actor_name
		"brace":
			return "%s 进入戒备：下一次受击减少6点。" % actor_name
		"guard":
			return "%s 护航 %s：下一次受击减少8点。" % [actor_name, target_name]
		_:
			var bonus_text := ""
			if int(outcome.get("stern_bonus", 0)) > 0:
				bonus_text += " 船尾+6"
			if int(outcome.get("coordinated_bonus", 0)) > 0:
				bonus_text += " 协同+6"
			if int(outcome.get("reduction", 0)) > 0:
				bonus_text += " 减伤-%d" % int(outcome["reduction"])
			var result_text := "，目标沉没" if bool(outcome.get("sunk", false)) else "，目标受压制·本轮不计航标"
			return "%s 对 %s 使用%s，造成%d伤害%s%s。" % [actor_name, target_name, _action_short_name(action_id), int(outcome.get("damage", 0)), bonus_text, result_text]


func _maneuver_name(kind: String) -> String:
	return {
		"sail": "航行",
		"sail_turn": "转向航行",
		"turn": "原地转舵",
		"reverse": "倒船",
		"wait": "稳舵待命",
	}.get(kind, kind)


func _reason_text(reason: String) -> String:
	return {
		"battle_over": "本局已经结束。",
		"activation_in_progress": "已有一艘船正在激活。",
		"invalid_ship": "该船不能行动。",
		"wrong_team": "现在不轮到这支舰队。",
		"already_activated": "该船本回合已经激活。",
		"not_active_ship": "这不是当前正在激活的船。",
		"maneuver_already_done": "本次机动令已经执行。",
		"invalid_maneuver": "该机动路径不合法。",
		"maneuver_required": "必须先完成机动令。",
		"wrong_class_action": "当前船型没有这个动作。",
		"target_required": "请选择一个目标。",
		"invalid_target": "目标不存在或已经沉没。",
		"friendly_target": "攻击动作不能以友船为目标。",
		"out_of_range": "目标不在射程内。",
		"outside_arc": "目标不在当前侧舷射界内。",
		"blocked_line": "岛礁或其他船只阻挡炮线。",
		"ram_requires_front": "冲撞目标必须在船首正前方一格。",
		"guard_requires_ally": "护航令只能选择两格内另一艘友船。",
		"already_guarded": "该船已经受到一份护航保护。",
	}.get(reason, "该动作现在不能执行。")


func _facing_name(facing: int) -> String:
	return ["东", "东南", "南", "西南", "西", "西北", "北", "东北"][posmod(facing, 8)]


func _facing_arrow(facing: int) -> String:
	return ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"][posmod(facing, 8)]


func _facing_rotation(facing: int) -> float:
	return deg_to_rad(float(posmod(facing, 8) * 45 - 90))
