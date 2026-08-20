shader_type canvas_item;
render_mode unshaded;

const int SAMPLE_RADIUS = 4;
uniform sampler2D mist_texture : source_color, filter_linear;
uniform vec4 fog_tint : source_color = vec4(0.93, 0.97, 0.95, 1.0);
uniform sampler2D concealment_texture : source_color, filter_linear;
uniform vec4 concealment_tint : source_color = vec4(0.05, 0.56, 0.68, 1.0);
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
	vec4 mist = texture(mist_texture, UV);
	vec3 mist_color = mix(fog_tint.rgb, mist.rgb, 0.72);
	vec3 concealment_sample = texture(concealment_texture, UV).rgb;
	float concealment_luma = dot(concealment_sample, vec3(0.24, 0.67, 0.09));
	vec3 concealed_sea = concealment_tint.rgb * mix(0.76, 1.20, concealment_luma);
	vec3 concealed_fog = mix(concealed_sea, mist_color, clamp(mist.a * fog_opacity, 0.0, 1.0));
	COLOR = vec4(concealed_fog, softened_alpha);
}
