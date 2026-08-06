class_name NavalTacticsController
extends Node2D

signal campaign_battle_finished(payload: Dictionary)

const BattleScript = preload("res://scripts/tactics/tactics_battle.gd")
const AIScript = preload("res://scripts/tactics/tactics_ai.gd")
const PresentationScript = preload("res://scripts/tactics/naval_combat_presentation.gd")
const PLAYER_SHIP_TEXTURE = preload("res://assets/sprites/naval_tactics/player_ship.png")
const ENEMY_SHIP_TEXTURE = preload("res://assets/sprites/naval_tactics/enemy_ship.png")

const CELL_SIZE := 64.0
const BOARD_ORIGIN := Vector2(240.0, 96.0)
const BOARD_SIZE := Vector2i(12, 8)
const PLAYER_COLOR := Color("39b8cf")
const ENEMY_COLOR := Color("e25b4d")
const SEA_A := Color("123f55")
const SEA_B := Color("164a61")
const GRID_COLOR := Color(0.46, 0.78, 0.83, 0.24)
const TEXT_COLOR := Color("edf7f4")
const MUTED_COLOR := Color("9eb8bd")

var battle = BattleScript.new()
var ai = AIScript.new()
var presentation: NavalCombatPresentation
var presentation_busy := false
var campaign_mode := false
var selected_ship_id := "player_1"
var action_mode := "select"
var hovered_cell := Vector2i(-1, -1)
var hovered_turn_facing := -1
var ship_sprites: Dictionary = {}
var action_buttons: Dictionary = {}
var _all_action_buttons: Dictionary = {}
var mission_buttons: Dictionary = {}
var roster_entries: Dictionary = {}
var friendly_roster_entries: Dictionary = {}
var enemy_roster_entries: Dictionary = {}
var game_title_label: Label
var phase_label: Label
var inspector_label: RichTextLabel
var action_context_label: Label
var hint_label: Label
var result_panel: ColorRect
var result_label: Label
var mission_panel: ColorRect
var mission_description_label: Label
var _round_label: Label
var _objective_label: Label
var _ai_running := false
var _mission_selected := false
var _campaign_result_reported := false
var _feedback_text := "选择一艘我方船只，每回合有2点行动力。"


func _ready() -> void:
	presentation = PresentationScript.new()
	presentation.name = "NavalCombatPresentation"
	add_child(presentation)
	_build_hud()
	_create_ship_sprites()
	_sync_all()


func _process(_delta: float) -> void:
	var cell: Vector2i = battle.grid.pixel_to_cell(get_local_mouse_position(), BOARD_ORIGIN, CELL_SIZE)
	var turn_facing := _turn_choice_at(get_local_mouse_position()) if action_mode == "turn" else -1
	if cell != hovered_cell or turn_facing != hovered_turn_facing:
		hovered_cell = cell
		hovered_turn_facing = turn_facing
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("naval_restart") and battle.result != "":
		reset_battle()
		get_viewport().set_input_as_handled()
		return
	if not _mission_selected or _ai_running or presentation_busy or battle.phase != "player" or battle.result != "":
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if action_mode == "turn":
			_handle_turn_click(event.position)
			get_viewport().set_input_as_handled()
			return
		var cell: Vector2i = battle.grid.pixel_to_cell(event.position, BOARD_ORIGIN, CELL_SIZE)
		_handle_cell_click(cell)
		get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280.0, 720.0)), Color("071b28"))
	draw_rect(Rect2(BOARD_ORIGIN - Vector2(8.0, 8.0), Vector2(BOARD_SIZE) * CELL_SIZE + Vector2(16.0, 16.0)), Color("092c3d"), true)
	var reachable := _reachable_destinations()
	var attack_range := _attack_range_cells()
	var valid_targets := _valid_target_cells()
	for y in BOARD_SIZE.y:
		for x in BOARD_SIZE.x:
			var cell := Vector2i(x, y)
			var rect := _cell_rect(cell)
			var fill := SEA_A if (x + y) % 2 == 0 else SEA_B
			if battle.islands.has(cell):
				fill = Color("806e48")
			elif reachable.has(cell):
				fill = Color("1c7180")
			elif valid_targets.has(cell):
				fill = Color("b78a36") if action_mode == "disrupt" else (Color("b84f35") if action_mode == "ram" else Color("a64252"))
			elif attack_range.has(cell):
				fill = Color("64552f") if action_mode == "disrupt" else (Color("6e3e35") if action_mode == "ram" else Color("553a43"))
			elif cell == hovered_cell and battle.BOARD_BOUNDS.has_point(cell):
				fill = fill.lightened(0.10)
			draw_rect(rect, fill, true)
			draw_rect(rect, GRID_COLOR, false, 1.0)
			if battle.mission_id == "beacon" and cell == battle.beacon_cell:
				draw_rect(rect.grow(-5.0), Color("f5cf6a"), false, 4.0)
			if battle.islands.has(cell):
				_draw_island(cell)

	if action_mode == "sail" and selected_ship_id != "":
		var preview_path := _path_ending_at(hovered_cell)
		if not preview_path.is_empty():
			var points := PackedVector2Array([_ship_center(selected_ship_id)])
			for cell_value in preview_path["cells"]:
				points.append(battle.grid.cell_to_pixel(cell_value, BOARD_ORIGIN, CELL_SIZE))
			if preview_path.get("reverse", false):
				var reverse_start: Vector2 = points[0]
				var reverse_end: Vector2 = points[-1]
				for dash_index in 4:
					var from_ratio := float(dash_index) / 4.0
					var to_ratio := from_ratio + 0.14
					draw_line(reverse_start.lerp(reverse_end, from_ratio), reverse_start.lerp(reverse_end, to_ratio), Color("f5a85b"), 5.0, true)
			else:
				draw_polyline(points, Color("f5cf6a"), 5.0, true)
			var end_point: Vector2 = points[-1]
			var facing: int = int(preview_path["facing"])
			var heading := Vector2(battle.grid.DIRECTIONS[facing]).normalized()
			draw_line(end_point, end_point + heading * 22.0, Color.WHITE, 4.0, true)

	if selected_ship_id != "" and battle.get_ship(selected_ship_id).get("alive", false):
		var center := _ship_center(selected_ship_id)
		var selected_team: int = int(battle.get_ship(selected_ship_id)["team"])
		draw_arc(center, 34.0, 0.0, TAU, 48, PLAYER_COLOR if selected_team == 0 else ENEMY_COLOR, 3.0, true)
		if selected_team == 0:
			_draw_side_indicator(center)
			if action_mode == "turn":
				_draw_turn_choices(center)
	_draw_class_markers()

	if action_mode in ["port", "starboard", "disrupt", "ram"]:
		var hovered_ship := _ship_at_cell(hovered_cell)
		if hovered_ship != "" and selected_ship_id != "":
			var check: Dictionary
			if action_mode == "disrupt":
				check = battle.can_disrupt(selected_ship_id, hovered_ship)
			elif action_mode == "ram":
				check = battle.can_ram(selected_ship_id, hovered_ship)
			else:
				check = battle.can_fire(selected_ship_id, hovered_ship, action_mode)
			var line_color := Color("f5cf6a") if check.get("ok", false) else Color("e25b4d")
			draw_line(_ship_center(selected_ship_id), _ship_center(hovered_ship), line_color, 4.0, true)


func reset_battle() -> void:
	battle.reset(battle.mission_id)
	selected_ship_id = "player_1"
	action_mode = "select"
	_ai_running = false
	presentation_busy = false
	_campaign_result_reported = false
	_mission_selected = true
	_feedback_text = "%s重新开始。双方使用同样的快船与炮船。" % battle.mission_title()
	_sync_all()


func start_mission_for_test(selected_mission_id: String) -> void:
	campaign_mode = false
	battle.reset(selected_mission_id)
	selected_ship_id = "player_1"
	action_mode = "select"
	_ai_running = false
	presentation_busy = false
	_campaign_result_reported = false
	_mission_selected = true
	_feedback_text = "%s开始：%s。" % [battle.mission_title(), battle.mission_summary()]
	_sync_all()


func start_campaign_mission(selected_mission_id: String, fleet_state: Dictionary) -> Dictionary:
	battle.reset(selected_mission_id)
	var apply_result: Dictionary = battle.apply_player_fleet_state(fleet_state)
	if not apply_result.get("ok", false):
		return apply_result
	campaign_mode = true
	_campaign_result_reported = false
	selected_ship_id = "player_1"
	action_mode = "select"
	_ai_running = false
	presentation_busy = false
	_mission_selected = true
	_feedback_text = "官船军令开始：%s。完成职责后返回榕湾水寨结算。" % battle.mission_summary()
	game_title_label.text = "岭南舰影  ·  岭海水师官船军令"
	_sync_all()
	return {"ok": true}


func perform_sail_for_test(ship_id: String, path: Dictionary) -> Dictionary:
	if presentation_busy:
		return {"ok": false, "reason": "presentation_busy"}
	var result_value: Dictionary = battle.sail(ship_id, path)
	if result_value.get("ok", false):
		presentation_busy = true
		selected_ship_id = ship_id
		var movement_text := "倒船脱困" if result_value.get("path", {}).get("reverse", false) else "完成航行"
		_feedback_text = "%s%s，剩余 %s AP。" % [battle.get_ship(ship_id)["name"], movement_text, battle.get_ship(ship_id)["ap"]]
		action_mode = "select"
		_sync_hud()
		var path_centers: Array[Vector2] = []
		for cell_value in result_value.get("path", {}).get("cells", []):
			path_centers.append(battle.grid.cell_to_pixel(cell_value, BOARD_ORIGIN, CELL_SIZE))
		var final_facing := int(result_value.get("path", {}).get("facing", battle.get_ship(ship_id)["facing"]))
		await presentation.play_sail(ship_sprites[ship_id], path_centers, _facing_rotation(final_facing), result_value.get("path", {}).get("reverse", false))
		presentation_busy = false
	_sync_all()
	return result_value


func perform_turn_for_test(ship_id: String, facing: int) -> Dictionary:
	if presentation_busy:
		return {"ok": false, "reason": "presentation_busy"}
	var sprite: Sprite2D = ship_sprites.get(ship_id)
	var visual_start: float = sprite.rotation if is_instance_valid(sprite) else _facing_rotation(int(battle.get_ship(ship_id).get("facing", 0)))
	var result_value: Dictionary = battle.turn(ship_id, facing)
	if result_value.get("ok", false):
		presentation_busy = true
		selected_ship_id = ship_id
		action_mode = "select"
		_feedback_text = "%s完成转舵，剩余 %s AP。" % [battle.get_ship(ship_id)["name"], battle.get_ship(ship_id)["ap"]]
		_sync_hud()
		var canonical_rotation := _facing_rotation(facing)
		var shortest_rotation := visual_start + wrapf(canonical_rotation - visual_start, -PI, PI)
		await presentation.play_turn(sprite, shortest_rotation)
		presentation_busy = false
	else:
		_feedback_text = _reason_text(result_value.get("reason", "invalid_turn"))
	_sync_all()
	return result_value


func _handle_cell_click(cell: Vector2i) -> void:
	if not battle.BOARD_BOUNDS.has_point(cell):
		_feedback_text = "目标超出海战区域。"
		_sync_all()
		return
	var ship_id := _ship_at_cell(cell)
	if action_mode == "sail":
		var path := _path_ending_at(cell)
		if path.is_empty():
			_feedback_text = "这个格子不在本次航行范围内。"
			_sync_all()
		else:
			perform_sail_for_test(selected_ship_id, path)
		return
	if action_mode == "port" or action_mode == "starboard":
		if ship_id == "":
			_feedback_text = "该格没有敌船；浅红区域是射界，亮红敌船才可攻击。"
			_sync_all()
		elif int(battle.get_ship(ship_id).get("team", 0)) != 1:
			_feedback_text = "不能攻击我方船只。"
			_sync_all()
		else:
			_perform_player_fire(ship_id, action_mode)
		return
	if action_mode == "disrupt":
		if ship_id == "":
			_feedback_text = "该格没有敌船；浅金区域是扰乱射界，亮金敌船才可攻击。"
			_sync_all()
		elif int(battle.get_ship(ship_id).get("team", 0)) != 1:
			_feedback_text = "扰乱射击不能攻击我方船只。"
			_sync_all()
		else:
			_perform_player_disrupt(ship_id)
		return
	if action_mode == "ram":
		if ship_id == "" or int(battle.get_ship(ship_id).get("team", 0)) != 1:
			_feedback_text = "只能冲撞船头正前方的敌船。"
			_sync_all()
		else:
			_perform_player_ram(ship_id)
		return
	if ship_id != "":
		selected_ship_id = ship_id
		var inspected_ship: Dictionary = battle.get_ship(ship_id)
		_feedback_text = "已选择 %s。" % inspected_ship["name"] if int(inspected_ship["team"]) == 0 else "正在查看敌方 %s 的公开状态。" % inspected_ship["name"]
		action_mode = "select"
		_sync_all()


func _handle_turn_click(screen_position: Vector2) -> void:
	var facing := _turn_choice_at(screen_position)
	if facing < 0:
		_feedback_text = "请选择船只周围的一个转舵方向。"
		_sync_hud()
		return
	perform_turn_for_test(selected_ship_id, facing)


func _perform_player_fire(target_id: String, side: String) -> void:
	if presentation_busy:
		return
	var attacker_id := selected_ship_id
	var result_value: Dictionary = battle.fire(selected_ship_id, target_id, side)
	if not result_value.get("ok", false):
		_feedback_text = _reason_text(result_value.get("reason", "invalid_target"))
	else:
		presentation_busy = true
		var hit_name: String = battle.get_ship(target_id)["name"]
		var attack_name := "协同齐射 +%d" % result_value.get("synergy_bonus", 0) if result_value.get("consumed_destabilized", false) else ("船尾炮击" if result_value.get("stern", false) else "侧舷齐射")
		_feedback_text = "%s命中 %s：耐久 -%d%s" % [
			attack_name,
			hit_name,
			result_value.get("damage", 0),
			"（船尾命中 +%d）" % result_value.get("stern_bonus", 0) if result_value.get("stern", false) else "",
		]
		action_mode = "select"
		_sync_hud()
		await presentation.play_broadside(ship_sprites[attacker_id], ship_sprites[target_id], side, result_value)
		if result_value.get("sunk", false):
			await presentation.play_sink(ship_sprites[target_id])
		presentation_busy = false
	_sync_all()


func _perform_player_disrupt(target_id: String) -> void:
	if presentation_busy:
		return
	var attacker_id := selected_ship_id
	var result_value: Dictionary = battle.fire_disrupt(selected_ship_id, target_id)
	if not result_value.get("ok", false):
		_feedback_text = _reason_text(result_value.get("reason", "invalid_target"))
	else:
		presentation_busy = true
		_feedback_text = "扰乱射击命中 %s：耐久 -%d%s。" % [battle.get_ship(target_id)["name"], result_value.get("damage", 0), "，目标失衡" if result_value.get("destabilized_applied", false) else ""]
		action_mode = "select"
		_sync_hud()
		await presentation.play_disrupt(ship_sprites[attacker_id], ship_sprites[target_id], result_value)
		if result_value.get("sunk", false):
			await presentation.play_sink(ship_sprites[target_id])
		presentation_busy = false
	_sync_all()


func _perform_player_ram(target_id: String) -> void:
	if presentation_busy:
		return
	var attacker_id := selected_ship_id
	var target_before := battle.get_ship(target_id).duplicate(true)
	var result_value: Dictionary = battle.ram(selected_ship_id, target_id)
	if not result_value.get("ok", false):
		_feedback_text = _reason_text(result_value.get("reason", "invalid_target"))
	else:
		presentation_busy = true
		var collision_text: String = {"open": "目标被推开", "obstacle": "目标撞上礁石", "ship": "目标撞上另一艘船"}.get(result_value.get("collision", "open"), "冲撞完成")
		_feedback_text = "冲撞成功：%s%s。" % [collision_text, "，目标失衡" if result_value.get("destabilized_applied", false) else ""]
		action_mode = "select"
		var target_after := battle.get_ship(target_id)
		var ram_view := result_value.duplicate(true)
		ram_view["target_damage"] = int(target_before.get("hp", 0)) - int(target_after.get("hp", 0))
		var movement_view := {
			"attacker_position": battle.grid.cell_to_pixel(battle.get_ship(attacker_id)["cell"], BOARD_ORIGIN, CELL_SIZE),
			"target_position": battle.grid.cell_to_pixel(target_after["cell"], BOARD_ORIGIN, CELL_SIZE),
		}
		_sync_hud()
		await presentation.play_ram(ship_sprites[attacker_id], ship_sprites[target_id], movement_view, ram_view)
		if result_value.get("target_sunk", false):
			await presentation.play_sink(ship_sprites[target_id])
		presentation_busy = false
	_sync_all()


func _on_action_pressed(mode: String) -> void:
	if not _mission_selected or _ai_running or presentation_busy or battle.phase != "player" or battle.result != "":
		return
	if mode == "undo":
		var undo_result: Dictionary = battle.undo_last_sail()
		_feedback_text = "已撤销最后一次航行。" if undo_result.get("ok", false) else "当前没有可以撤销的航行。"
		action_mode = "select"
	elif mode == "end_unit":
		if selected_ship_id != "" and battle.get_ship(selected_ship_id).get("alive", false):
			battle.clear_undo()
			battle.ships[selected_ship_id]["ap"] = 0
		_select_next_available_ship()
		_feedback_text = "该船已结束行动。"
		action_mode = "select"
	elif mode == "end_phase":
		_run_enemy_phase()
		return
	else:
		action_mode = mode
		if mode == "sail":
			_feedback_text = "蓝绿色格子是可航行位置；黄线预览路径与最终朝向。"
		elif mode == "turn":
			_feedback_text = "点击船只周围的船头标记：可左转或右转45°/90°，消耗1 AP。"
		elif mode == "disrupt":
			_feedback_text = "浅金格是完整扰乱射界，亮金敌船可攻击：造成8耐久伤害并施加失衡。"
		elif mode == "ram":
			_feedback_text = "冲撞只能攻击船头正前方一格的敌船。"
		else:
			_feedback_text = "浅红格是完整炮击射界，亮红敌船可攻击；岛屿会阻挡炮线。"
	_sync_all()


func _run_enemy_phase() -> void:
	if _ai_running or presentation_busy:
		return
	var phase_result: Dictionary = battle.end_player_phase()
	if not phase_result.get("ok", false):
		return
	_ai_running = true
	action_mode = "select"
	_feedback_text = "敌方回合：红旗舰队正在行动。"
	_sync_all()
	await _presentation_pause(0.35)
	for enemy_id in battle.living_ship_ids(1):
		var activation_context := {"visited_cells": {battle.get_ship(enemy_id)["cell"]: true}}
		for _step in 2:
			if battle.result != "" or int(battle.get_ship(enemy_id)["ap"]) <= 0:
				break
			var command: Dictionary = ai.choose_command(battle, enemy_id, activation_context)
			match command.get("type", "end"):
				"fire":
					var shot: Dictionary = battle.fire(enemy_id, command["target_id"], command["side"])
					_feedback_text = "%s向 %s 开炮%s。" % [battle.get_ship(enemy_id)["name"], battle.get_ship(command["target_id"])["name"], "，触发协同齐射 +%d" % shot.get("synergy_bonus", 0) if shot.get("consumed_destabilized", false) else ""]
					presentation_busy = true
					_sync_hud()
					await presentation.play_broadside(ship_sprites[enemy_id], ship_sprites[command["target_id"]], command["side"], shot)
					if shot.get("sunk", false):
						await presentation.play_sink(ship_sprites[command["target_id"]])
				"disrupt":
					var disrupt: Dictionary = battle.fire_disrupt(enemy_id, command["target_id"])
					_feedback_text = "%s使用扰乱射击攻击 %s%s。" % [battle.get_ship(enemy_id)["name"], battle.get_ship(command["target_id"])["name"], "，目标失衡" if disrupt.get("destabilized_applied", false) else ""]
					presentation_busy = true
					_sync_hud()
					await presentation.play_disrupt(ship_sprites[enemy_id], ship_sprites[command["target_id"]], disrupt)
					if disrupt.get("sunk", false):
						await presentation.play_sink(ship_sprites[command["target_id"]])
				"ram":
					var ram_target_id: String = command["target_id"]
					var target_before := battle.get_ship(ram_target_id).duplicate(true)
					var ram_result: Dictionary = battle.ram(enemy_id, command["target_id"])
					_feedback_text = "%s发动冲撞%s。" % [battle.get_ship(enemy_id)["name"], "，目标失衡" if ram_result.get("destabilized_applied", false) else ""]
					var target_after := battle.get_ship(ram_target_id)
					var ram_view := ram_result.duplicate(true)
					ram_view["target_damage"] = int(target_before.get("hp", 0)) - int(target_after.get("hp", 0))
					var movement_view := {
						"attacker_position": battle.grid.cell_to_pixel(battle.get_ship(enemy_id)["cell"], BOARD_ORIGIN, CELL_SIZE),
						"target_position": battle.grid.cell_to_pixel(target_after["cell"], BOARD_ORIGIN, CELL_SIZE),
					}
					presentation_busy = true
					_sync_hud()
					await presentation.play_ram(ship_sprites[enemy_id], ship_sprites[ram_target_id], movement_view, ram_view)
					if ram_result.get("target_sunk", false):
						await presentation.play_sink(ship_sprites[ram_target_id])
				"sail":
					var sail_result: Dictionary = battle.sail(enemy_id, command["path"])
					_feedback_text = "%s正在调整航向。" % battle.get_ship(enemy_id)["name"]
					if sail_result.get("ok", false):
						var path_centers: Array[Vector2] = []
						for cell_value in sail_result.get("path", {}).get("cells", []):
							path_centers.append(battle.grid.cell_to_pixel(cell_value, BOARD_ORIGIN, CELL_SIZE))
						activation_context["visited_cells"][battle.get_ship(enemy_id)["cell"]] = true
						presentation_busy = true
						_sync_hud()
						await presentation.play_sail(ship_sprites[enemy_id], path_centers, _facing_rotation(int(battle.get_ship(enemy_id)["facing"])), sail_result.get("path", {}).get("reverse", false))
				"turn":
					var enemy_sprite: Sprite2D = ship_sprites[enemy_id]
					var visual_start: float = enemy_sprite.rotation
					var turn_result: Dictionary = battle.turn(enemy_id, int(command["facing"]))
					if turn_result.get("ok", false):
						_feedback_text = "%s转舵调整侧舷。" % battle.get_ship(enemy_id)["name"]
						var canonical_rotation := _facing_rotation(int(turn_result["facing"]))
						var shortest_rotation := visual_start + wrapf(canonical_rotation - visual_start, -PI, PI)
						presentation_busy = true
						_sync_hud()
						await presentation.play_turn(enemy_sprite, shortest_rotation)
				_:
					battle.ships[enemy_id]["ap"] = 0
			presentation_busy = false
			_sync_all()
			await _presentation_pause(0.18)
	if battle.result == "":
		battle.begin_player_phase()
		if battle.result == "":
			selected_ship_id = battle.living_ship_ids(0)[0] if not battle.living_ship_ids(0).is_empty() else ""
			_feedback_text = "我方回合：两艘存活船只的行动力已恢复。"
		else:
			_feedback_text = "本局任务已经结束。"
	_ai_running = false
	presentation_busy = false
	_sync_all()


func _presentation_pause(duration: float) -> void:
	if presentation.presentation_speed <= 0.0:
		return
	await get_tree().create_timer(duration * presentation.presentation_speed).timeout


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(hud)

	var top_panel := _panel(Color(0.025, 0.09, 0.13, 0.96), Rect2(0.0, 0.0, 1280.0, 82.0))
	hud.add_child(top_panel)
	game_title_label = _label("岭南舰影  ·  方格海战 V2.6", 24, TEXT_COLOR)
	game_title_label.position = Vector2(22.0, 13.0)
	top_panel.add_child(game_title_label)
	phase_label = _label("", 18, PLAYER_COLOR)
	phase_label.position = Vector2(25.0, 47.0)
	top_panel.add_child(phase_label)
	_round_label = _label("", 18, TEXT_COLOR)
	_round_label.position = Vector2(170.0, 47.0)
	top_panel.add_child(_round_label)
	_objective_label = _label("", 16, MUTED_COLOR)
	_objective_label.position = Vector2(300.0, 49.0)
	_objective_label.size = Vector2(720.0, 28.0)
	top_panel.add_child(_objective_label)
	hint_label = _label("", 15, Color("f5cf6a"))
	hint_label.position = Vector2(520.0, 15.0)
	hint_label.size = Vector2(730.0, 28.0)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_panel.add_child(hint_label)

	var left_panel := _panel(Color(0.025, 0.09, 0.13, 0.93), Rect2(12.0, 96.0, 210.0, 512.0))
	hud.add_child(left_panel)
	var roster_title := _label("我方舰队", 18, PLAYER_COLOR)
	roster_title.position = Vector2(14.0, 12.0)
	left_panel.add_child(roster_title)
	var roster_box := VBoxContainer.new()
	roster_box.position = Vector2(12.0, 50.0)
	roster_box.size = Vector2(186.0, 438.0)
	roster_box.add_theme_constant_override("separation", 9)
	left_panel.add_child(roster_box)
	for ship_id in ["player_1", "player_2"]:
		var entry := _roster_button(Vector2(186.0, 104.0), 14)
		entry.pressed.connect(_select_from_roster.bind(ship_id))
		roster_box.add_child(entry)
		roster_entries[ship_id] = entry
		friendly_roster_entries[ship_id] = entry

	var right_panel := _panel(Color(0.025, 0.09, 0.13, 0.93), Rect2(1018.0, 96.0, 250.0, 512.0))
	hud.add_child(right_panel)
	var enemy_roster_title := _label("敌方舰队", 18, ENEMY_COLOR)
	enemy_roster_title.position = Vector2(14.0, 12.0)
	right_panel.add_child(enemy_roster_title)
	var enemy_roster_box := VBoxContainer.new()
	enemy_roster_box.position = Vector2(12.0, 44.0)
	enemy_roster_box.size = Vector2(226.0, 146.0)
	enemy_roster_box.add_theme_constant_override("separation", 6)
	right_panel.add_child(enemy_roster_box)
	for ship_id in ["enemy_1", "enemy_2"]:
		var entry := _roster_button(Vector2(226.0, 70.0), 13)
		entry.pressed.connect(_inspect_from_roster.bind(ship_id))
		enemy_roster_box.add_child(entry)
		roster_entries[ship_id] = entry
		enemy_roster_entries[ship_id] = entry

	var divider := ColorRect.new()
	divider.color = Color(0.38, 0.63, 0.67, 0.25)
	divider.position = Vector2(14.0, 199.0)
	divider.size = Vector2(222.0, 1.0)
	right_panel.add_child(divider)
	var inspector_title := _label("选中船只", 17, TEXT_COLOR)
	inspector_title.position = Vector2(14.0, 207.0)
	right_panel.add_child(inspector_title)
	inspector_label = RichTextLabel.new()
	inspector_label.bbcode_enabled = true
	inspector_label.fit_content = false
	inspector_label.scroll_active = false
	inspector_label.position = Vector2(14.0, 241.0)
	inspector_label.size = Vector2(222.0, 260.0)
	inspector_label.add_theme_font_size_override("normal_font_size", 13)
	inspector_label.add_theme_font_size_override("bold_font_size", 15)
	inspector_label.add_theme_constant_override("line_separation", 4)
	right_panel.add_child(inspector_label)

	var bottom_panel := _panel(Color(0.025, 0.09, 0.13, 0.96), Rect2(240.0, 620.0, 768.0, 88.0))
	hud.add_child(bottom_panel)
	var actions := HBoxContainer.new()
	actions.position = Vector2(10.0, 10.0)
	actions.size = Vector2(610.0, 68.0)
	actions.add_theme_constant_override("separation", 8)
	bottom_panel.add_child(actions)
	action_context_label = _label("正在查看敌舰；请从左侧选择我方船只下令。", 14, MUTED_COLOR)
	action_context_label.position = Vector2(16.0, 28.0)
	action_context_label.size = Vector2(590.0, 28.0)
	action_context_label.visible = false
	bottom_panel.add_child(action_context_label)
	var action_specs := [
		["sail", "航行\n1 AP"],
		["turn", "转舵\n1 AP"],
		["port", "左舷炮\n1 AP"],
		["starboard", "右舷炮\n1 AP"],
		["disrupt", "扰乱射击\n失衡"],
		["ram", "冲撞\n正前方"],
		["undo", "撤销\n最后航行"],
		["end_unit", "结束\n本船"],
		["end_phase", "结束我方\n敌方行动"],
	]
	for spec in action_specs:
		var button := Button.new()
		button.text = spec[1]
		button.add_theme_font_size_override("font_size", 12)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_action_pressed.bind(spec[0]))
		if spec[0] == "end_phase":
			button.position = Vector2(628.0, 10.0)
			button.size = Vector2(130.0, 62.0)
			button.custom_minimum_size = Vector2(130.0, 62.0)
			bottom_panel.add_child(button)
		else:
			button.custom_minimum_size = Vector2(86.0, 62.0)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			actions.add_child(button)
		_all_action_buttons[spec[0]] = button

	result_panel = _panel(Color(0.01, 0.035, 0.05, 0.96), Rect2(390.0, 230.0, 500.0, 250.0))
	result_panel.visible = false
	hud.add_child(result_panel)
	result_label = _label("", 30, TEXT_COLOR)
	result_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_panel.add_child(result_label)

	mission_panel = _panel(Color(0.01, 0.035, 0.05, 0.98), Rect2(380.0, 180.0, 520.0, 360.0))
	hud.add_child(mission_panel)
	var mission_title_label := _label("选择本局任务", 28, TEXT_COLOR)
	mission_title_label.position = Vector2(0.0, 24.0)
	mission_title_label.size = Vector2(520.0, 40.0)
	mission_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_panel.add_child(mission_title_label)
	mission_description_label = _label("单一耐久更直观；浅色格显示完整射界，亮色敌船可攻击。", 15, MUTED_COLOR)
	mission_description_label.position = Vector2(35.0, 72.0)
	mission_description_label.size = Vector2(450.0, 48.0)
	mission_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mission_panel.add_child(mission_description_label)
	var mission_specs := [
		["elimination", "歼灭战", "击沉全部敌船"],
		["flagship", "旗舰决战", "击沉敌方炮船旗舰"],
		["beacon", "航标争夺", "完整回合占点，率先得到2分"],
	]
	for index in mission_specs.size():
		var spec: Array = mission_specs[index]
		var mission_button := Button.new()
		mission_button.text = "%s\n%s" % [spec[1], spec[2]]
		mission_button.position = Vector2(70.0, 130.0 + index * 66.0)
		mission_button.size = Vector2(380.0, 54.0)
		mission_button.add_theme_font_size_override("font_size", 15)
		mission_button.focus_mode = Control.FOCUS_NONE
		mission_button.pressed.connect(start_mission_for_test.bind(spec[0]))
		mission_panel.add_child(mission_button)
		mission_buttons[spec[0]] = mission_button


func _create_ship_sprites() -> void:
	for ship_id in battle.ships:
		var ship: Dictionary = battle.ships[ship_id]
		var sprite := Sprite2D.new()
		sprite.name = ship_id
		sprite.texture = PLAYER_SHIP_TEXTURE if int(ship["team"]) == 0 else ENEMY_SHIP_TEXTURE
		sprite.scale = Vector2.ONE * (0.48 if ship["class_id"] == "fast" else 0.58)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(sprite)
		ship_sprites[ship_id] = sprite


func _sync_all() -> void:
	_sync_ship_sprites()
	_sync_hud()
	queue_redraw()
	if campaign_mode and battle.result != "" and not _campaign_result_reported:
		_campaign_result_reported = true
		_emit_campaign_result.call_deferred()


func _emit_campaign_result() -> void:
	if not campaign_mode or battle.result == "":
		return
	var player_ships: Dictionary = {}
	for ship_id in ["player_1", "player_2"]:
		player_ships[ship_id] = battle.get_ship(ship_id).duplicate(true)
	campaign_battle_finished.emit({
		"result": battle.result,
		"mission_id": battle.mission_id,
		"ships": player_ships,
	})


func _sync_ship_sprites() -> void:
	for ship_id in ship_sprites:
		var sprite: Sprite2D = ship_sprites[ship_id]
		var ship := battle.get_ship(ship_id)
		sprite.visible = not ship.is_empty() and bool(ship["alive"])
		if sprite.visible:
			sprite.position = battle.grid.cell_to_pixel(ship["cell"], BOARD_ORIGIN, CELL_SIZE)
			sprite.rotation = _facing_rotation(int(ship["facing"]))
			sprite.modulate = Color.WHITE if int(ship["ap"]) > 0 else Color(0.58, 0.66, 0.68)


func _facing_rotation(facing: int) -> float:
	return deg_to_rad(float(facing * 45 - 90))


func _sync_hud() -> void:
	phase_label.text = "我方回合" if battle.phase == "player" else "敌方回合"
	phase_label.modulate = PLAYER_COLOR if battle.phase == "player" else ENEMY_COLOR
	_round_label.text = "第 %d 回合" % battle.round_number
	var score_text := ""
	if battle.mission_id == "beacon":
		score_text = "    航标 %d : %d" % [battle.beacon_score[0], battle.beacon_score[1]]
	_objective_label.text = "%s：%s%s" % [battle.mission_title(), battle.mission_summary(), score_text]
	hint_label.text = _feedback_text
	for ship_id in roster_entries:
		var entry: Button = roster_entries[ship_id]
		var ship := battle.get_ship(ship_id)
		var emblem := "●" if int(ship["team"]) == 0 else "◆"
		var flagship_mark := " 旗舰" if battle.mission_id == "flagship" and battle.flagship_ids[int(ship["team"])] == ship_id else ""
		var faction_name := "我方" if int(ship["team"]) == 0 else "敌方"
		var warning := _fleet_status(ship)
		entry.text = "%s %s [%s] %s%s\nAP %s  耐久 %d/%d  %s" % [
			emblem, faction_name, "快" if ship["class_id"] == "fast" else "炮", ship["name"], flagship_mark,
			_ap_pips(int(ship["ap"])), ship["hp"], ship["max_hp"], warning
		]
		entry.disabled = not bool(ship["alive"])
		entry.modulate = Color.WHITE if bool(ship["alive"]) else Color(0.42, 0.46, 0.48)
		if ship_id == selected_ship_id:
			entry.add_theme_color_override("font_color", PLAYER_COLOR if int(ship["team"]) == 0 else ENEMY_COLOR)
		else:
			entry.add_theme_color_override("font_color", TEXT_COLOR)
	var selected := battle.get_ship(selected_ship_id)
	if selected.is_empty():
		inspector_label.text = "没有可选船只"
	else:
		var is_friendly: bool = int(selected["team"]) == 0
		var faction := "● 我方·蓝帆圆徽" if is_friendly else "◆ 敌方·红帆菱徽"
		var faction_color := "#39b8cf" if is_friendly else "#e25b4d"
		var current_move_range: int = int(selected["move_range"])
		var durability_effect := "已沉没" if not bool(selected["alive"]) else ("耐久告急" if int(selected["hp"]) * 2 <= int(selected["max_hp"]) else "状态稳定")
		var status_effect := "失衡｜敌方炮船下一次齐射 +6" if int(selected.get("destabilized_by_team", -1)) >= 0 else "正常"
		var facing: int = int(selected["facing"])
		inspector_label.text = "[font_size=17][b]%s[/b][/font_size]\n[color=%s]%s[/color] · %s\n行动力  [b]%s[/b]  %d / 2\n耐久  [b]%d / %d[/b]  %s\n%s\n机动  %d格/次\n转舵  45°/90° · 1 AP\n朝向  [b]%s %s[/b]\n状态  [color=#f5b642]%s[/color]" % [
			selected["name"], faction_color, faction, selected["class_name"], _ap_pips(int(selected["ap"])), selected["ap"],
			selected["hp"], selected["max_hp"], durability_effect, _bar(int(selected["hp"]), int(selected["max_hp"])), current_move_range,
			_facing_name(facing), _facing_arrow(facing), status_effect
		]
	var can_act: bool = _mission_selected and battle.phase == "player" and battle.result == "" and not _ai_running and not selected.is_empty() and bool(selected.get("alive", false)) and int(selected.get("team", 1)) == 0
	_sync_contextual_actions(selected, can_act)
	action_context_label.visible = _mission_selected and not selected.is_empty() and int(selected.get("team", 0)) == 1 and battle.phase == "player" and battle.result == "" and not _ai_running
	mission_panel.visible = not _mission_selected
	result_panel.visible = battle.result != ""
	if battle.result == "victory":
		result_label.text = "胜  利\n\n%s 已完成\n\n%s" % [battle.mission_title(), "正在返回榕湾水寨结算……" if campaign_mode else "按 R 重新开始"]
		result_label.modulate = Color("8fe3ba")
	elif battle.result == "defeat":
		result_label.text = "战  败\n\n%s 未完成\n\n%s" % [battle.mission_title(), "正在返回榕湾水寨整备……" if campaign_mode else "按 R 重新开始"]
		result_label.modulate = Color("f18c7e")
	elif battle.result == "draw":
		result_label.text = "平  局\n\n双方旗舰同时沉没\n\n%s" % ("正在返回榕湾水寨整备……" if campaign_mode else "按 R 重新开始")
		result_label.modulate = Color("f5cf6a")


func _sync_contextual_actions(selected: Dictionary, can_act: bool) -> void:
	var ship_actions: Array = battle.available_actions(selected_ship_id) if can_act else []
	var fleet_can_act: bool = _mission_selected and battle.phase == "player" and battle.result == "" and not _ai_running
	if action_mode != "select" and action_mode not in ship_actions:
		action_mode = "select"
	action_buttons.clear()
	for mode in _all_action_buttons:
		var button: Button = _all_action_buttons[mode]
		var visible_for_context: bool = mode in ship_actions or (mode == "end_phase" and fleet_can_act)
		button.visible = visible_for_context
		if not visible_for_context:
			button.disabled = true
			continue
		action_buttons[mode] = button
		if mode == "end_phase":
			button.disabled = not fleet_can_act
		elif mode == "undo":
			button.disabled = not battle.can_undo_sail()
		elif mode == "turn":
			button.disabled = not can_act or battle.legal_turn_commands(selected_ship_id).is_empty()
		else:
			button.disabled = not can_act or int(selected.get("ap", 0)) <= 0


func _reachable_destinations() -> Dictionary:
	var result_value := {}
	if action_mode != "sail" or selected_ship_id == "":
		return result_value
	for path_value in battle.legal_sailing_paths(selected_ship_id):
		var path: Dictionary = path_value
		var cells: Array = path["cells"]
		result_value[cells[-1]] = true
	return result_value


func _valid_target_cells() -> Dictionary:
	var result_value := {}
	if action_mode not in ["port", "starboard", "disrupt", "ram"] or selected_ship_id == "":
		return result_value
	for enemy_id in battle.living_ship_ids(1):
		var valid := false
		if action_mode == "disrupt":
			valid = battle.can_disrupt(selected_ship_id, enemy_id).get("ok", false)
		elif action_mode == "ram":
			valid = battle.can_ram(selected_ship_id, enemy_id).get("ok", false)
		else:
			valid = battle.can_fire(selected_ship_id, enemy_id, action_mode).get("ok", false)
		if valid:
			result_value[battle.get_ship(enemy_id)["cell"]] = true
	return result_value


func _attack_range_cells() -> Dictionary:
	var result_value := {}
	if action_mode not in ["port", "starboard", "disrupt", "ram"] or selected_ship_id == "":
		return result_value
	var ship: Dictionary = battle.get_ship(selected_ship_id)
	if ship.is_empty() or not bool(ship.get("alive", false)):
		return result_value
	if action_mode == "ram":
		var front_cell: Vector2i = ship["cell"] + battle.grid.DIRECTIONS[int(ship["facing"])]
		if battle.BOARD_BOUNDS.has_point(front_cell):
			result_value[front_cell] = true
		return result_value
	var max_range := int(ship.get("disrupt_range", 3)) if action_mode == "disrupt" else int(ship.get("broadside_range", 0))
	var forward := Vector2(battle.grid.DIRECTIONS[int(ship["facing"])]).normalized()
	var right := Vector2(-forward.y, forward.x)
	for y in BOARD_SIZE.y:
		for x in BOARD_SIZE.x:
			var cell := Vector2i(x, y)
			if cell == ship["cell"] or battle.grid.distance(ship["cell"], cell) > max_range:
				continue
			var relative := Vector2(cell - ship["cell"])
			var forward_projection := relative.dot(forward)
			var side_projection := relative.dot(right)
			var in_side_arc := absf(forward_projection) <= absf(side_projection) + 0.001
			var correct_side := true
			if action_mode == "port":
				correct_side = side_projection < -0.001
			elif action_mode == "starboard":
				correct_side = side_projection > 0.001
			else:
				correct_side = absf(side_projection) > 0.001
			if in_side_arc and correct_side:
				result_value[cell] = true
	return result_value


func _path_ending_at(cell: Vector2i) -> Dictionary:
	if selected_ship_id == "":
		return {}
	var candidates: Array = []
	for path_value in battle.legal_sailing_paths(selected_ship_id):
		var path: Dictionary = path_value
		var cells: Array = path["cells"]
		if cells[-1] == cell:
			candidates.append(path)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["cells"].size() != b["cells"].size():
			return a["cells"].size() < b["cells"].size()
		return int(a["facing"]) < int(b["facing"])
	)
	return candidates[0]


func _select_from_roster(ship_id: String) -> void:
	if battle.phase != "player" or _ai_running:
		return
	var ship := battle.get_ship(ship_id)
	if not ship.is_empty() and bool(ship["alive"]) and int(ship["team"]) == 0:
		selected_ship_id = ship_id
		action_mode = "select"
		_feedback_text = "已选择 %s。" % ship["name"]
		_sync_all()


func _inspect_from_roster(ship_id: String) -> void:
	if _ai_running:
		return
	var ship := battle.get_ship(ship_id)
	if not ship.is_empty() and int(ship["team"]) == 1:
		selected_ship_id = ship_id
		action_mode = "select"
		_feedback_text = "正在查看敌方 %s 的公开状态。" % ship["name"]
		_sync_all()


func _select_next_available_ship() -> void:
	for ship_id in battle.living_ship_ids(0):
		if int(battle.get_ship(ship_id)["ap"]) > 0:
			selected_ship_id = ship_id
			return


func _ship_at_cell(cell: Vector2i) -> String:
	for ship_id in battle.ships:
		var ship: Dictionary = battle.ships[ship_id]
		if bool(ship["alive"]) and ship["cell"] == cell:
			return str(ship_id)
	return ""


func _ship_center(ship_id: String) -> Vector2:
	var ship := battle.get_ship(ship_id)
	if ship.is_empty():
		return Vector2.ZERO
	return battle.grid.cell_to_pixel(ship["cell"], BOARD_ORIGIN, CELL_SIZE)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(BOARD_ORIGIN + Vector2(cell) * CELL_SIZE + Vector2.ONE, Vector2.ONE * (CELL_SIZE - 2.0))


func _draw_island(cell: Vector2i) -> void:
	var center: Vector2 = battle.grid.cell_to_pixel(cell, BOARD_ORIGIN, CELL_SIZE)
	draw_circle(center, 25.0, Color("c5a96a"))
	draw_circle(center + Vector2(-2.0, -2.0), 20.0, Color("4a5946"))
	draw_circle(center + Vector2(-9.0, -8.0), 7.0, Color("75895b"))
	draw_circle(center + Vector2(8.0, 2.0), 9.0, Color("303c37"))


func _draw_side_indicator(center: Vector2) -> void:
	var ship := battle.get_ship(selected_ship_id)
	var forward := Vector2(battle.grid.DIRECTIONS[int(ship["facing"])]).normalized()
	var right := Vector2(-forward.y, forward.x)
	draw_line(center - right * 23.0, center - right * 42.0, PLAYER_COLOR, 5.0, true)
	draw_line(center + right * 23.0, center + right * 42.0, Color("f5a85b"), 5.0, true)


func _draw_turn_choices(center: Vector2) -> void:
	for command_value in battle.legal_turn_commands(selected_ship_id):
		var facing: int = int(command_value["facing"])
		var point := center + Vector2(battle.grid.DIRECTIONS[facing]).normalized() * 44.0
		var highlighted := facing == hovered_turn_facing
		var color := Color("fff0b0") if highlighted else Color("66d8e6")
		draw_circle(point, 13.0 if highlighted else 11.0, Color(color, 0.30))
		draw_arc(point, 13.0 if highlighted else 11.0, 0.0, TAU, 20, color, 2.5, true)
		var heading := Vector2(battle.grid.DIRECTIONS[facing]).normalized()
		draw_line(point - heading * 6.0, point + heading * 8.0, color, 3.0, true)
		draw_circle(point + heading * 8.0, 2.5, color)


func _turn_choice_at(screen_position: Vector2) -> int:
	if action_mode != "turn" or selected_ship_id == "":
		return -1
	var center := _ship_center(selected_ship_id)
	var closest_facing := -1
	var closest_distance := 19.0
	for command_value in battle.legal_turn_commands(selected_ship_id):
		var facing: int = int(command_value["facing"])
		var point := center + Vector2(battle.grid.DIRECTIONS[facing]).normalized() * 44.0
		var distance_value := screen_position.distance_to(point)
		if distance_value < closest_distance:
			closest_distance = distance_value
			closest_facing = facing
	return closest_facing


func _draw_class_markers() -> void:
	for ship_id in battle.ships:
		var ship: Dictionary = battle.ships[ship_id]
		if not bool(ship["alive"]):
			continue
		var center: Vector2 = battle.grid.cell_to_pixel(ship["cell"], BOARD_ORIGIN, CELL_SIZE)
		var team_color := PLAYER_COLOR if int(ship["team"]) == 0 else ENEMY_COLOR
		var radius := 27.0 if ship["class_id"] == "fast" else 30.0
		draw_arc(center, radius, 0.0, TAU, 36, Color(team_color, 0.68), 2.0, true)
		if ship["class_id"] == "gunship":
			draw_arc(center, radius + 4.0, 0.0, TAU, 36, Color(team_color, 0.42), 2.0, true)
		var badge := "快" if ship["class_id"] == "fast" else "炮"
		draw_string(ThemeDB.fallback_font, center + Vector2(-8.0, -30.0), badge, HORIZONTAL_ALIGNMENT_CENTER, 16.0, 14, TEXT_COLOR)
		if battle.mission_id == "flagship" and battle.flagship_ids[int(ship["team"])] == ship_id:
			var crown_center := center + Vector2(0.0, -41.0)
			var crown := PackedVector2Array([
				crown_center + Vector2(-8.0, 5.0), crown_center + Vector2(-7.0, -3.0),
				crown_center + Vector2(-2.0, 2.0), crown_center + Vector2(0.0, -5.0),
				crown_center + Vector2(3.0, 2.0), crown_center + Vector2(8.0, -3.0),
				crown_center + Vector2(8.0, 5.0),
			])
			draw_polyline(crown, Color("f5cf6a"), 2.0, true)
		if int(ship.get("destabilized_by_team", -1)) >= 0:
			var status_color := Color("f5b642")
			draw_arc(center, radius + 8.0, 0.18, 1.25, 10, status_color, 3.0, true)
			draw_arc(center, radius + 8.0, 1.75, 2.82, 10, status_color, 3.0, true)
			draw_arc(center, radius + 8.0, 3.32, 4.39, 10, status_color, 3.0, true)
			draw_arc(center, radius + 8.0, 4.89, 5.96, 10, status_color, 3.0, true)
			draw_line(center + Vector2(-8.0, -8.0), center + Vector2(8.0, 8.0), status_color, 2.0, true)
			draw_line(center + Vector2(8.0, -8.0), center + Vector2(-8.0, 8.0), status_color, 2.0, true)


func _roster_button(minimum_size: Vector2, font_size: int) -> Button:
	var entry := Button.new()
	entry.custom_minimum_size = minimum_size
	entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	entry.add_theme_font_size_override("font_size", font_size)
	entry.focus_mode = Control.FOCUS_NONE
	return entry


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


func _bar(value: int, maximum: int) -> String:
	var filled := clampi(roundi(float(value) / float(maxi(1, maximum)) * 10.0), 0, 10)
	return "[color=#39b8cf]%s[/color][color=#31505a]%s[/color]" % ["■".repeat(filled), "■".repeat(10 - filled)]


func _ap_pips(ap: int) -> String:
	return "%s %s" % ["◆" if ap >= 1 else "◇", "◆" if ap >= 2 else "◇"]


func _fleet_status(ship: Dictionary) -> String:
	if not bool(ship["alive"]):
		return "已沉没"
	if int(ship.get("destabilized_by_team", -1)) >= 0:
		return "失衡"
	if int(ship["hp"]) * 2 <= int(ship["max_hp"]):
		return "耐久告急"
	if int(ship["ap"]) <= 0:
		return "已行动"
	return "状态正常"


func _facing_name(facing: int) -> String:
	return ["东", "东南", "南", "西南", "西", "西北", "北", "东北"][posmod(facing, 8)]


func _facing_arrow(facing: int) -> String:
	return ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"][posmod(facing, 8)]


func _reason_text(reason: String) -> String:
	return {
		"no_ap": "行动力不足。",
		"out_of_range": "目标超出当前武器射程；请查看浅色射界。",
		"outside_arc": "目标不在所选侧舷射界内。",
		"line_blocked": "岛屿挡住了炮线。",
		"not_in_front": "冲撞目标必须位于船头正前方一格。",
		"nothing_to_undo": "当前没有可以撤销的航行。",
		"friendly_target": "不能攻击我方船只。",
		"invalid_target": "该格没有可攻击的敌船。",
		"invalid_turn": "只能向左或向右转舵45°/90°。",
		"action_not_available": "这类船不能执行这个行动。",
		"wrong_phase": "现在不是这艘船的行动阶段。",
	}.get(reason, "这个行动现在无法执行。")
