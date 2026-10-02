// Toybox toon shader (spec §15.12): 3-band diffuse, hard spec, palette-tinted
// fresnel rim, emission, optional occlusion cutaway, optional checker/stripe.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

#include "res://rendering/shaders/occlusion_dither.gdshaderinc"
#include "res://rendering/shaders/toon_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(0.8, 0.8, 0.8, 1.0);
global uniform vec4 cc_rim_tint;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.45;
uniform float spec_strength : hint_range(0.0, 2.0) = 0.3;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform bool occludable = false;
uniform float flash = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (occludable && cc_occluded(world_pos, CAMERA_POSITION_WORLD, FRAGCOORD.xy)) {
		discard;
	}
	ALBEDO = albedo.rgb * tint.rgb;
	ROUGHNESS = 0.85;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = emission_color.rgb * emission_energy + cc_rim_tint.rgb * rim * rim_strength * 0.35 + vec3(flash);
}

void light() {
	cc_toon_light(NORMAL, LIGHT, VIEW, ATTENUATION, LIGHT_COLOR, spec_strength, DIFFUSE_LIGHT, SPECULAR_LIGHT);
}
