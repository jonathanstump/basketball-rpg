// Procedural half-court floor (spec §9.1): painted key, free-throw circle and
// 6.75 m three-point arc relative to the hoop. `arc_glow` lights the arc while
// the player still has to clear the ball (§7.10).
shader_type spatial;

#include "res://rendering/shaders/toon_light.gdshaderinc"

uniform vec4 floor_color : source_color = vec4(0.17, 0.36, 0.56, 1.0);
uniform vec4 key_color : source_color = vec4(0.55, 0.12, 0.16, 1.0);
uniform vec4 line_color : source_color = vec4(0.95, 0.96, 1.0, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);
uniform vec3 hoop_floor = vec3(0.0, 0.0, -10.0);
uniform vec3 hoop_facing = vec3(0.0, 0.0, 1.0);
uniform float arc_radius = 6.75;
uniform float key_width = 4.9;
uniform float key_length = 5.8;
uniform float line_w = 0.06;
uniform float arc_glow = 0.0;
uniform float wood = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float cc_line(float d, float w) {
	return 1.0 - smoothstep(w * 0.5, w * 0.5 + 0.015, abs(d));
}

void fragment() {
	vec2 f = normalize(hoop_facing.xz);
	vec2 s = vec2(f.y, -f.x);
	vec2 rel = world_pos.xz - hoop_floor.xz;
	float along = dot(rel, f) + 1.2;   // baseline sits 1.2 m behind the rim
	float side = dot(rel, s);
	vec3 col = floor_color.rgb;
	if (wood > 0.5) {
		col *= 0.92 + 0.08 * step(0.5, fract(world_pos.x * 1.4 + floor(world_pos.z * 0.25) * 0.37));
	}
	bool in_key = along > 0.0 && along < key_length && abs(side) < key_width * 0.5;
	if (in_key) {
		col = key_color.rgb;
	}
	float lines = 0.0;
	lines = max(lines, cc_line(along, line_w) * step(abs(side), 7.5));
	if (along > 0.0 && along < key_length + 0.02) {
		lines = max(lines, cc_line(abs(side) - key_width * 0.5, line_w));
	}
	if (abs(side) < key_width * 0.5) {
		lines = max(lines, cc_line(along - key_length, line_w));
	}
	float ft = length(vec2(along - key_length, side));
	lines = max(lines, cc_line(ft - 1.8, line_w) * step(key_length, along));
	float arc = length(rel);
	float arc_line = cc_line(arc - arc_radius, line_w * 1.4) * step(-1.2, along);
	lines = max(lines, arc_line);
	col = mix(col, line_color.rgb, lines);
	ALBEDO = col;
	ROUGHNESS = 0.6;
	EMISSION = glow_color.rgb * arc_line * arc_glow * 2.0;
}

void light() {
	cc_toon_light(NORMAL, LIGHT, VIEW, ATTENUATION, LIGHT_COLOR, 0.15, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
