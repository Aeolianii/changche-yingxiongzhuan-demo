class_name FieldEventDialogue
extends Control

signal option_selected(option_id: StringName)

const DIALOGUE_BACKGROUND := preload("res://assets/ui/dialogue/ink_dialogue_backdrop.png")
const DIALOGUE_NAMEPLATE := preload("res://assets/ui/dialogue/ink_speaker_nameplate.png")
const DEFAULT_DIALOGUE_MIN_HEIGHT := 62.0
const COMPACT_DIALOGUE_MIN_HEIGHT := 34.0
const OPTION_ARROW_SUFFIX := "  ▶"
const PORTRAIT_BASE_SIZE := Vector2(440.0, 520.0)
const PORTRAIT_BOTTOM := 930.0
const PORTRAIT_LEFT_EDGE := -20.0
const PORTRAIT_RIGHT_EDGE := 1324.0

@onready var paper_panel: PanelContainer = $FullWidthPaperDialogueBox
@onready var dialogue_margin: MarginContainer = $FullWidthPaperDialogueBox/DialogueMargin
@onready var dialogue_label: Label = $FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel
@onready var detail_label: RichTextLabel = $FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DetailLabel
@onready var option_box: VBoxContainer = $FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/OptionBox
@onready var portrait_image: TextureRect = $LargeTransparentPortrait
@onready var portrait_box: ColorRect = $PortraitBox
@onready var portrait_label: Label = $PortraitLabel
@onready var name_plate: PanelContainer = $NamePlate
@onready var speaker_label: Label = $NamePlate/SpeakerLabel


func _ready() -> void:
	_apply_scene_two_styles()
	hide_dialogue()


func present(
	speaker: String,
	line: String,
	portrait: Texture2D,
	options: Array[Dictionary],
	detail_bbcode: String = "",
	portrait_on_left: bool = false,
	portrait_scale: float = 1.0
) -> void:
	_apply_dialogue_side(portrait_on_left, portrait_scale)
	speaker_label.text = speaker
	dialogue_label.text = line
	dialogue_label.custom_minimum_size.y = COMPACT_DIALOGUE_MIN_HEIGHT if not detail_bbcode.is_empty() else DEFAULT_DIALOGUE_MIN_HEIGHT
	detail_label.text = detail_bbcode
	detail_label.visible = not detail_bbcode.is_empty()
	portrait_image.texture = portrait
	portrait_image.visible = portrait != null
	portrait_box.visible = portrait == null
	portrait_label.visible = portrait == null
	portrait_label.text = "兵"
	_clear_options()
	for option in options:
		_add_option(str(option.get("text", "继续")), StringName(option.get("id", &"continue")))
	show()


func hide_dialogue() -> void:
	hide()
	detail_label.clear()
	detail_label.hide()
	_clear_options()


func _apply_scene_two_styles() -> void:
	var paper_style := StyleBoxTexture.new()
	paper_style.texture = DIALOGUE_BACKGROUND
	paper_style.content_margin_left = 24
	paper_style.content_margin_right = 24
	paper_style.content_margin_top = 18
	paper_style.content_margin_bottom = 18
	paper_panel.add_theme_stylebox_override("panel", paper_style)

	var name_style := StyleBoxTexture.new()
	name_style.texture = DIALOGUE_NAMEPLATE
	name_style.content_margin_left = 18
	name_style.content_margin_right = 18
	name_style.content_margin_top = 7
	name_style.content_margin_bottom = 7
	name_plate.add_theme_stylebox_override("panel", name_style)
	_apply_dialogue_side(false, 1.0)


func _apply_dialogue_side(portrait_on_left: bool, portrait_scale: float) -> void:
	var safe_scale := clampf(portrait_scale, 0.5, 1.0)
	var portrait_size := PORTRAIT_BASE_SIZE * safe_scale
	portrait_image.size = portrait_size
	portrait_image.position.y = PORTRAIT_BOTTOM - portrait_size.y
	portrait_box.position = Vector2(48, 492) if portrait_on_left else Vector2(1076, 492)
	portrait_label.position = portrait_box.position
	if portrait_on_left:
		portrait_image.position.x = PORTRAIT_LEFT_EDGE
		name_plate.position = Vector2(24, 830)
		_set_dialogue_margins(426, 240, 76, 18)
		dialogue_label.custom_minimum_size.x = 630
		detail_label.custom_minimum_size.x = 630
		option_box.custom_minimum_size.x = 630
	else:
		portrait_image.position.x = PORTRAIT_RIGHT_EDGE - portrait_size.x
		name_plate.position = Vector2(1060, 830)
		_set_dialogue_margins(206, 440, 76, 18)
		dialogue_label.custom_minimum_size.x = 650
		detail_label.custom_minimum_size.x = 650
		option_box.custom_minimum_size.x = 650


func _set_dialogue_margins(left: int, right: int, top: int, bottom: int) -> void:
	dialogue_margin.add_theme_constant_override("margin_left", left)
	dialogue_margin.add_theme_constant_override("margin_right", right)
	dialogue_margin.add_theme_constant_override("margin_top", top)
	dialogue_margin.add_theme_constant_override("margin_bottom", bottom)


func _add_option(text_value: String, option_id: StringName) -> void:
	var button := Button.new()
	button.name = "Option%s" % option_box.get_child_count()
	button.text = _option_text_with_arrow(text_value)
	button.custom_minimum_size = Vector2(620, 28)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(0.94, 0.91, 0.82))
	var highlight_color := Color(1, 0.86, 0.54)
	button.add_theme_color_override("font_hover_color", highlight_color)
	button.add_theme_color_override("font_pressed_color", highlight_color)
	button.add_theme_color_override("font_hover_pressed_color", highlight_color)
	button.add_theme_color_override("font_focus_color", highlight_color)
	button.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.018, 0.96))
	button.add_theme_constant_override("outline_size", 4)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		button.add_theme_stylebox_override(state, _create_option_style(Color.TRANSPARENT))
	button.pressed.connect(option_selected.emit.bind(option_id))
	option_box.add_child(button)


func _option_text_with_arrow(text_value: String) -> String:
	var clean_text := text_value.strip_edges()
	return clean_text if clean_text.ends_with("▶") else clean_text + OPTION_ARROW_SUFFIX


func _create_option_style(background_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.content_margin_left = 18
	style.content_margin_right = 12
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


func _clear_options() -> void:
	for child in option_box.get_children():
		option_box.remove_child(child)
		child.queue_free()
