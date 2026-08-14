shader_type canvas_item;

uniform float fog_motion_speed : hint_range(0.0, 0.2, 0.001) = 0.032;
uniform float fog_opacity_variation : hint_range(0.0, 0.3, 0.01) = 0.12;
uniform float fog_brightness_variation : hint_range(0.0, 0.2, 0.01) = 0.07;

float fog_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

float fog_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	vec2 blend = local * local * (3.0 - 2.0 * local);
	float lower = mix(fog_hash(cell), fog_hash(cell + vec2(1.0, 0.0)), blend.x);
	float upper = mix(fog_hash(cell + vec2(0.0, 1.0)), fog_hash(cell + vec2(1.0, 1.0)), blend.x);
	return mix(lower, upper, blend.y);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	float fog_mask = smoothstep(0.50, 0.82, luminance) * smoothstep(0.04, 0.30, source.a);
	vec2 drift = vec2(TIME * fog_motion_speed, TIME * fog_motion_speed * 0.43);
	float broad_flow = fog_noise(UV * 4.6 + drift);
	float fine_flow = fog_noise(UV * 8.2 - drift.yx * 1.35 + vec2(3.7, 1.9));
	float rolling_fog = mix(broad_flow, fine_flow, 0.34) * 2.0 - 1.0;
	float breath = sin(TIME * 0.34 + UV.x * 2.4 - UV.y * 1.7) * 0.5 + 0.5;
	float opacity_motion = 1.0 + (rolling_fog * 0.72 + (breath - 0.5) * 0.28) * fog_opacity_variation;
	float brightness_motion = 1.0 + rolling_fog * fog_brightness_variation;
	source.rgb *= mix(1.0, brightness_motion, fog_mask);
	source.a *= mix(1.0, opacity_motion, fog_mask);
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float edge_flow = fog_noise(UV * 6.8 + drift * 0.8);
	float edge_width = 0.15 + (edge_flow - 0.5) * 0.035;
	float edge_fade = smoothstep(0.0, edge_width, edge_distance);
	COLOR = vec4(source.rgb, source.a * edge_fade);
}
