class_name YuehuanMerchantNpc
extends Node2D

@export var merchant_id := ""
@export var display_name := ""
@export_enum("goods", "shipyard") var shop_role := "goods"
@export_multiline var dialogue_text := ""
@export var portrait: Texture2D
@export var bark_lines: PackedStringArray = []
@export var bark_bubble_offset := Vector2(-70, -94)

var _bark_bubble: PanelContainer
var _bark_label: Label
var _bark_timer: Timer
var _bark_hide_timer: Timer
var _barks_enabled := true


func _ready() -> void:
	_build_bark_bubble()
	_schedule_next_bark()


func interaction_prompt() -> String:
	return "与%s交谈" % display_name


func trade_option_text() -> String:
	return "看看货物" if shop_role == "goods" else "看看图纸"


func set_barks_enabled(enabled: bool) -> void:
	_barks_enabled = enabled
	if not enabled:
		_bark_bubble.hide()
		_bark_timer.stop()
		_bark_hide_timer.stop()
	elif _bark_timer.is_stopped() and _bark_hide_timer.is_stopped():
		_schedule_next_bark()


func show_bark_for_test() -> void:
	_show_random_bark()


func _build_bark_bubble() -> void:
	_bark_bubble = PanelContainer.new()
	_bark_bubble.name = "BarkBubble"
	_bark_bubble.position = bark_bubble_offset
	_bark_bubble.custom_minimum_size = Vector2(140, 34)
	_bark_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bark_bubble.z_index = 20
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#efe4c9ed")
	style.border_color = Color("#51483b")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	_bark_bubble.add_theme_stylebox_override("panel", style)
	add_child(_bark_bubble)
	_bark_label = Label.new()
	_bark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bark_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bark_label.add_theme_font_size_override("font_size", 14)
	_bark_label.add_theme_color_override("font_color", Color("#2c2821"))
	_bark_bubble.add_child(_bark_label)
	_bark_bubble.hide()
	_bark_timer = Timer.new()
	_bark_timer.one_shot = true
	_bark_timer.timeout.connect(_show_random_bark)
	add_child(_bark_timer)
	_bark_hide_timer = Timer.new()
	_bark_hide_timer.one_shot = true
	_bark_hide_timer.timeout.connect(_hide_bark)
	add_child(_bark_hide_timer)


func _schedule_next_bark() -> void:
	if _barks_enabled and not bark_lines.is_empty():
		_bark_timer.start(randf_range(5.0, 9.0))


func _show_random_bark() -> void:
	if not _barks_enabled or bark_lines.is_empty():
		return
	_bark_label.text = bark_lines[randi_range(0, bark_lines.size() - 1)]
	_bark_bubble.show()
	_bark_hide_timer.start(2.5)


func _hide_bark() -> void:
	_bark_bubble.hide()
	_schedule_next_bark()
