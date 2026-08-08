shader_type canvas_item;

uniform float fade_width : hint_range(0.001, 0.25) = 0.05;
uniform bool fade_from_top = false;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float seam_coordinate = fade_from_top ? UV.y : UV.x;
	float seam_alpha = smoothstep(0.0, fade_width, seam_coordinate);
	COLOR = vec4(source.rgb, source.a * seam_alpha);
}
