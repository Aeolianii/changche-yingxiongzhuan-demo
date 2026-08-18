class_name FuboFishingStation
extends Node2D

const HIGHLIGHT_MODULATE := Color(1.35, 1.22, 0.72, 1.0)
const SPARKLE_POSITIONS := [
	Vector2(-25, -139),
	Vector2(17, -112),
	Vector2(-41, -83),
]

@onready var sprite: Sprite2D = $Sprite

var _available := false
var _highlighted := false
var _elapsed := 0.0
var _normal_modulate := Color.WHITE
var _normal_scale := Vector2.ONE


func _ready() -> void:
	_normal_modulate = sprite.modulate
	_normal_scale = sprite.scale
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, TAU)
	queue_redraw()


func set_available(value: bool) -> void:
	_available = value
	set_process(value)
	if not value:
		_elapsed = 0.0
		set_highlighted(false)
	queue_redraw()


func set_highlighted(value: bool) -> void:
	_highlighted = value and _available
	if not is_node_ready():
		return
	sprite.modulate = HIGHLIGHT_MODULATE if _highlighted else _normal_modulate
	sprite.scale = _normal_scale
	queue_redraw()


func is_available_for_test() -> bool:
	return _available


func is_highlighted_for_test() -> bool:
	return _highlighted


func _draw() -> void:
	if not _available:
		return
	for index in SPARKLE_POSITIONS.size():
		var pulse := 0.5 + 0.5 * sin(_elapsed * 2.4 + float(index) * 2.1)
		var size := 2.0 + pulse * (3.2 if _highlighted else 2.2)
		var alpha := 0.28 + pulse * (0.68 if _highlighted else 0.48)
		var center: Vector2 = SPARKLE_POSITIONS[index] + Vector2(0.0, sin(_elapsed * 1.8 + index) * 1.5)
		var color := Color(1.0, 0.88, 0.48, alpha)
		draw_line(center - Vector2(size, 0.0), center + Vector2(size, 0.0), color, 2.0, false)
		draw_line(center - Vector2(0.0, size), center + Vector2(0.0, size), color, 2.0, false)
		draw_circle(center, 1.2, Color(1.0, 0.97, 0.78, alpha), false)
