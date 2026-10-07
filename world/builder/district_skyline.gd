class_name DistrictSkyline
extends RefCounted
## Distant skyline ring around a district (playtest R2, revision 10): across
## the water (DistrictBorder), a low lit waterfront and then towers of a
## few kinds (SkylineTowers: slabs, wedding-cake setbacks, art deco crowns,
## needle spires, round glass, twins), taller toward the City. Each borough
## has its own profile (tuning camera.skyline.profiles): how wide the water
## is, how tall and which kinds. One MultiMesh per mesh kind, no collision,
## no shadows.

const SHADER: Shader = preload("res://rendering/shaders/skyline.gdshader")


static func profile(borough: String) -> Dictionary:
	var cfg: Dictionary = JU.dict(DataDB.tuning("camera"), "skyline")
	return JU.dict(JU.dict(cfg, "profiles"), borough)


static func ring_inner(m: MapData, borough: String) -> float:
	## Where the far shore starts: the map edge plus the borough's water.
	var cfg: Dictionary = JU.dict(DataDB.tuning("camera"), "skyline")
	var half: float = maxf(float(m.width), float(m.height)) * MapData.TILE * 0.5
	return half + JU.f(profile(borough), "water_m", JU.f(cfg, "ring_inner_m", 60.0))


static func towers(m: MapData, borough: String) -> Array[Dictionary]:
	## Pure placement: parts [{mesh, pos (base center), size, yaw, tint_k,
	## seed, lit, style}] in world space. Deterministic from the map seed.
	var cfg: Dictionary = JU.dict(DataDB.tuning("camera"), "skyline")
	var prof: Dictionary = profile(borough)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = m.seed_value() + 7919
	var inner: float = ring_inner(m, borough)
	var depth: float = JU.f(cfg, "ring_depth_m", 220.0)
	var wr: PackedFloat32Array = JU.floats(cfg, "width_m")
	var hr: PackedFloat32Array = JU.floats(cfg, "height_m")
	var chr: PackedFloat32Array = JU.floats(cfg, "city_height_m")
	var lr: PackedFloat32Array = JU.floats(cfg, "lit_ratio")
	var hm: float = JU.f(prof, "height_mult", 1.0)
	var city_deg: float = JU.f(JU.dict(cfg, "city_dir_deg"), borough, -1.0)
	var arc: float = deg_to_rad(JU.f(cfg, "city_arc_deg", 70.0))
	var mix: Dictionary = JU.dict(prof, "mix")
	var out: Array[Dictionary] = []
	var n: int = JU.i(cfg, "towers", 170)
	for i: int in n:
		var ang: float = (float(i) + rng.randf_range(-0.4, 0.4)) / float(n) * TAU
		var r: float = inner + 18.0 + pow(rng.randf(), 0.6) * depth   # thinner front row, so it reads as a skyline, not a wall
		var dir: Vector3 = Vector3(sin(ang), 0.0, -cos(ang))
		## City-ward towers are much taller (in the City, everything is).
		var city_k: float = 1.0 if city_deg < 0.0 else clampf(1.0 - absf(angle_difference(ang, deg_to_rad(city_deg))) / arc, 0.0, 1.0)
		var h: float = lerpf(rng.randf_range(hr[0], hr[1]), rng.randf_range(chr[0], chr[1]), city_k) * hm
		h *= lerpf(0.75, 1.15, clampf((r - inner) / depth, 0.0, 1.0))   # farther rows peek over nearer ones
		var w: float = rng.randf_range(wr[0], wr[1])
		var kind: String = SkylineTowers.pick(mix, rng) if (city_k > 0.2 or rng.randf() < 0.45) else "slab"
		out.append_array(SkylineTowers.parts(kind, dir * r, w, h, rng.randf_range(wr[0], wr[1]), ang, rng.randf_range(lr[0], lr[1]), rng))
	## The far waterfront: a low lit row right at the shore.
	var shore_n: int = 140
	for j: int in shore_n:
		var a2: float = (float(j) + rng.randf_range(-0.3, 0.3)) / float(shore_n) * TAU
		var dir2: Vector3 = Vector3(sin(a2), 0.0, -cos(a2))
		var w2: float = rng.randf_range(8.0, 18.0)
		out.append(SkylineTowers._part("box", dir2 * (inner + rng.randf_range(3.0, 10.0)), Vector3(w2, rng.randf_range(6.0, 16.0), 8.0), a2, rng, rng.randf_range(0.3, 0.6), 0))
	return out


static func _mesh(kind: String) -> Mesh:
	match kind:
		"cyl":
			var c: CylinderMesh = CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 16
			return c
		"prism":
			var p: CylinderMesh = CylinderMesh.new()
			p.top_radius = 0.0
			p.bottom_radius = 0.7
			p.height = 1.0
			p.radial_segments = 4
			return p
		"needle":
			var nd: CylinderMesh = CylinderMesh.new()
			nd.top_radius = 0.04
			nd.bottom_radius = 0.5
			nd.height = 1.0
			nd.radial_segments = 6
			return nd
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE
	return box


static func build(m: MapData, borough: String, env_id: String, root: Node3D) -> Node3D:
	var list: Array[Dictionary] = towers(m, borough)
	var env: Dictionary = DataDB.item("environments", env_id)
	var base: Color = JU.color(env.get("sky_horizon", "#2A1A30"))
	var dark: Color = Color(0.05, 0.05, 0.08)
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("haze_color", JU.color(env.get("fog_color", "#2A1528")).lerp(base, 0.5))
	mat.set_shader_parameter("accent", JU.color(profile(borough).get("accent", "#FFC93C")))
	var groups: Dictionary = {}
	for t: Dictionary in list:
		var k: String = JU.s(t, "mesh", "box")
		if not groups.has(k):
			groups[k] = [] as Array[Dictionary]
		(groups[k] as Array[Dictionary]).append(t)
	var holder: Node3D = Node3D.new()
	holder.name = "Skyline"
	for k2: Variant in groups.keys():
		var parts: Array[Dictionary] = groups[k2]
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = _mesh(str(k2))
		mm.instance_count = parts.size()
		for i: int in parts.size():
			var t2: Dictionary = parts[i]
			var size: Vector3 = t2["size"]
			var b: Basis = Basis(Vector3.UP, float(t2["yaw"])) * Basis.from_scale(size)   # local scale: no skewed towers
			mm.set_instance_transform(i, Transform3D(b, (t2["pos"] as Vector3) + Vector3(0, size.y * 0.5 - 2.0, 0)))
			mm.set_instance_color(i, dark.lerp(base, 0.25 + float(t2["tint_k"]) * 0.3))
			mm.set_instance_custom_data(i, Color(float(t2["seed"]), float(t2["lit"]), float(int(t2.get("style", 0))), 0))
		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.name = "Skyline_" + str(k2)
		node.multimesh = mm
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.custom_aabb = AABB(Vector3(-2000, -10, -2000), Vector3(4000, 900, 4000))
		holder.add_child(node)
	if root != null:
		root.add_child(holder)
	return holder
