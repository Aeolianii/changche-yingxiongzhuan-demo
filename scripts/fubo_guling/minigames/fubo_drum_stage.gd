class_name FuboDrumStage
extends Control

signal drum_pressed(index: int)

@export var drum_texture: Texture2D

const INK := Color("253c39")
const SKY := Color("b9dfcc")
const WALL := Color("9a9b83")
const WALL_LIGHT := Color("c2bda0")
const EARTH := Color("b8613d")
const EARTH_LIGHT := Color("d18153")
const WOOD := Color("684027")
const GOLD := Color("f6d36a")
const VERMILION := Color("bd3f35")
const TEAL := Color("287d7b")

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


func _draw() -> void:
	var frame := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_rect(frame, SKY, true)
	_draw_distant_hills()
	_draw_garrison_wall()
	draw_rect(Rect2(4, 142, size.x - 8, size.y - 146), EARTH, true)
	_draw_earth_courses()
	_draw_side_banners()
	_draw_drum_platforms()
	_draw_drums()
	draw_rect(frame, Color("d7bd72"), false, 5.0)
	draw_rect(frame.grow(-7), INK, false, 2.0)


func _draw_distant_hills() -> void:
	var left_hill := PackedVector2Array([
		Vector2(4, 104), Vector2(4, 72), Vector2(68, 45), Vector2(132, 64),
		Vector2(198, 40), Vector2(282, 82), Vector2(342, 54), Vector2(410, 104),
	])
	var right_hill := PackedVector2Array([
		Vector2(size.x - 410, 104), Vector2(size.x - 340, 55), Vector2(size.x - 270, 78),
		Vector2(size.x - 190, 42), Vector2(size.x - 120, 66), Vector2(size.x - 54, 46),
		Vector2(size.x - 4, 72), Vector2(size.x - 4, 104),
	])
	draw_colored_polygon(left_hill, Color("4f8a68"))
	draw_colored_polygon(right_hill, Color("3f7b62"))


func _draw_garrison_wall() -> void:
	draw_rect(Rect2(4, 92, size.x - 8, 54), INK, true)
	draw_rect(Rect2(4, 96, size.x - 8, 45), WALL, true)
	for x in range(14, int(size.x - 16), 54):
		draw_rect(Rect2(x, 99, 46, 17), WALL_LIGHT, true)
		draw_line(Vector2(x + 23, 118), Vector2(x + 23, 138), Color("6f756a"), 3.0, false)
	for x in range(22, int(size.x - 16), 86):
		draw_rect(Rect2(x, 76, 52, 20), INK, true)
		draw_rect(Rect2(x + 5, 80, 42, 16), Color("65736b"), true)


func _draw_earth_courses() -> void:
	for y in range(175, int(size.y - 15), 42):
		for x in range(20 + (y % 3) * 12, int(size.x - 20), 92):
			draw_line(Vector2(x, y), Vector2(x + 38, y), EARTH_LIGHT, 3.0, false)


func _draw_side_banners() -> void:
	for data in [[84.0, VERMILION], [size.x - 84.0, TEAL]]:
		var x := float(data[0])
		var color: Color = data[1]
		draw_rect(Rect2(x - 4, 84, 8, 235), WOOD, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + 4, 96), Vector2(x + 74 if x < size.x * 0.5 else x - 74, 118),
			Vector2(x + 4, 145),
		]), color)
		draw_circle(Vector2(x, 80), 9.0, GOLD)


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
