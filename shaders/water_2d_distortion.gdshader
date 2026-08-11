shader_type canvas_item;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_nearest;

group_uniforms water;
uniform sampler2D waterDistortionNoise : repeat_enable, filter_nearest;
uniform vec4 waterColor : source_color = vec4(0.12, 0.55, 0.76, 1.0);
uniform float colorCorection : hint_range(0.0, 1.0, 0.01) = 0.28;

group_uniforms water_waves;
uniform float flow_speed : hint_range(0.001, 0.05, 0.001) = 0.014;
uniform float warp_strength : hint_range(0.0, 0.12, 0.001) = 0.052;
uniform float caustic_strength : hint_range(0.0, 0.5, 0.01) = 0.24;
uniform vec2 tiling = vec2(1.35, 1.0);

group_uniforms BG_distortion;
uniform float refraction_strength : hint_range(0.0, 0.02, 0.0005) = 0.004;

float sea_luma(vec3 color) {
	return dot(color, vec3(0.24, 0.67, 0.09));
}

void fragment() {
	vec2 uv = fract(SCREEN_UV * tiling);
	float time = TIME * flow_speed;

	// Match the naval battle surface: two broad counter-flows bend three finer layers.
	float broad_a = sea_luma(texture(TEXTURE, fract(
		uv * 0.58 + vec2(time * 0.34, time * 0.09))).rgb);
	float broad_b = sea_luma(texture(TEXTURE, fract(
		uv * 0.82 + vec2(-time * 0.22, time * 0.13))).rgb);
	float broad = broad_a * 0.62 + broad_b * 0.38;
	vec2 warp = (vec2(broad_a, broad_b) - vec2(0.5)) * warp_strength;

	vec2 flow_a = uv * 1.10 + warp + vec2(time * 0.72, time * 0.18);
	vec2 flow_b = uv * 1.43 - warp.yx + vec2(-time * 0.48, time * 0.27);
	vec2 flow_c = uv * 0.91 + warp * 0.55 + vec2(time * 0.20, -time * 0.36);
	float light_a = sea_luma(texture(TEXTURE, fract(flow_a)).rgb);
	float light_b = sea_luma(texture(TEXTURE, fract(flow_b)).rgb);
	float light_c = sea_luma(texture(TEXTURE, fract(flow_c)).rgb);

	float ridge_a = 1.0 - smoothstep(0.020, 0.095, abs(light_a - light_b));
	float ridge_b = 1.0 - smoothstep(0.026, 0.120, abs(light_b - light_c));
	float caustic = ridge_a * 0.72 + ridge_b * 0.28;
	caustic *= smoothstep(0.40, 0.68, max(light_a, light_c));
	caustic *= 0.86 + 0.14 * sin(TIME * 0.72 + broad * 6.28318);

	vec2 distortion_uv = SCREEN_UV * vec2(2.7, 2.0)
		+ vec2(time * 0.08, time * 0.025);
	vec2 refraction = vec2(
		texture(waterDistortionNoise, distortion_uv).r,
		texture(waterDistortionNoise, distortion_uv + vec2(0.37, 0.19)).r
	) - vec2(0.5);
	vec3 scene_color = texture(SCREEN_TEXTURE,
		SCREEN_UV + refraction * refraction_strength).rgb;
	vec3 base = mix(scene_color, waterColor.rgb, colorCorection);
	float shade = mix(0.94, 1.06, smoothstep(0.34, 0.70, broad));
	vec3 paper_blue = vec3(0.77, 0.88, 0.86);
	vec3 color = base * shade + paper_blue * caustic * caustic_strength;
	COLOR = vec4(color, 1.0);
}
