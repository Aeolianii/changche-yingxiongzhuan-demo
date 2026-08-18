shader_type canvas_item;

uniform float phase : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dark_tint : source_color = vec4(0.035, 0.055, 0.06, 1.0);

void fragment() {
	vec4 moon = texture(TEXTURE, UV);
	vec2 sphere = (UV - vec2(0.5)) / 0.36;
	float sphere_z = sqrt(max(1.0 - dot(sphere, sphere), 0.0));
	float angle = phase * 6.28318530718;
	vec3 light_direction = normalize(vec3(sin(angle), 0.0, -cos(angle)));
	float light_amount = smoothstep(-0.018, 0.018, dot(vec3(sphere.x, sphere.y, sphere_z), light_direction));
	vec3 shaded_moon = mix(dark_tint.rgb, moon.rgb, light_amount);
	COLOR = vec4(shaded_moon, moon.a);
}
