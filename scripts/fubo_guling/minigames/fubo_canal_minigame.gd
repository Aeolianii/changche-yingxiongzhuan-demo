class_name FuboCanalMinigame
extends "res://scripts/fubo_guling/minigames/fubo_minigame_base.gd"

const CANAL_SCRIPT := preload("res://scripts/fubo_guling/fubo_canal_puzzle.gd")
const BRANCH_NAMES := ["左渠", "中渠", "右渠"]

@onready var round_label: Label = $Layout/RoundLabel
@onready var target_labels := [$Layout/TargetPanel/LeftTarget, $Layout/TargetPanel/CenterTarget, $Layout/TargetPanel/RightTarget]
@onready var branch_buttons := [$Layout/BranchButtons/Left, $Layout/BranchButtons/Center, $Layout/BranchButtons/Right]
@onready var release_button: Button = $Layout/ReleaseButton
@onready var status_label: Label = $Layout/Status
@onready var exit_confirm: PanelContainer = $ExitConfirm

var _game: FuboCanalPuzzle
var _selected_branch := 1
var _started_ms := 0
var _input_locked := false


func _ready() -> void:
	game_id = "canal"
	_started_ms = Time.get_ticks_msec()
	_game = CANAL_SCRIPT.new()
	_game.allocation_changed.connect(_on_allocation_changed)
	for index in branch_buttons.size():
		branch_buttons[index].pressed.connect(_select_branch.bind(index))
	release_button.pressed.connect(_release_selected)
	$ExitButton.pressed.connect(_show_exit_confirm)
	$ExitConfirm/VBoxContainer/Actions/Continue.pressed.connect(_hide_exit_confirm)
	$ExitConfirm/VBoxContainer/Actions/Leave.pressed.connect(func(): exit_requested.emit())
	exit_confirm.visible = false
	_game.start()
	_select_branch(1)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if exit_confirm.visible:
			_hide_exit_confirm()
		else:
			_show_exit_confirm()
		get_viewport().set_input_as_handled()


func _select_branch(branch: int) -> void:
	if _input_locked or branch < 0 or branch >= branch_buttons.size():
		return
	_selected_branch = branch
	for index in branch_buttons.size():
		branch_buttons[index].modulate = Color("ffe39b") if index == branch else Color.WHITE
	status_label.text = "已选择%s，点击“放水”释放一股水。" % BRANCH_NAMES[branch]


func _release_selected() -> int:
	if _input_locked:
		return CANAL_SCRIPT.RELEASE_REJECTED
	_input_locked = true
	_set_buttons_enabled(false)
	var result: int = _game.release_to(_selected_branch)
	match result:
		CANAL_SCRIPT.RELEASE_MISTAKE:
			status_label.text = "水流溢出或进入封闭支渠，本轮重新开始。"
		CANAL_SCRIPT.RELEASE_PROGRESS:
			status_label.text = "%s进水成功。" % BRANCH_NAMES[_selected_branch]
		CANAL_SCRIPT.RELEASE_ROUND_COMPLETE:
			status_label.text = "本轮完成，进入下一轮。"
		CANAL_SCRIPT.RELEASE_FINISHED:
			status_label.text = "三渠调度完成。"
			_finish_after_feedback.call_deferred()
	await get_tree().create_timer(0.22).timeout
	if result != CANAL_SCRIPT.RELEASE_FINISHED:
		_input_locked = false
		_set_buttons_enabled(true)
	return result


func _finish_after_feedback() -> void:
	await get_tree().create_timer(0.55).timeout
	completed.emit(build_result(_game.get_rating(), _game.get_mistakes(), Time.get_ticks_msec() - _started_ms))


func _on_allocation_changed(target: PackedInt32Array, levels: PackedInt32Array, blocked_branch: int, round_index: int) -> void:
	round_label.text = "第 %d / 3 轮" % (round_index + 1)
	for branch in 3:
		var suffix := " · 封闭" if branch == blocked_branch else ""
		target_labels[branch].text = "%s  %d / %d%s" % [BRANCH_NAMES[branch], levels[branch], target[branch], suffix]


func _set_buttons_enabled(enabled: bool) -> void:
	for button in branch_buttons:
		button.disabled = not enabled
	release_button.disabled = not enabled


func _show_exit_confirm() -> void:
	exit_confirm.visible = true
	_set_buttons_enabled(false)


func _hide_exit_confirm() -> void:
	exit_confirm.visible = false
	if not _input_locked:
		_set_buttons_enabled(true)


func choose_branch_for_test(branch: int) -> void:
	_select_branch(branch)


func get_selected_branch_for_test() -> int:
	return _selected_branch
