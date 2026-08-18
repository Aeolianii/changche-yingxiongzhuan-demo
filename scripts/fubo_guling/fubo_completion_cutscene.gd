class_name FuboCompletionCutscene
extends Control

signal cutscene_finished

const BASE_DURATION_SECONDS := 4.0

@export_range(0.1, 10.0, 0.01) var duration_seconds := BASE_DURATION_SECONDS
@export_range(0.01, 4.0, 0.01) var duration_scale := 1.0

@onready var cg_image: TextureRect = $CGImage
@onready var cg_shade: ColorRect = $CGShade
@onready var title_label: Label = $Caption/Title
@onready var subtitle_label: Label = $Caption/Subtitle

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
	cg_image.pivot_offset = cg_image.size * 0.5
	cg_image.scale = Vector2(1.045, 1.045)

	var camera_tween := create_tween()
	camera_tween.tween_property(cg_image, "scale", Vector2.ONE, _duration(BASE_DURATION_SECONDS))

	var fade_in := create_tween().set_parallel(true)
	fade_in.tween_property(cg_image, "modulate:a", 1.0, _duration(0.55))
	fade_in.tween_property(cg_shade, "modulate:a", 1.0, _duration(0.55))
	fade_in.tween_property(title_label, "modulate:a", 1.0, _duration(0.42)).set_delay(_duration(0.28))
	fade_in.tween_property(subtitle_label, "modulate:a", 1.0, _duration(0.42)).set_delay(_duration(0.52))
	await fade_in.finished

	await get_tree().create_timer(_duration(2.56)).timeout

	var fade_out := create_tween().set_parallel(true)
	fade_out.tween_property(cg_image, "modulate:a", 0.0, _duration(0.5))
	fade_out.tween_property(cg_shade, "modulate:a", 0.0, _duration(0.5))
	fade_out.tween_property(title_label, "modulate:a", 0.0, _duration(0.32))
	fade_out.tween_property(subtitle_label, "modulate:a", 0.0, _duration(0.32))
	await fade_out.finished

	hide()
	_playing = false
	cutscene_finished.emit()


func reset_cutscene() -> void:
	_playing = false
	hide()
	_reset_visuals()


func is_playing_for_test() -> bool:
	return _playing


func _reset_visuals() -> void:
	cg_image.modulate = Color(1.0, 1.0, 1.0, 0.0)
	cg_image.scale = Vector2.ONE
	cg_shade.modulate = Color(1.0, 1.0, 1.0, 0.0)
	title_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	subtitle_label.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _duration(seconds: float) -> float:
	return maxf(seconds * (duration_seconds / BASE_DURATION_SECONDS) * duration_scale, 0.001)
