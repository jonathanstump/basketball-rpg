class_name DistrictSkyline
extends RefCounted
## Distant skyline ring around a district (playtest R2): tower silhouettes
## with lit windows beyond the map edge, taller toward the City so you can
## look up and feel where you are. One MultiMesh, no collision, no shadows.

const SHADER: Shader = preload("res://rendering/shaders/skyline.gdshader")


static func towers(m: MapData, borough: String) -> Array[Dictionary]:
	## Pure placement: [{pos (base center), size, tint_k, seed, lit}] in world
	## space. Deterministic from the map seed.
	var cfg: Dictionary = JU.dict(DataDB.tuning("camera"), "skyline")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = m.seed_value() + 7919
	var half: float = maxf(float(m.width), float(m.height)) * MapData.TILE * 0.5
	var inner: float = half + JU.f(cfg, "ring_inner_m", 60.0)
	var depth: float = JU.f(cfg, "ring_depth_m", 220.0)
	var wr: PackedFloat32Array = JU.floats(cfg, "width_m")
	var hr: PackedFloat32Array = JU.floats(cfg, "height_m")
	var chr: PackedFloat32Array = JU.floats(cfg, "city_height_m")
	var lr: PackedFloat32Array = JU.floats(cfg, "lit_ratio")
	var city_deg: float = JU.f(JU.dict(cfg, "city_dir_deg"), borough, -1.0)
	var arc: float = deg_to_rad(JU.f(cfg, "city_arc_deg", 70.0))
	var out: Array[Dictionary] = []
	var n: int = JU.i(cfg, "towers", 170)
	for i: int in n:
		var ang: float = (float(i) + rng.randf_range(-0.4, 0.4)) / float(n) * TAU
		var r: float = inner + rng.randf() * depth
		var dir: Vector3 = Vector3(sin(ang), 0.0, -cos(ang))
		## City-ward towers are much taller (in the City, everything is).
		var city_k: float = 1.0 if city_deg < 0.0 else clampf(1.0 - absf(angle_difference(ang, deg_to_rad(city_deg))) / arc, 0.0, 1.0)
		var h: float = lerpf(rng.randf_range(hr[0], hr[1]), rng.randf_range(chr[0], chr[1]), city_k)
		h *= lerpf(0.75, 1.15, clampf((r - inner) / depth, 0.0, 1.0))   # farther rows peek over nearer ones
		var w: float = rng.randf_range(wr[0], wr[1])
		out.append({"pos": dir * r, "size": Vector3(w, h, rng.randf_range(wr[0], wr[1])), "yaw": ang,
			"tint_k": rng.randf(), "seed": rng.randf(), "lit": rng.randf_range(lr[0], lr[1])})
		if city_k > 0.5 and rng.randf() < 0.25:
			## A spire on the tall ones.
			out.append({"pos": dir * r + Vector3(0, h, 0), "size": Vector3(w * 0.3, h * 0.25, w * 0.3), "yaw": ang,
				"tint_k": rng.randf(), "seed": rng.randf(), "lit": 0.0})
	return out


static func build(m: MapData, borough: String, env_id: String, root: Node3D) -> MultiMeshInstance3D:
	var list: Array[Dictionary] = towers(m, borough)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3.ONE
	mm.mesh = box
	mm.instance_count = list.size()
	var env: Dictionary = DataDB.item("environments", env_id)
	var base: Color = JU.color(env.get("sky_horizon", "#2A1A30"))
	var dark: Color = Color(0.05, 0.05, 0.08)
	for i: int in list.size():
		var t: Dictionary = list[i]
		var size: Vector3 = t["size"]
		var b: Basis = Basis(Vector3.UP, float(t["yaw"])).scaled(size)
		mm.set_instance_transform(i, Transform3D(b, (t["pos"] as Vector3) + Vector3(0, size.y * 0.5 - 2.0, 0)))
		mm.set_instance_color(i, dark.lerp(base, 0.25 + float(t["tint_k"]) * 0.3))
		mm.set_instance_custom_data(i, Color(float(t["seed"]), float(t["lit"]), 0, 0))
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("haze_color", JU.color(env.get("fog_color", "#2A1528")).lerp(base, 0.5))
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = "Skyline"
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(-2000, -10, -2000), Vector3(4000, 600, 4000))
	if root != null:
		root.add_child(node)
	return node
