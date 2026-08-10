shader_type canvas_item;

uniform float edge_softness : hint_range(0.0, 0.2) = 0.065;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	color.a *= smoothstep(0.0, edge_softness, edge);
	COLOR = color;
}
