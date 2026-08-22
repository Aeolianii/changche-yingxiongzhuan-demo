extends SceneTree

const SHIP_TYPES: Array[String] = ["transport", "frigate", "flagship"]
const DIRECTIONS: Array[String] = ["n", "e", "s", "w"]
const PREVIEW_PATH := "res://.godot/enemy_ship_directional_assets_preview.png"

var failures: Array[String] = []


func _initialize() -> void:
	_run_tests.call_deferred()


func _run_tests() -> void:
	var preview := _build_preview()
	root.add_child(preview)
	await process_frame
	await process_frame

	if DisplayServer.get_name() != "headless":
		var screenshot_error := root.get_texture().get_image().save_png(PREVIEW_PATH)
		_expect(screenshot_error == OK, "Could not save the enemy ship directional preview.")

	preview.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: enemy ship directional assets")
		quit(0)
	else:
		for failure in failures:
			push_error("FAIL: %s" % failure)
		quit(1)


func _build_preview() -> Control:
	var preview := Control.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.color = Color("26313b")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.add_child(backdrop)

	var grid := GridContainer.new()
	grid.columns = DIRECTIONS.size()
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 18)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	preview.add_child(grid)

	for ship_type in SHIP_TYPES:
		for direction in DIRECTIONS:
			grid.add_child(_build_asset_cell(ship_type, direction))
	return preview


func _build_asset_cell(ship_type: String, direction: String) -> Control:
	var path := "res://assets/naval/battle/ships/enemy_%s_%s.png" % [ship_type, direction]
	var texture := load(path) as Texture2D
	_expect(texture != null, "Missing runtime texture: %s" % path)

	var cell := ColorRect.new()
	cell.custom_minimum_size = Vector2(314, 270)
	cell.color = Color("303d49")

	var label := Label.new()
	label.text = "%s  %s" % [ship_type, direction.to_upper()]
	label.position = Vector2(10, 6)
	label.add_theme_color_override("font_color", Color("f2ddb0"))
	label.add_theme_font_size_override("font_size", 17)
	cell.add_child(label)

	if texture == null:
		return cell

	var horizontal := direction == "e" or direction == "w"
	_expect((texture.get_width() > texture.get_height()) == horizontal, "%s has the wrong cardinal aspect ratio." % path)

	var image := texture.get_image()
	_expect(image != null and not image.is_empty(), "%s could not expose imported pixels." % path)
	if image != null and not image.is_empty():
		var used := image.get_used_rect()
		_expect(used.has_area(), "%s has no visible pixels." % path)
		_expect(used.position.x >= 12 and used.position.y >= 12, "%s is missing its top/left transparent safety margin." % path)
		_expect(used.end.x <= image.get_width() - 12 and used.end.y <= image.get_height() - 12, "%s is missing its bottom/right transparent safety margin." % path)
		_expect(image.get_pixel(0, 0).a < 0.01, "%s must keep a transparent background." % path)

	var ship := TextureRect.new()
	ship.texture = texture
	ship.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ship.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ship.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ship.position = Vector2(8, 30)
	ship.size = Vector2(298, 232)
	cell.add_child(ship)
	return cell


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
