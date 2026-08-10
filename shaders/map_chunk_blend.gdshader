shader_type canvas_item;

uniform float fade_width : hint_range(0.001, 0.25) = 0.05;
uniform bool fade_from_left = true;
uniform bool fade_from_top = false;
uniform vec2 world_origin = vec2(0.0);
uniform vec2 world_size = vec2(2508.0, 1412.0);
uniform float water_motion_strength : hint_range(0.0, 1.0, 0.05) = 0.7;
uniform float water_wave_speed : hint_range(0.0, 2.0, 0.05) = 0.55;

float sea_color_mask(vec3 color) {
	float blue_bias = smoothstep(0.18, 0.48, color.b - color.r);
	float cyan_bias = smoothstep(0.12, 0.4, color.g - color.r);
	float sea_brightness = smoothstep(0.36, 0.7, max(color.g, color.b));
	return blue_bias * cyan_bias * sea_brightness;
}

float random_value(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 local_position = fract(position);
	vec2 blend = local_position * local_position * (3.0 - 2.0 * local_position);
	float bottom = mix(random_value(cell), random_value(cell + vec2(1.0, 0.0)), blend.x);
	float top = mix(random_value(cell + vec2(0.0, 1.0)), random_value(cell + vec2(1.0, 1.0)), blend.x);
	return mix(bottom, top, blend.y);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 world_position = world_origin + UV * world_size;
	vec2 wave_position = world_position * 0.018;
	float drift = TIME * water_wave_speed;
	vec2 flow_noise_position = world_position * 0.0038;
	float warp_x = value_noise(flow_noise_position + vec2(drift * 0.08, -drift * 0.11));
	float warp_y = value_noise(flow_noise_position * 1.43 + vec2(-drift * 0.09, drift * 0.07));
	vec2 irregular_wave_position = wave_position + (vec2(warp_x, warp_y) - 0.5) * 5.2;
	float broad_warp = sin(irregular_wave_position.y * 0.31 - drift * 0.23) * 1.15;
	float cross_warp = sin(irregular_wave_position.x * 0.27 + drift * 0.19) * 0.95;
	float broad_wave = sin(irregular_wave_position.x * 1.05 + irregular_wave_position.y * 0.38 + broad_warp - drift);
	float cross_wave = sin(-irregular_wave_position.x * 0.42 + irregular_wave_position.y * 1.3 + cross_warp - drift * 0.68);
	float swell = (broad_wave + cross_wave) * 0.25;
	float breakup = value_noise(world_position * 0.009 + vec2(drift * 0.12, -drift * 0.08));
	float crest = smoothstep(0.68, 0.98, broad_wave * 0.5 + 0.5)
		* smoothstep(0.42, 0.98, cross_wave * 0.5 + 0.5)
		* smoothstep(0.2, 0.78, breakup);
	vec2 shimmer_position = vec2(
		world_position.x * 0.011 + world_position.y * 0.003,
		-world_position.x * 0.0025 + world_position.y * 0.023
	);
	float shimmer_noise = value_noise(shimmer_position + vec2(drift * 0.38, -drift * 0.52));
	float shimmer = smoothstep(0.74, 0.94, shimmer_noise) * smoothstep(0.28, 0.8, breakup);
	float water_mask = sea_color_mask(source.rgb);
	vec3 animated_water = source.rgb;
	animated_water += swell * vec3(0.012, 0.024, 0.038) * water_motion_strength;
	animated_water += crest * vec3(0.035, 0.07, 0.095) * water_motion_strength;
	animated_water += shimmer * vec3(0.012, 0.032, 0.05) * water_motion_strength;
	source.rgb = mix(source.rgb, animated_water, water_mask);
	float seam_alpha = 1.0;
	if (fade_from_left) {
		seam_alpha *= smoothstep(0.0, fade_width, UV.x);
	}
	if (fade_from_top) {
		seam_alpha *= smoothstep(0.0, fade_width, UV.y);
	}
	COLOR = vec4(source.rgb, source.a * seam_alpha);
}
