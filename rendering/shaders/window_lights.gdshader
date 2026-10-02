// Facade shader (spec §15.12): world-space window grid -> hashed lit/unlit
// windows with warm/cool tints and rare flicker. Works on plain boxes (no UVs).
shader_type spatial;
render_mode blend_mix, cull_back;

#include "res://rendering/shaders/occlusion_dither.gdshaderinc"
#include "res://rendering/shaders/toon_light.gdshaderinc"

uniform vec4 wall_color : source_color = vec4(0.45, 0.25, 0.2, 1.0);
uniform vec4 roof_color : source_color = vec4(0.12, 0.12, 0.15, 1.0);
uniform vec4 warm_light : source_color = vec4(1.0, 0.78, 0.45, 1.0);
uniform vec4 cool_light : source_color = vec4(0.55, 0.75, 1.0, 1.0);
global uniform vec4 cc_rim_tint;
uniform float floor_h = 3.0;
uniform float window_w = 2.0;
uniform float ground_floor_h = 3.0;
uniform float lit_ratio : hint_range(0.0, 1.0) = 0.4;
uniform float window_energy = 2.2;
uniform float seed = 0.0;
uniform bool occludable = true;

varying vec3 world_pos;
varying vec3 world_normal;

float cc_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (occludable && cc_occluded(world_pos, CAMERA_POSITION_WORLD, FRAGCOORD.xy)) {
		discard;
	}
	vec3 col = wall_color.rgb;
	vec3 emit = vec3(0.0);
	if (abs(world_normal.y) < 0.5) {
		float u = abs(world_normal.x) > abs(world_normal.z) ? world_pos.z : world_pos.x;
		float v = world_pos.y - ground_floor_h;
		vec2 cell = vec2(floor(u / window_w), floor(v / floor_h));
		vec2 f = vec2(fract(u / window_w), fract(v / floor_h));
		bool is_window = v > 0.0 && f.x > 0.2 && f.x < 0.8 && f.y > 0.28 && f.y < 0.85;
		if (is_window) {
			vec2 key = cell + vec2(seed, seed * 1.7) + floor(world_normal.xz * 3.0) * 13.0;
			float h = cc_hash(key);
			if (h < lit_ratio) {
				vec3 tint = cc_hash(key + 3.1) > 0.3 ? warm_light.rgb : cool_light.rgb;
				float flick = cc_hash(key + 7.7) > 0.97 ? step(0.3, fract(sin(floor(TIME * 9.0) + h * 50.0) * 43.0)) : 1.0;
				col = tint * 0.25;
				emit = tint * window_energy * flick;
			} else {
				col = vec3(0.04, 0.05, 0.09);
			}
		} else if (abs(f.y - 0.22) < 0.04 && v > 0.0) {
			col = wall_color.rgb * 0.7;
		}
	} else {
		col = roof_color.rgb;
	}
	ALBEDO = col;
	ROUGHNESS = 0.9;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = emit + cc_rim_tint.rgb * rim * 0.12;
}

void light() {
	cc_toon_light(NORMAL, LIGHT, VIEW, ATTENUATION, LIGHT_COLOR, 0.1, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
