shader_type canvas_item;

uniform vec4 highlight_color : source_color = vec4(0.96, 0.74, 0.28, 0.38);
uniform float alpha_cutoff : hint_range(0.0, 0.5) = 0.08;

void fragment() {
	float button_alpha = texture(TEXTURE, UV).a;
	float shaped_alpha = smoothstep(alpha_cutoff, alpha_cutoff + 0.18, button_alpha);
	COLOR = vec4(highlight_color.rgb, shaped_alpha * highlight_color.a);
}
