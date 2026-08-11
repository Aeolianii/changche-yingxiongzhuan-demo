class_name FuboWorldProp
extends Node2D

@export_enum("keeper", "house", "storage", "tree", "gate", "pool", "drum", "flag", "barrier", "stele") var kind := "tree"
@export var prop_size := Vector2(100, 80)
@export var main_color := Color("6f7b69")
@export var accent_color := Color("d6be78")
@export var label_text := ""
@export var state := 0
@export var highlighted := false
@export var art_texture: Texture2D
@export var art_scale := Vector2.ONE
@export var art_offset := Vector2.ZERO


func set_state(value: int) -> void:
	state = value
	queue_redraw()


func set_highlighted(value: bool) -> void:
	highlighted = value
	queue_redraw()


func _draw() -> void:
	if art_texture != null:
		_draw_generated_art()
		if kind == "gate":
			_draw_gate_indicator()
		elif kind == "pool" and state > 0:
			_draw_pool_water()
	else:
		match kind:
			"keeper": _draw_keeper()
			"house", "storage": _draw_house()
			"tree": _draw_tree()
			"gate": _draw_gate()
			"pool": _draw_pool()
			"drum": _draw_drum()
			"flag": _draw_flag()
			"barrier": _draw_barrier()
			"stele": _draw_stele()
	if not label_text.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(-prop_size.x * 0.5, -prop_size.y - 12), label_text, HORIZONTAL_ALIGNMENT_CENTER, prop_size.x, 18, Color("f6edcf"))


func _draw_generated_art() -> void:
	var texture_size := art_texture.get_size() * art_scale
	var target := Rect2(Vector2(-texture_size.x * 0.5, -texture_size.y) + art_offset, texture_size)
	draw_texture_rect(art_texture, target, false)


func _draw_gate_indicator() -> void:
	var angles := [-2.35, -PI * 0.5, -0.79]
	var center := Vector2(0, -24)
	var direction := Vector2.from_angle(angles[clampi(state, 0, 2)])
	draw_circle(center, 9.0, Color("26383b"))
	draw_line(center, center + direction * 20.0, Color("f1c965"), 4.0, false)
	draw_circle(center + direction * 20.0, 3.0, Color("fff0a6"))


func _draw_pool_water() -> void:
	var width := minf(prop_size.x - 24.0, art_texture.get_width() * art_scale.x - 28.0)
	for y in [-45.0, -34.0, -23.0]:
		draw_line(Vector2(-width * 0.5, y), Vector2(width * 0.5, y), Color(0.32, 0.86, 0.82, 0.75), 3.0, false)


func _draw_keeper() -> void:
	draw_set_transform(Vector2(0, -2), 0.0, Vector2(1.5, 0.5))
	draw_circle(Vector2.ZERO, 11.0, Color(0.02, 0.03, 0.03, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(-9, -48, 18, 38), Color("3b4b52"))
	draw_circle(Vector2(0, -56), 10.0, Color("d1a375"))
	draw_rect(Rect2(-12, -67, 24, 7), Color("26343a"))
	draw_line(Vector2(-12, -44), Vector2(-18, 1), Color("7b5635"), 4.0, false)


func _draw_house() -> void:
	var half := prop_size.x * 0.5
	draw_rect(Rect2(-half, -prop_size.y, prop_size.x, prop_size.y), main_color)
	for y in range(int(-prop_size.y + 14), 0, 18):
		draw_line(Vector2(-half, y), Vector2(half, y), main_color.darkened(0.2), 2.0, false)
	var roof := PackedVector2Array([
		Vector2(-half - 18, -prop_size.y + 8), Vector2(-half + 12, -prop_size.y - 35),
		Vector2(half - 12, -prop_size.y - 35), Vector2(half + 18, -prop_size.y + 8),
	])
	draw_colored_polygon(roof, Color("30373c"))
	draw_line(Vector2(-half - 18, -prop_size.y + 8), Vector2(half + 18, -prop_size.y + 8), accent_color, 3.0, false)
	draw_rect(Rect2(-18, -36, 36, 36), Color("7a3d32"))


func _draw_tree() -> void:
	draw_rect(Rect2(-8, -50, 16, 50), Color("68492f"))
	for offset in [Vector2(-24, -62), Vector2(0, -76), Vector2(25, -62), Vector2(0, -50)]:
		draw_circle(offset, 29.0, main_color)
		draw_circle(offset + Vector2(-5, -5), 18.0, main_color.lightened(0.12))


func _draw_gate() -> void:
	draw_rect(Rect2(-22, -14, 44, 28), Color("707570"))
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 12, accent_color, 4.0, false)
	var angles := [-2.35, -PI * 0.5, -0.79]
	var direction := Vector2.from_angle(angles[clampi(state, 0, 2)])
	draw_line(Vector2.ZERO, direction * 30.0, Color("b37842"), 7.0, false)
	draw_circle(direction * 30.0, 5.0, Color("e3bd68"))


func _draw_pool() -> void:
	draw_rect(Rect2(-prop_size.x * 0.5, -prop_size.y, prop_size.x, prop_size.y), Color("747b76"))
	var inner := Rect2(-prop_size.x * 0.5 + 9, -prop_size.y + 9, prop_size.x - 18, prop_size.y - 18)
	draw_rect(inner, Color("367f86") if state > 0 else Color("454c49"))
	if state > 0:
		for y in range(int(inner.position.y + 10), int(inner.end.y), 16):
			draw_line(Vector2(inner.position.x + 8, y), Vector2(inner.end.x - 8, y), Color("55c8c2"), 3.0, false)


func _draw_drum() -> void:
	draw_rect(Rect2(-22, -35, 44, 35), Color("6d452a"))
	draw_circle(Vector2.ZERO + Vector2(0, -28), 26.0, Color("a74433"))
	draw_circle(Vector2(0, -28), 19.0, Color("dfcda5"))


func _draw_flag() -> void:
	draw_line(Vector2(0, 0), Vector2(0, -75), Color("68492f"), 5.0, false)
	draw_colored_polygon(PackedVector2Array([Vector2(2, -72), Vector2(42, -62), Vector2(2, -48)]), main_color)
	draw_rect(Rect2(-10, -7, 20, 7), Color("727772"))


func _draw_barrier() -> void:
	draw_line(Vector2(-prop_size.x * 0.5, -18), Vector2(prop_size.x * 0.5, 4), main_color, 10.0, false)
	draw_line(Vector2(-prop_size.x * 0.5, 4), Vector2(prop_size.x * 0.5, -18), main_color, 10.0, false)
	draw_rect(Rect2(-36, -46, 72, 25), Color("3d3027"))
	draw_string(ThemeDB.fallback_font, Vector2(-30, -28), label_text, HORIZONTAL_ALIGNMENT_CENTER, 60, 14, accent_color)


func _draw_stele() -> void:
	draw_rect(Rect2(-18, -58, 36, 58), Color("747a78"))
	draw_rect(Rect2(-26, -8, 52, 8), Color("545b59"))
