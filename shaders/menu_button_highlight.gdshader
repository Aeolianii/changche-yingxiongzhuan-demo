shader_type canvas_item;

uniform vec4 highlight_color : source_color = vec4(0.93, 0.68, 0.24, 0.42);

void fragment() {
	float button_alpha = texture(TEXTURE, UV).a;
	COLOR = vec4(highlight_color.rgb, button_alpha * highlight_color.a);
}
