shader_type canvas_item;

uniform vec4 ripple_color : source_color = vec4(0.47, 0.78, 0.80, 0.15);
uniform float ripple_speed : hint_range(0.0, 1.0, 0.01) = 0.16;
uniform float phase_offset = 0.0;

float ripple_band(float distance_to_center, float radius, float width) {
	return 1.0 - smoothstep(width, width * 2.1, abs(distance_to_center - radius));
}

void fragment() {
	vec2 point = UV - vec2(0.5);
	point.y *= 1.68;
	float distance_to_center = length(point);
	float angle = atan(point.y, point.x);
	float uneven_edge = sin(angle * 5.0 + TIME * 0.37) * 0.006;
	float phase_a = fract(TIME * ripple_speed + phase_offset);
	float phase_b = fract(phase_a + 0.5);
	float radius_a = mix(0.11, 0.46, phase_a) + uneven_edge;
	float radius_b = mix(0.11, 0.46, phase_b) - uneven_edge;
	float ring_a = ripple_band(distance_to_center, radius_a, 0.008) * sin(PI * phase_a);
	float ring_b = ripple_band(distance_to_center, radius_b, 0.008) * sin(PI * phase_b);
	float alpha = (ring_a + ring_b) * ripple_color.a;
	COLOR = vec4(ripple_color.rgb, alpha);
}
