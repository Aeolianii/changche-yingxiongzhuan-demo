class_name FuboFishingMinigame
extends "res://scripts/fubo_guling/minigames/fubo_minigame_base.gd"

const FISHING_GAME := preload("res://scripts/fubo_guling/fubo_fishing_game.gd")
const EXIT_BUTTON_BRUSH := preload("res://assets/ui/sea_overworld/sea_map_return_brush_v1.png")
const CATCH_NAMES := {
	"small_fish": "黄花鱼",
	"big_fish": "大石斑",
	"crab": "青蟹",
	"rock": "海底岩石",
}

@onready var board: FuboFishingBoard = $Layout/FishingBoard
@onready var score_label: Label = $Layout/Info/Score
@onready var timer_label: Label = $Layout/Info/Timer
@onready var action_button: Button = $Layout/ActionButton
@onready var status_label: Label = $Layout/Status
@onready var exit_button: Button = $ExitButton

var _game: FuboFishingGame
var _started_ms := 0
var _completion_sent := false
var _exiting := false
var _catch_counts: Dictionary = {}


func _ready() -> void:
	game_id = "fishing"
	_started_ms = Time.get_ticks_msec()
	_game = FISHING_GAME.new()
	board.game = _game
	_apply_exit_button_style()
	board.cast_requested.connect(_perform_action)
	action_button.pressed.connect(_perform_action)
	exit_button.pressed.connect(_request_exit)
	_game.catch_landed.connect(_on_catch_landed)
	_game.empty_hook_returned.connect(_on_empty_hook_returned)
	_refresh_hud()


func _process(delta: float) -> void:
	if _game == null or _completion_sent:
		return
	_game.step(delta)
	_refresh_hud()
	if _game.get_state() == FISHING_GAME.State.FINISHED:
		_completion_sent = true
		action_button.disabled = true
		status_label.text = "目标达成！满载而归。"
		_finish_after_feedback.call_deferred()
	elif _game.get_state() == FISHING_GAME.State.FAILED:
		action_button.text = "再试一次"
		action_button.disabled = false
		status_label.text = "潮水将退，本次分数不足。点击“再试一次”。"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		_request_exit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_perform_action()
		get_viewport().set_input_as_handled()


func _perform_action() -> void:
	if _game == null or _completion_sent:
		return
	if _game.get_state() == FISHING_GAME.State.FAILED:
		_game.restart()
		_started_ms = Time.get_ticks_msec()
		action_button.text = "放下渔钩"
		status_label.text = "看准方向，按空格或点击放下渔钩。"
		return
	if _game.cast_hook():
		action_button.disabled = true
		status_label.text = "渔钩下水……碰到鱼获会自动收线。"


func _refresh_hud() -> void:
	score_label.text = "渔获 %d / %d 分" % [_game.get_score(), FISHING_GAME.TARGET_SCORE]
	timer_label.text = "剩余 %d 秒" % ceili(_game.get_time_left())
	if _game.get_state() == FISHING_GAME.State.SWINGING:
		action_button.disabled = false
		action_button.text = "放下渔钩"
	elif _game.get_state() == FISHING_GAME.State.EXTENDING:
		action_button.disabled = true
		action_button.text = "正在下钩"
	elif _game.get_state() == FISHING_GAME.State.RETRACTING:
		action_button.disabled = true
		action_button.text = "正在收线"


func _on_catch_landed(kind: String, value: int) -> void:
	_catch_counts[kind] = int(_catch_counts.get(kind, 0)) + 1
	board.flash_catch()
	status_label.text = "钓到%s，+%d 分！" % [String(CATCH_NAMES.get(kind, "鱼获")), value]


func _on_empty_hook_returned() -> void:
	status_label.text = "这一钩落空了，再看准些。"


func _finish_after_feedback() -> void:
	await get_tree().create_timer(0.65).timeout
	var result := build_result(_game.get_rating(), _game.get_empty_casts(), Time.get_ticks_msec() - _started_ms)
	result["catches"] = _catch_counts.duplicate(true)
	completed.emit(result)


func _request_exit() -> void:
	if _exiting:
		return
	_exiting = true
	action_button.disabled = true
	exit_button.disabled = true
	exit_requested.emit()


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


func cast_for_test() -> bool:
	return _game.cast_hook()


func get_game_for_test() -> FuboFishingGame:
	return _game
