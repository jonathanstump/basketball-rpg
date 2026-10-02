// Stylized night sky (spec §12.5): blue-violet gradient, orange city-glow
// horizon, a flat toon moon and sparse stars. Dawn preset reuses it.
shader_type sky;

uniform vec4 top_color : source_color = vec4(0.05, 0.04, 0.14, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.18, 0.1, 0.25, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.45, 0.2, 1.0);
uniform float glow_strength = 0.6;
uniform vec3 moon_dir = vec3(0.4, 0.45, -0.8);
uniform vec4 moon_color : source_color = vec4(1.0, 0.96, 0.85, 1.0);
uniform float moon_size = 0.035;
uniform float stars = 0.5;
uniform vec4 sun_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

float cc_hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float y = dir.y;
	vec3 col = mix(horizon_color.rgb, top_color.rgb, smoothstep(-0.05, 0.55, y));
	col += glow_color.rgb * pow(1.0 - clamp(abs(y), 0.0, 1.0), 7.0) * glow_strength;
	float m = dot(dir, normalize(moon_dir));
	float disk = smoothstep(1.0 - moon_size, 1.0 - moon_size * 0.9, m);
	float bite = smoothstep(1.0 - moon_size * 0.9, 1.0 - moon_size * 0.8, dot(dir, normalize(moon_dir + vec3(0.025, 0.02, 0.0))));
	col = mix(col, moon_color.rgb * 1.6, clamp(disk - bite * 0.85, 0.0, 1.0));
	if (y > 0.05 && stars > 0.0) {
		vec3 cell = floor(dir * 220.0);
		float s = cc_hash3(cell);
		col += vec3(step(1.0 - 0.004 * stars, s)) * 0.8 * smoothstep(0.05, 0.3, y);
	}
	col += sun_color.rgb * pow(clamp(dot(dir, normalize(vec3(0.0, 0.15, -1.0))), 0.0, 1.0), 40.0) * 3.0;
	COLOR = col;
}
