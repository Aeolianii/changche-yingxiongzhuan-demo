class_name FuboDrumStage
extends Control

signal drum_pressed(index: int)

@export var drum_texture: Texture2D

const INK := Color("253c39")
const WOOD := Color("684027")
const GOLD := Color("f6d36a")
const VERMILION := Color("bd3f35")
const DRUM_STAGE_BACKGROUND := preload("res://assets/fubo_guling/minigames/drum/drum_training_yard_background_v1.png")

var input_enabled := false
var _active_drum := -1
var _flash_time := 0.0
var _impact_radius := 0.0


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func _process(delta: float) -> void:
	if _flash_time > 0.0:
		_flash_time = maxf(0.0, _flash_time - delta)
		_impact_radius += delta * 125.0
		if _flash_time <= 0.0:
			_active_drum = -1
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var rects := _get_drum_rects()
		for index in rects.size():
			if rects[index].has_point(event.position):
				drum_pressed.emit(index)
				accept_event()
				return


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	queue_redraw()


func flash_drum(index: int) -> void:
	if index < 0 or index > 2:
		return
	_active_drum = index
	_flash_time = 0.26
	_impact_radius = 18.0
	queue_redraw()


func get_drum_rects_for_test() -> Array[Rect2]:
	return _get_drum_rects()


func get_background_texture_path_for_test() -> String:
	return DRUM_STAGE_BACKGROUND.resource_path


func _draw() -> void:
	var frame := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_texture_rect(DRUM_STAGE_BACKGROUND, frame, false)
	_draw_drum_platforms()
	_draw_drums()
	draw_rect(frame, Color("d7bd72"), false, 5.0)
	draw_rect(frame.grow(-7), INK, false, 2.0)


func _draw_drum_platforms() -> void:
	for rect in _get_drum_rects():
		var base_y := rect.end.y - 15.0
		draw_rect(Rect2(rect.position.x - 15, base_y, rect.size.x + 30, 20), INK, true)
		draw_rect(Rect2(rect.position.x - 9, base_y + 4, rect.size.x + 18, 12), WOOD, true)


func _draw_drums() -> void:
	var rects := _get_drum_rects()
	for index in rects.size():
		var rect: Rect2 = rects[index]
		if index == _active_drum:
			rect.position.y -= 8.0
			draw_rect(rect.grow(13), Color(GOLD, 0.82), false, 7.0)
		if drum_texture != null:
			draw_texture_rect(drum_texture, rect, false)
		else:
			draw_rect(rect, VERMILION, true)
		if index == _active_drum:
			var center := rect.get_center() + Vector2(-rect.size.x * 0.18, -rect.size.y * 0.07)
			draw_arc(center, _impact_radius, 0.0, TAU, 28, Color(GOLD, _flash_time * 2.9), 5.0, false)
		if not input_enabled:
			draw_rect(rect, Color(INK, 0.08), true)


func _get_drum_rects() -> Array[Rect2]:
	var bottom := size.y - 24.0
	var widths := [242.0, 218.0, 190.0]
	var centers := [size.x * 0.24, size.x * 0.5, size.x * 0.76]
	var rects: Array[Rect2] = []
	for index in 3:
		var width: float = widths[index]
		var height := width * 1.255
		rects.append(Rect2(Vector2(float(centers[index]) - width * 0.5, bottom - height), Vector2(width, height)))
	return rects
