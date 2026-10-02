// Occlusion cutaway (spec D2, §15.12): screen-door fade for geometry that sits
// between the camera and the focus (player). The focus position is a global
// shader parameter written every frame by the CameraRig, so this works for
// MultiMesh batches too (no per-object raycast state needed).
global uniform vec3 cc_focus_pos;
global uniform float cc_cutaway_radius;

const float CC_BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

bool cc_occluded(vec3 world_pos, vec3 cam_pos, vec2 frag_coord) {
	vec3 to_focus = cc_focus_pos - cam_pos;
	float len = length(to_focus);
	if (len < 0.01) {
		return false;
	}
	vec3 dir = to_focus / len;
	vec3 rel = world_pos - cam_pos;
	float t = dot(rel, dir);
	if (t <= 0.0 || t >= len - 0.5) {
		return false;
	}
	float dist = length(rel - dir * t);
	float r = cc_cutaway_radius * smoothstep(0.0, 3.0, len - t);
	if (dist > r) {
		return false;
	}
	float fade = 1.0 - smoothstep(r * 0.55, r, dist);
	int x = int(mod(frag_coord.x, 4.0));
	int y = int(mod(frag_coord.y, 4.0));
	float threshold = (CC_BAYER[y * 4 + x] + 0.5) / 16.0;
	return fade * 0.9 > threshold;
}
