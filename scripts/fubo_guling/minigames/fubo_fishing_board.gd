class_name FuboFishingBoard
extends Control

signal cast_requested

const SKY := Color("a9dfd1")
const FAR_WATER := Color("319aa4")
const DEEP_WATER := Color("176878")
const FOAM := Color("9be7d9")
const WOOD_DARK := Color("583b25")
const WOOD_MID := Color("9b6332")
const WOOD_LIGHT := Color("d39a4d")
const ROPE := Color("f0d79b")
const OUTLINE := Color("193b3b")

var game: FuboFishingGame
var _water_phase := 0.0
var _flash_time := 0.0


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func _process(delta: float) -> void:
	_water_phase = fmod(_water_phase + delta * 28.0, 32.0)
	_flash_time = maxf(0.0, _flash_time - delta)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cast_requested.emit()
		accept_event()


func flash_catch() -> void:
	_flash_time = 0.28


func _draw() -> void:
	var frame := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_rect(frame, SKY, true)
	draw_rect(Rect2(4, 112, size.x - 8, size.y - 116), DEEP_WATER, true)
	draw_rect(Rect2(4, 112, size.x - 8, 72), FAR_WATER, true)
	_draw_waves()
	_draw_dock()
	if game == null:
		return
	_draw_items()
	_draw_rope_and_hook()
	if _flash_time > 0.0:
		draw_rect(frame.grow(-5), Color(1.0, 0.86, 0.36, _flash_time), false, 7.0)
	draw_rect(frame, Color("d5c081"), false, 4.0)


func _draw_waves() -> void:
	for y in range(142, int(size.y - 10), 42):
		var shift := fmod(_water_phase + y * 0.25, 32.0)
		for x in range(-32, int(size.x + 32), 64):
			draw_line(Vector2(x + shift, y), Vector2(x + 20 + shift, y), FOAM, 3.0, false)
			draw_line(Vector2(x + 20 + shift, y), Vector2(x + 30 + shift, y - 5), Color("62c6c2"), 3.0, false)


func _draw_dock() -> void:
	draw_rect(Rect2(300, 8, 240, 62), WOOD_DARK, true)
	for x in range(308, 540, 28):
		draw_rect(Rect2(x, 12, 22, 49), WOOD_MID, true)
		draw_line(Vector2(x + 3, 18), Vector2(x + 19, 18), WOOD_LIGHT, 3.0, false)
	draw_rect(Rect2(396, 56, 48, 20), WOOD_DARK, true)
	draw_circle(FuboFishingGame.PIVOT, 11.0, WOOD_LIGHT)
	draw_circle(FuboFishingGame.PIVOT, 5.0, OUTLINE)


func _draw_rope_and_hook() -> void:
	var hook := game.get_hook_position()
	draw_line(FuboFishingGame.PIVOT, hook, OUTLINE, 5.0, false)
	draw_line(FuboFishingGame.PIVOT, hook, ROPE, 2.0, false)
	draw_line(hook, hook + Vector2(0, 13), Color("c8d6c9"), 4.0, false)
	draw_arc(hook + Vector2(8, 15), 11.0, PI * 0.45, PI * 1.55, 12, Color("e7eee0"), 4.0, false)


func _draw_items() -> void:
	var items := game.get_items()
	for index in items.size():
		var item: Dictionary = items[index]
		if not bool(item["active"]):
			continue
		var position := Vector2(item["position"])
		var facing := signf(float(Vector2(item["velocity"]).x))
		if index == game.get_caught_index():
			position = game.get_hook_position() + Vector2(0, 21)
		match String(item["kind"]):
			"small_fish":
				_draw_fish(position, facing, Color("f1c75b"), 18.0)
			"big_fish":
				_draw_fish(position, facing, Color("e4774f"), 29.0)
			"crab":
				_draw_crab(position)
			"boot":
				_draw_boot(position)


func _draw_fish(position: Vector2, facing: float, color: Color, radius: float) -> void:
	if facing == 0.0:
		facing = 1.0
	var body := Rect2(position - Vector2(radius, radius * 0.55), Vector2(radius * 2.0, radius * 1.1))
	draw_rect(body, OUTLINE, true)
	draw_rect(body.grow(-4), color, true)
	var tail_x := position.x - radius * facing
	var tail := PackedVector2Array([
		Vector2(tail_x, position.y),
		Vector2(tail_x - 14.0 * facing, position.y - 12.0),
		Vector2(tail_x - 14.0 * facing, position.y + 12.0),
	])
	draw_colored_polygon(tail, color.darkened(0.15))
	draw_circle(position + Vector2(radius * 0.55 * facing, -3), 3.5, Color.WHITE)
	draw_circle(position + Vector2(radius * 0.55 * facing, -3), 1.8, OUTLINE)


func _draw_crab(position: Vector2) -> void:
	draw_rect(Rect2(position - Vector2(20, 10), Vector2(40, 20)), OUTLINE, true)
	draw_rect(Rect2(position - Vector2(16, 7), Vector2(32, 14)), Color("e56046"), true)
	for side in [-1.0, 1.0]:
		draw_line(position + Vector2(16 * side, -3), position + Vector2(29 * side, -13), Color("f08759"), 5.0, false)
		draw_line(position + Vector2(16 * side, 4), position + Vector2(29 * side, 14), Color("f08759"), 5.0, false)


func _draw_boot(position: Vector2) -> void:
	var points := PackedVector2Array([
		position + Vector2(-9, -22), position + Vector2(10, -22),
		position + Vector2(10, 8), position + Vector2(25, 14),
		position + Vector2(25, 23), position + Vector2(-9, 23),
	])
	draw_colored_polygon(points, OUTLINE)
	draw_polyline(points, Color("916849"), 4.0, false)
