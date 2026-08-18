extends SceneTree


func _init() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		push_error("Usage: make_seamless_texture.gd -- <input.png> <output.png>")
		quit(1)
		return

	var source_path: String = arguments[0]
	var output_path: String = arguments[1]
	var source := Image.load_from_file(source_path)
	if source.is_empty():
		push_error("Unable to load source texture: %s" % source_path)
		quit(1)
		return

	var width := source.get_width()
	var height := source.get_height()
	var half_width := width / 2
	var half_height := height / 2
	var result := Image.create(width, height, false, source.get_format())

	for y in range(height):
		var vertical_weight := sin(PI * float(y) / float(height - 1))
		vertical_weight *= vertical_weight
		var shifted_y := (y + half_height) % height
		for x in range(width):
			var horizontal_weight := sin(PI * float(x) / float(width - 1))
			horizontal_weight *= horizontal_weight
			var shifted_x := (x + half_width) % width
			var original := source.get_pixel(x, y)
			var shifted_horizontal := source.get_pixel(shifted_x, y)
			var shifted_vertical := source.get_pixel(x, shifted_y)
			var shifted_both := source.get_pixel(shifted_x, shifted_y)
			var upper := shifted_horizontal.lerp(original, horizontal_weight)
			var lower := shifted_both.lerp(shifted_vertical, horizontal_weight)
			result.set_pixel(x, y, lower.lerp(upper, vertical_weight))

	# Make the stored border pixels identical as well as visually continuous.
	for y in range(height):
		result.set_pixel(width - 1, y, result.get_pixel(0, y))
	for x in range(width):
		result.set_pixel(x, height - 1, result.get_pixel(x, 0))

	var save_error := result.save_png(output_path)
	if save_error != OK:
		push_error("Unable to save seamless texture: %s" % error_string(save_error))
		quit(1)
		return

	print("Saved seamless texture: %s" % output_path)
	quit()
