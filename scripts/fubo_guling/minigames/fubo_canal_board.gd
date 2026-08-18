class_name FuboCanalBoard
extends Control

signal branch_selected(branch: int)

const STONE_DARK := Color("293b3a")
const STONE_MID := Color("66736b")
const STONE_LIGHT := Color("a4aa8f")
const WATER_DARK := Color("176875")
const WATER_MID := Color("2697a2")
const WATER_LIGHT := Color("7de0d2")
const WOOD_DARK := Color("493423")
const WOOD_LIGHT := Color("b67b3d")
const SELECTED := Color("ffd56a")
const BLOCKED := Color("c54a3f")

var _target := PackedInt32Array([1, 1, 1])
var _levels := PackedInt32Array([0, 0, 0])
var _blocked_branch := -1
var _selected_branch := 1
var _water_phase := 0.0
var _release_flash := -1
var _release_flash_time := 0.0
var _release_succeeded := true


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func _process(delta: float) -> void:
	_water_phase = fmod(_water_phase + delta * 46.0, 18.0)
	if _release_flash_time > 0.0:
		_release_flash_time = maxf(0.0, _release_flash_time - delta)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var branch := clampi(int(event.position.x / maxf(size.x / 3.0, 1.0)), 0, 2)
		branch_selected.emit(branch)
		accept_event()


func set_state(target: PackedInt32Array, levels: PackedInt32Array, blocked_branch: int) -> void:
	_target = target.duplicate()
	_levels = levels.duplicate()
	_blocked_branch = blocked_branch
	queue_redraw()


func set_selected(branch: int) -> void:
	_selected_branch = clampi(branch, 0, 2)
	queue_redraw()


func play_release(branch: int, succeeded: bool) -> void:
	_release_flash = clampi(branch, 0, 2)
	_release_succeeded = succeeded
	_release_flash_time = 0.32
	queue_redraw()


func _draw() -> void:
	var board := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_rect(board, Color("172e2b"), true)
	draw_rect(board, STONE_LIGHT, false, 4.0)
	_draw_stone_course(Rect2(10, 10, size.x - 20, size.y - 20))

	var source_center := Vector2(size.x * 0.5, 34)
	_draw_source_pool(source_center)
	_draw_distributor(source_center)

	var centers := [size.x * 0.17, size.x * 0.5, size.x * 0.83]
	for branch in 3:
		_draw_branch(branch, centers[branch])


func _draw_source_pool(center: Vector2) -> void:
	var outer := Rect2(center - Vector2(68, 25), Vector2(136, 50))
	var inner := outer.grow(-8)
	draw_rect(outer, STONE_MID, true)
	draw_rect(outer, STONE_LIGHT, false, 3.0)
	draw_rect(inner, WATER_DARK, true)
	for x in range(int(inner.position.x - _water_phase), int(inner.end.x), 18):
		draw_line(Vector2(x, inner.position.y + 12), Vector2(x + 9, inner.position.y + 12), WATER_LIGHT, 3.0, false)


func _draw_distributor(source_center: Vector2) -> void:
	var stem := Rect2(source_center.x - 22, 58, 44, 44)
	draw_rect(stem.grow(7), STONE_MID, true)
	draw_rect(stem, WATER_DARK, true)
	var cross_channel := Rect2(size.x * 0.12, 92, size.x * 0.76, 30)
	draw_rect(cross_channel.grow(7), STONE_MID, true)
	draw_rect(cross_channel, WATER_DARK, true)
	for x in range(int(cross_channel.position.x - _water_phase), int(cross_channel.end.x), 24):
		draw_line(Vector2(x, cross_channel.position.y + 15), Vector2(x + 11, cross_channel.position.y + 15), WATER_MID, 4.0, false)


func _draw_branch(branch: int, center_x: float) -> void:
	var selected := branch == _selected_branch
	var blocked := branch == _blocked_branch
	var channel := Rect2(center_x - 18, 112, 36, 58)
	draw_rect(channel.grow(7), SELECTED if selected else STONE_MID, true)
	draw_rect(channel, Color("1a4d54") if blocked else WATER_DARK, true)

	var gate_y := 132.0
	draw_rect(Rect2(center_x - 31, gate_y - 6, 62, 12), WOOD_DARK, true)
	draw_rect(Rect2(center_x - 25, gate_y - 4, 50, 6), WOOD_LIGHT, true)
	draw_circle(Vector2(center_x, gate_y - 8), 6.0, SELECTED if selected else STONE_LIGHT)

	var basin := Rect2(center_x - 91, 171, 182, 91)
	draw_rect(basin.grow(7), SELECTED if selected else STONE_MID, true)
	draw_rect(basin, STONE_DARK, true)
	_draw_basin_water(branch, basin.grow(-10))
	_draw_target_marker(branch, basin.grow(-10))
	_draw_basin_bricks(basin)

	if blocked:
		draw_line(Vector2(center_x - 36, 119), Vector2(center_x + 36, 165), BLOCKED, 8.0, false)
		draw_line(Vector2(center_x + 36, 119), Vector2(center_x - 36, 165), BLOCKED, 8.0, false)
	if _release_flash_time > 0.0 and branch == _release_flash:
		var flash := WATER_LIGHT if _release_succeeded else BLOCKED
		draw_rect(basin.grow(13), flash, false, 6.0)


func _draw_basin_water(branch: int, inner: Rect2) -> void:
	var target_value := _target[branch] if branch < _target.size() else 0
	var level_value := _levels[branch] if branch < _levels.size() else 0
	var capacity := maxi(1, maxi(target_value, level_value))
	var ratio := clampf(float(level_value) / float(capacity), 0.0, 1.0)
	var fill_height := inner.size.y * ratio
	if fill_height <= 0.0:
		return
	var water_rect := Rect2(inner.position.x, inner.end.y - fill_height, inner.size.x, fill_height)
	draw_rect(water_rect, WATER_MID, true)
	for y in range(int(water_rect.position.y + _water_phase), int(water_rect.end.y), 14):
		draw_line(Vector2(water_rect.position.x + 6, y), Vector2(water_rect.end.x - 6, y), WATER_LIGHT, 3.0, false)


func _draw_target_marker(branch: int, inner: Rect2) -> void:
	var target_value := _target[branch] if branch < _target.size() else 0
	if target_value <= 0:
		return
	var marker_y := inner.position.y + 8
	draw_line(Vector2(inner.position.x + 4, marker_y), Vector2(inner.end.x - 4, marker_y), SELECTED, 3.0, false)
	for x in range(int(inner.position.x + 4), int(inner.end.x - 4), 18):
		draw_line(Vector2(x, marker_y - 4), Vector2(x, marker_y + 4), SELECTED, 2.0, false)


func _draw_basin_bricks(basin: Rect2) -> void:
	for x in range(int(basin.position.x + 10), int(basin.end.x), 24):
		draw_line(Vector2(x, basin.position.y - 6), Vector2(x, basin.position.y + 2), STONE_LIGHT, 2.0, false)
	for x in range(int(basin.position.x + 20), int(basin.end.x), 28):
		draw_line(Vector2(x, basin.end.y - 2), Vector2(x, basin.end.y + 6), STONE_LIGHT, 2.0, false)


func _draw_stone_course(rect: Rect2) -> void:
	for x in range(int(rect.position.x + 12), int(rect.end.x), 38):
		draw_line(Vector2(x, rect.position.y), Vector2(x + 18, rect.position.y), STONE_MID, 3.0, false)
		draw_line(Vector2(x, rect.end.y), Vector2(x + 18, rect.end.y), STONE_MID, 3.0, false)
