// Distant skyline (playtest R2): far tower silhouettes with lit window grids.
// Unshaded and fog-free; a manual haze toward the horizon color keeps them
// readable through the district fog. One MultiMesh per mesh kind:
// COLOR = wall tint, INSTANCE_CUSTOM.x = window seed, .y = lit ratio,
// .z = style (0 windows, 1 glass curtain, 2 lit crown, 3 beacon tip).
shader_type spatial;
render_mode unshaded, fog_disabled, cull_back, shadows_disabled;

uniform vec4 haze_color : source_color = vec4(0.16, 0.1, 0.2, 1.0);
uniform vec4 warm_light : source_color = vec4(1.0, 0.78, 0.45, 1.0);
uniform vec4 cool_light : source_color = vec4(0.55, 0.75, 1.0, 1.0);
uniform float haze = 0.55;
uniform float floor_h = 4.0;
uniform float window_w = 3.2;
uniform float window_energy = 1.6;
uniform vec4 accent : source_color = vec4(1.0, 0.79, 0.24, 1.0);

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 tint;
varying vec3 custom;

float sk_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tint = COLOR;
	custom = INSTANCE_CUSTOM.xyz;
}

void fragment() {
	vec3 col = tint.rgb;
	int style = int(custom.z + 0.5);
	if (style == 3) {
		// Aircraft beacon: a slow red blink at the tip.
		float blink = step(0.55, fract(TIME * 0.6 + custom.x * 7.0));
		ALBEDO = mix(tint.rgb * 1.3, vec3(1.0, 0.15, 0.1) * 2.5, blink * 0.7);
	} else if (style == 2) {
		// Lit crown: the borough's accent washing up the top.
		ALBEDO = mix(tint.rgb, accent.rgb * 1.8, 0.75);
	} else if (style == 1 && abs(world_normal.y) < 0.5) {
		// Glass curtain: tall bright mullion strips, a few lit floors.
		float u = abs(world_normal.x) > abs(world_normal.z) ? world_pos.z : world_pos.x;
		float strip = step(0.86, fract(u / 2.4));
		float fl = floor(world_pos.y / floor_h);
		float lit_floor = step(1.0 - custom.y * 0.6, sk_hash(vec2(fl, custom.x * 53.0)));
		col = mix(tint.rgb * 1.1 + vec3(0.01, 0.03, 0.06), cool_light.rgb * 0.7, strip * 0.28);
		col = mix(col, warm_light.rgb * window_energy * 0.8, lit_floor * step(0.35, fract(world_pos.y / floor_h)) * 0.8);
		col = mix(col, haze_color.rgb * 1.6, clamp(world_pos.y / 260.0, 0.0, 0.35));
		ALBEDO = mix(col, haze_color.rgb, haze * (1.0 - clamp(world_pos.y / 200.0, 0.0, 0.5)));
	} else if (abs(world_normal.y) < 0.5) {
		float u = abs(world_normal.x) > abs(world_normal.z) ? world_pos.z : world_pos.x;
		vec2 cell = vec2(floor(u / window_w), floor(world_pos.y / floor_h));
		vec2 f = vec2(fract(u / window_w), fract(world_pos.y / floor_h));
		if (world_pos.y > 3.0 && f.x > 0.25 && f.x < 0.75 && f.y > 0.3 && f.y < 0.8) {
			vec2 key = cell + vec2(custom.x * 91.0, custom.x * 17.0) + floor(world_normal.xz * 3.0) * 13.0;
			float h = sk_hash(key);
			if (h < custom.y) {
				vec3 lt = sk_hash(key + 3.1) > 0.35 ? warm_light.rgb : cool_light.rgb;
				col = lt * window_energy;
			} else {
				col = tint.rgb * 0.6;
			}
		}
		// lighter toward the top: city glow on the haze
		col = mix(col, haze_color.rgb * 1.6, clamp(world_pos.y / 260.0, 0.0, 0.35));
		ALBEDO = mix(col, haze_color.rgb, haze * (1.0 - clamp(world_pos.y / 200.0, 0.0, 0.5)));
	} else {
		col = tint.rgb * 0.7;
		ALBEDO = mix(col, haze_color.rgb, haze * (1.0 - clamp(world_pos.y / 200.0, 0.0, 0.5)));
	}
}
