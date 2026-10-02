// Inverted-hull outline (spec §15.12), used as next_pass on toon materials.
// Width scales with camera distance so outlines stay readable at 12 m.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque;

#include "res://rendering/shaders/occlusion_dither.gdshaderinc"

uniform vec4 outline_color : source_color = vec4(0.043, 0.043, 0.063, 1.0);
uniform float width = 0.012;
uniform bool occludable = false;

varying vec3 world_pos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(CAMERA_POSITION_WORLD - wp);
	VERTEX += NORMAL * width * clamp(dist * 0.12, 0.6, 3.0);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (occludable && cc_occluded(world_pos, CAMERA_POSITION_WORLD, FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = outline_color.rgb;
}
