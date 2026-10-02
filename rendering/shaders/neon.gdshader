// Neon tubes and signs (spec §15.12): unshaded HDR color that blooms through
// the environment glow; optional buzz-flicker.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.24, 0.65, 1.0);
uniform float energy = 3.0;
uniform float flicker : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;

void fragment() {
	float f = 1.0;
	if (flicker > 0.0) {
		float t = floor(TIME * 14.0 + seed * 31.0);
		float r = fract(sin(t * 12.9898 + seed) * 43758.5453);
		f = r < flicker * 0.35 ? 0.2 : 1.0;
	}
	ALBEDO = color.rgb * energy * f;
}
