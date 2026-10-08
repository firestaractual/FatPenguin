shader_type canvas_item;
render_mode unshaded;
// Queasy (ScreenFx): the picture swims about, doubles, and goes green.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float wobble = 0.008;
uniform vec4 tint : source_color = vec4(0.55, 0.78, 0.25, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	uv += vec2(sin(uv.y * 9.0 + t * 2.1), sin(uv.x * 7.0 + t * 1.5)) * wobble * amount;
	vec3 col = texture(screen_texture, uv).rgb;
	vec3 ghost = texture(screen_texture, uv + vec2(sin(t * 1.3), cos(t * 0.9)) * wobble * 1.6 * amount).rgb;
	col = mix(col, ghost, 0.35 * amount);
	col = mix(col, col * tint.rgb * 1.3, 0.28 * amount);
	COLOR = vec4(col, amount > 0.001 ? 1.0 : 0.0);
}
