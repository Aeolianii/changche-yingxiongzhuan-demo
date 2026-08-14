shader_type canvas_item;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge_fade = smoothstep(0.0, 0.16, edge_distance);
	COLOR = vec4(source.rgb, source.a * edge_fade);
}
