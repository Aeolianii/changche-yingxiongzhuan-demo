shader_type canvas_item;

uniform float fade_width : hint_range(0.001, 0.25) = 0.05;
uniform bool fade_from_left = true;
uniform bool fade_from_top = false;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float seam_alpha = 1.0;
	if (fade_from_left) {
		seam_alpha *= smoothstep(0.0, fade_width, UV.x);
	}
	if (fade_from_top) {
		seam_alpha *= smoothstep(0.0, fade_width, UV.y);
	}
	COLOR = vec4(source.rgb, source.a * seam_alpha);
}
