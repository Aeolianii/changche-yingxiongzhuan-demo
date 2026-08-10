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

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 world_position = world_origin + UV * world_size;
	vec2 wave_position = world_position * 0.018;
	float drift = TIME * water_wave_speed;
	float broad_warp = sin(wave_position.y * 0.31 - drift * 0.23) * 1.1;
	float cross_warp = sin(wave_position.x * 0.27 + drift * 0.19) * 0.9;
	float broad_wave = sin(wave_position.x * 1.05 + wave_position.y * 0.38 + broad_warp - drift);
	float cross_wave = sin(-wave_position.x * 0.42 + wave_position.y * 1.3 + cross_warp - drift * 0.68);
	float swell = (broad_wave + cross_wave) * 0.25;
	float crest = smoothstep(0.68, 0.98, broad_wave * 0.5 + 0.5)
		* smoothstep(0.42, 0.98, cross_wave * 0.5 + 0.5);
	float shimmer = smoothstep(0.82, 1.0, sin(
		wave_position.x * 2.6 - wave_position.y * 1.15 - drift * 1.45
	) * 0.5 + 0.5);
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
