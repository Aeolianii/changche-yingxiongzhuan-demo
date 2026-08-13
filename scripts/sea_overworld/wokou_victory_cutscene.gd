class_name WokouVictoryCutscene
extends Control

signal cutscene_finished

const BASE_DURATION_SECONDS := 4.0

@export_range(0.1, 10.0, 0.01) var duration_seconds := BASE_DURATION_SECONDS
@export_range(0.01, 4.0, 0.01) var duration_scale := 1.0

@onready var cg_placeholder: Control = $CGPlaceholder
@onready var victory_mark: Label = $CGPlaceholder/VictoryMark
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
	cg_placeholder.pivot_offset = cg_placeholder.size * 0.5
	cg_placeholder.scale = Vector2(1.045, 1.045)

	var camera_tween := create_tween()
	camera_tween.tween_property(cg_placeholder, "scale", Vector2.ONE, _duration(BASE_DURATION_SECONDS))

	var fade_in := create_tween().set_parallel(true)
	fade_in.tween_property(cg_placeholder, "modulate:a", 1.0, _duration(0.55))
	fade_in.tween_property(victory_mark, "modulate:a", 0.2, _duration(0.55))
	fade_in.tween_property(title_label, "modulate:a", 1.0, _duration(0.42)).set_delay(_duration(0.28))
	fade_in.tween_property(subtitle_label, "modulate:a", 1.0, _duration(0.42)).set_delay(_duration(0.52))
	await fade_in.finished
	await get_tree().create_timer(_duration(2.56)).timeout

	var fade_out := create_tween().set_parallel(true)
	fade_out.tween_property(cg_placeholder, "modulate:a", 0.0, _duration(0.5))
	fade_out.tween_property(victory_mark, "modulate:a", 0.0, _duration(0.5))
	fade_out.tween_property(title_label, "modulate:a", 0.0, _duration(0.32))
	fade_out.tween_property(subtitle_label, "modulate:a", 0.0, _duration(0.32))
	await fade_out.finished

	hide()
	_playing = false
	cutscene_finished.emit()


func is_playing_for_test() -> bool:
	return _playing


func _reset_visuals() -> void:
	cg_placeholder.modulate = Color(1.0, 1.0, 1.0, 0.0)
	cg_placeholder.scale = Vector2.ONE
	victory_mark.modulate = Color(0.95, 0.82, 0.48, 0.0)
	title_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	subtitle_label.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _duration(seconds: float) -> float:
	return maxf(seconds * (duration_seconds / BASE_DURATION_SECONDS) * duration_scale, 0.001)
