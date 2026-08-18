class_name FuboDrumMinigame
extends "res://scripts/fubo_guling/minigames/fubo_minigame_base.gd"

const DRUM_SCRIPT := preload("res://scripts/fubo_guling/fubo_drum_memory.gd")
const EXIT_BUTTON_BRUSH := preload("res://assets/ui/sea_overworld/sea_map_return_brush_v1.png")
const DRUM_NAMES := ["大鼓", "堂鼓", "鼓边"]

@onready var round_label: Label = $Layout/RoundLabel
@onready var beat_track: FuboTimingMeter = $Layout/BeatTrack
@onready var drum_stage: FuboDrumStage = $Layout/DrumStage
@onready var drum_buttons: Array[Button] = [$Layout/Drums/LeftDrum, $Layout/Drums/CenterDrum, $Layout/Drums/RightDrum]
@onready var ready_button: Button = $Layout/ReadyButton
@onready var status_label: Label = $Layout/StatusPanel/Status
@onready var audio_players: Array[AudioStreamPlayer] = [$AudioLow, $AudioMid, $AudioRim]
@onready var fail_audio: AudioStreamPlayer = $AudioFail
@onready var resume_countdown: Label = $ResumeCountdown
@onready var exit_button: Button = $ExitButton

var _game: FuboDrumMemory
var _started_ms := 0
var _demonstrating := false
var _input_enabled := false
var _focus_suspended := false
var _waiting_for_ready := false
var _waiting_for_first_input := false
var _counting_in := false
var _expected_input_ms := 0
var _round_token := 0


func _ready() -> void:
	game_id = "drum"
	_started_ms = Time.get_ticks_msec()
	_game = DRUM_SCRIPT.new()
	_apply_exit_button_style()
	for index in drum_buttons.size():
		drum_buttons[index].pressed.connect(_submit_drum.bind(index))
	drum_stage.drum_pressed.connect(_submit_drum)
	ready_button.pressed.connect(_begin_player_turn)
	exit_button.pressed.connect(request_exit)
	resume_countdown.visible = false
	ready_button.visible = false
	beat_track.reset()
	_game.start()
	_play_current_round.call_deferred()


func _exit_tree() -> void:
	_round_token += 1
	_input_enabled = false


func _process(_delta: float) -> void:
	if not _input_enabled or _focus_suspended or _waiting_for_first_input:
		return
	var error_ms := Time.get_ticks_msec() - _expected_input_ms
	beat_track.set_timing_error(error_ms)
	if error_ms > DRUM_SCRIPT.PASS_WINDOW_MS:
		var sequence := _game.get_current_sequence()
		_game.submit(sequence[_game.get_input_index()], DRUM_SCRIPT.PASS_WINDOW_MS + 1)
		beat_track.show_result(error_ms)
		_handle_mistake("慢拍超过 0.52 秒，本轮重新听。")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		request_exit()
		get_viewport().set_input_as_handled()
		return
	if _waiting_for_ready and event.is_action_pressed("ui_accept"):
		_begin_player_turn()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A, KEY_LEFT:
				_submit_drum(0)
			KEY_S, KEY_DOWN:
				_submit_drum(1)
			KEY_D, KEY_RIGHT:
				_submit_drum(2)


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focus_suspended = true
		_round_token += 1
		_input_enabled = false
		_waiting_for_ready = false
		_waiting_for_first_input = false
		_counting_in = false
		ready_button.visible = false
		resume_countdown.visible = false
		_set_drums_enabled(false)
		status_label.text = "游戏已暂停，返回窗口后继续。"
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and _focus_suspended:
		_focus_suspended = false
		_resume_after_focus.call_deferred()


func _play_current_round() -> void:
	_round_token += 1
	var token := _round_token
	_demonstrating = true
	_input_enabled = false
	_waiting_for_ready = false
	_waiting_for_first_input = false
	_counting_in = false
	ready_button.visible = false
	resume_countdown.visible = false
	_set_drums_enabled(false)
	var sequence := _game.get_current_sequence()
	var intervals := _game.get_current_intervals_ms()
	round_label.text = "第 %d / 3 轮　%d BPM" % [_game.get_round_index() + 1, _game.get_current_bpm()]
	status_label.text = "先听鼓点，再用 A / S / D 跟敲。"
	beat_track.reset()
	await get_tree().create_timer(0.45).timeout
	for index in sequence.size():
		if token != _round_token or _focus_suspended:
			return
		_play_drum(sequence[index])
		_flash_drum(sequence[index])
		beat_track.set_demo_progress(float(index + 1) / float(sequence.size()))
		await get_tree().create_timer(float(intervals[index]) / 1000.0).timeout
	if token != _round_token or _focus_suspended:
		return
	_enter_ready_state()


func _enter_ready_state() -> void:
	_demonstrating = false
	_input_enabled = false
	_waiting_for_ready = true
	_waiting_for_first_input = false
	_counting_in = false
	_set_drums_enabled(false)
	ready_button.visible = true
	ready_button.disabled = false
	ready_button.text = "准备好了 · 开始跟敲"
	status_label.text = "示范结束。看清键位后再开始；等待多久都不会判错。"
	beat_track.reset()


func _begin_player_turn() -> void:
	if not _waiting_for_ready or _focus_suspended:
		return
	_waiting_for_ready = false
	_counting_in = true
	ready_button.disabled = true
	ready_button.visible = false
	var token := _round_token
	resume_countdown.visible = true
	for number in [3, 2, 1]:
		if token != _round_token or _focus_suspended:
			resume_countdown.visible = false
			_counting_in = false
			return
		resume_countdown.text = str(number)
		status_label.text = "准备跟敲……%d" % number
		await get_tree().create_timer(0.52).timeout
	if token != _round_token or _focus_suspended:
		resume_countdown.visible = false
		_counting_in = false
		return
	resume_countdown.visible = false
	_counting_in = false
	_input_enabled = true
	_waiting_for_first_input = true
	_game.begin_input()
	_set_drums_enabled(true)
	status_label.text = "轮到你：第一下由你起拍，从第二拍开始跟节奏。"
	beat_track.reset()


func _submit_drum(drum_index: int) -> int:
	if not _input_enabled or _demonstrating or _focus_suspended:
		return DRUM_SCRIPT.SUBMIT_REJECTED
	_play_drum(drum_index)
	_flash_drum(drum_index)
	var input_index := _game.get_input_index()
	var first_input := _waiting_for_first_input
	var now_ms := Time.get_ticks_msec()
	var timing_error := 0 if first_input else now_ms - _expected_input_ms
	var sequence := _game.get_current_sequence()
	var expected_drum := sequence[input_index]
	var wrong_drum := drum_index != expected_drum
	_waiting_for_first_input = false
	var result: int = _game.submit(drum_index, timing_error)
	beat_track.show_result(timing_error)
	match result:
		DRUM_SCRIPT.SUBMIT_MISTAKE:
			if wrong_drum:
				_handle_mistake("按错鼓：这一拍应敲%s。本轮重新听。" % DRUM_NAMES[expected_drum])
			else:
				_handle_mistake("慢拍超过 0.52 秒，本轮重新听。")
		DRUM_SCRIPT.SUBMIT_PROGRESS:
			status_label.text = "%s　%d / %d" % [_game.get_timing_label(timing_error), _game.get_input_index(), _game.get_current_sequence().size()]
			var intervals := _game.get_current_intervals_ms()
			if first_input:
				_expected_input_ms = now_ms + intervals[mini(input_index, intervals.size() - 1)]
			else:
				_expected_input_ms += intervals[mini(input_index, intervals.size() - 1)]
		DRUM_SCRIPT.SUBMIT_ROUND_COMPLETE:
			_input_enabled = false
			_set_drums_enabled(false)
			status_label.text = "这一轮合拍！准备下一轮。"
			await get_tree().create_timer(0.75).timeout
			_play_current_round()
		DRUM_SCRIPT.SUBMIT_FINISHED:
			_input_enabled = false
			_set_drums_enabled(false)
			status_label.text = "三轮鼓令完成！"
			await get_tree().create_timer(0.6).timeout
			var rating := "应鼓如神" if _game.get_mistakes() == 0 else ("鼓点稳健" if _game.get_mistakes() <= 2 else "完成鼓令")
			completed.emit(build_result(rating, _game.get_mistakes(), Time.get_ticks_msec() - _started_ms))
	return result


func _handle_mistake(message: String) -> void:
	if not _input_enabled:
		return
	_input_enabled = false
	_waiting_for_first_input = false
	_set_drums_enabled(false)
	fail_audio.play()
	status_label.text = message
	round_restarted.emit(_game.get_round_index())
	await get_tree().create_timer(0.7).timeout
	_play_current_round()


func _play_drum(index: int) -> void:
	if index >= 0 and index < audio_players.size():
		audio_players[index].play()


func _flash_drum(index: int) -> void:
	if index < 0 or index >= drum_buttons.size():
		return
	drum_stage.flash_drum(index)
	var button := drum_buttons[index]
	button.modulate = Color("fff0a6")
	var tween := create_tween()
	tween.tween_property(button, "modulate", Color.WHITE, 0.18)


func _set_drums_enabled(enabled: bool) -> void:
	drum_stage.set_input_enabled(enabled)
	for button in drum_buttons:
		button.disabled = not enabled


func _apply_exit_button_style() -> void:
	exit_button.focus_mode = Control.FOCUS_NONE
	exit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	exit_button.add_theme_font_size_override("font_size", 19)
	exit_button.add_theme_color_override("font_color", Color("f4ead0"))
	exit_button.add_theme_color_override("font_hover_color", Color("f6d987"))
	exit_button.add_theme_color_override("font_pressed_color", Color("f6d987"))
	exit_button.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.02, 1.0))
	exit_button.add_theme_constant_override("outline_size", 4)
	exit_button.add_theme_stylebox_override("normal", _exit_brush_style(Color.WHITE))
	exit_button.add_theme_stylebox_override("hover", _exit_brush_style(Color(1.0, 0.94, 0.78, 1.0)))
	exit_button.add_theme_stylebox_override("pressed", _exit_brush_style(Color(0.72, 0.76, 0.72, 1.0)))
	exit_button.add_theme_stylebox_override("disabled", _exit_brush_style(Color(0.5, 0.5, 0.5, 0.65)))


func _exit_brush_style(modulate: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = EXIT_BUTTON_BRUSH
	style.modulate_color = modulate
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


func _resume_after_focus() -> void:
	resume_countdown.visible = true
	for number in [3, 2, 1]:
		resume_countdown.text = str(number)
		await get_tree().create_timer(0.55).timeout
	resume_countdown.visible = false
	_play_current_round()


func enter_ready_state_for_test() -> void:
	_round_token += 1
	_enter_ready_state()


func begin_player_turn_immediately_for_test() -> void:
	if not _waiting_for_ready:
		return
	_waiting_for_ready = false
	_counting_in = false
	ready_button.visible = false
	resume_countdown.visible = false
	_input_enabled = true
	_waiting_for_first_input = true
	_game.begin_input()
	_set_drums_enabled(true)


func is_waiting_for_ready_for_test() -> bool:
	return _waiting_for_ready


func is_waiting_for_first_input_for_test() -> bool:
	return _waiting_for_first_input


func is_counting_in_for_test() -> bool:
	return _counting_in


func get_mistakes_for_test() -> int:
	return _game.get_mistakes()


func get_current_sequence_for_test() -> PackedInt32Array:
	return _game.get_current_sequence()


func submit_drum_for_test(index: int) -> int:
	return await _submit_drum(index)
