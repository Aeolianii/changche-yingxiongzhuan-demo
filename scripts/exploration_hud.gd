extends Control

const PROTAGONIST_PORTRAIT := preload("res://assets/characters/protagonist/picture.png")

const INK := Color(0.055, 0.073, 0.075, 0.96)
const INK_SOFT := Color(0.075, 0.105, 0.108, 0.9)
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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_status_panel()
	_build_task_tracker()
	_build_function_buttons()
	_build_toast()
	set_exploration_visible(false)


func set_exploration_visible(value: bool) -> void:
	visible = value
	if not value and is_instance_valid(_toast_panel):
		_toast_panel.hide()


func set_main_task(task_title: String) -> void:
	if is_instance_valid(_main_task_label):
		_main_task_label.text = task_title


func _build_status_panel() -> void:
	var status := Control.new()
	status.name = "PlayerStatus"
	status.position = Vector2(22, 18)
	status.size = Vector2(330, 128)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)

	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array([
		Vector2(57, 3), Vector2(116, 62), Vector2(57, 121), Vector2(-2, 62)
	])
	shadow.position = Vector2(4, 5)
	shadow.color = Color(0.0, 0.0, 0.0, 0.55)
	status.add_child(shadow)

	var diamond := Polygon2D.new()
	diamond.name = "PortraitDiamond"
	diamond.polygon = PackedVector2Array([
		Vector2(57, 0), Vector2(114, 57), Vector2(57, 114), Vector2(0, 57)
	])
	diamond.color = GOLD
	status.add_child(diamond)

	var portrait_frame := Panel.new()
	portrait_frame.name = "PortraitFrame"
	portrait_frame.position = Vector2(10, 10)
	portrait_frame.size = Vector2(94, 94)
	portrait_frame.clip_contents = true
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_theme_stylebox_override("panel", _panel_style(INK, GOLD_BRIGHT, 2, 5))
	status.add_child(portrait_frame)

	var portrait := TextureRect.new()
	portrait.name = "ProtagonistPortrait"
	portrait.position = Vector2(4, 4)
	portrait.size = Vector2(86, 86)
	portrait.texture = PROTAGONIST_PORTRAIT
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)

	var name_panel := Panel.new()
	name_panel.name = "NamePlate"
	name_panel.position = Vector2(92, 20)
	name_panel.size = Vector2(224, 72)
	name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_panel.add_theme_stylebox_override("panel", _panel_style(INK, GOLD, 2, 6))
	status.add_child(name_panel)

	var name_label := _make_label("水师主帅", 23, TEXT_LIGHT)
	name_label.name = "PlayerName"
	name_label.position = Vector2(24, 8)
	name_label.size = Vector2(185, 32)
	name_panel.add_child(name_label)

	var subtitle := _make_label("伏波将军 · 南疆水师", 15, TEXT_MUTED)
	subtitle.name = "PlayerTitle"
	subtitle.position = Vector2(25, 39)
	subtitle.size = Vector2(185, 24)
	name_panel.add_child(subtitle)

	var seal := Label.new()
	seal.name = "StatusSeal"
	seal.position = Vector2(292, 76)
	seal.size = Vector2(34, 34)
	seal.text = "帅"
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_theme_font_size_override("font_size", 17)
	seal.add_theme_color_override("font_color", GOLD_BRIGHT)
	seal.add_theme_stylebox_override("normal", _panel_style(Color(0.25, 0.06, 0.045, 0.96), GOLD, 1, 2))
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.add_child(seal)


func _build_task_tracker() -> void:
	var tracker := Panel.new()
	tracker.name = "QuestTracker"
	tracker.position = Vector2(24, 174)
	tracker.size = Vector2(326, 342)
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.065, 0.065, 0.9), Color(0.51, 0.43, 0.27, 0.86), 2, 5))
	add_child(tracker)

	var title_ribbon := Panel.new()
	title_ribbon.name = "TitleRibbon"
	title_ribbon.position = Vector2(-7, 12)
	title_ribbon.size = Vector2(340, 48)
	title_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_ribbon.add_theme_stylebox_override("panel", _panel_style(INK, GOLD, 2, 3))
	tracker.add_child(title_ribbon)

	var title := _make_label("◆  任 务", 24, TEXT_LIGHT)
	title.name = "QuestTitle"
	title.position = Vector2(18, 3)
	title.size = Vector2(270, 40)
	title_ribbon.add_child(title)

	_build_quest_entry(tracker, "MainQuest", Vector2(15, 76), "主线", "帅", Color(0.38, 0.12, 0.08, 1.0), true)
	_build_quest_entry(tracker, "SideQuest", Vector2(15, 203), "支线", "商", JADE, false)


func _build_quest_entry(parent: Control, node_name: String, at: Vector2, section: String, badge_text: String, badge_color: Color, is_main: bool) -> void:
	var entry := Panel.new()
	entry.name = node_name
	entry.position = at
	entry.size = Vector2(296, 112)
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_theme_stylebox_override("panel", _panel_style(Color(0.09, 0.105, 0.095, 0.93), Color(GOLD.r, GOLD.g, GOLD.b, 0.68), 1, 4))
	parent.add_child(entry)

	var accent := ColorRect.new()
	accent.name = "Accent"
	accent.position = Vector2(0, 0)
	accent.size = Vector2(5, 112)
	accent.color = GOLD if is_main else JADE
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(accent)

	var badge := Panel.new()
	badge.name = "CharacterPlaceholder"
	badge.position = Vector2(16, 22)
	badge.size = Vector2(62, 62)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _panel_style(badge_color, GOLD, 2, 31))
	entry.add_child(badge)

	var badge_label := _make_label(badge_text, 25, TEXT_LIGHT)
	badge_label.position = Vector2.ZERO
	badge_label.size = badge.size
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(badge_label)

	var tag := _make_label("【%s】" % section, 17, GOLD_BRIGHT if is_main else Color(0.55, 0.82, 0.75, 1.0))
	tag.name = "QuestType"
	tag.position = Vector2(90, 10)
	tag.size = Vector2(180, 25)
	entry.add_child(tag)

	var task := _make_label("奉诏入殿" if is_main else "访查军港", 20, TEXT_LIGHT)
	task.name = "TaskName"
	task.position = Vector2(91, 37)
	task.size = Vector2(190, 28)
	entry.add_child(task)
	if is_main:
		_main_task_label = task

	var objective := _make_label("前往标记地点推进剧情" if is_main else "与船匠交谈（效果占位）", 15, TEXT_MUTED)
	objective.name = "Objective"
	objective.position = Vector2(91, 68)
	objective.size = Vector2(192, 34)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.add_child(objective)


func _build_function_buttons() -> void:
	var actions := HBoxContainer.new()
	actions.name = "FunctionButtons"
	actions.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	actions.offset_left = -468.0
	actions.offset_top = 18.0
	actions.offset_right = -18.0
	actions.offset_bottom = 130.0
	actions.add_theme_constant_override("separation", 8)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(actions)

	var specs := [
		["菜单", "≡", "MenuButton"],
		["物品栏", "囊", "InventoryButton"],
		["船只", "舟", "ShipButton"],
		["人物", "将", "CharacterButton"],
	]
	for spec in specs:
		_build_function_button(actions, spec[0], spec[1], spec[2])


func _build_function_button(parent: HBoxContainer, action_name: String, symbol: String, node_name: String) -> void:
	var slot := Control.new()
	slot.name = "%sSlot" % node_name
	slot.custom_minimum_size = Vector2(106, 108)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(slot)

	var shadow := Polygon2D.new()
	shadow.position = Vector2(4, 5)
	shadow.polygon = _diamond_points(Vector2(53, 42), 42)
	shadow.color = Color(0, 0, 0, 0.58)
	slot.add_child(shadow)

	var outer := Polygon2D.new()
	outer.name = "OuterDiamond"
	outer.polygon = _diamond_points(Vector2(53, 42), 42)
	outer.color = GOLD
	slot.add_child(outer)

	var inner := Polygon2D.new()
	inner.name = "InnerDiamond"
	inner.polygon = _diamond_points(Vector2(53, 42), 36)
	inner.color = INK_SOFT
	slot.add_child(inner)

	var icon := _make_label(symbol, 28, TEXT_LIGHT)
	icon.name = "Symbol"
	icon.position = Vector2(24, 14)
	icon.size = Vector2(58, 48)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.84, 0.67, 0.31, 0.14), Color(0, 0, 0, 0), 0, 7))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.84, 0.67, 0.31, 0.27), Color(0, 0, 0, 0), 0, 7))
	button.pressed.connect(_show_locked_message.bind(action_name))
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
	_toast_label.text = "%s · 功能即将开放" % action_name
	_toast_panel.show()
	_toast_timer.start()


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


func _diamond_points(center: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius, 0),
	])
