shader_type canvas_item;
render_mode unshaded;

uniform float blur_texels : hint_range(0.5, 3.0) = 2.25;
uniform float edge_irregularity : hint_range(0.0, 0.2) = 0.04;
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
	vec2 sample_step = TEXTURE_PIXEL_SIZE * blur_texels;
	float alpha = texture(TEXTURE, UV).a * 0.28;
	alpha += texture(TEXTURE, clamp(UV + vec2(sample_step.x, 0.0), vec2(0.0), vec2(1.0))).a * 0.12;
	alpha += texture(TEXTURE, clamp(UV - vec2(sample_step.x, 0.0), vec2(0.0), vec2(1.0))).a * 0.12;
	alpha += texture(TEXTURE, clamp(UV + vec2(0.0, sample_step.y), vec2(0.0), vec2(1.0))).a * 0.12;
	alpha += texture(TEXTURE, clamp(UV - vec2(0.0, sample_step.y), vec2(0.0), vec2(1.0))).a * 0.12;
	alpha += texture(TEXTURE, clamp(UV + sample_step, vec2(0.0), vec2(1.0))).a * 0.06;
	alpha += texture(TEXTURE, clamp(UV - sample_step, vec2(0.0), vec2(1.0))).a * 0.06;
	alpha += texture(TEXTURE, clamp(UV + vec2(sample_step.x, -sample_step.y), vec2(0.0), vec2(1.0))).a * 0.06;
	alpha += texture(TEXTURE, clamp(UV + vec2(-sample_step.x, sample_step.y), vec2(0.0), vec2(1.0))).a * 0.06;
	float edge_shift = (ink_noise(UV * vec2(47.0, 29.0)) - 0.5) * edge_irregularity;
	float softened_alpha = smoothstep(0.0 + edge_shift, 1.0 + edge_shift, alpha);
	COLOR = vec4(0.0, 0.0, 0.0, softened_alpha * fog_opacity);
}
