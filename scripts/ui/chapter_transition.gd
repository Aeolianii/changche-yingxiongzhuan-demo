class_name ChapterTransition
extends Control

signal transition_finished

@export_range(0.01, 4.0, 0.01) var duration_scale := 1.0

@onready var backdrop: ColorRect = $Backdrop
@onready var journey_image: TextureRect = $JourneyImage
@onready var journey_shade: ColorRect = $JourneyShade
@onready var chapter_title: Label = $ChapterTitle
@onready var chapter_subtitle: Label = $ChapterSubtitle
@onready var journey_text: Label = $JourneyText

var _playing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func play() -> void:
	if _playing:
		return
	_playing = true
	_reset_visuals()
	show()
	await get_tree().process_frame
	journey_image.pivot_offset = journey_image.size * 0.5

	chapter_title.text = "第一章·奉诏入殿"
	chapter_subtitle.text = "完"
	await _fade_pair(chapter_title, chapter_subtitle, 1.0, 0.42)
	await _pause(0.95)
	await _fade_pair(chapter_title, chapter_subtitle, 0.0, 0.34)

	journey_image.scale = Vector2(1.035, 1.035)
	create_tween().tween_property(journey_image, "scale", Vector2.ONE, _duration(4.4))
	var journey_in := create_tween().set_parallel(true)
	journey_in.tween_property(journey_image, "modulate:a", 1.0, _duration(0.62))
	journey_in.tween_property(journey_shade, "modulate:a", 1.0, _duration(0.62))
	await journey_in.finished

	await _show_journey_caption("诏令既下，星夜南驰。")
	await _show_journey_caption("越千山，渡长河，抵南疆。")
	await _pause(0.35)

	var journey_out := create_tween().set_parallel(true)
	journey_out.tween_property(journey_image, "modulate:a", 0.0, _duration(0.48))
	journey_out.tween_property(journey_shade, "modulate:a", 0.0, _duration(0.48))
	journey_out.tween_property(journey_text, "modulate:a", 0.0, _duration(0.28))
	await journey_out.finished

	chapter_title.text = "第二章·南疆水师"
	chapter_subtitle.text = ""
	await _fade_pair(chapter_title, chapter_subtitle, 1.0, 0.42)
	await _pause(1.05)
	await _fade_pair(chapter_title, chapter_subtitle, 0.0, 0.34)
	transition_finished.emit()


func reset_transition() -> void:
	_playing = false
	hide()
	_reset_visuals()


func _reset_visuals() -> void:
	backdrop.modulate = Color.WHITE
	journey_image.modulate = Color(1.0, 1.0, 1.0, 0.0)
	journey_image.scale = Vector2.ONE
	journey_shade.modulate = Color(1.0, 1.0, 1.0, 0.0)
	chapter_title.modulate = Color(1.0, 1.0, 1.0, 0.0)
	chapter_subtitle.modulate = Color(1.0, 1.0, 1.0, 0.0)
	journey_text.modulate = Color(1.0, 1.0, 1.0, 0.0)
	journey_text.text = ""


func _show_journey_caption(caption: String) -> void:
	journey_text.text = caption
	journey_text.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(journey_text, "modulate:a", 1.0, _duration(0.3))
	await fade_in.finished
	await _pause(0.95)
	var fade_out := create_tween()
	fade_out.tween_property(journey_text, "modulate:a", 0.0, _duration(0.26))
	await fade_out.finished


func _fade_pair(first: CanvasItem, second: CanvasItem, alpha: float, seconds: float) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(first, "modulate:a", alpha, _duration(seconds))
	tween.tween_property(second, "modulate:a", alpha, _duration(seconds))
	await tween.finished


func _pause(seconds: float) -> void:
	await get_tree().create_timer(_duration(seconds)).timeout


func _duration(seconds: float) -> float:
	return maxf(seconds * duration_scale, 0.001)
