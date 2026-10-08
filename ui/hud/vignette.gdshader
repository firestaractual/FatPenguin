shader_type canvas_item;
render_mode unshaded;
// The dark edges of ScreenFx: they close in from the sides (reach), get darker (darkness), and
// can black out the whole screen (blackout). No danger colour: a deep navy black.

uniform float darkness : hint_range(0.0, 1.0) = 0.0;
uniform float reach : hint_range(0.0, 1.0) = 0.0;
uniform float blackout : hint_range(0.0, 1.0) = 0.0;
uniform float softness = 0.4;
uniform vec4 tint : source_color = vec4(0.0, 0.015, 0.04, 1.0);

void fragment() {
	// 0 in the middle, 1 at the left and right edges: the sides close in first, the top and
	// bottom a little later.
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(vec2(p.x, p.y * 0.72));
	float start = 1.05 - reach;
	float v = smoothstep(start - softness, start + softness * 0.35, d);
	COLOR = vec4(tint.rgb, max(clamp(v * darkness, 0.0, 1.0), blackout));
}
