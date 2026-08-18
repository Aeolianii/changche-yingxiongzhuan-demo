class_name SceneLoadingTransition
extends Control

@export_range(0.01, 5.0, 0.01) var minimum_duration := 1.0

@onready var loading_image: TextureRect = $LoadingImage
@onready var loading_text: Label = $LoadingText
@onready var loading_bar: Control = $LoadingBar
@onready var loading_progress: ProgressBar = $LoadingBar/Progress

var _playing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func play_loading(message: String) -> void:
	if _playing:
		return
	_playing = true
	loading_text.text = message
	loading_image.modulate.a = 0.0
	loading_text.modulate.a = 0.0
	loading_bar.modulate.a = 0.0
	loading_progress.value = 0.0
	show()
	await get_tree().process_frame

	var minimum_timer := get_tree().create_timer(minimum_duration)
	var fade_in := create_tween().set_parallel(true)
	fade_in.tween_property(loading_image, "modulate:a", 1.0, 0.16)
	fade_in.tween_property(loading_text, "modulate:a", 1.0, 0.2)
	fade_in.tween_property(loading_bar, "modulate:a", 1.0, 0.24)
	var rise_duration := minimum_duration * 0.68
	var hold_duration := minimum_duration * 0.24
	var finish_duration := maxf(minimum_duration - rise_duration - hold_duration, 0.01)
	var progress_tween := create_tween()
	progress_tween.tween_property(loading_progress, "value", 90.0, rise_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	progress_tween.tween_interval(hold_duration)
	progress_tween.tween_property(loading_progress, "value", 100.0, finish_duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await minimum_timer.timeout
	loading_progress.value = 100.0


func reset_loading() -> void:
	_playing = false
	loading_progress.value = 0.0
	hide()
