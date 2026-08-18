shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0, 0.1) = 3.2;
uniform float saturation : hint_range(0.0, 1.0, 0.05) = 0.72;

void fragment() {
	vec4 screen_color = textureLod(screen_texture, SCREEN_UV, blur_amount);
	float luminance = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
	screen_color.rgb = mix(vec3(luminance), screen_color.rgb, saturation);
	COLOR = screen_color;
}
