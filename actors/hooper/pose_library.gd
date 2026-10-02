class_name PoseLibrary
extends RefCounted
## Named poses + pose-sequence animations from data/poses/<set>.json
## (spec §15.11). sample() returns joint -> Vector3 euler degrees, plus the
## special keys "_root" (hips offset, m) and "_root_rot" (hips rotation, deg).

var poses: Dictionary = {}
var anims: Dictionary = {}
var state_map: Dictionary = {}

static var _sets: Dictionary = {}


static func get_set(set_name: String) -> PoseLibrary:
	if _sets.has(set_name):
		return _sets[set_name]
	var lib: PoseLibrary = PoseLibrary.new()
	var d: Dictionary = DataDB.get_dict("poses/" + set_name)
	lib.poses = JU.dict(d, "poses")
	lib.anims = JU.dict(d, "anims")
	lib.state_map = JU.dict(d, "state_map")
	_sets[set_name] = lib
	return lib


static func clear_cache() -> void:
	_sets.clear()


func anim_for_state(state: String) -> String:
	if anims.has(state):
		return state
	return str(state_map.get(state, "idle"))


func has_anim(name: String) -> bool:
	return anims.has(name)


func duration(anim: String) -> float:
	var total: float = 0.0
	for k: Variant in JU.a(JU.dict(anims, anim), "keys"):
		total += float((k as Array)[1])
	return total


func pose(name: String) -> Dictionary:
	## Pose with JSON arrays converted to Vector3 (cached).
	var key: String = "_v_" + name
	if poses.has(key):
		return poses[key]
	var out: Dictionary = {}
	var raw: Dictionary = JU.dict(poses, name)
	for k: Variant in raw.keys():
		out[k] = JU.vec3(raw[k])
	poses[key] = out
	return out


func sample(anim: String, t: float) -> Dictionary:
	var a: Dictionary = JU.dict(anims, anim)
	var keys: Array = JU.a(a, "keys")
	if keys.is_empty():
		return pose("idle")
	var loop: bool = JU.b(a, "loop")
	var total: float = duration(anim)
	if loop and total > 0.0:
		t = fmod(t, total)
	var acc: float = 0.0
	for i: int in keys.size():
		var k: Array = keys[i]
		var d: float = float(k[1])
		if t < acc + d or i == keys.size() - 1:
			var next_i: int = i + 1
			if next_i >= keys.size():
				if not loop:
					return pose(str(k[0]))
				next_i = 0
			var f: float = clampf((t - acc) / maxf(d, 0.0001), 0.0, 1.0)
			f = f * f * (3.0 - 2.0 * f)
			return blend(pose(str(k[0])), pose(str((keys[next_i] as Array)[0])), f)
		acc += d
	return pose(str((keys[keys.size() - 1] as Array)[0]))


static func blend(a: Dictionary, b: Dictionary, f: float) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in a.keys():
		out[k] = JU.vec3(a[k])
	for k2: Variant in b.keys():
		var vb: Vector3 = JU.vec3(b[k2])
		var va: Vector3 = out.get(k2, Vector3.ZERO)
		out[k2] = va.lerp(vb, f)
	for k3: Variant in out.keys():
		if not b.has(k3):
			out[k3] = (out[k3] as Vector3).lerp(Vector3.ZERO, f)
	return out
