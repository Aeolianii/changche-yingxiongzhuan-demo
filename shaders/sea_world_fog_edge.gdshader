shader_type canvas_item;
render_mode unshaded;

const int DISTANCE_SEARCH_RADIUS = 4;
uniform sampler2D mist_texture : source_color, repeat_enable, filter_linear;
uniform vec4 fog_tint : source_color = vec4(0.93, 0.97, 0.95, 1.0);
uniform float fog_base_alpha : hint_range(0.0, 1.0) = 0.32;
uniform float feather_texels : hint_range(0.5, 4.0) = 3.4;
uniform float edge_warp_texels : hint_range(0.0, 2.0) = 0.8;
uniform float edge_irregularity : hint_range(0.0, 1.0) = 0.34;
uniform float alpha_dither : hint_range(0.0, 0.08) = 0.012;
uniform float fog_opacity : hint_range(0.0, 1.0) = 0.72;


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


vec4 layered_mist(vec2 uv) {
	vec2 first_uv = uv * vec2(1.82, 1.14) + vec2(0.13, 0.27);
	vec2 mirrored_uv = vec2(1.0 - uv.x, uv.y) * vec2(1.57, 1.31) + vec2(0.61, 0.08);
	vec2 cross_uv = vec2(uv.y, 1.0 - uv.x) * vec2(1.36, 1.68) + vec2(0.29, 0.54);
	vec2 broad_uv = vec2(uv.x, 1.0 - uv.y) * vec2(2.14, 1.39) + vec2(0.78, 0.42);
	vec2 fill_uv = vec2(1.0 - uv.y, uv.x) * vec2(1.24, 1.09) + vec2(0.47, 0.71);
	vec2 detail_uv = uv * vec2(2.47, 1.73) + vec2(0.92, 0.16);
	vec4 first_layer = texture(mist_texture, first_uv);
	vec4 second_layer = texture(mist_texture, mirrored_uv);
	vec4 cross_layer = texture(mist_texture, cross_uv);
	vec4 broad_layer = texture(mist_texture, broad_uv);
	vec4 fill_layer = texture(mist_texture, fill_uv);
	vec4 detail_layer = texture(mist_texture, detail_uv);
	float combined_alpha = 1.0 - (1.0 - first_layer.a) * (1.0 - second_layer.a * 0.9) * (1.0 - cross_layer.a * 0.78) * (1.0 - broad_layer.a * 0.7) * (1.0 - fill_layer.a * 0.72) * (1.0 - detail_layer.a * 0.64);
	float total_alpha = max(first_layer.a + second_layer.a + cross_layer.a + broad_layer.a + fill_layer.a + detail_layer.a, 0.001);
	vec3 asset_color = (first_layer.rgb * first_layer.a + second_layer.rgb * second_layer.a + cross_layer.rgb * cross_layer.a + broad_layer.rgb * broad_layer.a + fill_layer.rgb * fill_layer.a + detail_layer.rgb * detail_layer.a) / total_alpha;
	vec3 mist_color = mix(fog_tint.rgb, asset_color, clamp(total_alpha * 0.27, 0.0, 0.88));
	return vec4(mist_color, mix(fog_base_alpha, 1.0, combined_alpha));
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
	vec4 mist = layered_mist(UV);
	COLOR = vec4(mist.rgb, softened_alpha * fog_opacity * mist.a);
}
