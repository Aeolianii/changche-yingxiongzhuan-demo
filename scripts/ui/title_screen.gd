class_name TitleScreen
extends Control

const PALACE_SCENE := "res://scenes/palace/palace_demo.tscn"
const MUSIC_BUS_NAME := &"Music"
const SFX_BUS_NAME := &"SFX"
const AUDIO_FLOOR_DB := -80.0
const MENU_BUTTON_TEXTURE := preload("res://assets/ui/title_screen/menu_button_ink_v1.png")

@onready var background: TextureRect = $Background
@onready var main_content: Control = $MainContent
@onready var menu_block: VBoxContainer = %MenuBlock
@onready var save_status: Label = %SaveStatus
@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var settings_button: Button = %SettingsButton
@onready var exit_button: Button = %ExitButton
@onready var settings_panel: PanelContainer = %SettingsPanel
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_value: Label = %SfxValue
@onready var settings_return_button: Button = %SettingsReturnButton
@onready var fade: ColorRect = %Fade

var _busy := false


func _ready() -> void:
	_apply_visual_styles()
	_ensure_audio_buses()
	_connect_controls()
	_refresh_audio_controls()
	refresh_save_state()
	_start_entrance_animation()
	_focus_primary_action.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and settings_panel.visible:
		_close_settings()
		get_viewport().set_input_as_handled()


func refresh_save_state() -> void:
	var game_state := _game_state()
	var has_save := game_state != null and bool(game_state.call("has_save"))
	continue_button.disabled = not has_save or _busy
	save_status.hide()
	if has_save:
		continue_button.tooltip_text = "读取最近保存的主流程进度"
	else:
		continue_button.tooltip_text = "当前没有可读取的存档"


func is_settings_open() -> bool:
	return settings_panel.visible


func _connect_controls() -> void:
	continue_button.pressed.connect(_continue_game)
	new_game_button.pressed.connect(_start_new_game)
	settings_button.pressed.connect(_open_settings)
	exit_button.pressed.connect(_exit_game)
	settings_return_button.pressed.connect(_close_settings)
	music_slider.value_changed.connect(_on_volume_changed.bind(MUSIC_BUS_NAME, music_value))
	sfx_slider.value_changed.connect(_on_volume_changed.bind(SFX_BUS_NAME, sfx_value))


func _continue_game() -> void:
	if _busy:
		return
	var game_state := _game_state()
	if game_state == null:
		_show_error("read_failed")
		return
	_set_busy(true)
	var result: Dictionary = game_state.call("load_game")
	if not result.get("ok", false):
		_show_error(str(result.get("reason", "read_failed")))
		_set_busy(false)
		return
	var change_error := get_tree().change_scene_to_file(str(result["scene_path"]))
	if change_error == OK:
		return
	game_state.call("clear_pending_scene_state")
	_show_error("scene_change_failed")
	_set_busy(false)


func _start_new_game() -> void:
	if _busy:
		return
	_set_busy(true)
	var game_state := _game_state()
	if game_state != null:
		game_state.call("clear_pending_scene_state")
		game_state.call("reset_runtime_world_state")
	var change_error := get_tree().change_scene_to_file(PALACE_SCENE)
	if change_error == OK:
		return
	_show_error("scene_change_failed")
	_set_busy(false)


func _open_settings() -> void:
	if _busy:
		return
	menu_block.hide()
	save_status.hide()
	settings_panel.show()
	settings_return_button.grab_focus()


func _close_settings() -> void:
	settings_panel.hide()
	menu_block.show()
	save_status.hide()
	settings_button.grab_focus()


func _exit_game() -> void:
	get_tree().quit()


func _set_busy(value: bool) -> void:
	_busy = value
	var game_state := _game_state()
	continue_button.disabled = value or game_state == null or not bool(game_state.call("has_save"))
	new_game_button.disabled = value
	settings_button.disabled = value
	exit_button.disabled = value


func _show_error(reason: String) -> void:
	var game_state := _game_state()
	save_status.text = "存档操作失败。" if game_state == null else str(game_state.call("error_message", reason))
	save_status.modulate = Color(0.9, 0.55, 0.46)
	save_status.show()


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func _focus_primary_action() -> void:
	if not continue_button.disabled:
		continue_button.grab_focus()
	else:
		new_game_button.grab_focus()


func _ensure_audio_buses() -> void:
	for bus_name in [MUSIC_BUS_NAME, SFX_BUS_NAME]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var bus_index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
		AudioServer.set_bus_send(bus_index, &"Master")


func _refresh_audio_controls() -> void:
	music_slider.set_value_no_signal(_bus_volume_percent(MUSIC_BUS_NAME))
	sfx_slider.set_value_no_signal(_bus_volume_percent(SFX_BUS_NAME))
	music_value.text = "%d%%" % roundi(music_slider.value)
	sfx_value.text = "%d%%" % roundi(sfx_slider.value)


func _bus_volume_percent(bus_name: StringName) -> float:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0 or AudioServer.is_bus_mute(bus_index):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0, 0.0, 100.0)


func _on_volume_changed(value: float, bus_name: StringName, value_label: Label) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var percent := clampf(value, 0.0, 100.0)
	AudioServer.set_bus_mute(bus_index, percent <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, AUDIO_FLOOR_DB if percent <= 0.0 else linear_to_db(percent / 100.0))
	value_label.text = "%d%%" % roundi(percent)


func _apply_visual_styles() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.043, 0.043, 0.94)
	panel_style.border_color = Color(0.47, 0.36, 0.19, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 3
	panel_style.corner_radius_top_right = 3
	panel_style.corner_radius_bottom_left = 3
	panel_style.corner_radius_bottom_right = 3
	panel_style.shadow_color = Color(0, 0, 0, 0.55)
	panel_style.shadow_size = 18
	settings_panel.add_theme_stylebox_override("panel", panel_style)

	for button in [continue_button, new_game_button, settings_button, exit_button, settings_return_button]:
		_style_button(button)


func _style_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 25)
	button.add_theme_color_override("font_color", Color(0.86, 0.84, 0.75))
	button.add_theme_color_override("font_hover_color", Color(0.98, 0.84, 0.48))
	button.add_theme_color_override("font_focus_color", Color(0.98, 0.84, 0.48))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.9, 0.61))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.49, 0.45))
	button.add_theme_stylebox_override("normal", _button_texture_style(Color(0.82, 0.85, 0.8, 0.88)))
	button.add_theme_stylebox_override("hover", _button_texture_style(Color(1.12, 1.08, 0.85, 1.0)))
	button.add_theme_stylebox_override("focus", _button_texture_style(Color(1.12, 1.08, 0.85, 1.0)))
	button.add_theme_stylebox_override("pressed", _button_texture_style(Color(1.2, 1.1, 0.78, 1.0)))
	button.add_theme_stylebox_override("disabled", _button_texture_style(Color(0.44, 0.46, 0.43, 0.5)))


func _button_texture_style(modulate_color: Color) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = MENU_BUTTON_TEXTURE
	style.modulate_color = modulate_color
	style.content_margin_left = 86
	style.content_margin_right = 32
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _start_entrance_animation() -> void:
	main_content.modulate.a = 0.0
	background.pivot_offset = size * 0.5
	background.scale = Vector2(1.025, 1.025)
	var intro := create_tween().set_parallel(true)
	intro.tween_property(fade, "color:a", 0.0, 1.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	intro.tween_property(main_content, "modulate:a", 1.0, 0.9).set_delay(0.25)
	var drift := create_tween().set_loops()
	drift.tween_property(background, "scale", Vector2(1.055, 1.055), 18.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(background, "scale", Vector2(1.025, 1.025), 18.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
