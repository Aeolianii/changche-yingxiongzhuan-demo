extends SceneTree

const KEY_START := 0.18
const KEY_END := 0.62
const INK_CELL_SIZE := 4
const BLUR_RADIUS := 3
const INK_COLOR := Color(0.075, 0.27, 0.33, 1.0)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Usage: chroma_key_texture.gd -- <input.png> <output.png>")
		quit(2)
		return

	var source := Image.load_from_file(args[0])
	if source.is_empty():
		push_error("Could not load source image: %s" % args[0])
		quit(3)
		return

	var output := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			var color := source.get_pixel(x, y)
			# Pure magenta has far more red/blue than green; the teal ink does not.
			var key_likeness := minf(color.r, color.b) - color.g
			var alpha := 1.0 - clampf(
				inverse_lerp(KEY_START, KEY_END, key_likeness),
				0.0,
				1.0
			)
			alpha = alpha * alpha * (3.0 - 2.0 * alpha)
			if alpha <= 0.0:
				output.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			else:
				# Despill only the red channel so edge pixels remain blue-gray instead of pink.
				color.r = minf(color.r, color.g * 1.05)
				output.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))

	output = _flatten_to_ink_shadow(output)
	var error := output.save_png(args[1])
	if error != OK:
		push_error("Could not save chroma-keyed image: %s" % error_string(error))
		quit(4)
		return
	print("Saved transparent texture: %s" % args[1])
	quit()


func _flatten_to_ink_shadow(source: Image) -> Image:
	var mask_width := ceili(float(source.get_width()) / INK_CELL_SIZE)
	var mask_height := ceili(float(source.get_height()) / INK_CELL_SIZE)
	var mask := Image.create(mask_width, mask_height, false, Image.FORMAT_RF)
	for mask_y in mask_height:
		for mask_x in mask_width:
			var alpha_sum := 0.0
			var sample_count := 0
			for offset_y in INK_CELL_SIZE:
				for offset_x in INK_CELL_SIZE:
					var source_x := mask_x * INK_CELL_SIZE + offset_x
					var source_y := mask_y * INK_CELL_SIZE + offset_y
					if source_x < source.get_width() and source_y < source.get_height():
						alpha_sum += source.get_pixel(source_x, source_y).a
						sample_count += 1
			mask.set_pixel(mask_x, mask_y, Color(alpha_sum / maxf(sample_count, 1), 0.0, 0.0, 1.0))

	mask = _blur_mask(_blur_mask(mask, true), false)
	var flattened := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			var cell_x := mini(x / INK_CELL_SIZE, mask_width - 1)
			var cell_y := mini(y / INK_CELL_SIZE, mask_height - 1)
			var coverage := mask.get_pixel(cell_x, cell_y).r
			var noise := fposmod(sin(float(cell_x * 127 + cell_y * 311)) * 43758.5453, 1.0)
			var edge_breakup := lerpf(0.68, 1.0, noise) if coverage < 0.72 else lerpf(0.88, 1.0, noise)
			var alpha := pow(coverage, 0.82) * 0.72 * edge_breakup
			if alpha < 0.018:
				flattened.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			else:
				var tone := lerpf(0.82, 1.14, noise)
				flattened.set_pixel(x, y, Color(INK_COLOR.r * tone, INK_COLOR.g * tone, INK_COLOR.b * tone, alpha))
	return flattened


func _blur_mask(source: Image, horizontal: bool) -> Image:
	var blurred := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RF)
	for y in source.get_height():
		for x in source.get_width():
			var total := 0.0
			var count := 0
			for offset in range(-BLUR_RADIUS, BLUR_RADIUS + 1):
				var sample_x := clampi(x + offset if horizontal else x, 0, source.get_width() - 1)
				var sample_y := clampi(y if horizontal else y + offset, 0, source.get_height() - 1)
				total += source.get_pixel(sample_x, sample_y).r
				count += 1
			blurred.set_pixel(x, y, Color(total / count, 0.0, 0.0, 1.0))
	return blurred
