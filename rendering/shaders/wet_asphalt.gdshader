// Wet asphalt (spec §15.12): noise puddle mask drives roughness so SSR and
// streetlight speculars read as rain-slick night streets.
shader_type spatial;

uniform vec4 albedo : source_color = vec4(0.118, 0.118, 0.141, 1.0);
uniform vec4 line_color : source_color = vec4(0.85, 0.75, 0.3, 1.0);
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.42;
uniform float puddle_scale = 0.18;
uniform float lane_lines = 0.0;

varying vec3 world_pos;

float cc_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cc_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(cc_hash(i), cc_hash(i + vec2(1.0, 0.0)), u.x),
		mix(cc_hash(i + vec2(0.0, 1.0)), cc_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz * puddle_scale;
	float n = cc_noise(p) * 0.6 + cc_noise(p * 2.7 + 5.0) * 0.4;
	float puddle = smoothstep(1.0 - puddle_amount, 1.0 - puddle_amount + 0.06, n);
	float grit = cc_noise(world_pos.xz * 6.0) * 0.08;
	vec3 base = albedo.rgb * (0.9 + grit);
	if (lane_lines > 0.5) {
		float dash = step(0.5, fract(world_pos.x * 0.25)) * (1.0 - step(0.12, abs(fract(world_pos.z / 8.0 + 0.5) - 0.5) * 8.0));
		base = mix(base, line_color.rgb * 0.6, dash * 0.0);
	}
	ALBEDO = mix(base, base * 0.4, puddle);
	ROUGHNESS = mix(0.82, 0.04, puddle);
	SPECULAR = mix(0.35, 0.9, puddle);
	METALLIC = 0.0;
}
