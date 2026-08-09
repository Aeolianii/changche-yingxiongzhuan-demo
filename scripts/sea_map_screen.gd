extends Control

signal close_requested

const SEA_MAP_TEXTURE := preload("res://assets/backgrounds/sea_overworld/guangdong_sea_map_v2_hd.png")
const MAP_CHUNK_BLEND_SHADER := preload("res://shaders/map_chunk_blend.gdshader")
const SEA_MAP_SCROLL_FRAME := preload("res://assets/ui/sea_overworld/sea_map_scroll_frame_v1.png")

const GOLD := Color(0.73, 0.59, 0.32, 1.0)
const GOLD_BRIGHT := Color(0.96, 0.83, 0.52, 1.0)
const TEXT_LIGHT := Color(0.96, 0.91, 0.78, 1.0)
const MAP_VIEW_SIZE := Vector2(870, 510)

var _player: Node2D
var _world_size := Vector2.ONE
var _map_viewport: Control
var _map_texture_layer: Control
var _location_layer: Control
var _player_marker: Control
var _player_name_label: Label
var _map_content_rect := Rect2(Vector2.ZERO, MAP_VIEW_SIZE)


func _ready() -> void:
	z_index = 90
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()
	hide()


func configure(player_node: Node2D, world_size: Vector2, locations: Array, map_chunks: Array = []) -> void:
	_player = player_node
	_world_size = Vector2(maxf(world_size.x, 1.0), maxf(world_size.y, 1.0))
	_refresh_map_content_rect()
	_rebuild_map_chunks(map_chunks)
	for child in _location_layer.get_children():
		child.free()
	for location_data in locations:
		var location_label := _make_label("【%s】" % str(location_data.get("name", "未知地点")), 18, GOLD_BRIGHT)
		location_label.name = "LocationLabel"
		location_label.size = Vector2(180, 34)
		location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		location_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		location_label.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.018, 0.98))
		location_label.add_theme_constant_override("outline_size", 5)
		location_label.set_meta("world_position", location_data.get("position", Vector2.ZERO))
		_location_layer.add_child(location_label)
	_player_name_label.text = "当前位置"
	_refresh_markers()


func show_screen() -> void:
	_refresh_markers()
	show()


func _build_interface() -> void:
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.015, 0.025, 0.025, 0.78)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	var panel := Panel.new()
	panel.name = "MapPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -640.0
	panel.offset_top = -426.5
	panel.offset_right = 640.0
	panel.offset_bottom = 426.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(panel)

	var scroll_frame := TextureRect.new()
	scroll_frame.name = "GeneratedScrollFrame"
	scroll_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_frame.texture = SEA_MAP_SCROLL_FRAME
	scroll_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scroll_frame.stretch_mode = TextureRect.STRETCH_SCALE
	scroll_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scroll_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(scroll_frame)

	var title := _make_label("岭 南 海 图", 27, TEXT_LIGHT)
	title.name = "Title"
	title.position = Vector2(460, 92)
	title.size = Vector2(360, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.02, 1.0))
	title.add_theme_constant_override("outline_size", 5)
	panel.add_child(title)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.position = Vector2(1080, 84)
	close_button.size = Vector2(100, 48)
	close_button.text = "返回"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.add_theme_color_override("font_color", TEXT_LIGHT)
	close_button.add_theme_stylebox_override("normal", _panel_style(Color(0.05, 0.08, 0.075, 0.96), GOLD, 2, 4))
	close_button.add_theme_stylebox_override("hover", _panel_style(Color(0.12, 0.22, 0.19, 0.98), GOLD_BRIGHT, 2, 4))
	close_button.add_theme_stylebox_override("pressed", _panel_style(Color(0.03, 0.05, 0.05, 1.0), GOLD_BRIGHT, 2, 4))
	close_button.pressed.connect(close_requested.emit)
	panel.add_child(close_button)

	_map_viewport = Panel.new()
	_map_viewport.name = "MapViewport"
	_map_viewport.position = Vector2(205, 175)
	_map_viewport.size = MAP_VIEW_SIZE
	_map_viewport.clip_contents = true
	_map_viewport.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_viewport.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.035, 0.035, 1.0), GOLD, 2, 2))
	panel.add_child(_map_viewport)

	_map_texture_layer = Control.new()
	_map_texture_layer.name = "MapTextureLayer"
	_map_texture_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_texture_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_viewport.add_child(_map_texture_layer)

	var wash := ColorRect.new()
	wash.name = "InkWash"
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wash.color = Color(0.02, 0.055, 0.05, 0.08)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_viewport.add_child(wash)

	_location_layer = Control.new()
	_location_layer.name = "MapLocationLayer"
	_location_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_location_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_viewport.add_child(_location_layer)

	_player_marker = Control.new()
	_player_marker.name = "PlayerMarker"
	_player_marker.size = Vector2(210, 40)
	_player_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_viewport.add_child(_player_marker)

	var marker_glyph := _make_label("◆", 27, Color(0.88, 0.2, 0.12, 1.0))
	marker_glyph.name = "MarkerGlyph"
	marker_glyph.position = Vector2(-17, -18)
	marker_glyph.size = Vector2(36, 36)
	marker_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker_glyph.add_theme_color_override("font_outline_color", Color(1.0, 0.82, 0.36, 1.0))
	marker_glyph.add_theme_constant_override("outline_size", 3)
	_player_marker.add_child(marker_glyph)

	_player_name_label = _make_label("当前位置", 17, TEXT_LIGHT)
	_player_name_label.name = "PlayerName"
	_player_name_label.position = Vector2(18, -13)
	_player_name_label.size = Vector2(190, 30)
	_player_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_player_name_label.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.018, 1.0))
	_player_name_label.add_theme_constant_override("outline_size", 5)
	_player_marker.add_child(_player_name_label)

func _refresh_markers() -> void:
	if not is_instance_valid(_location_layer):
		return
	for location_label in _location_layer.get_children():
		var world_position: Vector2 = location_label.get_meta("world_position", Vector2.ZERO)
		location_label.position = _map_position(world_position) - location_label.size * 0.5
	if is_instance_valid(_player) and is_instance_valid(_player_marker):
		var marker_position := _map_position(_player.global_position)
		_player_marker.position = Vector2(
			clampf(marker_position.x, 20.0, MAP_VIEW_SIZE.x - 208.0),
			clampf(marker_position.y, 22.0, MAP_VIEW_SIZE.y - 22.0)
		)


func _map_position(world_position: Vector2) -> Vector2:
	var normalized := Vector2(
		clampf(world_position.x / _world_size.x, 0.0, 1.0),
		clampf(world_position.y / _world_size.y, 0.0, 1.0)
	)
	return _map_content_rect.position + normalized * _map_content_rect.size


func _refresh_map_content_rect() -> void:
	var content_scale := minf(MAP_VIEW_SIZE.x / _world_size.x, MAP_VIEW_SIZE.y / _world_size.y)
	var content_size := _world_size * content_scale
	_map_content_rect = Rect2((MAP_VIEW_SIZE - content_size) * 0.5, content_size)


func _rebuild_map_chunks(map_chunks: Array) -> void:
	for child in _map_texture_layer.get_children():
		child.free()
	var chunks := map_chunks
	if chunks.is_empty():
		chunks = [{"texture": SEA_MAP_TEXTURE, "world_rect": Rect2(Vector2.ZERO, _world_size)}]
	var content_scale := _map_content_rect.size.x / _world_size.x
	for index in range(chunks.size()):
		var chunk_data: Dictionary = chunks[index]
		var chunk_texture := chunk_data.get("texture") as Texture2D
		var chunk_rect: Rect2 = chunk_data.get("world_rect", Rect2(Vector2.ZERO, _world_size))
		if chunk_texture == null:
			continue
		var map_texture := TextureRect.new()
		map_texture.name = "MapTexture" if index == 0 else "MapTexture%d" % (index + 1)
		map_texture.position = _map_content_rect.position + chunk_rect.position * content_scale
		map_texture.size = chunk_rect.size * content_scale
		map_texture.texture = chunk_texture
		map_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		map_texture.stretch_mode = TextureRect.STRETCH_SCALE
		map_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		map_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if index > 0:
			var blend_material := ShaderMaterial.new()
			blend_material.shader = MAP_CHUNK_BLEND_SHADER
			blend_material.set_shader_parameter("fade_from_left", bool(chunk_data.get("fade_from_left", true)))
			blend_material.set_shader_parameter("fade_from_top", bool(chunk_data.get("fade_from_top", false)))
			map_texture.material = blend_material
		_map_texture_layer.add_child(map_texture)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ESCAPE or key_event.keycode == KEY_E):
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _make_label(text_value: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel_style(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.48)
	style.shadow_size = 7
	style.shadow_offset = Vector2(2, 3)
	return style
