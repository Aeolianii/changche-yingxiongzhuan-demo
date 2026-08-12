class_name SeaFogOfWar
extends Node2D

signal state_changed

const STATE_VERSION := 1
const CELL_SIZE := 16.0
const WORLD_FOG_Z_INDEX := 40

var _world_size := Vector2.ONE
var _grid_size := Vector2i.ONE
var _cell_world_size := Vector2.ONE
var _camera: Camera2D
var _revealed_bits := PackedByteArray()
var _fog_image: Image
var _fog_texture: ImageTexture
var _world_overlay: Sprite2D
var _last_reveal_position := Vector2(INF, INF)
var _last_camera_center := Vector2(INF, INF)
var _last_camera_target := Vector2(INF, INF)


func setup(world_size: Vector2, camera_node: Camera2D, saved_state: Dictionary = {}) -> void:
	_world_size = Vector2(maxf(world_size.x, 1.0), maxf(world_size.y, 1.0))
	_camera = camera_node
	_grid_size = Vector2i(
		maxi(1, ceili(_world_size.x / CELL_SIZE)),
		maxi(1, ceili(_world_size.y / CELL_SIZE))
	)
	_cell_world_size = _world_size / Vector2(_grid_size)
	_revealed_bits.resize(ceili(float(_grid_size.x * _grid_size.y) / 8.0))
	_revealed_bits.fill(0)
	_restore_state(saved_state)
	_build_texture()
	_build_world_overlay()


func reveal_at(world_position: Vector2) -> bool:
	if _fog_image == null or _camera == null:
		return false
	if world_position.distance_squared_to(_last_reveal_position) < pow(CELL_SIZE * 0.5, 2.0):
		return false
	_last_reveal_position = world_position
	var vision_size := get_vision_world_size()
	var half_vision := vision_size * 0.5
	return _reveal_world_rect(world_position - half_vision - _cell_world_size, world_position + half_vision + _cell_world_size)


func _reveal_world_rect(minimum_world: Vector2, maximum_world: Vector2) -> bool:
	var minimum := _world_to_cell(minimum_world)
	var maximum := _world_to_cell(maximum_world)
	var changed := false
	for cell_y in range(minimum.y, maximum.y + 1):
		for cell_x in range(minimum.x, maximum.x + 1):
			var cell_index := cell_y * _grid_size.x + cell_x
			if _set_revealed(cell_index):
				_fog_image.set_pixel(cell_x, cell_y, Color(0, 0, 0, 0))
				changed = true
	_commit_reveal(changed)
	return changed


func reveal_camera_view() -> bool:
	if _camera == null or not _camera.is_inside_tree():
		return false
	var camera_center := to_local(_camera.get_screen_center_position())
	var camera_target := to_local(_camera.global_position)
	var half_vision := get_vision_world_size() * 0.5
	var minimum_valid_center := Vector2(_camera.limit_left, _camera.limit_top) + half_vision
	var maximum_valid_center := Vector2(_camera.limit_right, _camera.limit_bottom) - half_vision
	if camera_center.x < minimum_valid_center.x - _cell_world_size.x or camera_center.y < minimum_valid_center.y - _cell_world_size.y or camera_center.x > maximum_valid_center.x + _cell_world_size.x or camera_center.y > maximum_valid_center.y + _cell_world_size.y:
		return false
	var movement_threshold_squared := pow(CELL_SIZE * 0.5, 2.0)
	if camera_center.distance_squared_to(_last_camera_center) < movement_threshold_squared and camera_target.distance_squared_to(_last_camera_target) < movement_threshold_squared:
		return false
	_last_camera_center = camera_center
	_last_camera_target = camera_target
	var minimum_center := Vector2(minf(camera_center.x, camera_target.x), minf(camera_center.y, camera_target.y))
	var maximum_center := Vector2(maxf(camera_center.x, camera_target.x), maxf(camera_center.y, camera_target.y))
	return _reveal_world_rect(minimum_center - half_vision - _cell_world_size, maximum_center + half_vision + _cell_world_size)


func reveal_polygon(world_polygon: PackedVector2Array) -> bool:
	if _fog_image == null or world_polygon.size() < 3:
		return false
	var bounds := Rect2(world_polygon[0], Vector2.ZERO)
	for world_point in world_polygon:
		bounds = bounds.expand(world_point)
	var minimum := _world_to_cell(bounds.position)
	var maximum := _world_to_cell(bounds.end)
	var changed := false
	for cell_y in range(minimum.y, maximum.y + 1):
		for cell_x in range(minimum.x, maximum.x + 1):
			if not _cell_overlaps_polygon(Vector2i(cell_x, cell_y), world_polygon):
				continue
			for padded_y in range(maxi(0, cell_y - 1), mini(_grid_size.y - 1, cell_y + 1) + 1):
				for padded_x in range(maxi(0, cell_x - 1), mini(_grid_size.x - 1, cell_x + 1) + 1):
					var cell_index := padded_y * _grid_size.x + padded_x
					if _set_revealed(cell_index):
						_fog_image.set_pixel(padded_x, padded_y, Color(0, 0, 0, 0))
						changed = true
	_commit_reveal(changed)
	return changed


func is_world_position_revealed(world_position: Vector2) -> bool:
	if world_position.x < 0.0 or world_position.y < 0.0 or world_position.x > _world_size.x or world_position.y > _world_size.y:
		return false
	var cell := _world_to_cell(world_position)
	return _is_revealed(cell.y * _grid_size.x + cell.x)


func get_vision_world_size() -> Vector2:
	if _camera == null or _camera.get_viewport() == null:
		return Vector2.ZERO
	var viewport_size := _camera.get_viewport().get_visible_rect().size
	var camera_zoom := Vector2(maxf(absf(_camera.zoom.x), 0.001), maxf(absf(_camera.zoom.y), 0.001))
	return viewport_size / camera_zoom


func get_fog_texture() -> Texture2D:
	return _fog_texture


func get_explored_ratio() -> float:
	var revealed_count := 0
	for cell_index in range(_grid_size.x * _grid_size.y):
		if _is_revealed(cell_index):
			revealed_count += 1
	return float(revealed_count) / float(_grid_size.x * _grid_size.y)


func serialize_state() -> Dictionary:
	return {
		"version": STATE_VERSION,
		"cell_size": CELL_SIZE,
		"grid_width": _grid_size.x,
		"grid_height": _grid_size.y,
		"revealed_bits": Marshalls.raw_to_base64(_revealed_bits),
	}


func _build_texture() -> void:
	_fog_image = Image.create(_grid_size.x, _grid_size.y, false, Image.FORMAT_RGBA8)
	_fog_image.fill(Color.BLACK)
	for cell_y in range(_grid_size.y):
		for cell_x in range(_grid_size.x):
			if _is_revealed(cell_y * _grid_size.x + cell_x):
				_fog_image.set_pixel(cell_x, cell_y, Color(0, 0, 0, 0))
	_fog_texture = ImageTexture.create_from_image(_fog_image)


func _build_world_overlay() -> void:
	_world_overlay = Sprite2D.new()
	_world_overlay.name = "WorldFogOverlay"
	_world_overlay.centered = false
	_world_overlay.texture = _fog_texture
	_world_overlay.position = Vector2.ZERO
	_world_overlay.scale = _world_size / Vector2(_grid_size)
	_world_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_world_overlay.z_index = WORLD_FOG_Z_INDEX
	add_child(_world_overlay)


func _restore_state(saved_state: Dictionary) -> void:
	if int(saved_state.get("version", 0)) != STATE_VERSION:
		return
	if int(saved_state.get("grid_width", 0)) != _grid_size.x or int(saved_state.get("grid_height", 0)) != _grid_size.y:
		return
	if not is_equal_approx(float(saved_state.get("cell_size", 0.0)), CELL_SIZE):
		return
	var restored_bits := Marshalls.base64_to_raw(str(saved_state.get("revealed_bits", "")))
	if restored_bits.size() != _revealed_bits.size():
		return
	_revealed_bits = restored_bits


func _world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(
		clampi(floori(world_position.x / _cell_world_size.x), 0, _grid_size.x - 1),
		clampi(floori(world_position.y / _cell_world_size.y), 0, _grid_size.y - 1)
	)


func _is_revealed(cell_index: int) -> bool:
	var byte_index := cell_index >> 3
	var bit_mask := 1 << (cell_index & 7)
	return (_revealed_bits[byte_index] & bit_mask) != 0


func _set_revealed(cell_index: int) -> bool:
	if _is_revealed(cell_index):
		return false
	var byte_index := cell_index >> 3
	var bit_mask := 1 << (cell_index & 7)
	_revealed_bits[byte_index] = _revealed_bits[byte_index] | bit_mask
	return true


func _cell_overlaps_polygon(cell: Vector2i, world_polygon: PackedVector2Array) -> bool:
	var cell_rect := Rect2(Vector2(cell) * _cell_world_size, _cell_world_size)
	var center := cell_rect.get_center()
	if Geometry2D.is_point_in_polygon(center, world_polygon):
		return true
	for corner in [cell_rect.position, Vector2(cell_rect.end.x, cell_rect.position.y), cell_rect.end, Vector2(cell_rect.position.x, cell_rect.end.y)]:
		if Geometry2D.is_point_in_polygon(corner, world_polygon):
			return true
	for polygon_point in world_polygon:
		if cell_rect.has_point(polygon_point):
			return true
	return false


func _commit_reveal(changed: bool) -> void:
	if not changed:
		return
	_fog_texture.update(_fog_image)
	state_changed.emit()
