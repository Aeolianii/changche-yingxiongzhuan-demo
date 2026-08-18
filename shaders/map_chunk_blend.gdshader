shader_type canvas_item;

uniform float fade_width : hint_range(0.001, 0.25) = 0.05;
uniform bool fade_from_left = true;
uniform bool fade_from_top = false;
uniform vec2 world_origin = vec2(0.0);
uniform vec2 world_size = vec2(2508.0, 1412.0);
uniform float water_motion_strength : hint_range(0.0, 1.0, 0.05) = 0.9;
uniform float water_wave_speed : hint_range(0.0, 2.0, 0.05) = 0.55;
uniform sampler2D waterNoise : repeat_enable, filter_linear;
uniform sampler2D waterFlowTexture : repeat_enable, filter_linear;
uniform sampler2D waterDistortionNoise : repeat_enable, filter_linear;

float sea_color_mask(vec3 color) {
	float blue_bias = smoothstep(0.18, 0.48, color.b - color.r);
	float cyan_bias = smoothstep(0.12, 0.4, color.g - color.r);
	float sea_brightness = smoothstep(0.36, 0.7, max(color.g, color.b));
	return blue_bias * cyan_bias * sea_brightness;
}

float sea_luma(vec3 color) {
	return dot(color, vec3(0.24, 0.67, 0.09));
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec2 world_position = world_origin + UV * world_size;
	float time = TIME * water_wave_speed * 0.02545;
	// Keep the base coordinates continuous; the seamless flow texture handles wrapping.
	vec2 flow_uv = world_position * vec2(0.00082, 0.00105);

	// Same three-layer counter-flow used by the naval battle surface.
	float broad_a = sea_luma(texture(waterFlowTexture, fract(
		flow_uv * 0.58 + vec2(time * 0.34, time * 0.09))).rgb);
	float broad_b = sea_luma(texture(waterFlowTexture, fract(
		flow_uv * 0.82 + vec2(-time * 0.22, time * 0.13))).rgb);
	float broad = broad_a * 0.62 + broad_b * 0.38;
	vec2 warp = (vec2(broad_a, broad_b) - vec2(0.5)) * 0.052;

	vec2 flow_a = flow_uv * 1.10 + warp + vec2(time * 0.72, time * 0.18);
	vec2 flow_b = flow_uv * 1.43 - warp.yx + vec2(-time * 0.48, time * 0.27);
	vec2 flow_c = flow_uv * 0.91 + warp * 0.55 + vec2(time * 0.20, -time * 0.36);
	float light_a = sea_luma(texture(waterFlowTexture, fract(flow_a)).rgb);
	float light_b = sea_luma(texture(waterFlowTexture, fract(flow_b)).rgb);
	float light_c = sea_luma(texture(waterFlowTexture, fract(flow_c)).rgb);
	float ridge_a = 1.0 - smoothstep(0.020, 0.095, abs(light_a - light_b));
	float ridge_b = 1.0 - smoothstep(0.026, 0.120, abs(light_b - light_c));
	float caustic = ridge_a * 0.72 + ridge_b * 0.28;
	caustic *= smoothstep(0.40, 0.68, max(light_a, light_c));
	caustic *= 0.86 + 0.14 * sin(TIME * 0.72 + broad * 6.28318);

	vec2 distortion_uv = world_position * 0.0027 + vec2(time * 0.08, time * 0.025);
	float distortion = texture(waterDistortionNoise, distortion_uv).r - 0.5;
	float distortion_y = texture(waterDistortionNoise, distortion_uv + vec2(0.37, 0.19)).r - 0.5;
	float water_mask = sea_color_mask(source.rgb);
	vec2 refraction_offset = vec2(distortion, distortion_y) * 0.0016 * water_motion_strength;
	vec4 refracted_source = texture(TEXTURE, UV + refraction_offset);
	float safe_refraction_mask = water_mask * sea_color_mask(refracted_source.rgb);
	source.rgb = mix(source.rgb, refracted_source.rgb, safe_refraction_mask * 0.22);
	vec3 animated_water = source.rgb;
	float shade = mix(0.94, 1.06, smoothstep(0.34, 0.70, broad));
	animated_water *= shade;
	animated_water += vec3(0.77, 0.88, 0.86) * caustic * 0.24 * water_motion_strength;
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
