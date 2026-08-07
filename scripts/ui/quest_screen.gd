extends Control

const QUEST_BACKGROUND := preload("res://assets/ui/quest_screen/quest_screen_background.png")
const FUNCTION_BUTTON_FRAME := preload("res://assets/ui/exploration_hud/function_button.png")
const RETURN_ICON := preload("res://assets/ui/icons/menu_return_title.png")

const GOLD := Color(0.73, 0.59, 0.32, 1.0)
const GOLD_BRIGHT := Color(0.96, 0.78, 0.28, 1.0)
const JADE := Color(0.28, 0.58, 0.52, 1.0)
const TEXT_LIGHT := Color(0.94, 0.91, 0.80, 1.0)
const TEXT_MUTED := Color(0.69, 0.70, 0.63, 1.0)
const PANEL_INK := Color(0.025, 0.045, 0.04, 0.78)

const QUESTS := [
	{
		"type": "主线",
		"title": "奉诏入殿",
		"objective": "前往标记地点推进剧情",
		"description": "岭南军情骤变，你奉水师都督之命入宫面圣。请先抵达宣政殿，将水师急报呈交监国，再领取调兵所需的水师令。",
		"keywords": ["宣政殿", "水师急报", "水师令"],
		"steps": [
			{
				"title": "接领入宫诏命",
				"description": "你已从传令校尉手中接过诏书，获准进入宫城。",
				"keywords": ["诏书", "宫城"],
				"completed": true,
				"expanded": false,
			},
			{
				"title": "前往宣政殿",
				"description": "沿宫城中轴向北行进，前往宣政殿，将水师急报呈交监国。",
				"keywords": ["向北", "宣政殿", "水师急报", "监国"],
				"completed": false,
				"expanded": true,
			},
			{
				"title": "领取水师令",
				"description": "完成觐见后，从监国处领取水师令，为后续调遣舰队做准备。",
				"keywords": ["监国", "水师令", "舰队"],
				"completed": false,
				"expanded": false,
			},
		],
	},
	{
		"type": "支线",
		"title": "访查军港",
		"objective": "与船匠交谈（效果占位）",
		"description": "军港近日频繁出现修造延期。前往东侧船坞拜访老船匠，询问缺料原因，并记录可能影响舰队出航的异常。",
		"keywords": ["东侧船坞", "老船匠", "舰队出航"],
		"steps": [
			{
				"title": "前往军港",
				"description": "离开宫城后前往东侧军港，在船坞入口寻找值守军士。",
				"keywords": ["东侧军港", "船坞入口"],
				"completed": false,
				"expanded": true,
			},
			{
				"title": "询问老船匠",
				"description": "找到负责修造的老船匠，询问木料短缺与工期延误的具体情况。",
				"keywords": ["老船匠", "木料短缺", "工期延误"],
				"completed": false,
				"expanded": false,
			},
			{
				"title": "记录船坞异常",
				"description": "将船匠提供的线索记入军务簿，作为后续调查的任务占位记录。",
				"keywords": ["军务簿", "后续调查"],
				"completed": false,
				"expanded": false,
			},
		],
	},
]

var _selected_quest := 0
var _quests: Array[Dictionary] = []
var _quest_buttons: Array[Button] = []
var _detail_title: RichTextLabel
var _detail_description: RichTextLabel
var _steps_container: VBoxContainer

signal close_requested


func _ready() -> void:
	for quest_value in QUESTS:
		var quest: Dictionary = quest_value
		_quests.append(quest.duplicate(true))
	z_index = 80
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background()
	_build_headers()
	_build_return_button()
	_build_quest_list()
	_build_quest_detail()
	_refresh_quest_detail()
	hide()


func show_screen() -> void:
	_selected_quest = 0
	_refresh_quest_selectors()
	_refresh_quest_detail()
	show()


func set_main_task(task_title: String) -> void:
	if task_title.is_empty():
		return
	if _quests.is_empty():
		return
	_quests[0] = _make_main_quest_state(task_title)
	if not _quest_buttons.is_empty():
		var main_selector := _quest_buttons[0]
		(main_selector.get_node("QuestName") as Label).text = task_title
		(main_selector.get_node("QuestObjective") as Label).text = str(_quests[0]["objective"])
	if _selected_quest == 0:
		_refresh_quest_detail()


func _build_background() -> void:
	var background := TextureRect.new()
	background.name = "GeneratedQuestBackground"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = QUEST_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)


func _build_headers() -> void:
	var screen_title := _make_label("任务", 36, TEXT_LIGHT)
	screen_title.name = "ScreenTitle"
	screen_title.position = Vector2(54, 32)
	screen_title.size = Vector2(260, 58)
	add_child(screen_title)

	var list_title := _make_label("任务列表", 24, TEXT_LIGHT)
	list_title.name = "QuestListTitle"
	list_title.position = Vector2(148, 165)
	list_title.size = Vector2(240, 46)
	list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(list_title)

	var detail_title := _make_label("任务详情", 24, TEXT_LIGHT)
	detail_title.name = "QuestDetailHeader"
	detail_title.position = Vector2(740, 165)
	detail_title.size = Vector2(330, 46)
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(detail_title)


func _build_return_button() -> void:
	var slot := Control.new()
	slot.name = "QuestReturnSlot"
	slot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	slot.offset_left = -126.0
	slot.offset_top = 12.0
	slot.offset_right = -16.0
	slot.offset_bottom = 122.0
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(slot)

	var frame := TextureRect.new()
	frame.name = "GeneratedReturnFrame"
	frame.position = Vector2(8, -2)
	frame.size = Vector2(94, 94)
	frame.texture = FUNCTION_BUTTON_FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(frame)

	var icon := TextureRect.new()
	icon.name = "ReturnIcon"
	icon.position = Vector2(28, 18)
	icon.size = Vector2(54, 54)
	icon.texture = RETURN_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var label := _make_label("返回", 17, TEXT_LIGHT)
	label.name = "ReturnLabel"
	label.position = Vector2(5, 84)
	label.size = Vector2(100, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_child(label)

	var button := Button.new()
	button.name = "QuestReturnButton"
	button.position = Vector2(5, 0)
	button.size = Vector2(100, 108)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "返回游戏"
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", _flat_style(Color(0.82, 0.65, 0.28, 0.16), Color(0, 0, 0, 0), 0))
	button.add_theme_stylebox_override("pressed", _flat_style(Color(0.92, 0.72, 0.30, 0.24), Color(0, 0, 0, 0), 0))
	button.pressed.connect(_request_close)
	slot.add_child(button)


func _build_quest_list() -> void:
	var list := VBoxContainer.new()
	list.name = "QuestChoices"
	list.position = Vector2(86, 232)
	list.size = Vector2(368, 540)
	list.add_theme_constant_override("separation", 12)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(list)

	var active_label := _make_label("进行中", 18, GOLD_BRIGHT)
	active_label.name = "ActiveQuestLabel"
	active_label.custom_minimum_size = Vector2(360, 30)
	list.add_child(active_label)

	for quest_index in range(_quests.size()):
		var quest: Dictionary = _quests[quest_index]
		var selector := Button.new()
		selector.name = "QuestChoice%d" % quest_index
		selector.custom_minimum_size = Vector2(360, 112)
		selector.flat = true
		selector.focus_mode = Control.FOCUS_NONE
		selector.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		selector.pressed.connect(_select_quest.bind(quest_index))
		list.add_child(selector)
		_quest_buttons.append(selector)

		var quest_type := _make_label("【%s】" % quest["type"], 16, GOLD_BRIGHT if quest_index == 0 else JADE)
		quest_type.name = "QuestType"
		quest_type.position = Vector2(18, 11)
		quest_type.size = Vector2(100, 24)
		selector.add_child(quest_type)

		var quest_title := _make_label(str(quest["title"]), 21, TEXT_LIGHT)
		quest_title.name = "QuestName"
		quest_title.position = Vector2(18, 38)
		quest_title.size = Vector2(320, 30)
		selector.add_child(quest_title)

		var objective := _make_label(str(quest["objective"]), 14, TEXT_MUTED)
		objective.name = "QuestObjective"
		objective.position = Vector2(18, 73)
		objective.size = Vector2(320, 27)
		selector.add_child(objective)

	_refresh_quest_selectors()


func _build_quest_detail() -> void:
	_detail_title = _make_rich_text(22)
	_detail_title.name = "SelectedQuestTitle"
	_detail_title.position = Vector2(528, 228)
	_detail_title.size = Vector2(744, 38)
	add_child(_detail_title)

	_detail_description = _make_rich_text(17)
	_detail_description.name = "SelectedQuestDescription"
	_detail_description.position = Vector2(528, 272)
	_detail_description.size = Vector2(744, 88)
	add_child(_detail_description)

	var separator := ColorRect.new()
	separator.name = "DetailSeparator"
	separator.position = Vector2(528, 369)
	separator.size = Vector2(744, 1)
	separator.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.38)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(separator)

	var flow_title := _make_label("任务流程", 19, GOLD_BRIGHT)
	flow_title.name = "QuestFlowTitle"
	flow_title.position = Vector2(528, 382)
	flow_title.size = Vector2(300, 30)
	add_child(flow_title)

	var flow_hint := _make_label("点击右侧三角查看每一步详情", 13, TEXT_MUTED)
	flow_hint.name = "QuestFlowHint"
	flow_hint.position = Vector2(980, 385)
	flow_hint.size = Vector2(292, 26)
	flow_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(flow_hint)

	var scroll := ScrollContainer.new()
	scroll.name = "QuestStepsScroll"
	scroll.position = Vector2(522, 420)
	scroll.size = Vector2(758, 355)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scroll)

	_steps_container = VBoxContainer.new()
	_steps_container.name = "QuestSteps"
	_steps_container.custom_minimum_size = Vector2(738, 0)
	_steps_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steps_container.add_theme_constant_override("separation", 5)
	_steps_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_steps_container)


func _select_quest(quest_index: int) -> void:
	if quest_index < 0 or quest_index >= _quests.size():
		return
	_selected_quest = quest_index
	_refresh_quest_selectors()
	_refresh_quest_detail()


func _refresh_quest_selectors() -> void:
	for quest_index in range(_quest_buttons.size()):
		var selected := quest_index == _selected_quest
		var button := _quest_buttons[quest_index]
		button.add_theme_stylebox_override("normal", _quest_selector_style(selected, false))
		button.add_theme_stylebox_override("hover", _quest_selector_style(selected, true))
		button.add_theme_stylebox_override("pressed", _quest_selector_style(true, true))


func _refresh_quest_detail() -> void:
	if _detail_title == null or _steps_container == null:
		return
	var quest: Dictionary = _quests[_selected_quest]
	_detail_title.text = "[color=#f1c24f]【%s】[/color]  %s" % [quest["type"], quest["title"]]
	_detail_description.text = _highlight_keywords(str(quest["description"]), quest["keywords"])

	for old_step in _steps_container.get_children():
		_steps_container.remove_child(old_step)
		old_step.queue_free()

	var steps: Array = quest["steps"]
	for step_index in range(steps.size()):
		_build_step(steps[step_index], step_index)


func _build_step(step: Dictionary, step_index: int) -> void:
	var block := VBoxContainer.new()
	block.name = "QuestStep%d" % step_index
	block.custom_minimum_size = Vector2(730, 0)
	block.add_theme_constant_override("separation", 4)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_steps_container.add_child(block)

	var header := HBoxContainer.new()
	header.name = "StepHeader"
	header.custom_minimum_size = Vector2(730, 42)
	header.add_theme_constant_override("separation", 12)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(header)

	var marker := _make_label("✓" if bool(step["completed"]) else "●", 20, GOLD_BRIGHT if bool(step["completed"]) else JADE)
	marker.name = "StepMarker"
	marker.custom_minimum_size = Vector2(26, 38)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(marker)

	var title := _make_label(str(step["title"]), 18, TEXT_LIGHT)
	title.name = "StepTitle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	var toggle := Button.new()
	toggle.name = "StepToggle"
	toggle.custom_minimum_size = Vector2(48, 38)
	toggle.text = "▼" if bool(step["expanded"]) else "▶"
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.add_theme_font_size_override("font_size", 18)
	toggle.add_theme_color_override("font_color", TEXT_LIGHT)
	toggle.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	toggle.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	toggle.add_theme_stylebox_override("hover", _flat_style(Color(GOLD.r, GOLD.g, GOLD.b, 0.13), Color(0, 0, 0, 0), 0))
	toggle.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	header.add_child(toggle)

	var description := _make_rich_text(15)
	description.name = "StepDescription"
	description.custom_minimum_size = Vector2(700, 58)
	description.text = _highlight_keywords(str(step["description"]), step["keywords"])
	description.visible = bool(step["expanded"])
	block.add_child(description)
	toggle.pressed.connect(_toggle_step.bind(description, toggle))

	var separator := HSeparator.new()
	separator.name = "StepSeparator"
	var separator_style := StyleBoxLine.new()
	separator_style.color = Color(GOLD.r, GOLD.g, GOLD.b, 0.28)
	separator_style.thickness = 1
	separator.add_theme_stylebox_override("separator", separator_style)
	block.add_child(separator)


func _toggle_step(description: RichTextLabel, toggle: Button) -> void:
	description.visible = not description.visible
	toggle.text = "▼" if description.visible else "▶"


func _request_close() -> void:
	close_requested.emit()


func _highlight_keywords(text_value: String, keywords: Array) -> String:
	var highlighted := text_value
	for keyword_value in keywords:
		var keyword := str(keyword_value)
		highlighted = highlighted.replace(keyword, "[color=#f1c24f]%s[/color]" % keyword)
	return highlighted


func _make_main_quest_state(task_title: String) -> Dictionary:
	if task_title == "奉诏入殿":
		var default_main: Dictionary = QUESTS[0]
		return default_main.duplicate(true)
	if task_title == "巡视水师驻地":
		return {
			"type": "主线",
			"title": task_title,
			"objective": "前往标记地点推进剧情",
			"description": "抵达南疆水师驻地后，先巡视中军楼船与周边泊位，确认官兵值守、舰船修缮和出航准备情况。",
			"keywords": ["南疆水师驻地", "中军楼船", "舰船修缮", "出航准备"],
			"steps": [
				{
					"title": "巡视中军楼船",
					"description": "沿主甲板巡视中军楼船，查看各处值守是否正常。",
					"keywords": ["主甲板", "中军楼船", "值守"],
					"completed": false,
					"expanded": true,
				},
				{
					"title": "询问值守军官",
					"description": "与甲板上的值守军官交谈，了解近期操练与巡防安排。",
					"keywords": ["值守军官", "操练", "巡防安排"],
					"completed": false,
					"expanded": false,
				},
				{
					"title": "检查舰船战备",
					"description": "检查停泊舰船的修缮、补给与出航准备情况。",
					"keywords": ["停泊舰船", "补给", "出航准备"],
					"completed": false,
					"expanded": false,
				},
			],
		}
	return {
		"type": "主线",
		"title": task_title,
		"objective": "前往标记地点推进剧情",
		"description": "当前剧情已推进至“%s”。请按照场景中的标记与对话提示完成这一阶段的主线目标。" % task_title,
		"keywords": [task_title, "场景标记", "主线目标"],
		"steps": [
			{
				"title": task_title,
				"description": "跟随场景标记与剧情对话，完成“%s”。" % task_title,
				"keywords": ["场景标记", task_title],
				"completed": false,
				"expanded": true,
			},
			{
				"title": "继续推进剧情",
				"description": "完成当前目标后，新的主线步骤会随剧情自动更新。",
				"keywords": ["当前目标", "自动更新"],
				"completed": false,
				"expanded": false,
			},
		],
	}


func _quest_selector_style(selected: bool, hovered: bool) -> StyleBoxFlat:
	var background := Color(0.38, 0.30, 0.13, 0.50) if selected else PANEL_INK
	if hovered:
		background = background.lightened(0.08)
	var style := _flat_style(background, Color(GOLD.r, GOLD.g, GOLD.b, 0.58 if selected else 0.22), 1)
	style.set_border_width(SIDE_LEFT, 4 if selected else 2)
	style.content_margin_left = 12.0
	return style


func _make_label(text_value: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_rich_text(font_size: int) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", TEXT_LIGHT)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _flat_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style
