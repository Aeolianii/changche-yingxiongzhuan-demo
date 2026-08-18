shader_type canvas_item;
render_mode unshaded;

const int SAMPLE_RADIUS = 4;
uniform sampler2D mist_texture : source_color, repeat_enable, filter_linear;
uniform vec4 fog_tint : source_color = vec4(0.93, 0.97, 0.95, 1.0);
uniform float fog_base_alpha : hint_range(0.0, 1.0) = 0.72;
uniform float fog_opacity : hint_range(0.0, 1.0) = 0.72;
uniform float edge_warp_texels : hint_range(0.0, 8.0) = 5.0;
uniform float edge_irregularity : hint_range(0.0, 0.5) = 0.34;


float ink_hash(vec2 position) {
	position = fract(position * vec2(123.34, 456.21));
	position += dot(position, position + 45.32);
	return fract(position.x * position.y);
}


float ink_value_noise(vec2 position) {
	vec2 cell = floor(position);
	vec2 local_position = fract(position);
	vec2 blend = local_position * local_position * (3.0 - 2.0 * local_position);
	float bottom = mix(ink_hash(cell), ink_hash(cell + vec2(1.0, 0.0)), blend.x);
	float top = mix(ink_hash(cell + vec2(0.0, 1.0)), ink_hash(cell + vec2(1.0, 1.0)), blend.x);
	return mix(bottom, top, blend.y);
}


vec4 layered_mist(vec2 uv) {
	vec2 first_uv = uv * vec2(1.78, 1.12) + vec2(0.11, 0.33);
	vec2 mirrored_uv = vec2(1.0 - uv.x, uv.y) * vec2(1.53, 1.28) + vec2(0.67, 0.07);
	vec2 cross_uv = vec2(uv.y, 1.0 - uv.x) * vec2(1.34, 1.64) + vec2(0.31, 0.57);
	vec2 broad_uv = vec2(uv.x, 1.0 - uv.y) * vec2(2.08, 1.36) + vec2(0.81, 0.39);
	vec2 fill_uv = vec2(1.0 - uv.y, uv.x) * vec2(1.21, 1.07) + vec2(0.44, 0.73);
	vec2 detail_uv = uv * vec2(2.43, 1.69) + vec2(0.94, 0.14);
	vec4 first_layer = texture(mist_texture, first_uv);
	vec4 second_layer = texture(mist_texture, mirrored_uv);
	vec4 cross_layer = texture(mist_texture, cross_uv);
	vec4 broad_layer = texture(mist_texture, broad_uv);
	vec4 fill_layer = texture(mist_texture, fill_uv);
	vec4 detail_layer = texture(mist_texture, detail_uv);
	float combined_alpha = 1.0 - (1.0 - first_layer.a) * (1.0 - second_layer.a * 0.92) * (1.0 - cross_layer.a * 0.82) * (1.0 - broad_layer.a * 0.74) * (1.0 - fill_layer.a * 0.76) * (1.0 - detail_layer.a * 0.66);
	float total_alpha = max(first_layer.a + second_layer.a + cross_layer.a + broad_layer.a + fill_layer.a + detail_layer.a, 0.001);
	vec3 asset_color = (first_layer.rgb * first_layer.a + second_layer.rgb * second_layer.a + cross_layer.rgb * cross_layer.a + broad_layer.rgb * broad_layer.a + fill_layer.rgb * fill_layer.a + detail_layer.rgb * detail_layer.a) / total_alpha;
	vec3 mist_color = mix(fog_tint.rgb, asset_color, clamp(total_alpha * 0.27, 0.0, 0.88));
	return vec4(mist_color, mix(fog_base_alpha, 1.0, combined_alpha));
}


void fragment() {
	float warp_x = ink_value_noise((UV + vec2(0.17, 0.43)) * vec2(17.0, 29.0));
	float warp_y = ink_value_noise((UV + vec2(0.61, 0.09)) * vec2(31.0, 19.0));
	vec2 warped_uv = UV + (vec2(warp_x, warp_y) - vec2(0.5)) * TEXTURE_PIXEL_SIZE * edge_warp_texels;
	float alpha_sum = 0.0;
	float weight_sum = 0.0;
	for (int sample_y = -SAMPLE_RADIUS; sample_y <= SAMPLE_RADIUS; sample_y++) {
		for (int sample_x = -SAMPLE_RADIUS; sample_x <= SAMPLE_RADIUS; sample_x++) {
			vec2 sample_offset = vec2(float(sample_x), float(sample_y));
			float distance_squared = dot(sample_offset, sample_offset);
			float weight = 1.0 / (1.0 + distance_squared * 0.55);
			vec2 sample_uv = clamp(warped_uv + sample_offset * TEXTURE_PIXEL_SIZE, vec2(0.0), vec2(1.0));
			alpha_sum += texture(TEXTURE, sample_uv).a * weight;
			weight_sum += weight;
		}
	}
	float broad_noise = ink_value_noise(UV * vec2(14.0, 9.0));
	float detail_noise = ink_value_noise((UV + vec2(0.29, 0.73)) * vec2(43.0, 27.0));
	float edge_noise = mix(broad_noise, detail_noise, 0.32) - 0.5;
	float edge_shift = edge_noise * edge_irregularity;
	float softened_alpha = smoothstep(0.16 + edge_shift, 0.84 + edge_shift, alpha_sum / weight_sum);
	vec4 mist = layered_mist(UV);
	float transition_band = 4.0 * softened_alpha * (1.0 - softened_alpha);
	float textured_mask = clamp(softened_alpha + (mist.a - 0.58) * transition_band * 0.82, 0.0, 1.0);
	COLOR = vec4(mist.rgb, textured_mask * fog_opacity * mist.a);
}
