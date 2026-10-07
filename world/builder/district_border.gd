class_name DistrictBorder
extends RefCounted
## The edge of a district (revision 10): instead of haze where the ground
## stops, a stone quay with a railing and lamps, harbor water out to a far
## shore, and the borough's bridges you can see but never cross (tuning
## camera.skyline.profiles.<borough>.bridges: suspension with stone or steel
## towers, steel arch, or truss). No collision (the map's '#' ring already
## stops you) and no real lights: emissive "necklace" bulbs only (§15.17).

const WATER_SHADER: Shader = preload("res://rendering/shaders/harbor_water.gdshader")
const DECK_Y: float = 9.0
const DECK_W: float = 14.0


static func build(m: MapData, borough: String, root: Node3D) -> Node3D:
	var holder: Node3D = Node3D.new()
	holder.name = "Border"
	var prof: Dictionary = DistrictSkyline.profile(borough)
	var half: float = maxf(float(m.width), float(m.height)) * MapData.TILE * 0.5
	var shore: float = DistrictSkyline.ring_inner(m, borough)
	holder.add_child(_water(half, shore, prof))
	holder.add_child(_far_shore(shore))
	var b: MeshBatcher = MeshBatcher.new()
	_quay(b, half - MapData.TILE)
	for br: Variant in JU.a(prof, "bridges"):
		bridge(b, br as Dictionary, half - MapData.TILE, shore)
	b.flush(holder, false)
	if root != null:
		root.add_child(holder)
	return holder


static func _mats() -> Dictionary:
	return {
		"stone": ToonMaterials.toon(Color("#4A4650"), false, false, Color("#2A2830"), 0.25),
		"steel": ToonMaterials.toon(Color("#2C3644"), false, false, Color("#3A4C66"), 0.35),
		"green": ToonMaterials.toon(Color("#2E4A44"), false, false, Color("#365C54"), 0.3),
		"rail": ToonMaterials.toon(Color("#1C2028"), false),
		"bulb": ToonMaterials.toon(Color("#FFF0C8"), false, false, Color("#FFE4A0"), 3.0),
		"lamp": ToonMaterials.toon(Color("#FFD890"), false, false, Color("#FFC870"), 2.2),
	}


static func _water(half: float, shore: float, prof: Dictionary) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Water"
	mi.mesh = MeshLib.plane(Vector2.ONE * (shore + 60.0) * 2.0)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = WATER_SHADER
	mat.set_shader_parameter("deep", JU.color(prof.get("water", "#0A1830")))
	mat.set_shader_parameter("accent", JU.color(prof.get("accent", "#FFC93C")))
	mat.set_shader_parameter("shore_r", shore)
	mat.set_shader_parameter("edge_r", half)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, -1.6, 0)
	return mi


static func _far_shore(shore: float) -> MeshInstance3D:
	## A flat dark ring of land the skyline stands on.
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "FarShore"
	var t: TorusMesh = TorusMesh.new()
	t.inner_radius = shore
	t.outer_radius = shore + 700.0
	t.rings = 64
	t.ring_segments = 4
	mi.mesh = t
	mi.scale = Vector3(1, 0.004, 1)
	mi.position = Vector3(0, -1.2, 0)
	mi.material_override = ToonMaterials.toon(Color("#121018"), false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _quay(b: MeshBatcher, e: float) -> void:
	## Seawall + railing + lamps along the four edges, `e` from the center.
	var mats: Dictionary = _mats()
	for side: int in 4:
		var n: Vector3 = [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)][side]
		var along: Vector3 = Vector3(-n.z, 0, n.x)
		var c: Vector3 = n * (e + 0.6)
		var yaw: float = rad_to_deg(atan2(n.x, n.z))
		b.add_at(MeshLib.box(Vector3(e * 2.0 + 2.4, 2.4, 1.2)), mats["stone"], c + Vector3(0, -0.6, 0), Vector3(0, yaw, 0))
		b.add_at(MeshLib.box(Vector3(e * 2.0 + 2.4, 0.08, 0.08)), mats["rail"], c + Vector3(0, 1.65, 0), Vector3(0, yaw, 0))
		b.add_at(MeshLib.box(Vector3(e * 2.0 + 2.4, 0.06, 0.06)), mats["rail"], c + Vector3(0, 1.15, 0), Vector3(0, yaw, 0))
		var k: int = 0
		var s: float = -e
		while s <= e:
			var p: Vector3 = c + along * s
			b.add_at(MeshLib.box(Vector3(0.08, 1.1, 0.08)), mats["rail"], p + Vector3(0, 1.1, 0))
			if k % 8 == 0:
				b.add_at(MeshLib.cylinder(0.07, 4.2), mats["rail"], p + Vector3(0, 2.1, 0) - n * 0.3)
				b.add_at(MeshLib.sphere(0.28), mats["lamp"], p + Vector3(0, 4.3, 0) - n * 0.3)
			s += 2.5
			k += 1


static func _seg(b: MeshBatcher, mesh: Mesh, mat: Material, a: Vector3, c: Vector3, thick: float) -> void:
	## A thin box from a to c (cables, ribs, chords).
	var d: Vector3 = c - a
	var l: float = d.length()
	if l < 0.01:
		return
	var basis: Basis = Basis.looking_at(d / l, Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)
	b.add(mesh, mat, Transform3D(basis * Basis.from_scale(Vector3(thick, thick, l)), (a + c) * 0.5))   # scale on the segment's own axes


static func bridge(b: MeshBatcher, spec: Dictionary, e: float, shore: float) -> void:
	var mats: Dictionary = _mats()
	var ang: float = deg_to_rad(JU.f(spec, "deg", 0.0))
	var dir: Vector3 = Vector3(sin(ang), 0, -cos(ang))
	var p0: Vector3 = dir * (e / maxf(absf(dir.x), absf(dir.z))) + Vector3(0, DECK_Y, 0)
	var p1: Vector3 = dir * (shore + 8.0) + Vector3(0, DECK_Y, 0)
	var side: Vector3 = Vector3(-dir.z, 0, dir.x)
	var unit: BoxMesh = MeshLib.box(Vector3.ONE)
	var style: String = JU.s(spec, "style", "suspension")
	var tower_mat: Material = mats["stone"] if JU.s(spec, "tower") == "stone" else (mats["green"] if style == "truss" else mats["steel"])
	# Deck, abutment and pier at the quay, road lamps along both edges.
	_seg(b, unit, mats["steel"], p0, p1, 1.0)
	for s: float in [-1.0, 1.0]:
		_seg(b, unit, mats["rail"], p0 + side * (DECK_W * 0.5 * s), p1 + side * (DECK_W * 0.5 * s), 0.3)
	b.add_at(MeshLib.box(Vector3(DECK_W + 4.0, DECK_Y + 2.0, 6.0)), mats["stone"], p0 - Vector3(0, DECK_Y * 0.5 + 0.6, 0) + dir * 2.0, Vector3(0, rad_to_deg(ang), 0))
	var span: float = p0.distance_to(p1)
	var t: float = 0.0
	while t <= span:
		for s2: float in [-1.0, 1.0]:
			b.add_at(MeshLib.box(Vector3(0.35, 0.35, 0.35)), mats["bulb"], p0 + dir * t + side * (DECK_W * 0.5 * s2) + Vector3(0, 1.4, 0))
		t += 9.0
	match style:
		"arch":
			_arch(b, mats, p0, p1, side, tower_mat)
		"truss":
			_truss(b, mats, p0, p1, side, tower_mat)
		_:
			_suspension(b, mats, p0, p1, side, tower_mat, JU.s(spec, "tower") == "stone")


static func _suspension(b: MeshBatcher, mats: Dictionary, p0: Vector3, p1: Vector3, side: Vector3, tower_mat: Material, stone: bool) -> void:
	var unit: BoxMesh = MeshLib.box(Vector3.ONE)
	var dir: Vector3 = (p1 - p0).normalized()
	var span: float = p0.distance_to(p1)
	var tower_h: float = 34.0 if stone else 44.0
	var towers: Array[float] = [span * 0.2, span * 0.8]
	for tt: float in towers:
		var base: Vector3 = p0 + dir * tt - Vector3(0, DECK_Y + 1.6, 0)
		for s: float in [-1.0, 1.0]:
			var leg_w: float = 3.2 if stone else 1.6
			_seg(b, unit, tower_mat, base + side * (DECK_W * 0.5 + leg_w * 0.4) * s, base + side * (DECK_W * 0.5 + leg_w * 0.4) * s + Vector3(0, DECK_Y + 1.6 + tower_h, 0), leg_w)
		for yb: float in ([tower_h * 0.55, tower_h * 0.98] if stone else [tower_h * 0.4, tower_h * 0.7, tower_h * 0.98]):
			_seg(b, unit, tower_mat, base - side * (DECK_W * 0.5 + 1.4) + Vector3(0, DECK_Y + 1.6 + yb, 0), base + side * (DECK_W * 0.5 + 1.4) + Vector3(0, DECK_Y + 1.6 + yb, 0), 2.4 if stone else 1.2)
	# Main cables: anchor -> tower -> sag -> tower -> anchor, lit like a necklace.
	for s3: float in [-1.0, 1.0]:
		var off: Vector3 = side * (DECK_W * 0.5 + 0.5) * s3
		var pts: Array[Vector3] = []
		var n: int = 36
		for i: int in n + 1:
			var u: float = float(i) / float(n) * span
			var y: float
			if u < towers[0]:
				y = lerpf(2.0, tower_h, u / towers[0])
			elif u > towers[1]:
				y = lerpf(tower_h, 2.0, (u - towers[1]) / (span - towers[1]))
			else:
				var v: float = (u - towers[0]) / (towers[1] - towers[0])
				y = 4.0 + (tower_h - 4.0) * pow(2.0 * v - 1.0, 2.0)
			pts.append(p0 + dir * u + off + Vector3(0, y, 0))
		for i2: int in n:
			_seg(b, unit, mats["rail"], pts[i2], pts[i2 + 1], 0.35)
			b.add_at(MeshLib.box(Vector3(0.45, 0.45, 0.45)), mats["bulb"], pts[i2])
			if i2 % 2 == 0:
				_seg(b, unit, mats["rail"], pts[i2], Vector3(pts[i2].x, p0.y, pts[i2].z), 0.08)


static func _arch(b: MeshBatcher, mats: Dictionary, p0: Vector3, p1: Vector3, side: Vector3, mat: Material) -> void:
	var unit: BoxMesh = MeshLib.box(Vector3.ONE)
	var dir: Vector3 = (p1 - p0).normalized()
	var span: float = p0.distance_to(p1)
	var rise: float = minf(36.0, span * 0.35)
	var n: int = 28
	for s: float in [-1.0, 1.0]:
		var off: Vector3 = side * (DECK_W * 0.5 + 0.8) * s
		for i: int in n:
			var u0: float = float(i) / float(n)
			var u1: float = float(i + 1) / float(n)
			var a: Vector3 = p0 + dir * (u0 * span) + off + Vector3(0, rise * 4.0 * u0 * (1.0 - u0) - DECK_Y * 0.4 * (1.0 - 4.0 * u0 * (1.0 - u0)), 0)
			var c: Vector3 = p0 + dir * (u1 * span) + off + Vector3(0, rise * 4.0 * u1 * (1.0 - u1) - DECK_Y * 0.4 * (1.0 - 4.0 * u1 * (1.0 - u1)), 0)
			_seg(b, unit, mat, a, c, 1.8)
			b.add_at(MeshLib.box(Vector3(0.5, 0.5, 0.5)), mats["bulb"], a + Vector3(0, 1.1, 0))
			if i % 2 == 0 and a.y > p0.y + 1.0:
				_seg(b, unit, mats["rail"], a, Vector3(a.x, p0.y, a.z), 0.15)


static func _truss(b: MeshBatcher, mats: Dictionary, p0: Vector3, p1: Vector3, side: Vector3, mat: Material) -> void:
	var unit: BoxMesh = MeshLib.box(Vector3.ONE)
	var dir: Vector3 = (p1 - p0).normalized()
	var span: float = p0.distance_to(p1)
	var hgt: float = 11.0
	var step: float = 8.0
	for s: float in [-1.0, 1.0]:
		var off: Vector3 = side * (DECK_W * 0.5 + 0.4) * s
		_seg(b, unit, mat, p0 + off + Vector3(0, hgt, 0), p1 + off + Vector3(0, hgt, 0), 0.9)
		var t: float = 0.0
		var k: int = 0
		while t + step <= span + 0.01:
			var a: Vector3 = p0 + dir * t + off
			var c: Vector3 = p0 + dir * (t + step) + off
			_seg(b, unit, mat, a, a + Vector3(0, hgt, 0), 0.6)
			_seg(b, unit, mat, a, c + Vector3(0, hgt, 0), 0.45)
			_seg(b, unit, mat, a + Vector3(0, hgt, 0), c, 0.45)
			b.add_at(MeshLib.box(Vector3(0.45, 0.45, 0.45)), mats["bulb"], a + Vector3(0, hgt + 0.7, 0))
			t += step
			k += 1
	# Piers down to the water.
	var t2: float = span * 0.33
	while t2 < span:
		b.add_at(MeshLib.box(Vector3(DECK_W + 2.0, DECK_Y + 2.0, 4.0)), mats["stone"], p0 + dir * t2 - Vector3(0, DECK_Y * 0.5 + 1.0, 0), Vector3(0, rad_to_deg(atan2(dir.x, dir.z)), 0))
		t2 += span * 0.33
