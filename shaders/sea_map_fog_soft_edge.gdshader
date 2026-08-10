shader_type canvas_item;
render_mode unshaded;

const int SAMPLE_RADIUS = 3;


void fragment() {
	float alpha_sum = 0.0;
	float weight_sum = 0.0;
	for (int sample_y = -SAMPLE_RADIUS; sample_y <= SAMPLE_RADIUS; sample_y++) {
		for (int sample_x = -SAMPLE_RADIUS; sample_x <= SAMPLE_RADIUS; sample_x++) {
			vec2 sample_offset = vec2(float(sample_x), float(sample_y));
			float distance_squared = dot(sample_offset, sample_offset);
			float weight = 1.0 / (1.0 + distance_squared * 0.55);
			vec2 sample_uv = clamp(UV + sample_offset * TEXTURE_PIXEL_SIZE, vec2(0.0), vec2(1.0));
			alpha_sum += texture(TEXTURE, sample_uv).a * weight;
			weight_sum += weight;
		}
	}
	float softened_alpha = smoothstep(0.16, 0.84, alpha_sum / weight_sum);
	COLOR = vec4(0.0, 0.0, 0.0, softened_alpha);
}
