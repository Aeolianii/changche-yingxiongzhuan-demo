shader_type canvas_item;

uniform float fade_width : hint_range(0.001, 0.25) = 0.05;
uniform bool fade_from_left = true;
uniform bool fade_from_top = false;
uniform vec2 world_origin = vec2(0.0);
uniform vec2 world_size = vec2(2508.0, 1412.0);
uniform float water_motion_strength : hint_range(0.0, 1.0, 0.05) = 0.7;
uniform float water_wave_speed : hint_range(0.0, 2.0, 0.05) = 0.55;
uniform sampler2D waterNoise : repeat_enable, filter_linear;
uniform sampler2D waterDistortionNoise : repeat_enable, filter_linear;

float sea_color_mask(vec3 color) {
	float blue_bias = smoothstep(0.18, 0.48, color.b - color.r);
	float cyan_bias = smoothstep(0.12, 0.4, color.g - color.r);
	float sea_brightness = smoothstep(0.36, 0.7, max(color.g, color.b));
	return blue_bias * cyan_bias * sea_brightness;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 world_position = world_origin + UV * world_size;
	float drift = TIME * water_wave_speed;
	vec2 base_noise_uv = world_position * 0.0032;
	vec2 distortion_uv = base_noise_uv * vec2(0.82, 1.18) + vec2(drift * 0.075, drift * 0.032);
	float distortion = texture(waterDistortionNoise, distortion_uv).r - 0.5;
	float distortion_y = texture(waterDistortionNoise, distortion_uv + vec2(0.37, 0.19)).r - 0.5;
	vec2 primary_flow_uv = base_noise_uv + vec2(drift * 0.082, drift * 0.036);
	primary_flow_uv += vec2(distortion * 0.11, distortion * 0.065);
	vec2 crossing_flow_uv = base_noise_uv * vec2(1.72, 1.38) + vec2(-drift * 0.046, drift * 0.058);
	crossing_flow_uv += vec2(-distortion * 0.07, distortion * 0.09);
	float primary_flow = texture(waterNoise, primary_flow_uv).r;
	float crossing_flow = texture(waterNoise, crossing_flow_uv).r;
	float broken_surface = primary_flow * 0.68 + crossing_flow * 0.32;
	float crest = smoothstep(0.61, 0.9, broken_surface);
	float fine_crest = smoothstep(0.72, 0.94, crossing_flow) * smoothstep(0.42, 0.82, primary_flow);
	float trough = 1.0 - smoothstep(0.18, 0.7, broken_surface);
	float water_mask = sea_color_mask(source.rgb);
	vec2 refraction_offset = vec2(distortion, distortion_y) * 0.0016 * water_motion_strength;
	vec4 refracted_source = texture(TEXTURE, UV + refraction_offset);
	float safe_refraction_mask = water_mask * sea_color_mask(refracted_source.rgb);
	source.rgb = mix(source.rgb, refracted_source.rgb, safe_refraction_mask * 0.22);
	vec3 animated_water = source.rgb;
	animated_water -= trough * vec3(0.004, 0.009, 0.014) * water_motion_strength;
	animated_water += crest * vec3(0.018, 0.052, 0.075) * water_motion_strength;
	animated_water += fine_crest * vec3(0.025, 0.07, 0.1) * water_motion_strength;
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
