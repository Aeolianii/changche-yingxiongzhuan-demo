class_name FuboTimingMeter
extends Control

const DISPLAY_RANGE_MS := 520.0
const EARLY_COLOR := Color("3faaa1")
const PERFECT_COLOR := Color("e7b94f")
const LATE_COLOR := Color("d98745")
const BORDER_COLOR := Color("ead596")
const MARKER_COLOR := Color("fff5c7")

var _marker_ratio := 0.0
var _marker_visible := false
var _result_flash := 0.0


func _process(delta: float) -> void:
	if _result_flash > 0.0:
		_result_flash = maxf(0.0, _result_flash - delta)
		queue_redraw()


func reset() -> void:
	_marker_ratio = 0.0
	_marker_visible = false
	_result_flash = 0.0
	queue_redraw()


func set_demo_progress(progress: float) -> void:
	_marker_ratio = clampf(progress, 0.0, 1.0)
	_marker_visible = true
	queue_redraw()


func set_timing_error(timing_error_ms: int) -> void:
	_marker_ratio = clampf(0.5 + float(timing_error_ms) / (DISPLAY_RANGE_MS * 2.0), 0.0, 1.0)
	_marker_visible = true
	queue_redraw()


func show_result(timing_error_ms: int) -> void:
	set_timing_error(timing_error_ms)
	_result_flash = 0.22


func get_marker_ratio_for_test() -> float:
	return _marker_ratio


func _draw() -> void:
	var outer := Rect2(Vector2.ZERO, size)
	draw_rect(outer, Color("10201d"), true)
	var inner := outer.grow(-3.0)
	var perfect_start := inner.position.x + inner.size.x * 0.40
	var perfect_end := inner.position.x + inner.size.x * 0.60
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * 0.40, inner.size.y)), EARLY_COLOR, true)
	draw_rect(Rect2(Vector2(perfect_start, inner.position.y), Vector2(inner.size.x * 0.20, inner.size.y)), PERFECT_COLOR, true)
	draw_rect(Rect2(Vector2(perfect_end, inner.position.y), Vector2(inner.size.x * 0.40, inner.size.y)), LATE_COLOR, true)
	draw_line(Vector2(perfect_start, inner.position.y), Vector2(perfect_start, inner.end.y), Color(1, 1, 1, 0.35), 2.0)
	draw_line(Vector2(perfect_end, inner.position.y), Vector2(perfect_end, inner.end.y), Color(1, 1, 1, 0.35), 2.0)
	draw_rect(outer.grow(-1.0), BORDER_COLOR, false, 2.0)
	if not _marker_visible:
		return
	var marker_x := lerpf(inner.position.x, inner.end.x, _marker_ratio)
	var marker_color := Color.WHITE if _result_flash > 0.0 else MARKER_COLOR
	draw_line(Vector2(marker_x, -4.0), Vector2(marker_x, size.y + 4.0), marker_color, 4.0)
	var tip := PackedVector2Array([
		Vector2(marker_x - 7.0, -1.0),
		Vector2(marker_x + 7.0, -1.0),
		Vector2(marker_x, 8.0),
	])
	draw_colored_polygon(tip, marker_color)
