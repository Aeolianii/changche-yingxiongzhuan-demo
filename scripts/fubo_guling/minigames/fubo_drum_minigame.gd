class_name FuboDrumMinigame
extends "res://scripts/fubo_guling/minigames/fubo_minigame_base.gd"

const DRUM_SCRIPT := preload("res://scripts/fubo_guling/fubo_drum_memory.gd")
const DRUM_NAMES := ["左鼓", "中鼓", "边鼓"]

@onready var round_label: Label = $Layout/RoundLabel
@onready var beat_track: ProgressBar = $Layout/BeatTrack
@onready var drum_buttons: Array[Button] = [$Layout/Drums/LeftDrum, $Layout/Drums/CenterDrum, $Layout/Drums/RightDrum]
@onready var status_label: Label = $Layout/Status
@onready var audio_players: Array[AudioStreamPlayer] = [$AudioLow, $AudioMid, $AudioRim]
@onready var fail_audio: AudioStreamPlayer = $AudioFail
@onready var exit_confirm: PanelContainer = $ExitConfirm
@onready var resume_countdown: Label = $ResumeCountdown

var _game: FuboDrumMemory
var _started_ms := 0
var _demonstrating := false
var _input_enabled := false
var _focus_suspended := false
var _expected_input_ms := 0
var _round_token := 0


func _ready() -> void:
	game_id = "drum"
	_started_ms = Time.get_ticks_msec()
	_game = DRUM_SCRIPT.new()
	for index in drum_buttons.size():
		drum_buttons[index].pressed.connect(_submit_drum.bind(index))
	$ExitButton.pressed.connect(_show_exit_confirm)
	$ExitConfirm/VBoxContainer/Actions/Continue.pressed.connect(_hide_exit_confirm)
	$ExitConfirm/VBoxContainer/Actions/Leave.pressed.connect(func(): exit_requested.emit())
	exit_confirm.visible = false
	resume_countdown.visible = false
	beat_track.value = 0
	_game.start()
	_play_current_round.call_deferred()


func _exit_tree() -> void:
	_round_token += 1
	_input_enabled = false


func _process(_delta: float) -> void:
	if not _input_enabled or _focus_suspended:
		return
	var error_ms := Time.get_ticks_msec() - _expected_input_ms
	beat_track.value = clampf(50.0 + float(error_ms) / 5.6, 0.0, 100.0)
	if error_ms > DRUM_SCRIPT.PASS_WINDOW_MS:
		var sequence := _game.get_current_sequence()
		_game.submit(sequence[_game.get_input_index()], DRUM_SCRIPT.PASS_WINDOW_MS + 1)
		_handle_mistake("慢了一拍，本轮重新来。")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if exit_confirm.visible:
			_hide_exit_confirm()
		else:
			_show_exit_confirm()
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
	_set_drums_enabled(false)
	var sequence := _game.get_current_sequence()
	var intervals := _game.get_current_intervals_ms()
	round_label.text = "第 %d / 3 轮　%d BPM" % [_game.get_round_index() + 1, _game.get_current_bpm()]
	status_label.text = "先听鼓点，再用 A / S / D 跟敲。"
	beat_track.value = 0
	await get_tree().create_timer(0.45).timeout
	for index in sequence.size():
		if token != _round_token or _focus_suspended:
			return
		_play_drum(sequence[index])
		_flash_drum(sequence[index])
		beat_track.value = 100.0 * float(index + 1) / float(sequence.size())
		await get_tree().create_timer(float(intervals[index]) / 1000.0).timeout
	if token != _round_token or _focus_suspended:
		return
	_demonstrating = false
	_input_enabled = true
	_game.begin_input()
	_set_drums_enabled(true)
	status_label.text = "轮到你：按 A / S / D，尽量踩准节拍。"
	_expected_input_ms = Time.get_ticks_msec() + 420
	beat_track.value = 0


func _submit_drum(drum_index: int) -> int:
	if not _input_enabled or _demonstrating or _focus_suspended or exit_confirm.visible:
		return DRUM_SCRIPT.SUBMIT_REJECTED
	_play_drum(drum_index)
	_flash_drum(drum_index)
	var input_index := _game.get_input_index()
	var timing_error := Time.get_ticks_msec() - _expected_input_ms
	var result: int = _game.submit(drum_index, timing_error)
	match result:
		DRUM_SCRIPT.SUBMIT_MISTAKE:
			_handle_mistake("鼓色或节拍不对，本轮重新来。")
		DRUM_SCRIPT.SUBMIT_PROGRESS:
			status_label.text = "%s　%d / %d" % [_game.get_timing_label(timing_error), _game.get_input_index(), _game.get_current_sequence().size()]
			var intervals := _game.get_current_intervals_ms()
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
	var button := drum_buttons[index]
	button.modulate = Color("fff0a6")
	var tween := create_tween()
	tween.tween_property(button, "modulate", Color.WHITE, 0.18)


func _set_drums_enabled(enabled: bool) -> void:
	for button in drum_buttons:
		button.disabled = not enabled


func _show_exit_confirm() -> void:
	_round_token += 1
	_input_enabled = false
	_set_drums_enabled(false)
	exit_confirm.visible = true


func _hide_exit_confirm() -> void:
	exit_confirm.visible = false
	_play_current_round()


func _resume_after_focus() -> void:
	resume_countdown.visible = true
	for number in [3, 2, 1]:
		resume_countdown.text = str(number)
		await get_tree().create_timer(0.55).timeout
	resume_countdown.visible = false
	_play_current_round()
