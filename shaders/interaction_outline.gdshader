shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.78, 0.24, 1.0);
uniform float outline_width : hint_range(0.0, 3.0, 1.0) = 1.0;

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;
}

void fragment() {
	// Godot has already multiplied the texture by the CanvasItem color here.
	// Sampling TEXTURE and multiplying COLOR again would square the sprite RGB.
	vec4 base_color = COLOR;
	if (base_color.a > 0.001) {
		COLOR = base_color;
	} else {
		vec2 pixel = TEXTURE_PIXEL_SIZE * outline_width;
		float nearby_alpha = 0.0;
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - vec2(0.0, pixel.y)).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + pixel).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV - pixel).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(pixel.x, -pixel.y)).a);
		nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-pixel.x, pixel.y)).a);
		COLOR = vec4(
			outline_color.rgb * vertex_color.rgb,
			nearby_alpha * outline_color.a * vertex_color.a
		);
	}
}
