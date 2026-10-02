class_name ArenaThemesBK
extends RefCounted
## Brooklyn arena sets (spec §9.3): The Barker's Funhouse (hall of mirrors,
## floor panels, hoop over a clown-mouth doorway) and The Toll's bridge
## archway (cobblestones, girders overhead, the locked City across the water).


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = MeshLib.box(size)
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func funhouse(parent: Node3D, hoop: SimHoop, half: Vector2) -> void:
	var back: float = hoop.rim.z - 1.4
	var wall_mat: Material = ToonMaterials.toon(Color("#2A1840"))
	_box(parent, Vector3(half.x * 2.0 + 8.0, 9.0, 1.0), Vector3(0, 4.5, back - 1.2), wall_mat)
	# Clown-mouth doorway under the hoop: big face, red lips, dark mouth.
	_box(parent, Vector3(7.0, 6.5, 0.4), Vector3(0, 4.0, back - 0.6), ToonMaterials.toon(Color("#F4F0E0")))
	var lips: MeshInstance3D = MeshInstance3D.new()
	lips.mesh = MeshLib.torus(1.1, 1.6)
	lips.material_override = ToonMaterials.toon(Color("#D8263A"), true, false, Color("#D8263A"), 0.4)
	lips.position = Vector3(0, 1.6, back - 0.3)
	lips.rotation_degrees = Vector3(90, 0, 0)
	parent.add_child(lips)
	_box(parent, Vector3(2.0, 2.4, 0.2), Vector3(0, 1.2, back - 0.35), ToonMaterials.toon(Color("#08060C")))
	for ex: float in [-1.4, 1.4]:
		var eye: MeshInstance3D = MeshInstance3D.new()
		eye.mesh = MeshLib.sphere(0.45)
		eye.material_override = ToonMaterials.toon(Color("#00C2B8"), true, false, Color("#00C2B8"), 1.5)
		eye.position = Vector3(ex, 5.2, back - 0.3)
		parent.add_child(eye)
	# Mirror panels down both sides (only the real Barker casts a shadow).
	var mirror: StandardMaterial3D = StandardMaterial3D.new()
	mirror.albedo_color = Color(0.75, 0.85, 0.95)
	mirror.metallic = 1.0
	mirror.roughness = 0.05
	var z: float = -half.y + 1.0
	while z < half.y:
		for sx: float in [-1.0, 1.0]:
			var p: MeshInstance3D = _box(parent, Vector3(0.15, 3.6, 2.2), Vector3(sx * (half.x + 2.2), 1.8, z), mirror)
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_box(parent, Vector3(0.2, 0.25, 2.4), Vector3(sx * (half.x + 2.2), 3.7, z), ToonMaterials.neon(Color("#FF3EA5") if int(z) % 2 == 0 else Color("#00C2B8"), 2.0))
		z += 3.0
	# Floor panels (tilt in phase 2) as a checker overlay.
	for ix: int in range(-2, 3):
		for iz: int in range(-2, 3):
			if (ix + iz) % 2 == 0:
				var tile: MeshInstance3D = _box(parent, Vector3(3.0, 0.02, 3.0), Vector3(float(ix) * 3.2, 0.005, float(iz) * 3.0 + 1.0), ToonMaterials.toon(Color("#4A3460"), false))
				tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# String of bulbs overhead.
	for i: int in 12:
		var bulb: OmniLight3D = OmniLight3D.new()
		bulb.light_color = Color("#FFD08A") if i % 2 == 0 else Color("#FF7AC8")
		bulb.light_energy = 0.9
		bulb.omni_range = 6.0
		bulb.position = Vector3(-half.x + float(i) * (half.x * 2.0 / 11.0), 6.0, 0)
		parent.add_child(bulb)


static func bridge_arch(parent: Node3D, hoop: SimHoop, half: Vector2) -> void:
	var stone: Material = ToonMaterials.toon(Color("#6E6458"))
	var steel: Material = ToonMaterials.toon(Color("#2E3A4A"))
	var back: float = hoop.rim.z - 1.2
	# Granite pylon carrying the hoop.
	_box(parent, Vector3(5.0, 16.0, 3.0), Vector3(0, 8.0, back - 1.6), stone)
	# The arch: two piers + a lintel high above the court.
	for sx: float in [-1.0, 1.0]:
		_box(parent, Vector3(4.0, 22.0, 6.0), Vector3(sx * (half.x + 6.0), 11.0, 0), stone)
	_box(parent, Vector3(half.x * 2.0 + 16.0, 4.0, 6.0), Vector3(0, 22.0, 0), stone).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Steel girders overhead (The Toll's Overpass perch).
	var gz: float = -half.y
	while gz <= half.y:
		_box(parent, Vector3(half.x * 2.0 + 12.0, 0.6, 0.5), Vector3(0, 14.0, gz), steel).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gz += 4.0
	for gx: float in [-half.x, 0.0, half.x]:
		_box(parent, Vector3(0.5, 0.6, half.y * 2.0 + 4.0), Vector3(gx, 14.6, 0), steel).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Cobblestone apron stripes.
	for i: int in 9:
		var strip: MeshInstance3D = _box(parent, Vector3(half.x * 2.0 + 6.0, 0.01, 0.12), Vector3(0, 0.003, -half.y - 2.0 + float(i) * 0.6), ToonMaterials.toon(Color("#3A3640"), false))
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Water and the locked City skyline across it.
	var water: MeshInstance3D = MeshInstance3D.new()
	water.mesh = MeshLib.plane(Vector2(220.0, 90.0))
	water.material_override = ToonMaterials.toon(Color("#0E2236"), false, false, Color("#12304A"), 0.25)
	water.position = Vector3(0, -0.6, back - 55.0)
	parent.add_child(water)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7707
	for i2: int in 22:
		var h: float = rng.randf_range(18.0, 70.0)
		var bx: float = -100.0 + float(i2) * 9.5
		var b: MeshInstance3D = _box(parent, Vector3(rng.randf_range(5.0, 9.0), h, 6.0), Vector3(bx, h * 0.5 - 0.6, back - 95.0),
			ToonMaterials.facade(Color("#1C2236"), float(i2), 0.55, 0.0))
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Work floodlights on the court corners so the granite reads at night.
	for fx: float in [-1.0, 1.0]:
		var flood: OmniLight3D = OmniLight3D.new()
		flood.light_color = Color("#FFE0B0")
		flood.light_energy = 4.0
		flood.omni_range = 22.0
		flood.position = Vector3(fx * (half.x - 1.0), 9.0, half.y - 2.0)
		parent.add_child(flood)
	# Bridge deck lights strung across the top.
	for i3: int in 10:
		var l: OmniLight3D = OmniLight3D.new()
		l.light_color = Color("#FFE6A8")
		l.light_energy = 1.1
		l.omni_range = 8.0
		l.position = Vector3(-half.x - 4.0 + float(i3) * (half.x * 2.0 + 8.0) / 9.0, 13.0, 0)
		parent.add_child(l)
