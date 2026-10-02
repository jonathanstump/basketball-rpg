class_name MeshBatcher
extends RefCounted
## Collects (mesh, material, transform) triples and emits one
## MultiMeshInstance3D per (mesh, material) pair (spec §15.10, §15.17: MultiMesh
## repeated props, < 2,500 draw calls). Also hashes the geometry so the
## builder's determinism can be tested.

var groups: Dictionary = {}   # key -> {mesh, mat, xforms: Array[Transform3D]}
var count: int = 0


func add(mesh: Mesh, mat: Material, xf: Transform3D) -> void:
	var key: String = "%d|%d" % [mesh.get_instance_id(), mat.get_instance_id() if mat != null else 0]
	if not groups.has(key):
		groups[key] = {"mesh": mesh, "mat": mat, "xforms": [] as Array[Transform3D]}
	((groups[key] as Dictionary)["xforms"] as Array[Transform3D]).append(xf)
	count += 1


func add_at(mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scale_v: Vector3 = Vector3.ONE) -> void:
	var b: Basis = Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))).scaled(scale_v)
	add(mesh, mat, Transform3D(b, pos))


func flush(parent: Node3D, shadows: bool = true) -> int:
	var n: int = 0
	for key: Variant in groups.keys():
		var g: Dictionary = groups[key]
		var xforms: Array[Transform3D] = g["xforms"]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = g["mesh"]
		mm.instance_count = xforms.size()
		for i: int in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = g["mat"]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
		n += 1
	return n


func geometry_hash() -> int:
	var parts: PackedStringArray = PackedStringArray()
	for key: Variant in groups.keys():
		var g: Dictionary = groups[key]
		var mesh: Mesh = g["mesh"]
		var acc: Vector3 = Vector3.ZERO
		for xf: Transform3D in (g["xforms"] as Array[Transform3D]):
			acc += xf.origin + xf.basis.x * 0.37 + xf.basis.y * 0.71 + xf.basis.z * 0.13
		parts.append("%s:%s:%d:%s" % [mesh.get_class(), mesh.get_aabb().size.snapped(Vector3(0.01, 0.01, 0.01)), (g["xforms"] as Array).size(), acc.snapped(Vector3(0.01, 0.01, 0.01))])
	parts.sort()
	return "|".join(parts).hash()
