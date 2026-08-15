shader_type canvas_item;
render_mode unshaded;

const int GAUSSIAN_RADIUS = 2;
uniform float blur_texels : hint_range(0.5, 4.0) = 2.2;
uniform float edge_warp_texels : hint_range(0.0, 4.0) = 2.8;
uniform float edge_irregularity : hint_range(0.0, 0.2) = 0.065;
uniform float alpha_dither : hint_range(0.0, 0.08) = 0.036;
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
	vec2 warped_uv = clamp(
		UV + (broad_warp * 0.72 + fine_warp * 0.28) * TEXTURE_PIXEL_SIZE * edge_warp_texels,
		vec2(0.0),
		vec2(1.0)
	);
	vec2 sample_step = TEXTURE_PIXEL_SIZE * blur_texels;
	float alpha_sum = 0.0;
	float weight_sum = 0.0;
	for (int sample_y = -GAUSSIAN_RADIUS; sample_y <= GAUSSIAN_RADIUS; sample_y++) {
		for (int sample_x = -GAUSSIAN_RADIUS; sample_x <= GAUSSIAN_RADIUS; sample_x++) {
			float weight_x = sample_x == 0 ? 6.0 : (abs(sample_x) == 1 ? 4.0 : 1.0);
			float weight_y = sample_y == 0 ? 6.0 : (abs(sample_y) == 1 ? 4.0 : 1.0);
			float weight = weight_x * weight_y;
			vec2 sample_uv = clamp(
				warped_uv + vec2(float(sample_x), float(sample_y)) * sample_step,
				vec2(0.0),
				vec2(1.0)
			);
			alpha_sum += texture(TEXTURE, sample_uv).a * weight;
			weight_sum += weight;
		}
	}
	float alpha = alpha_sum / weight_sum;
	float edge_shift = (ink_noise(fog_texel_position * vec2(0.31, 0.27)) - 0.5) * edge_irregularity;
	float softened_alpha = smoothstep(0.06 + edge_shift, 0.94 + edge_shift, alpha);
	float transition_mask = 4.0 * softened_alpha * (1.0 - softened_alpha);
	float stable_dither = ink_hash(floor(fog_texel_position * 2.0) + vec2(83.0, 29.0)) - 0.5;
	softened_alpha = clamp(softened_alpha + stable_dither * alpha_dither * transition_mask, 0.0, 1.0);
	COLOR = vec4(0.0, 0.0, 0.0, softened_alpha * fog_opacity);
}
