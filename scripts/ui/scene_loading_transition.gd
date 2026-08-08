class_name SceneLoadingTransition
extends Control

@export_range(0.01, 5.0, 0.01) var minimum_duration := 1.0

@onready var loading_image: TextureRect = $LoadingImage
@onready var loading_text: Label = $LoadingText
@onready var loading_line: ColorRect = $LoadingLine

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
	loading_line.modulate.a = 0.0
	show()
	await get_tree().process_frame

	var minimum_timer := get_tree().create_timer(minimum_duration)
	var fade_in := create_tween().set_parallel(true)
	fade_in.tween_property(loading_image, "modulate:a", 1.0, 0.16)
	fade_in.tween_property(loading_text, "modulate:a", 1.0, 0.2)
	fade_in.tween_property(loading_line, "modulate:a", 1.0, 0.24)
	await minimum_timer.timeout


func reset_loading() -> void:
	_playing = false
	hide()
