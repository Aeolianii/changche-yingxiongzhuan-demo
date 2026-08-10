class_name FuboPlaceholderWorld
extends Node2D

const WORLD_SIZE := Vector2(3200, 2200)
var main_path := PackedVector2Array([
	Vector2(420, 1850), Vector2(720, 1780), Vector2(1150, 1650),
	Vector2(1480, 1490), Vector2(1980, 1420), Vector2(2600, 1180),
	Vector2(2300, 920), Vector2(1850, 620), Vector2(2160, 500),
	Vector2(2550, 320),
])
var canal_segments := [
	PackedVector2Array([Vector2(2700, 1060), Vector2(2650, 1120), Vector2(2600, 1180)]),
	PackedVector2Array([Vector2(2630, 1210), Vector2(2530, 1250), Vector2(2440, 1270)]),
	PackedVector2Array([Vector2(2580, 1220), Vector2(2680, 1280), Vector2(2790, 1320)]),
]


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("315d46"))
	for y in range(0, int(WORLD_SIZE.y), 64):
		for x in range(0, int(WORLD_SIZE.x), 64):
			if (x * 7 + y * 11) % 5 == 0:
				draw_rect(Rect2(x + 12, y + 20, 8, 4), Color("4f8054"))
				draw_rect(Rect2(x + 24, y + 11, 4, 3), Color("244d3e"))
	_draw_coast()
	draw_polyline(main_path, Color("705b43"), 108.0, false)
	draw_polyline(main_path, Color("b99a68"), 88.0, false)
	_draw_courtyard()
	_draw_canal()
	_draw_training_yard()
	_draw_viewpoint()


func _draw_coast() -> void:
	draw_rect(Rect2(0, 2050, 1800, 150), Color("4daec3"))
	draw_rect(Rect2(0, 2018, 1800, 32), Color("dfc788"))
	for x in range(0, 1500, 56):
		draw_line(Vector2(x, 2090 + (x % 3) * 8), Vector2(x + 34, 2090 + (x % 3) * 8), Color("86d7df"), 3.0, false)
	draw_rect(Rect2(2700, 0, 500, 90), Color("52aec0"))


func _draw_courtyard() -> void:
	pass


func _draw_canal() -> void:
	for segment in canal_segments:
		draw_polyline(segment, Color("686b68"), 24.0, false)
		draw_polyline(segment, Color("383f3e"), 11.0, false)


func _draw_training_yard() -> void:
	pass


func _draw_viewpoint() -> void:
	pass
