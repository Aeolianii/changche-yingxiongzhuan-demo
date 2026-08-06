class_name SquareGrid
extends RefCounted

const DIRECTIONS := [
	Vector2i(1, 0),
	Vector2i(1, 1),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
]


func distance(from_cell: Vector2i, to_cell: Vector2i) -> int:
	var delta := to_cell - from_cell
	return maxi(absi(delta.x), absi(delta.y))


func direction_index(delta: Vector2i) -> int:
	var normalized := Vector2i(signi(delta.x), signi(delta.y))
	return DIRECTIONS.find(normalized)


func line(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var x0 := from_cell.x
	var y0 := from_cell.y
	var x1 := to_cell.x
	var y1 := to_cell.y
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var error := dx + dy
	while true:
		result.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var doubled := error * 2
		if doubled >= dy:
			error += dy
			x0 += sx
		if doubled <= dx:
			error += dx
			y0 += sy
	return result


func cell_to_pixel(cell: Vector2i, origin: Vector2, cell_size: float) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func pixel_to_cell(pixel: Vector2, origin: Vector2, cell_size: float) -> Vector2i:
	return Vector2i(floori((pixel.x - origin.x) / cell_size), floori((pixel.y - origin.y) / cell_size))


func sailing_paths(
	start: Vector2i,
	facing: int,
	max_steps: int,
	can_turn: bool,
	blocked: Dictionary,
	bounds: Rect2i
) -> Array:
	var result: Array = []
	var seen := {}
	var normalized_facing := posmod(facing, DIRECTIONS.size())
	_append_course(result, seen, start, [normalized_facing], max_steps, blocked, bounds)
	_append_reverse(result, seen, start, normalized_facing, blocked, bounds)
	if not can_turn:
		return result
	for turn_delta in [-1, 1]:
		var turned: int = posmod(normalized_facing + turn_delta, DIRECTIONS.size())
		_append_course(result, seen, start, [turned], max_steps, blocked, bounds)
		if max_steps >= 2:
			_append_exact_path(result, seen, start, [normalized_facing, turned], blocked, bounds)
	return result


func _append_reverse(
	result: Array,
	seen: Dictionary,
	start: Vector2i,
	facing: int,
	blocked: Dictionary,
	bounds: Rect2i
) -> void:
	var stern_cell: Vector2i = start - DIRECTIONS[facing]
	if not bounds.has_point(stern_cell) or blocked.has(stern_cell):
		return
	_append_path(result, seen, [stern_cell], facing, true)


func _append_course(
	result: Array,
	seen: Dictionary,
	start: Vector2i,
	directions: Array,
	max_steps: int,
	blocked: Dictionary,
	bounds: Rect2i
) -> void:
	var cells: Array[Vector2i] = []
	var cursor := start
	var direction: int = directions[0]
	for _step in max_steps:
		cursor += DIRECTIONS[direction]
		if not bounds.has_point(cursor) or blocked.has(cursor):
			break
		cells.append(cursor)
		_append_path(result, seen, cells, direction)


func _append_exact_path(
	result: Array,
	seen: Dictionary,
	start: Vector2i,
	directions: Array,
	blocked: Dictionary,
	bounds: Rect2i
) -> void:
	var cells: Array[Vector2i] = []
	var cursor := start
	for direction_value in directions:
		var direction: int = direction_value
		cursor += DIRECTIONS[direction]
		if not bounds.has_point(cursor) or blocked.has(cursor):
			return
		cells.append(cursor)
	_append_path(result, seen, cells, int(directions[-1]))


func _append_path(result: Array, seen: Dictionary, cells: Array[Vector2i], facing: int, reverse: bool = false) -> void:
	var key := "%s:%s:%s" % [cells, facing, reverse]
	if seen.has(key):
		return
	seen[key] = true
	var path := {"cells": cells.duplicate(), "facing": facing}
	if reverse:
		path["reverse"] = true
	result.append(path)
