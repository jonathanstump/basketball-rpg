// Tilt-shift blur (spec D2, §12.1): sharp horizontal band, blurred top and
// bottom for the toy-diorama look. Mip-based so it's cheap.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float focus_center = 0.55;
uniform float focus_width = 0.35;
uniform float max_lod = 2.2;
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float d = abs(SCREEN_UV.y - focus_center);
	float b = smoothstep(focus_width * 0.5, focus_width * 0.5 + 0.35, d) * max_lod * amount;
	COLOR = vec4(textureLod(screen_tex, SCREEN_UV, b).rgb, 1.0);
}
