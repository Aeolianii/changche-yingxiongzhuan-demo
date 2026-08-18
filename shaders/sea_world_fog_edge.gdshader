shader_type canvas_item;
render_mode unshaded;

const int DISTANCE_SEARCH_RADIUS = 4;
uniform sampler2D fog_back_texture : source_color, filter_linear;
uniform sampler2D fog_mid_texture : source_color, filter_linear;
uniform sampler2D fog_detail_texture : source_color, filter_linear;
uniform vec4 fog_back_tint : source_color = vec4(0.59, 0.69, 0.72, 1.0);
uniform vec4 fog_mid_tint : source_color = vec4(0.78, 0.86, 0.87, 1.0);
uniform vec4 fog_detail_tint : source_color = vec4(0.78, 0.81, 0.80, 1.0);
uniform float fog_back_opacity : hint_range(0.0, 1.0) = 0.78;
uniform float fog_mid_opacity : hint_range(0.0, 1.0) = 0.86;
uniform float fog_detail_opacity : hint_range(0.0, 1.0) = 0.70;
uniform sampler2D concealment_texture : source_color, repeat_enable, filter_linear;
uniform vec4 concealment_tint : source_color = vec4(0.05, 0.56, 0.68, 1.0);
uniform vec2 concealment_uv_scale = vec2(4.0, 2.8);
uniform float feather_texels : hint_range(0.5, 4.0) = 3.4;
uniform float edge_warp_texels : hint_range(0.0, 2.0) = 0.8;
uniform float edge_irregularity : hint_range(0.0, 1.0) = 0.34;
uniform float alpha_dither : hint_range(0.0, 0.08) = 0.012;


float ink_hash(vec2 position) {
	position = fract(position * vec2(123.34, 456.21));
	position += dot(position, position + 45.32);
	return fract(position.x * position.y);
}


float ink_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 local_position = fract(position);
	vec2 blend = local_position * local_position * (3.0 - 2.0 * local_position);
	float bottom = mix(ink_hash(cell), ink_hash(cell + vec2(1.0, 0.0)), blend.x);
	float top = mix(ink_hash(cell + vec2(0.0, 1.0)), ink_hash(cell + vec2(1.0, 1.0)), blend.x);
	return mix(bottom, top, blend.y);
}


void fragment() {
	vec2 fog_texel_position = UV / TEXTURE_PIXEL_SIZE;
	vec2 broad_warp = vec2(
		ink_noise(fog_texel_position * vec2(0.075, 0.11) + vec2(13.7, 4.2)),
		ink_noise(fog_texel_position * vec2(0.105, 0.07) + vec2(41.3, 19.6))
	) * 2.0 - 1.0;
	vec2 fine_warp = vec2(
		ink_noise(fog_texel_position * vec2(0.22, 0.28) + vec2(7.1, 28.4)),
		ink_noise(fog_texel_position * vec2(0.26, 0.19) + vec2(31.8, 9.5))
	) * 2.0 - 1.0;
	vec2 texture_size = vec2(1.0) / TEXTURE_PIXEL_SIZE;
	vec2 distance_position = clamp(
		fog_texel_position + (broad_warp * 0.72 + fine_warp * 0.28) * edge_warp_texels,
		vec2(0.0),
		texture_size - vec2(0.001)
	);
	vec2 base_cell = floor(distance_position);
	vec2 base_uv = (base_cell + vec2(0.5)) * TEXTURE_PIXEL_SIZE;
	float center_mask = step(0.5, texture(TEXTURE, base_uv).a);
	float nearest_opposite = float(DISTANCE_SEARCH_RADIUS) + 1.0;
	for (int sample_y = -DISTANCE_SEARCH_RADIUS; sample_y <= DISTANCE_SEARCH_RADIUS; sample_y++) {
		for (int sample_x = -DISTANCE_SEARCH_RADIUS; sample_x <= DISTANCE_SEARCH_RADIUS; sample_x++) {
			vec2 sample_cell = clamp(
				base_cell + vec2(float(sample_x), float(sample_y)),
				vec2(0.0),
				texture_size - vec2(1.0)
			);
			vec2 sample_uv = (sample_cell + vec2(0.5)) * TEXTURE_PIXEL_SIZE;
			float sample_mask = step(0.5, texture(TEXTURE, sample_uv).a);
			if (abs(sample_mask - center_mask) > 0.5) {
				vec2 rectangle_distance = max(
					max(sample_cell - distance_position, distance_position - (sample_cell + vec2(1.0))),
					vec2(0.0)
				);
				nearest_opposite = min(nearest_opposite, length(rectangle_distance));
			}
		}
	}
	float signed_distance = center_mask > 0.5 ? nearest_opposite : -nearest_opposite;
	float edge_noise = ink_noise(fog_texel_position * vec2(0.19, 0.23) + vec2(37.0, 11.0)) - 0.5;
	signed_distance += edge_noise * edge_irregularity;
	float softened_alpha = smoothstep(-feather_texels, feather_texels, signed_distance);
	float transition_mask = 4.0 * softened_alpha * (1.0 - softened_alpha);
	float stable_dither = ink_hash(floor(fog_texel_position * 2.0) + vec2(83.0, 29.0)) - 0.5;
	softened_alpha = clamp(softened_alpha + stable_dither * alpha_dither * transition_mask, 0.0, 1.0);
	vec4 fog_back = texture(fog_back_texture, UV);
	vec4 fog_mid = texture(fog_mid_texture, UV);
	vec4 fog_detail = texture(fog_detail_texture, UV);
	vec3 concealment_sample = texture(concealment_texture, fract(UV * concealment_uv_scale)).rgb;
	float concealment_luma = dot(concealment_sample, vec3(0.24, 0.67, 0.09));
	vec3 concealed_sea = concealment_tint.rgb * mix(0.74, 1.22, concealment_luma);
	vec3 fog_back_color = mix(fog_back_tint.rgb, fog_back.rgb, 0.24);
	vec3 fog_mid_color = mix(fog_mid_tint.rgb, fog_mid.rgb, 0.34);
	vec3 fog_detail_color = mix(fog_detail_tint.rgb, fog_detail.rgb, 0.28);
	vec3 concealed_fog = mix(concealed_sea, fog_back_color, clamp(fog_back.a * fog_back_opacity, 0.0, 1.0));
	concealed_fog = mix(concealed_fog, fog_mid_color, clamp(fog_mid.a * fog_mid_opacity, 0.0, 1.0));
	concealed_fog = mix(concealed_fog, fog_detail_color, clamp(fog_detail.a * fog_detail_opacity, 0.0, 1.0));
	COLOR = vec4(concealed_fog, softened_alpha);
}
