extends Control

const PROTAGONIST_PORTRAIT := preload("res://assets/characters/protagonist/picture.png")
const EXPLORATION_STATUS_FRAME := preload("res://assets/ui/exploration_hud/player_status_frame.png")
const EXPLORATION_QUEST_FRAME := preload("res://assets/ui/exploration_hud/quest_tracker_frame.png")
const EXPLORATION_FUNCTION_BUTTON := preload("res://assets/ui/exploration_hud/function_button.png")
const EXPLORATION_FUNCTION_BRUSHSTROKE := preload("res://assets/ui/exploration_hud/function_buttons_brushstroke.png")
const HUD_ICON_QUEST := preload("res://assets/ui/icons/hud_quest.png")
const HUD_ICON_CHARACTER := preload("res://assets/ui/icons/hud_character.png")
const HUD_ICON_INVENTORY := preload("res://assets/ui/icons/hud_inventory.png")
const HUD_ICON_SHIP := preload("res://assets/ui/icons/hud_ship.png")
const HUD_ICON_MENU := preload("res://assets/ui/icons/hud_menu.png")
const HUD_ICON_MAP := preload("res://assets/ui/icons/hud_map_v1.png")
const SEA_MOON_TEXTURE := preload("res://assets/ui/sea_overworld/moon_clock_moon.png")
const MOON_PHASE_SHADER := preload("res://shaders/moon_phase.gdshader")
const MENU_ICON_CONTINUE := preload("res://assets/ui/icons/menu_continue.png")
const MENU_ICON_SAVE := preload("res://assets/ui/icons/menu_save.png")
const MENU_ICON_LOAD := preload("res://assets/ui/icons/menu_load.png")
const MENU_ICON_SETTINGS := preload("res://assets/ui/icons/menu_settings.png")
const MENU_ICON_RETURN_TITLE := preload("res://assets/ui/icons/menu_return_title.png")
const MENU_ICON_EXIT := preload("res://assets/ui/icons/menu_exit.png")
const MENU_BLUR_SHADER := preload("res://shaders/menu_blur.gdshader")
const MENU_BUTTON_HIGHLIGHT_SHADER := preload("res://shaders/menu_button_highlight.gdshader")
const SYSTEM_MENU_FRAME := preload("res://assets/ui/system_menu/system_menu_frame.png")
const SYSTEM_MENU_BUTTON := preload("res://assets/ui/system_menu/menu_button.png")
const SYSTEM_MENU_CLOSE := preload("res://assets/ui/system_menu/close_button.png")
const SETTINGS_RETURN_BUTTON := preload("res://assets/ui/system_menu/settings_return_button.png")
const VOLUME_SLIDER_TRACK := preload("res://assets/ui/system_menu/volume_slider_track.png")
const VOLUME_SLIDER_KNOB := preload("res://assets/ui/system_menu/volume_slider_knob.png")
const QUEST_SCREEN_SCENE := preload("res://scenes/ui/quest_screen.tscn")
const SEA_MAP_SCREEN_SCENE := preload("res://scenes/ui/sea_map_screen.tscn")

const INK := Color(0.055, 0.073, 0.075, 0.96)
const PAPER := Color(0.83, 0.77, 0.61, 0.96)
const PAPER_DARK := Color(0.55, 0.48, 0.34, 0.96)
const GOLD := Color(0.73, 0.59, 0.32, 1.0)
const GOLD_BRIGHT := Color(0.95, 0.82, 0.51, 1.0)
const JADE := Color(0.16, 0.38, 0.36, 1.0)
const TEXT_LIGHT := Color(0.96, 0.91, 0.78, 1.0)
const TEXT_MUTED := Color(0.72, 0.71, 0.64, 1.0)
const MUSIC_BUS_NAME := &"Music"
const SFX_BUS_NAME := &"SFX"
const AUDIO_FLOOR_DB := -80.0
const LUNAR_CYCLE_DAYS := 29.5

var _main_task_label: Label
var _main_objective_label: Label
var _toast_panel: Panel
var _toast_label: Label
var _toast_timer: Timer
var _menu_overlay: Control
var _system_panel: Control
var _settings_panel: Control
var _quest_screen: Control
var _map_screen: Control
var _map_icon: TextureRect
var _moon_icon: TextureRect
var _moon_phase_label: Label
var _moon_material: ShaderMaterial
var _sea_map_status: Control
var _sea_map_mode := false

signal menu_visibility_changed(is_open: bool)
signal save_requested
signal load_requested
signal return_title_requested


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_audio_buses()
	_build_status_panel()
	_build_task_tracker()
	_build_function_buttons()
	_build_quest_screen()
	_build_map_screen()
	_build_system_menu()
	_build_settings_panel()
	_build_toast()
	set_exploration_visible(false)


func set_exploration_visible(value: bool) -> void:
	if not value:
		if is_map_screen_open():
			_map_screen.hide()
			_set_function_buttons_visible(true)
		if is_quest_screen_open():
			_close_quest_screen()
		if _is_system_menu_open():
			_close_system_menu()
	visible = value
	if not value and is_instance_valid(_toast_panel):
		_toast_panel.hide()


func set_main_task(task_title: String) -> void:
	if is_instance_valid(_main_task_label):
		_main_task_label.text = task_title
	if is_instance_valid(_quest_screen):
		_quest_screen.call("set_main_task", task_title)


func set_main_task_progress(task_title: String, objective: String, progress_stage: int) -> void:
	if is_instance_valid(_main_task_label):
		_main_task_label.text = task_title
	if is_instance_valid(_main_objective_label):
		_main_objective_label.text = objective
	if is_instance_valid(_quest_screen):
		_quest_screen.call("set_main_task_progress", task_title, objective, progress_stage)


func set_quest_context(context_id: StringName) -> void:
	if context_id != &"sea_overworld":
		return
	_enable_sea_map_status()
	if is_instance_valid(_main_task_label):
		_main_task_label.text = "探索海域，完善海图"
	if is_instance_valid(_main_objective_label):
		_main_objective_label.text = "使用WASD或方向键驾驶船只"
	var side_task := get_node_or_null("QuestTracker/SideQuest/TaskName") as Label
	var side_objective := get_node_or_null("QuestTracker/SideQuest/Objective") as Label
	if side_task != null:
		side_task.text = "海上见闻"
	if side_objective != null:
		side_objective.text = "接触海上的船只或漂流事件"
	if is_instance_valid(_quest_screen):
		_quest_screen.call("set_quest_context", context_id)


func configure_sea_map(player_node: Node2D, world_size: Vector2, locations: Array, map_chunks: Array = [], fog_of_war: Node = null) -> void:
	if is_instance_valid(_map_screen):
		_map_screen.call("configure", player_node, world_size, locations, map_chunks, fog_of_war)


func set_lunar_day(total_days: float) -> void:
	if not _sea_map_mode or not is_instance_valid(_moon_material):
		return
	var normalized_phase := fposmod(total_days, LUNAR_CYCLE_DAYS) / LUNAR_CYCLE_DAYS
	_moon_material.set_shader_parameter("phase", normalized_phase)
	if is_instance_valid(_moon_phase_label):
		_moon_phase_label.text = _lunar_phase_name(normalized_phase)


func show_toast(message: String) -> void:
	if not is_instance_valid(_toast_panel):
		return
	_position_toast(false)
	_toast_label.text = message
	_toast_panel.show()
	_toast_timer.start()


func is_menu_open() -> bool:
	return _is_system_menu_open() or is_quest_screen_open() or is_map_screen_open()


func is_quest_screen_open() -> bool:
	return is_instance_valid(_quest_screen) and _quest_screen.visible


func is_settings_open() -> bool:
	return is_instance_valid(_settings_panel) and _settings_panel.visible


func is_map_screen_open() -> bool:
	return is_instance_valid(_map_screen) and _map_screen.visible


func _is_system_menu_open() -> bool:
	return is_instance_valid(_menu_overlay) and _menu_overlay.visible


func _build_status_panel() -> void:
	var status := Control.new()
	status.name = "PlayerStatus"
	status.position = Vector2(22, 18)
	status.size = Vector2(495, 192)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)

	var generated_frame := TextureRect.new()
	generated_frame.name = "GeneratedStatusFrame"
	generated_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	generated_frame.texture = EXPLORATION_STATUS_FRAME
	generated_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	generated_frame.stretch_mode = TextureRect.STRETCH_SCALE
	generated_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	generated_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(generated_frame)

	var portrait_frame := Panel.new()
	portrait_frame.name = "PortraitFrame"
	portrait_frame.position = Vector2(33, 23)
	portrait_frame.size = Vector2(141, 141)
	portrait_frame.clip_contents = true
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	status.add_child(portrait_frame)

	var portrait := Polygon2D.new()
	portrait.name = "ProtagonistPortrait"
	portrait.texture = PROTAGONIST_PORTRAIT
	portrait.polygon = PackedVector2Array([
		Vector2(70.5, 1.5), Vector2(139.5, 70.5), Vector2(70.5, 139.5), Vector2(1.5, 70.5)
	])
	var portrait_size := PROTAGONIST_PORTRAIT.get_size()
	portrait.uv = PackedVector2Array([
		Vector2(portrait_size.x * 0.5, 0),
		Vector2(portrait_size.x, portrait_size.y * 0.5),
		Vector2(portrait_size.x * 0.5, portrait_size.y),
		Vector2(0, portrait_size.y * 0.5),
	])
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait_frame.add_child(portrait)

	var name_panel := Panel.new()
	name_panel.name = "NamePlate"
	name_panel.position = Vector2(138, 64)
	name_panel.size = Vector2(336, 108)
	name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	status.add_child(name_panel)

	var name_label := _make_label("水师元帅", 23, Color(0.12, 0.13, 0.105, 1.0))
	name_label.name = "PlayerName"
	name_label.position = Vector2(56, 8)
	name_label.size = Vector2(278, 34)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	name_panel.add_child(name_label)

	var subtitle := _make_label("伏波将军 · 南疆水师", 15, Color(0.28, 0.29, 0.25, 1.0))
	subtitle.name = "PlayerTitle"
	subtitle.position = Vector2(57, 40)
	subtitle.size = Vector2(278, 28)
	subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	name_panel.add_child(subtitle)


func _enable_sea_map_status() -> void:
	var status := get_node_or_null("PlayerStatus") as Control
	if status == null or _sea_map_mode:
		return
	_sea_map_mode = true
	status.position = Vector2(69.5, 20)
	status.size = Vector2(195, 195)
	var generated_frame := status.get_node("GeneratedStatusFrame") as TextureRect
	generated_frame.texture = EXPLORATION_FUNCTION_BUTTON
	var portrait_frame := status.get_node("PortraitFrame") as Control
	portrait_frame.position = Vector2(40.5, 40.5)
	portrait_frame.size = Vector2(114, 114)
	portrait_frame.clip_contents = false
	var portrait := portrait_frame.get_node("ProtagonistPortrait") as CanvasItem
	portrait.hide()
	var name_panel := status.get_node("NamePlate") as Control
	name_panel.hide()

	_moon_material = ShaderMaterial.new()
	_moon_material.shader = MOON_PHASE_SHADER
	_moon_icon = TextureRect.new()
	_moon_icon.name = "MoonIcon"
	_moon_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_moon_icon.texture = SEA_MOON_TEXTURE
	_moon_icon.material = _moon_material
	_moon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_moon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_moon_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_moon_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(_moon_icon)

	_moon_phase_label = _make_label("新月", 17, TEXT_LIGHT)
	_moon_phase_label.name = "MoonPhaseName"
	_moon_phase_label.position = Vector2(0, 156)
	_moon_phase_label.size = Vector2(195, 25)
	_moon_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_moon_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.add_child(_moon_phase_label)

	_build_sea_map_button()


func _build_sea_map_button() -> void:
	_sea_map_status = Control.new()
	_sea_map_status.name = "SeaMapStatus"
	_sea_map_status.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_sea_map_status.offset_left = -156.0
	_sea_map_status.offset_top = -156.0
	_sea_map_status.offset_right = -20.0
	_sea_map_status.offset_bottom = -20.0
	_sea_map_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sea_map_status)

	var map_frame := TextureRect.new()
	map_frame.name = "GeneratedMapFrame"
	map_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_frame.texture = EXPLORATION_FUNCTION_BUTTON
	map_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_frame.stretch_mode = TextureRect.STRETCH_SCALE
	map_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sea_map_status.add_child(map_frame)

	_map_icon = TextureRect.new()
	_map_icon.name = "MapIcon"
	_map_icon.position = Vector2(25, 25)
	_map_icon.size = Vector2(86, 86)
	_map_icon.texture = HUD_ICON_MAP
	_map_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sea_map_status.add_child(_map_icon)

	var map_button := Button.new()
	map_button.name = "MapButton"
	map_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_button.flat = true
	map_button.focus_mode = Control.FOCUS_NONE
	map_button.tooltip_text = "查看岭南海图"
	map_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	map_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	map_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	map_button.add_theme_stylebox_override("pressed", _panel_style(Color(0.84, 0.67, 0.31, 0.18), Color(0, 0, 0, 0), 0, 70))
	map_button.mouse_entered.connect(_set_map_icon_highlight.bind(true))
	map_button.mouse_exited.connect(_set_map_icon_highlight.bind(false))
	map_button.pressed.connect(_open_map_screen)
	_sea_map_status.add_child(map_button)


func _lunar_phase_name(normalized_phase: float) -> String:
	var phase_index := posmod(roundi(normalized_phase * 8.0), 8)
	return ["新月", "蛾眉月", "上弦月", "盈凸月", "满月", "亏凸月", "下弦月", "残月"][phase_index]


func _set_map_icon_highlight(highlighted: bool) -> void:
	if is_instance_valid(_map_icon):
		_map_icon.modulate = Color(1.12, 1.08, 0.9, 1.0) if highlighted else Color.WHITE


func _build_task_tracker() -> void:
	var tracker := Panel.new()
	tracker.name = "QuestTracker"
	tracker.position = Vector2(24, 224)
	tracker.size = Vector2(286, 270)
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(tracker)

	var generated_frame := TextureRect.new()
	generated_frame.name = "GeneratedQuestFrame"
	generated_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	generated_frame.texture = EXPLORATION_QUEST_FRAME
	generated_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	generated_frame.stretch_mode = TextureRect.STRETCH_SCALE
	generated_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	generated_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.add_child(generated_frame)

	var title_ribbon := Panel.new()
	title_ribbon.name = "TitleRibbon"
	title_ribbon.position = Vector2(0, -2)
	title_ribbon.size = Vector2(286, 44)
	title_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_ribbon.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tracker.add_child(title_ribbon)

	var title := _make_label("任 务", 21, TEXT_LIGHT)
	title.name = "QuestTitle"
	title.position = Vector2.ZERO
	title.size = Vector2(286, 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_ribbon.add_child(title)

	_build_quest_entry(tracker, "MainQuest", Vector2(28, 48), "主线", true)
	_build_quest_entry(tracker, "SideQuest", Vector2(28, 156), "支线", false)


func _build_quest_entry(parent: Control, node_name: String, at: Vector2, section: String, is_main: bool) -> void:
	var entry_height := 96.0 if is_main else 88.0
	var entry := Panel.new()
	entry.name = node_name
	entry.position = at
	entry.size = Vector2(232, entry_height)
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var entry_style := StyleBoxFlat.new()
	entry_style.bg_color = Color(0, 0, 0, 0)
	entry_style.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.42)
	entry_style.set_border_width_all(0)
	if is_main:
		entry_style.set_border_width(SIDE_BOTTOM, 1)
	entry.add_theme_stylebox_override("panel", entry_style)
	parent.add_child(entry)

	var accent := ColorRect.new()
	accent.name = "Accent"
	accent.position = Vector2(0, 0)
	accent.size = Vector2(4, entry_height)
	accent.color = GOLD if is_main else JADE
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(accent)

	var tag := _make_label("【%s】" % section, 15, GOLD_BRIGHT if is_main else Color(0.55, 0.82, 0.75, 1.0))
	tag.name = "QuestType"
	tag.position = Vector2(18, 5)
	tag.size = Vector2(198, 22)
	entry.add_child(tag)

	var task := _make_label("奉诏入殿" if is_main else "访查军港", 18, TEXT_LIGHT)
	task.name = "TaskName"
	task.position = Vector2(19, 28)
	task.size = Vector2(198, 25)
	entry.add_child(task)
	if is_main:
		_main_task_label = task

	var objective := _make_label("前往标记地点推进剧情" if is_main else "与船匠交谈（效果占位）", 13, TEXT_MUTED)
	objective.name = "Objective"
	objective.position = Vector2(19, 52)
	objective.size = Vector2(198, 40 if is_main else 32)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.max_lines_visible = 2
	objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective.clip_text = true
	entry.add_child(objective)
	if is_main:
		_main_objective_label = objective


func _build_function_buttons() -> void:
	var brushstroke := TextureRect.new()
	brushstroke.name = "FunctionButtonsBrushstroke"
	brushstroke.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	brushstroke.offset_left = -680.0
	brushstroke.offset_top = 32.0
	brushstroke.offset_right = 0.0
	brushstroke.offset_bottom = 100.0
	brushstroke.texture = EXPLORATION_FUNCTION_BRUSHSTROKE
	brushstroke.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brushstroke.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	brushstroke.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	brushstroke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brushstroke.modulate.a = 0.82
	add_child(brushstroke)

	var actions := HBoxContainer.new()
	actions.name = "FunctionButtons"
	actions.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	actions.offset_left = -580.0
	actions.offset_top = 18.0
	actions.offset_right = -18.0
	actions.offset_bottom = 130.0
	actions.add_theme_constant_override("separation", 8)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(actions)

	var specs := [
		["任务", HUD_ICON_QUEST, "QuestButton"],
		["人物", HUD_ICON_CHARACTER, "CharacterButton"],
		["物品栏", HUD_ICON_INVENTORY, "InventoryButton"],
		["船只", HUD_ICON_SHIP, "ShipButton"],
		["菜单", HUD_ICON_MENU, "MenuButton"],
	]
	for spec in specs:
		_build_function_button(actions, spec[0], spec[1], spec[2])


func _build_function_button(parent: HBoxContainer, action_name: String, icon_texture: Texture2D, node_name: String) -> void:
	var slot := Control.new()
	slot.name = "%sSlot" % node_name
	slot.custom_minimum_size = Vector2(106, 108)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(slot)

	var generated_texture := TextureRect.new()
	generated_texture.name = "GeneratedFunctionTexture"
	generated_texture.position = Vector2(6, -2)
	generated_texture.size = Vector2(94, 94)
	generated_texture.texture = EXPLORATION_FUNCTION_BUTTON
	generated_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	generated_texture.stretch_mode = TextureRect.STRETCH_SCALE
	generated_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	generated_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(generated_texture)

	var icon := TextureRect.new()
	icon.name = "FunctionIcon"
	var icon_x := 25.0
	if node_name == "ShipButton":
		icon_x = 21.0
	elif node_name == "MenuButton":
		icon_x = 29.0
	icon.position = Vector2(icon_x, 18)
	icon.size = Vector2(56, 56)
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var name_label := _make_label(action_name, 17, TEXT_LIGHT)
	name_label.name = "FunctionName"
	name_label.position = Vector2(3, 86)
	name_label.size = Vector2(100, 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_child(name_label)

	var button := Button.new()
	button.name = node_name
	button.position = Vector2(5, 0)
	button.size = Vector2(96, 106)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = action_name
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.84, 0.67, 0.31, 0.27), Color(0, 0, 0, 0), 0, 7))
	if node_name == "MenuButton":
		button.pressed.connect(_open_system_menu)
	elif node_name == "QuestButton":
		button.pressed.connect(_open_quest_screen)
	else:
		button.pressed.connect(_show_locked_message.bind(action_name))
	slot.add_child(button)


func _build_quest_screen() -> void:
	_quest_screen = QUEST_SCREEN_SCENE.instantiate() as Control
	_quest_screen.name = "QuestScreen"
	_quest_screen.connect("close_requested", _close_quest_screen)
	add_child(_quest_screen)


func _build_map_screen() -> void:
	_map_screen = SEA_MAP_SCREEN_SCENE.instantiate() as Control
	_map_screen.name = "SeaMapScreen"
	_map_screen.connect("close_requested", _close_map_screen)
	add_child(_map_screen)


func _build_system_menu() -> void:
	_menu_overlay = Control.new()
	_menu_overlay.name = "SystemMenu"
	_menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_overlay.z_index = 100
	_menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_menu_overlay)

	var back_buffer := BackBufferCopy.new()
	back_buffer.name = "BackgroundCopy"
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_menu_overlay.add_child(back_buffer)

	var blur := ColorRect.new()
	blur.name = "BlurredBackground"
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var blur_material := ShaderMaterial.new()
	blur_material.shader = MENU_BLUR_SHADER
	blur.material = blur_material
	_menu_overlay.add_child(blur)

	var dim := ColorRect.new()
	dim.name = "Dimmer"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.025, 0.035, 0.03, 0.28)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_overlay.add_child(dim)

	_system_panel = Control.new()
	_system_panel.name = "SystemPanel"
	_system_panel.set_anchors_preset(Control.PRESET_CENTER)
	_system_panel.offset_left = -225.0
	_system_panel.offset_top = -320.0
	_system_panel.offset_right = 225.0
	_system_panel.offset_bottom = 320.0
	_system_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_overlay.add_child(_system_panel)

	var generated_frame := TextureRect.new()
	generated_frame.name = "GeneratedFrame"
	generated_frame.position = Vector2(-80, -60)
	generated_frame.size = Vector2(610, 780)
	generated_frame.texture = SYSTEM_MENU_FRAME
	generated_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	generated_frame.stretch_mode = TextureRect.STRETCH_SCALE
	generated_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	generated_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_system_panel.add_child(generated_frame)

	var title := _make_label("系  统", 25, Color(0.12, 0.13, 0.105, 1.0))
	title.name = "MenuTitle"
	title.position = Vector2(102, -44)
	title.size = Vector2(246, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_system_panel.add_child(title)

	var close_slot := Control.new()
	close_slot.name = "CloseButtonOrnament"
	close_slot.position = Vector2(409, -28)
	close_slot.size = Vector2(82, 82)
	close_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_system_panel.add_child(close_slot)

	var close_texture := TextureRect.new()
	close_texture.name = "GeneratedCloseTexture"
	close_texture.position = Vector2(-8, -8)
	close_texture.size = Vector2(98, 98)
	close_texture.texture = SYSTEM_MENU_CLOSE
	close_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	close_texture.stretch_mode = TextureRect.STRETCH_SCALE
	close_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	close_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_slot.add_child(close_texture)

	var close_button := Button.new()
	close_button.name = "CloseMenuButton"
	close_button.position = Vector2.ZERO
	close_button.size = Vector2(82, 82)
	close_button.text = "×"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_size_override("font_size", 30)
	close_button.add_theme_color_override("font_color", TEXT_LIGHT)
	close_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	close_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	close_button.add_theme_stylebox_override("pressed", _panel_style(Color(0.84, 0.67, 0.31, 0.24), Color(0, 0, 0, 0), 0, 38))
	close_button.pressed.connect(_close_system_menu)
	close_slot.add_child(close_button)

	var menu_list := VBoxContainer.new()
	menu_list.name = "MenuEntries"
	menu_list.position = Vector2(68, 58)
	menu_list.size = Vector2(314, 505)
	menu_list.add_theme_constant_override("separation", 29)
	menu_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_system_panel.add_child(menu_list)

	var entries := [
		["继续游戏", MENU_ICON_CONTINUE, "ContinueGameButton"],
		["保存进度", MENU_ICON_SAVE, "SaveGameButton"],
		["读取进度", MENU_ICON_LOAD, "LoadGameButton"],
		["游戏设置", MENU_ICON_SETTINGS, "SettingsButton"],
		["返回标题", MENU_ICON_RETURN_TITLE, "ReturnTitleButton"],
		["退出游戏", MENU_ICON_EXIT, "ExitGameButton"],
	]
	for entry in entries:
		_build_system_menu_entry(menu_list, entry[0], entry[1], entry[2])

	_menu_overlay.hide()


func _build_settings_panel() -> void:
	_settings_panel = Control.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.offset_left = -225.0
	_settings_panel.offset_top = -320.0
	_settings_panel.offset_right = 225.0
	_settings_panel.offset_bottom = 320.0
	_settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_overlay.add_child(_settings_panel)

	var generated_frame := TextureRect.new()
	generated_frame.name = "GeneratedFrame"
	generated_frame.position = Vector2(-80, -60)
	generated_frame.size = Vector2(610, 780)
	generated_frame.texture = SYSTEM_MENU_FRAME
	generated_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	generated_frame.stretch_mode = TextureRect.STRETCH_SCALE
	generated_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	generated_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_panel.add_child(generated_frame)

	var title := _make_label("游戏设置", 25, Color(0.12, 0.13, 0.105, 1.0))
	title.name = "SettingsTitle"
	title.position = Vector2(102, -44)
	title.size = Vector2(246, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_settings_panel.add_child(title)

	var return_slot := Control.new()
	return_slot.name = "SettingsReturnOrnament"
	return_slot.position = Vector2(409, -28)
	return_slot.size = Vector2(82, 112)
	return_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_panel.add_child(return_slot)

	var return_texture := TextureRect.new()
	return_texture.name = "GeneratedReturnTexture"
	return_texture.position = Vector2(-8, -8)
	return_texture.size = Vector2(98, 98)
	return_texture.texture = SETTINGS_RETURN_BUTTON
	return_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return_texture.stretch_mode = TextureRect.STRETCH_SCALE
	return_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return_slot.add_child(return_texture)

	var return_button := Button.new()
	return_button.name = "SettingsReturnButton"
	return_button.position = Vector2.ZERO
	return_button.size = Vector2(82, 82)
	return_button.tooltip_text = "返回系统菜单"
	return_button.focus_mode = Control.FOCUS_NONE
	return_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	return_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	return_button.add_theme_stylebox_override("pressed", _panel_style(Color(0.84, 0.67, 0.31, 0.24), Color(0, 0, 0, 0), 0, 38))
	return_button.pressed.connect(_return_to_system_menu)
	return_slot.add_child(return_button)

	var section_title := _make_label("音律调校", 21, GOLD_BRIGHT)
	section_title.name = "AudioSectionTitle"
	section_title.position = Vector2(45, 92)
	section_title.size = Vector2(360, 34)
	section_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_panel.add_child(section_title)

	_build_audio_setting(_settings_panel, "MusicVolume", "音乐音量", MUSIC_BUS_NAME, Vector2(45, 155))
	_build_audio_setting(_settings_panel, "SfxVolume", "音效音量", SFX_BUS_NAME, Vector2(45, 335))

	var hint := _make_label("拖动滑块调节音量", 15, TEXT_MUTED)
	hint.name = "SettingsHint"
	hint.position = Vector2(45, 510)
	hint.size = Vector2(360, 28)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_panel.add_child(hint)
	_settings_panel.hide()


func _build_audio_setting(parent: Control, node_prefix: String, label_text: String, bus_name: StringName, at: Vector2) -> void:
	var row := Panel.new()
	row.name = "%sRow" % node_prefix
	row.position = at
	row.size = Vector2(360, 132)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.06, 0.055, 0.88), Color(GOLD.r, GOLD.g, GOLD.b, 0.72), 2, 0))
	parent.add_child(row)

	var setting_label := _make_label(label_text, 20, TEXT_LIGHT)
	setting_label.name = "SettingLabel"
	setting_label.position = Vector2(20, 14)
	setting_label.size = Vector2(220, 30)
	row.add_child(setting_label)

	var value_label := _make_label("100%", 18, GOLD_BRIGHT)
	value_label.name = "ValueLabel"
	value_label.position = Vector2(268, 14)
	value_label.size = Vector2(72, 30)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	var generated_track := TextureRect.new()
	generated_track.name = "GeneratedSliderTrack"
	generated_track.position = Vector2(22, 68)
	generated_track.size = Vector2(316, 32)
	generated_track.texture = VOLUME_SLIDER_TRACK
	generated_track.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	generated_track.stretch_mode = TextureRect.STRETCH_SCALE
	generated_track.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	generated_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(generated_track)

	var slider := HSlider.new()
	slider.name = "%sSlider" % node_prefix
	slider.position = Vector2(22, 58)
	slider.size = Vector2(316, 52)
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.tick_count = 0
	slider.focus_mode = Control.FOCUS_ALL
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	slider.add_theme_stylebox_override("slider", StyleBoxEmpty.new())
	slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
	slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
	slider.add_theme_icon_override("grabber", VOLUME_SLIDER_KNOB)
	slider.add_theme_icon_override("grabber_highlight", VOLUME_SLIDER_KNOB)
	slider.add_theme_icon_override("grabber_disabled", VOLUME_SLIDER_KNOB)
	slider.value = _get_bus_percent(bus_name)
	value_label.text = "%d%%" % roundi(slider.value)
	slider.value_changed.connect(_on_audio_volume_changed.bind(bus_name, value_label))
	row.add_child(slider)
func _build_system_menu_entry(parent: VBoxContainer, action_name: String, icon_texture: Texture2D, node_name: String) -> void:
	var slot := Control.new()
	slot.name = "%sSlot" % node_name
	slot.custom_minimum_size = Vector2(314, 76)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(slot)

	var generated_button := TextureRect.new()
	generated_button.name = "GeneratedButtonTexture"
	generated_button.position = Vector2(-10, -17)
	generated_button.size = Vector2(340, 110)
	generated_button.texture = SYSTEM_MENU_BUTTON
	generated_button.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	generated_button.stretch_mode = TextureRect.STRETCH_SCALE
	generated_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	generated_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(generated_button)

	# Reuse the button texture's alpha as the hover mask. A StyleBox always fills
	# the rectangular Control, while this overlay follows the paper and diamond
	# silhouette, including the redrawn stair-stepped pixel edges.
	var hover_highlight := TextureRect.new()
	hover_highlight.name = "HoverHighlight"
	hover_highlight.position = generated_button.position
	hover_highlight.size = generated_button.size
	hover_highlight.texture = SYSTEM_MENU_BUTTON
	hover_highlight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hover_highlight.stretch_mode = TextureRect.STRETCH_SCALE
	hover_highlight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hover_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var highlight_material := ShaderMaterial.new()
	highlight_material.shader = MENU_BUTTON_HIGHLIGHT_SHADER
	hover_highlight.material = highlight_material
	hover_highlight.hide()
	slot.add_child(hover_highlight)

	var icon := TextureRect.new()
	icon.name = "EntryIcon"
	icon.position = Vector2(23, 11)
	icon.size = Vector2(54, 54)
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var button := Button.new()
	button.name = node_name
	button.position = Vector2(30, 4)
	button.size = Vector2(278, 68)
	button.text = action_name
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 21)
	var button_text_color := Color(0.13, 0.13, 0.105, 1.0)
	button.add_theme_color_override("font_color", button_text_color)
	button.add_theme_color_override("font_hover_color", button_text_color)
	button.add_theme_color_override("font_pressed_color", Color(0.08, 0.07, 0.045, 1.0))
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.mouse_entered.connect(hover_highlight.show)
	button.mouse_exited.connect(hover_highlight.hide)
	match node_name:
		"ContinueGameButton":
			button.pressed.connect(_close_system_menu)
		"SaveGameButton":
			button.pressed.connect(_request_save_game)
		"LoadGameButton":
			button.pressed.connect(_request_load_game)
		"SettingsButton":
			button.pressed.connect(_open_settings_panel)
		"ReturnTitleButton":
			button.pressed.connect(_request_return_title)
		"ExitGameButton":
			button.pressed.connect(_exit_game)
		_:
			button.pressed.connect(_show_menu_placeholder.bind(action_name))
	slot.add_child(button)


func _build_toast() -> void:
	_toast_panel = Panel.new()
	_toast_panel.name = "ComingSoonToast"
	_toast_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast_panel.offset_left = -365.0
	_toast_panel.offset_top = 142.0
	_toast_panel.offset_right = -24.0
	_toast_panel.offset_bottom = 204.0
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.z_index = 200
	_toast_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.065, 0.065, 0.97), GOLD, 2, 5))
	add_child(_toast_panel)

	_toast_label = _make_label("功能即将开放", 20, TEXT_LIGHT)
	_toast_label.name = "Message"
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_panel.add_child(_toast_label)
	_toast_panel.hide()

	_toast_timer = Timer.new()
	_toast_timer.name = "ToastTimer"
	_toast_timer.one_shot = true
	_toast_timer.wait_time = 1.8
	_toast_timer.timeout.connect(_toast_panel.hide)
	add_child(_toast_timer)


func _show_locked_message(action_name: String) -> void:
	_position_toast(false)
	_toast_label.text = "%s · 功能即将开放" % action_name
	_toast_panel.show()
	_toast_timer.start()


func _show_menu_placeholder(action_name: String) -> void:
	_position_toast(true)
	_toast_label.text = "%s · 该功能即将实现" % action_name
	_toast_panel.show()
	_toast_timer.start()


func _request_save_game() -> void:
	save_requested.emit()


func _request_load_game() -> void:
	load_requested.emit()


func _request_return_title() -> void:
	return_title_requested.emit()


func _position_toast(menu_mode: bool) -> void:
	if menu_mode:
		_toast_panel.set_anchors_preset(Control.PRESET_CENTER)
		_toast_panel.offset_left = -210.0
		_toast_panel.offset_top = 260.0
		_toast_panel.offset_right = 210.0
		_toast_panel.offset_bottom = 322.0
	else:
		_toast_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_toast_panel.offset_left = -365.0
		_toast_panel.offset_top = 142.0
		_toast_panel.offset_right = -24.0
		_toast_panel.offset_bottom = 204.0


func _open_system_menu() -> void:
	if not visible or is_menu_open():
		return
	_toast_panel.hide()
	_system_panel.show()
	_settings_panel.hide()
	_menu_overlay.show()
	menu_visibility_changed.emit(true)


func _close_system_menu() -> void:
	if not _is_system_menu_open():
		return
	_toast_panel.hide()
	_menu_overlay.hide()
	_settings_panel.hide()
	_system_panel.show()
	menu_visibility_changed.emit(false)


func _open_settings_panel() -> void:
	if not _is_system_menu_open():
		return
	_toast_panel.hide()
	_system_panel.hide()
	_settings_panel.show()


func _return_to_system_menu() -> void:
	if not is_settings_open():
		return
	_settings_panel.hide()
	_system_panel.show()


func _ensure_audio_buses() -> void:
	for bus_name in [MUSIC_BUS_NAME, SFX_BUS_NAME]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var bus_index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus_index, bus_name)
			AudioServer.set_bus_send(bus_index, &"Master")


func _get_bus_percent(bus_name: StringName) -> float:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0 or AudioServer.is_bus_mute(bus_index):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(bus_index)) * 100.0, 0.0, 100.0)


func _on_audio_volume_changed(value: float, bus_name: StringName, value_label: Label) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var percent := clampf(value, 0.0, 100.0)
	AudioServer.set_bus_mute(bus_index, percent <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, AUDIO_FLOOR_DB if percent <= 0.0 else linear_to_db(percent / 100.0))
	value_label.text = "%d%%" % roundi(percent)


func _open_quest_screen() -> void:
	if not visible or is_menu_open():
		return
	_toast_panel.hide()
	_set_function_buttons_visible(false)
	_quest_screen.call("show_screen")
	menu_visibility_changed.emit(true)


func _open_map_screen() -> void:
	if not visible or is_menu_open() or not is_instance_valid(_map_screen):
		return
	_toast_panel.hide()
	_set_function_buttons_visible(false)
	_map_screen.call("show_screen")
	menu_visibility_changed.emit(true)


func _close_map_screen() -> void:
	if not is_map_screen_open():
		return
	_map_screen.hide()
	_set_function_buttons_visible(true)
	menu_visibility_changed.emit(false)


func _close_quest_screen() -> void:
	if not is_quest_screen_open():
		return
	_quest_screen.hide()
	_set_function_buttons_visible(true)
	menu_visibility_changed.emit(false)


func _set_function_buttons_visible(value: bool) -> void:
	var function_buttons := get_node_or_null("FunctionButtons") as Control
	var brushstroke := get_node_or_null("FunctionButtonsBrushstroke") as Control
	if function_buttons != null:
		function_buttons.visible = value
	if brushstroke != null:
		brushstroke.visible = value


func _exit_game() -> void:
	get_tree().quit()


func _make_label(text_value: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.78))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel_style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 5
	style.shadow_offset = Vector2(2, 3)
	return style
