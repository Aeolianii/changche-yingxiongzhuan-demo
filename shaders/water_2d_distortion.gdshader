shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, repeat_disable, filter_nearest;

group_uniforms water;
uniform sampler2D waterNoise : repeat_enable, filter_nearest;
uniform sampler2D waterDistortionNoise : repeat_enable, filter_nearest;
uniform vec4 waterColor : source_color = vec4(0.12, 0.55, 0.76, 1.0);
uniform float colorCorection : hint_range(0.0, 1.0, 0.01) = 0.28;

group_uniforms water_waves;
uniform float distortionForce : hint_range(0.00, 0.1, 0.001) = 0.01;
uniform float WDBrightness : hint_range(0.0, 3.0, 0.05) = 1.25;
uniform float WDFreq : hint_range(0.2, 0.9, 0.05) = 0.62;
uniform float WDSize : hint_range(0.6, 1.2, 0.05) = 0.92;
uniform float WDSpeed : hint_range(1.0, 20.0, 0.05) = 4.0;
uniform vec2 tiling = vec2(4.0, 2.4);
uniform vec2 offSetSpeed = vec2(0.08, 0.035);

group_uniforms BG_distortion;
uniform float backGroundDirX : hint_range(-0.1, 0.1) = 0.01;
uniform float backGroundDirY : hint_range(-0.1, 0.1) = 0.006;

void fragment() {
	vec4 color = vec4(waterColor.rgb, 1.0);
	float seaTexture = texture(TEXTURE, UV).r;
	color.rgb *= mix(0.78, 1.18, seaTexture);

	vec2 noiseUV = SCREEN_UV * tiling + offSetSpeed * TIME;
	float noiseValue = texture(waterDistortionNoise, noiseUV).r;

	vec2 waterUV = SCREEN_UV * tiling;
	waterUV.x += offSetSpeed.x * TIME;
	waterUV.y += cos(TIME * min(1.0, offSetSpeed.y)) * 0.01;
	waterUV += noiseValue * distortionForce * WDSpeed;

	vec4 noiseColor = texture(waterNoise, waterUV);
	float intensity = smoothstep(WDFreq, WDSize, noiseColor.r);
	color.rgb += intensity * vec3(WDBrightness);

	vec2 backGroundUV = SCREEN_UV;
	backGroundUV.x += noiseValue * backGroundDirX;
	backGroundUV.y += noiseValue * backGroundDirY;
	color = mix(texture(SCREEN_TEXTURE, backGroundUV), color, 0.2);

	COLOR = mix(color, waterColor, colorCorection);
}
