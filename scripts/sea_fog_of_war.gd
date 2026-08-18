class_name SeaFogOfWar
extends Node2D

signal state_changed

const STATE_VERSION := 2
const LEGACY_STATE_VERSION := 1
const LEGACY_CELL_SIZE := 16.0
const CELL_SIZE := 8.0
const VISUAL_FOG_CELL_WORLD_SIZE := 224.0
const NAVAL_FOG_CELL_SIZE := 26.0
const NAVAL_FOG_STAMP_ALPHA := 0.38
const WORLD_FOG_Z_INDEX := 40
const VIEW_EDGE_FOG_INSET := 48.0
const REVEAL_UPDATE_DISTANCE := 2.0
const WORLD_FOG_SHADER := preload("res://shaders/sea_world_fog_edge.gdshader")
const EXPLORATION_FOG_MIST_TEXTURE := preload("res://assets/naval/ui/fog/white_ink_mist_v1.png")
const SEA_CONCEALMENT_TEXTURE := preload("res://assets/textures/water/sea_ink_pixel_seamless_v2.png")

var _world_size := Vector2.ONE
var _grid_size := Vector2i.ONE
var _cell_world_size := Vector2.ONE
var _camera: Camera2D
var _revealed_bits := PackedByteArray()
var _fog_image: Image
var _fog_texture: ImageTexture
var _fog_stamp_image: Image
var _fog_stamp_texture: ImageTexture
var _visual_fog_grid_size := Vector2i.ONE
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
	_build_fog_stamp_texture()
	_build_world_overlay()


func reveal_at(world_position: Vector2, immediate := false) -> bool:
	if _fog_image == null or _camera == null:
		return false
	if world_position.distance_squared_to(_last_reveal_position) < pow(REVEAL_UPDATE_DISTANCE, 2.0):
		return false
	_last_reveal_position = world_position
	var reveal_half_size := _get_camera_reveal_half_size()
	return _reveal_world_rect(world_position - reveal_half_size, world_position + reveal_half_size, immediate)


func _reveal_world_rect(minimum_world: Vector2, maximum_world: Vector2, immediate := false) -> bool:
	var minimum := _world_to_cell(minimum_world)
	var maximum := _world_to_cell(maximum_world)
	var changed := false
	for cell_y in range(minimum.y, maximum.y + 1):
		for cell_x in range(minimum.x, maximum.x + 1):
			var cell_index := cell_y * _grid_size.x + cell_x
			if _set_revealed(cell_index):
				_queue_reveal_visual(cell_x, cell_y, cell_index, immediate)
				changed = true
	_commit_reveal(changed, immediate)
	return changed


func reveal_camera_view() -> bool:
	if _camera == null or not _camera.is_inside_tree():
		return false
	var camera_center := to_local(_camera.get_screen_center_position())
	var camera_target := to_local(_camera.global_position)
	var half_vision := get_vision_world_size() * 0.5
	var reveal_half_size := _get_camera_reveal_half_size()
	var minimum_valid_center := Vector2(_camera.limit_left, _camera.limit_top) + half_vision
	var maximum_valid_center := Vector2(_camera.limit_right, _camera.limit_bottom) - half_vision
	if camera_center.x < minimum_valid_center.x - _cell_world_size.x or camera_center.y < minimum_valid_center.y - _cell_world_size.y or camera_center.x > maximum_valid_center.x + _cell_world_size.x or camera_center.y > maximum_valid_center.y + _cell_world_size.y:
		return false
	var movement_threshold_squared := pow(REVEAL_UPDATE_DISTANCE, 2.0)
	if camera_center.distance_squared_to(_last_camera_center) < movement_threshold_squared and camera_target.distance_squared_to(_last_camera_target) < movement_threshold_squared:
		return false
	_last_camera_center = camera_center
	_last_camera_target = camera_target
	var minimum_center := Vector2(minf(camera_center.x, camera_target.x), minf(camera_center.y, camera_target.y))
	var maximum_center := Vector2(maxf(camera_center.x, camera_target.x), maxf(camera_center.y, camera_target.y))
	return _reveal_world_rect(minimum_center - reveal_half_size, maximum_center + reveal_half_size)


func reveal_polygon(world_polygon: PackedVector2Array, immediate := false) -> bool:
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
						_queue_reveal_visual(padded_x, padded_y, cell_index, immediate)
						changed = true
	_commit_reveal(changed, immediate)
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


func get_view_edge_fog_inset() -> float:
	return VIEW_EDGE_FOG_INSET


func get_pending_reveal_fade_count_for_test() -> int:
	return 0


func _get_camera_reveal_half_size() -> Vector2:
	var half_vision := get_vision_world_size() * 0.5
	return Vector2(
		maxf(_cell_world_size.x, half_vision.x - VIEW_EDGE_FOG_INSET),
		maxf(_cell_world_size.y, half_vision.y - VIEW_EDGE_FOG_INSET)
	)


func get_fog_texture() -> Texture2D:
	return _fog_texture


func get_fog_stamp_texture() -> Texture2D:
	return _fog_stamp_texture


func get_visual_fog_grid_size() -> Vector2i:
	return _visual_fog_grid_size


func get_visual_fog_cell_world_size() -> float:
	return VISUAL_FOG_CELL_WORLD_SIZE


func get_fog_stamp_stats_for_test() -> Dictionary:
	var transparent_count := 0
	var light_count := 0
	var dense_count := 0
	var maximum_alpha := 0.0
	if _fog_stamp_image == null:
		return {}
	for cell_y in range(_fog_stamp_image.get_height()):
		for cell_x in range(_fog_stamp_image.get_width()):
			var alpha := _fog_stamp_image.get_pixel(cell_x, cell_y).a
			maximum_alpha = maxf(maximum_alpha, alpha)
			if alpha < 0.04:
				transparent_count += 1
			elif alpha < 0.34:
				light_count += 1
			else:
				dense_count += 1
	return {
		"transparent_count": transparent_count,
		"light_count": light_count,
		"dense_count": dense_count,
		"maximum_alpha": maximum_alpha,
	}


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


func _build_fog_stamp_texture() -> void:
	_visual_fog_grid_size = Vector2i(
		maxi(1, ceili(_world_size.x / VISUAL_FOG_CELL_WORLD_SIZE)),
		maxi(1, ceili(_world_size.y / VISUAL_FOG_CELL_WORLD_SIZE))
	)
	_fog_stamp_image = Image.create(_grid_size.x, _grid_size.y, false, Image.FORMAT_RGBA8)
	_fog_stamp_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var source_image := EXPLORATION_FOG_MIST_TEXTURE.get_image()
	if source_image == null or source_image.is_empty():
		_fog_stamp_texture = ImageTexture.create_from_image(_fog_stamp_image)
		return

	var pixels_per_visual_cell := Vector2(_grid_size) / Vector2(_visual_fog_grid_size)
	var stamp_variants: Array[Image] = []
	var edge_stamp_variants: Array[Image] = []
	for size_index in range(6):
		var stamp_width := pixels_per_visual_cell.x * (4.4 + float(size_index) * 0.22)
		var stamp_size := Vector2i(
			maxi(1, roundi(stamp_width)),
			maxi(1, roundi(stamp_width * 0.6875))
		)
		stamp_variants.append(_make_fog_stamp_variant(source_image, stamp_size, NAVAL_FOG_STAMP_ALPHA))
		edge_stamp_variants.append(_make_fog_stamp_variant(source_image, stamp_size, NAVAL_FOG_STAMP_ALPHA * 0.76))

	for cell_x in range(_visual_fog_grid_size.x):
		for cell_y in range(_visual_fog_grid_size.y):
			var neighbors := _visual_fog_neighbor_count(Vector2i(cell_x, cell_y))
			var seed := _fog_hash(cell_x, cell_y, 53)
			if seed % 4 != 0 or neighbors < 3:
				continue
			var variant_index := seed % 6
			var stamp := stamp_variants[variant_index] if neighbors >= 7 else edge_stamp_variants[variant_index]
			var center := (Vector2(cell_x, cell_y) + Vector2(0.5, 0.5)) * pixels_per_visual_cell
			var battle_offset := Vector2(float(seed % 17) - 8.0, float((seed / 19) % 13) - 6.0)
			var scaled_offset := battle_offset * pixels_per_visual_cell / NAVAL_FOG_CELL_SIZE
			var destination := Vector2i((center + scaled_offset - Vector2(stamp.get_size()) * 0.5).round())
			_fog_stamp_image.blend_rect(stamp, Rect2i(Vector2i.ZERO, stamp.get_size()), destination)
	_fog_stamp_texture = ImageTexture.create_from_image(_fog_stamp_image)


func _make_fog_stamp_variant(source_image: Image, stamp_size: Vector2i, alpha_multiplier: float) -> Image:
	var stamp := source_image.duplicate() as Image
	stamp.resize(stamp_size.x, stamp_size.y, Image.INTERPOLATE_LANCZOS)
	for pixel_y in range(stamp.get_height()):
		for pixel_x in range(stamp.get_width()):
			var color := stamp.get_pixel(pixel_x, pixel_y)
			color.a *= alpha_multiplier
			stamp.set_pixel(pixel_x, pixel_y, color)
	return stamp


func _visual_fog_neighbor_count(center: Vector2i) -> int:
	var count := 0
	for offset_x in range(-1, 2):
		for offset_y in range(-1, 2):
			var neighbor := center + Vector2i(offset_x, offset_y)
			if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < _visual_fog_grid_size.x and neighbor.y < _visual_fog_grid_size.y:
				count += 1
	return count


func _fog_hash(cell_x: int, cell_y: int, salt: int) -> int:
	return ((cell_x * 73856093) ^ (cell_y * 19349663) ^ (salt * 83492791)) & 0x7fffffff


func _build_world_overlay() -> void:
	_world_overlay = Sprite2D.new()
	_world_overlay.name = "WorldFogOverlay"
	_world_overlay.centered = false
	_world_overlay.texture = _fog_texture
	_world_overlay.position = Vector2.ZERO
	_world_overlay.scale = _world_size / Vector2(_grid_size)
	_world_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_world_overlay.z_index = WORLD_FOG_Z_INDEX
	var fog_material := ShaderMaterial.new()
	fog_material.shader = WORLD_FOG_SHADER
	fog_material.set_shader_parameter("mist_texture", _fog_stamp_texture)
	fog_material.set_shader_parameter("fog_tint", Color(0.93, 0.97, 0.95, 1.0))
	fog_material.set_shader_parameter("concealment_texture", SEA_CONCEALMENT_TEXTURE)
	fog_material.set_shader_parameter("concealment_tint", Color(0.05, 0.56, 0.68, 1.0))
	fog_material.set_shader_parameter("concealment_uv_scale", _world_size * Vector2(0.00082, 0.00105))
	fog_material.set_shader_parameter("feather_texels", 3.4)
	fog_material.set_shader_parameter("edge_warp_texels", 0.8)
	fog_material.set_shader_parameter("edge_irregularity", 0.34)
	fog_material.set_shader_parameter("alpha_dither", 0.012)
	fog_material.set_shader_parameter("fog_opacity", 1.0)
	_world_overlay.material = fog_material
	add_child(_world_overlay)


func _restore_state(saved_state: Dictionary) -> void:
	var state_version := int(saved_state.get("version", 0))
	if state_version == LEGACY_STATE_VERSION and is_equal_approx(float(saved_state.get("cell_size", 0.0)), LEGACY_CELL_SIZE):
		_restore_legacy_state(saved_state)
		return
	if state_version != STATE_VERSION:
		return
	if int(saved_state.get("grid_width", 0)) != _grid_size.x or int(saved_state.get("grid_height", 0)) != _grid_size.y:
		return
	if not is_equal_approx(float(saved_state.get("cell_size", 0.0)), CELL_SIZE):
		return
	var restored_bits := Marshalls.base64_to_raw(str(saved_state.get("revealed_bits", "")))
	if restored_bits.size() != _revealed_bits.size():
		return
	_revealed_bits = restored_bits


func _restore_legacy_state(saved_state: Dictionary) -> void:
	var legacy_grid_size := Vector2i(
		maxi(1, ceili(_world_size.x / LEGACY_CELL_SIZE)),
		maxi(1, ceili(_world_size.y / LEGACY_CELL_SIZE))
	)
	if int(saved_state.get("grid_width", 0)) != legacy_grid_size.x or int(saved_state.get("grid_height", 0)) != legacy_grid_size.y:
		return
	var legacy_bits := Marshalls.base64_to_raw(str(saved_state.get("revealed_bits", "")))
	if legacy_bits.size() != ceili(float(legacy_grid_size.x * legacy_grid_size.y) / 8.0):
		return
	for cell_y in _grid_size.y:
		for cell_x in _grid_size.x:
			var world_center := (Vector2(cell_x, cell_y) + Vector2(0.5, 0.5)) * _cell_world_size
			var legacy_cell := Vector2i(
				clampi(floori(world_center.x / LEGACY_CELL_SIZE), 0, legacy_grid_size.x - 1),
				clampi(floori(world_center.y / LEGACY_CELL_SIZE), 0, legacy_grid_size.y - 1)
			)
			var legacy_index := legacy_cell.y * legacy_grid_size.x + legacy_cell.x
			if _packed_bit_is_set(legacy_bits, legacy_index):
				_set_revealed(cell_y * _grid_size.x + cell_x)


func _packed_bit_is_set(bits: PackedByteArray, bit_index: int) -> bool:
	var byte_index := bit_index >> 3
	var bit_mask := 1 << (bit_index & 7)
	return (bits[byte_index] & bit_mask) != 0


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


func _queue_reveal_visual(cell_x: int, cell_y: int, _cell_index: int, _immediate: bool) -> void:
	_fog_image.set_pixel(cell_x, cell_y, Color(0, 0, 0, 0))


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


func _commit_reveal(changed: bool, _immediate := false) -> void:
	if not changed:
		return
	_fog_texture.update(_fog_image)
	state_changed.emit()
