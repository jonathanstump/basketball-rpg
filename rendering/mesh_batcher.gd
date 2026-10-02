class_name MeshBatcher
extends RefCounted
## Collects (mesh, material, transform) triples and emits one
## MultiMeshInstance3D per (mesh, material) pair (spec §15.10, §15.17: MultiMesh
## repeated props, < 2,500 draw calls). Also hashes the geometry so the
## builder's determinism can be tested.

const CHUNK_M: float = 32.0   # spatial chunks so camera/shadow culling can skip far groups

var groups: Dictionary = {}   # key -> {mesh, mat, xforms: Array[Transform3D]}
var count: int = 0


func add(mesh: Mesh, mat: Material, xf: Transform3D) -> void:
	var key: String = "%d|%d|%d|%d" % [mesh.get_instance_id(), mat.get_instance_id() if mat != null else 0,
		floori(xf.origin.x / CHUNK_M), floori(xf.origin.z / CHUNK_M)]
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
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows and casts_shadow(g["mesh"], xforms) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
		n += 1
	return n


func max_view_groups(radius_chunks: int = 1) -> int:
	## Most groups inside any (2r+1)^2 chunk window: what one camera view
	## can draw (the culled stand-in for the < 2,500 draw-call budget).
	var per_chunk: Dictionary = {}
	for key: Variant in groups.keys():
		var parts: PackedStringArray = str(key).split("|")
		var cell: Vector2i = Vector2i(int(parts[2]), int(parts[3]))
		per_chunk[cell] = int(per_chunk.get(cell, 0)) + 1
	var best: int = 0
	for c: Variant in per_chunk.keys():
		var center: Vector2i = c
		var n: int = 0
		for dx: int in range(-radius_chunks, radius_chunks + 1):
			for dz: int in range(-radius_chunks, radius_chunks + 1):
				n += int(per_chunk.get(center + Vector2i(dx, dz), 0))
		best = maxi(best, n)
	return best


static func casts_shadow(mesh: Mesh, xforms: Array[Transform3D]) -> bool:
	## Ground planes and small clutter skip the shadow passes: each shadowed
	## omni re-draws every caster in range (§15.17 draw-call budget).
	if mesh is PlaneMesh:
		return false
	var size: Vector3 = mesh.get_aabb().size
	if not xforms.is_empty():
		size *= xforms[0].basis.get_scale()
	return maxf(size.x, maxf(size.y, size.z)) >= 1.2


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
