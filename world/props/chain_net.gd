class_name ChainNet
extends Node3D
## Procedural verlet net hanging from a rim (spec §15.6): chain links for
## outdoor courts ("ching"), white nylon indoors (swish). Segments are drawn
## as a MultiMesh of thin boxes; swish() kicks the nodes downward.

const STRANDS: int = 10
const NODES: int = 5
const SEG: float = 0.1

var rim_radius: float = 0.23
var kind: String = "chain"
var _pts: Array[Vector3] = []
var _prev: Array[Vector3] = []
var _mm: MultiMeshInstance3D
var _links: Array[Vector2i] = []


func _ready() -> void:
	for s: int in STRANDS:
		var ang: float = TAU * float(s) / float(STRANDS)
		for n: int in NODES:
			var taper: float = 1.0 - 0.35 * float(n) / float(NODES - 1)
			var p: Vector3 = Vector3(cos(ang) * rim_radius * taper, -SEG * float(n), sin(ang) * rim_radius * taper)
			_pts.append(p)
			_prev.append(p)
	for s2: int in STRANDS:
		for n2: int in range(NODES - 1):
			_links.append(Vector2i(_idx(s2, n2), _idx(s2, n2 + 1)))
			_links.append(Vector2i(_idx(s2, n2), _idx((s2 + 1) % STRANDS, n2 + 1)))
	_mm = MultiMeshInstance3D.new()
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = MeshLib.box(Vector3(0.012, 1.0, 0.012))
	mm.instance_count = _links.size()
	_mm.multimesh = mm
	var col: Color = Color("#C8CCD4") if kind == "chain" else Color("#F4F4F4")
	_mm.material_override = ToonMaterials.toon(col, false, false, col if kind == "chain" else Color.BLACK, 0.3 if kind == "chain" else 0.0)
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mm)
	_update_mesh()


func _idx(s: int, n: int) -> int:
	return s * NODES + n


func swish(strength: float = 1.0) -> void:
	for i: int in _pts.size():
		if i % NODES != 0:
			_prev[i] = _pts[i] + Vector3(0, 0.05 * strength, 0)


func _process(delta: float) -> void:
	var g: Vector3 = Vector3(0, -9.8, 0) * delta * delta
	for i: int in _pts.size():
		if i % NODES == 0:
			continue
		var cur: Vector3 = _pts[i]
		var vel: Vector3 = (cur - _prev[i]) * 0.94
		_prev[i] = cur
		_pts[i] = cur + vel + g
	for _iter: int in 3:
		for s: int in STRANDS:
			for n: int in range(1, NODES):
				var a: int = _idx(s, n - 1)
				var b: int = _idx(s, n)
				var d: Vector3 = _pts[b] - _pts[a]
				var len_v: float = d.length()
				if len_v < 0.0001:
					continue
				var diff: float = (len_v - SEG) / len_v
				if n - 1 == 0:
					_pts[b] -= d * diff
				else:
					_pts[a] += d * diff * 0.5
					_pts[b] -= d * diff * 0.5
	_update_mesh()


func _update_mesh() -> void:
	var mm: MultiMesh = _mm.multimesh
	for i: int in _links.size():
		var a: Vector3 = _pts[_links[i].x]
		var b: Vector3 = _pts[_links[i].y]
		var mid: Vector3 = (a + b) * 0.5
		var dir: Vector3 = b - a
		var length: float = maxf(dir.length(), 0.001)
		var y: Vector3 = dir / length
		var x: Vector3 = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		var z: Vector3 = x.cross(y)
		mm.set_instance_transform(i, Transform3D(Basis(x, y * length, z), mid))
