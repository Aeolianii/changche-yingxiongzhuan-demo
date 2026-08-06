extends Control

const PROTAGONIST_PORTRAIT := preload("res://assets/characters/protagonist/picture.png")
const EXPLORATION_STATUS_FRAME := preload("res://assets/ui/exploration_hud/player_status_frame.png")
const EXPLORATION_QUEST_FRAME := preload("res://assets/ui/exploration_hud/quest_tracker_frame.png")
const EXPLORATION_FUNCTION_BUTTON := preload("res://assets/ui/exploration_hud/function_button.png")
const HUD_ICON_QUEST := preload("res://assets/ui/icons/hud_quest.png")
const HUD_ICON_CHARACTER := preload("res://assets/ui/icons/hud_character.png")
const HUD_ICON_INVENTORY := preload("res://assets/ui/icons/hud_inventory.png")
const HUD_ICON_SHIP := preload("res://assets/ui/icons/hud_ship.png")
const HUD_ICON_MENU := preload("res://assets/ui/icons/hud_menu.png")
const MENU_ICON_CONTINUE := preload("res://assets/ui/icons/menu_continue.png")
const MENU_ICON_SAVE := preload("res://assets/ui/icons/menu_save.png")
const MENU_ICON_LOAD := preload("res://assets/ui/icons/menu_load.png")
const MENU_ICON_SETTINGS := preload("res://assets/ui/icons/menu_settings.png")
const MENU_ICON_RETURN_TITLE := preload("res://assets/ui/icons/menu_return_title.png")
const MENU_ICON_EXIT := preload("res://assets/ui/icons/menu_exit.png")
const MENU_BLUR_SHADER := preload("res://shaders/menu_blur.gdshader")
const SYSTEM_MENU_FRAME := preload("res://assets/ui/system_menu/system_menu_frame.png")
const SYSTEM_MENU_BUTTON := preload("res://assets/ui/system_menu/menu_button.png")
const SYSTEM_MENU_CLOSE := preload("res://assets/ui/system_menu/close_button.png")

const INK := Color(0.055, 0.073, 0.075, 0.96)
const PAPER := Color(0.83, 0.77, 0.61, 0.96)
const PAPER_DARK := Color(0.55, 0.48, 0.34, 0.96)
const GOLD := Color(0.73, 0.59, 0.32, 1.0)
const GOLD_BRIGHT := Color(0.95, 0.82, 0.51, 1.0)
const JADE := Color(0.16, 0.38, 0.36, 1.0)
const TEXT_LIGHT := Color(0.96, 0.91, 0.78, 1.0)
const TEXT_MUTED := Color(0.72, 0.71, 0.64, 1.0)

var _main_task_label: Label
var _toast_panel: Panel
var _toast_label: Label
var _toast_timer: Timer
var _menu_overlay: Control

signal menu_visibility_changed(is_open: bool)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_status_panel()
	_build_task_tracker()
	_build_function_buttons()
	_build_system_menu()
	_build_toast()
	set_exploration_visible(false)


func set_exploration_visible(value: bool) -> void:
	if not value and is_menu_open():
		_close_system_menu()
	visible = value
	if not value and is_instance_valid(_toast_panel):
		_toast_panel.hide()


func set_main_task(task_title: String) -> void:
	if is_instance_valid(_main_task_label):
		_main_task_label.text = task_title


func is_menu_open() -> bool:
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
	generated_frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	generated_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(generated_frame)

	var portrait_frame := Panel.new()
	portrait_frame.name = "PortraitFrame"
	portrait_frame.position = Vector2(25, 23)
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
	name_label.position = Vector2(36, 8)
	name_label.size = Vector2(278, 34)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	name_panel.add_child(name_label)

	var subtitle := _make_label("伏波将军 · 南疆水师", 15, Color(0.28, 0.29, 0.25, 1.0))
	subtitle.name = "PlayerTitle"
	subtitle.position = Vector2(37, 40)
	subtitle.size = Vector2(278, 28)
	subtitle.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	name_panel.add_child(subtitle)


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
	generated_frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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

	_build_quest_entry(tracker, "MainQuest", Vector2(14, 64), "主线", true)
	_build_quest_entry(tracker, "SideQuest", Vector2(14, 164), "支线", false)


func _build_quest_entry(parent: Control, node_name: String, at: Vector2, section: String, is_main: bool) -> void:
	var entry := Panel.new()
	entry.name = node_name
	entry.position = at
	entry.size = Vector2(258, 88)
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
	accent.size = Vector2(4, 88)
	accent.color = GOLD if is_main else JADE
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(accent)

	var tag := _make_label("【%s】" % section, 15, GOLD_BRIGHT if is_main else Color(0.55, 0.82, 0.75, 1.0))
	tag.name = "QuestType"
	tag.position = Vector2(18, 5)
	tag.size = Vector2(224, 22)
	entry.add_child(tag)

	var task := _make_label("奉诏入殿" if is_main else "访查军港", 18, TEXT_LIGHT)
	task.name = "TaskName"
	task.position = Vector2(19, 28)
	task.size = Vector2(224, 25)
	entry.add_child(task)
	if is_main:
		_main_task_label = task

	var objective := _make_label("前往标记地点推进剧情" if is_main else "与船匠交谈（效果占位）", 13, TEXT_MUTED)
	objective.name = "Objective"
	objective.position = Vector2(19, 54)
	objective.size = Vector2(224, 28)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(objective)


func _build_function_buttons() -> void:
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
	generated_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	generated_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(generated_texture)

	var icon := TextureRect.new()
	icon.name = "FunctionIcon"
	icon.position = Vector2(25, 18)
	icon.size = Vector2(56, 56)
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	if action_name == "菜单":
		button.pressed.connect(_open_system_menu)
	else:
		button.pressed.connect(_show_locked_message.bind(action_name))
	slot.add_child(button)


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

	var frame := Control.new()
	frame.name = "SystemPanel"
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -225.0
	frame.offset_top = -320.0
	frame.offset_right = 225.0
	frame.offset_bottom = 320.0
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_overlay.add_child(frame)

	var generated_frame := TextureRect.new()
	generated_frame.name = "GeneratedFrame"
	generated_frame.position = Vector2(-80, -60)
	generated_frame.size = Vector2(610, 780)
	generated_frame.texture = SYSTEM_MENU_FRAME
	generated_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	generated_frame.stretch_mode = TextureRect.STRETCH_SCALE
	generated_frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	generated_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(generated_frame)

	var title := _make_label("系  统", 25, Color(0.12, 0.13, 0.105, 1.0))
	title.name = "MenuTitle"
	title.position = Vector2(102, -52)
	title.size = Vector2(246, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	frame.add_child(title)

	var close_slot := Control.new()
	close_slot.name = "CloseButtonOrnament"
	close_slot.position = Vector2(409, -28)
	close_slot.size = Vector2(82, 82)
	close_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(close_slot)

	var close_texture := TextureRect.new()
	close_texture.name = "GeneratedCloseTexture"
	close_texture.position = Vector2(-8, -8)
	close_texture.size = Vector2(98, 98)
	close_texture.texture = SYSTEM_MENU_CLOSE
	close_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	close_texture.stretch_mode = TextureRect.STRETCH_SCALE
	close_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	frame.add_child(menu_list)

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
	generated_button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	generated_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(generated_button)

	var icon := TextureRect.new()
	icon.name = "EntryIcon"
	icon.position = Vector2(20, 11)
	icon.size = Vector2(54, 54)
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.83, 0.64, 0.31, 0.42), Color(0, 0, 0, 0), 0, 3))
	if action_name == "退出游戏":
		button.pressed.connect(_exit_game)
	else:
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
	_menu_overlay.show()
	menu_visibility_changed.emit(true)


func _close_system_menu() -> void:
	if not is_menu_open():
		return
	_toast_panel.hide()
	_menu_overlay.hide()
	menu_visibility_changed.emit(false)


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
