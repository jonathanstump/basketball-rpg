class_name MeshLib
extends RefCounted
## Cached primitive meshes so the toybox builders share geometry.

static var _cache: Dictionary = {}


static func sphere(r: float, hemi: bool = false) -> SphereMesh:
	var key: String = "s|%s|%s" % [r, hemi]
	if not _cache.has(key):
		var m: SphereMesh = SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.is_hemisphere = hemi
		m.radial_segments = 16
		m.rings = 8
		_cache[key] = m
	return _cache[key]


static func capsule(r: float, h: float) -> CapsuleMesh:
	var key: String = "c|%s|%s" % [r, h]
	if not _cache.has(key):
		var m: CapsuleMesh = CapsuleMesh.new()
		m.radius = r
		m.height = maxf(h, r * 2.0)
		m.radial_segments = 12
		m.rings = 4
		_cache[key] = m
	return _cache[key]


static func cylinder(r: float, h: float, top_r: float = -1.0) -> CylinderMesh:
	var key: String = "y|%s|%s|%s" % [r, h, top_r]
	if not _cache.has(key):
		var m: CylinderMesh = CylinderMesh.new()
		m.bottom_radius = r
		m.top_radius = r if top_r < 0.0 else top_r
		m.height = h
		m.radial_segments = 14
		_cache[key] = m
	return _cache[key]


static func box(size: Vector3) -> BoxMesh:
	var key: String = "b|%s" % size
	if not _cache.has(key):
		var m: BoxMesh = BoxMesh.new()
		m.size = size
		_cache[key] = m
	return _cache[key]


static func torus(inner: float, outer: float) -> TorusMesh:
	var key: String = "t|%s|%s" % [inner, outer]
	if not _cache.has(key):
		var m: TorusMesh = TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 16
		m.ring_segments = 8
		_cache[key] = m
	return _cache[key]


static func plane(size: Vector2) -> PlaneMesh:
	var key: String = "p|%s" % size
	if not _cache.has(key):
		var m: PlaneMesh = PlaneMesh.new()
		m.size = size
		_cache[key] = m
	return _cache[key]


static func from_recipe(shape: String, size: Array) -> Mesh:
	var a: float = float(size[0]) if size.size() > 0 else 0.1
	var b: float = float(size[1]) if size.size() > 1 else a
	match shape:
		"sphere":
			return sphere(a)
		"hemi":
			return sphere(a, true)
		"capsule":
			return capsule(a, b)
		"cylinder":
			return cylinder(a, b)
		"cone":
			return cylinder(a, b, 0.0)
		"box":
			return box(Vector3(a, b, float(size[2]) if size.size() > 2 else a))
		"torus":
			return torus(a, b)
	return sphere(a)


static func clear_cache() -> void:
	_cache.clear()
