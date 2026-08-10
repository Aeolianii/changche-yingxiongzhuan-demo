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
	var minimum := _world_to_cell(world_position - half_vision)
	var maximum := _world_to_cell(world_position + half_vision)
	var changed := false
	for cell_y in range(minimum.y, maximum.y + 1):
		for cell_x in range(minimum.x, maximum.x + 1):
			var cell_center := Vector2(
				(float(cell_x) + 0.5) * _cell_world_size.x,
				(float(cell_y) + 0.5) * _cell_world_size.y
			)
			var offset := cell_center - world_position
			var normalized_distance := pow(offset.x / half_vision.x, 2.0) + pow(offset.y / half_vision.y, 2.0)
			if normalized_distance > 1.0:
				continue
			var cell_index := cell_y * _grid_size.x + cell_x
			if _set_revealed(cell_index):
				_fog_image.set_pixel(cell_x, cell_y, Color(0, 0, 0, 0))
				changed = true
	if changed:
		_fog_texture.update(_fog_image)
		state_changed.emit()
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
