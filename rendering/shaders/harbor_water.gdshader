// Harbor water around a district (revision 10): dark rippling water with
// streaks of reflected shore light that brighten toward the far shore.
// Unlit (night), fogged so it melts into the haze at the horizon.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 deep : source_color = vec4(0.04, 0.09, 0.17, 1.0);
uniform vec4 glint_warm : source_color = vec4(1.0, 0.75, 0.4, 1.0);
uniform vec4 glint_cool : source_color = vec4(0.5, 0.75, 1.0, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 0.79, 0.24, 1.0);
uniform float shore_r = 200.0;     // radius of the far shore (world m)
uniform float edge_r = 128.0;      // half-size of the district

varying vec3 world_pos;

float hw_hash(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = length(world_pos.xz);
	float ang = atan(world_pos.z, world_pos.x);
	// Rolling ripples.
	float rip = sin(world_pos.x * 0.35 + TIME * 0.8) * sin(world_pos.z * 0.29 - TIME * 0.65);
	rip += 0.5 * sin((world_pos.x + world_pos.z) * 0.9 + TIME * 1.7);
	vec3 col = deep.rgb * (1.0 + 0.18 * rip);
	// Reflected shore lights: thin radial streaks, broken by the ripples.
	float lanes = ang * 1440.0 / 3.14159;          // quarter-degree lanes
	float lane = floor(lanes);
	float h = hw_hash(lane);
	float thin = 1.0 - abs(fract(lanes) - 0.5) * 2.0;   // brightest down the lane's middle
	float k = clamp((r - edge_r) / max(1.0, shore_r - edge_r), 0.0, 1.0);
	float shimmer = step(0.55, sin(r * 2.6 - TIME * 2.4 + h * 40.0) * 0.5 + 0.5 + 0.25 * rip);
	float streak = step(0.8, h) * smoothstep(0.35, 1.0, k) * shimmer * smoothstep(0.3, 0.9, thin);
	vec3 lc = h > 0.93 ? accent.rgb : (h > 0.82 ? glint_cool.rgb : glint_warm.rgb);
	col += lc * streak * 0.75;
	// A soft sheen near the quay from the streetlights.
	col += glint_warm.rgb * 0.08 * (1.0 - smoothstep(0.0, 0.12, k)) * (0.6 + 0.4 * rip);
	ALBEDO = col;
}
