// Comic halftone post pass (spec §12.1, §15.12) for POSTER moments.
// Drawn on a full-screen ColorRect; `amount` animates 0 -> 1 -> 0.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float dot_size = 7.0;
uniform vec4 ink : source_color = vec4(0.043, 0.043, 0.063, 1.0);
uniform vec4 paper : source_color = vec4(1.0, 0.93, 0.78, 1.0);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float s = 0.7071;
	mat2 rot = mat2(vec2(s, -s), vec2(s, s));
	vec2 p = rot * (FRAGCOORD.xy / dot_size);
	vec2 cell = fract(p) - 0.5;
	float radius = sqrt(clamp(1.0 - lum * 1.4, 0.0, 1.0)) * 0.62;
	float d = 1.0 - smoothstep(radius - 0.06, radius, length(cell));
	vec3 poster = floor(c * 4.0 + 0.5) / 4.0;
	vec3 ht = mix(mix(paper.rgb, poster * 1.2, 0.7), ink.rgb, d);
	COLOR = vec4(mix(c, ht, amount), 1.0);
}
