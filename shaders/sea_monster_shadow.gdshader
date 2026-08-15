shader_type canvas_item;

uniform vec4 shadow_color : source_color = vec4(0.025, 0.16, 0.22, 1.0);
uniform float shadow_opacity : hint_range(0.0, 1.0, 0.01) = 0.34;
uniform float flow_speed : hint_range(0.0, 1.0, 0.01) = 0.16;
uniform float flow_phase = 0.0;

float shadow_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float shadow_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	float lower = mix(shadow_hash(cell), shadow_hash(cell + vec2(1.0, 0.0)), blend.x);
	float upper = mix(shadow_hash(cell + vec2(0.0, 1.0)), shadow_hash(cell + vec2(1.0, 1.0)), blend.x);
	return mix(lower, upper, blend.y);
}

void fragment() {
	float time = TIME * flow_speed + flow_phase;
	vec2 flow = vec2(
		shadow_noise(UV * 5.4 + vec2(time, time * 0.31)),
		shadow_noise(UV * 5.9 + vec2(-time * 0.42, time * 0.57) + vec2(4.2, 1.3))
	) - vec2(0.5);
	vec2 sampled_uv = clamp(UV + flow * 0.009, vec2(0.0), vec2(1.0));
	vec2 pixel_step = TEXTURE_PIXEL_SIZE * 4.0;
	sampled_uv = (floor(sampled_uv / pixel_step) + vec2(0.5)) * pixel_step;
	vec4 source = texture(TEXTURE, sampled_uv);
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float darkness = 1.0 - smoothstep(0.30, 0.74, luminance);
	float shadow_mask = source.a * smoothstep(0.06, 0.72, darkness);
	float ink_grain = mix(0.82, 1.0, shadow_hash(floor(UV / pixel_step)));
	float breath = 0.92 + sin(TIME * 0.29 + flow_phase) * 0.08;
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge_fade = smoothstep(0.02, 0.16, edge_distance);
	COLOR = vec4(shadow_color.rgb, shadow_mask * shadow_opacity * ink_grain * breath * edge_fade);
}
