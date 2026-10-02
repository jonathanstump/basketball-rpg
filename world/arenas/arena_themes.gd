class_name ArenaThemes
extends RefCounted
## Visual dressing for arenas (spec §9.3 "Arena" lines). Every arena gets the
## court, apron, chain-link fence + gate and corner lights; the theme hook
## adds the per-boss set (stoop, market hall, El tracks...). Unknown themes
## fall back to a palette-tinted generic set so every boss always has a stage.


static func dress(parent: Node3D, w: SimWorld, boss: Dictionary, lay: Dictionary) -> void:
	var arena: Dictionary = JU.dict(boss, "arena")
	var hoop: SimHoop = lay["hoop"]
	var half: Vector2 = lay["half"]
	var region: String = JU.s(boss, "borough", "city")
	var pal: Dictionary = JU.dict(JU.dict(DataDB.get_dict("palettes"), "regions"), region)
	CourtFloor.build(parent, hoop, half * 2.0, Vector3(0, -0.02, 0), {
		"floor": JU.s(arena, "floor", JU.s(pal, "base", "#2C5D8F")), "key": JU.s(arena, "key", JU.s(pal, "primary", "#8C1F2A")),
		"wood": JU.b(arena, "indoor")})
	var apron: Vector2 = half * 2.0 + Vector2(ArenaBuilder.APRON_M, ArenaBuilder.APRON_M) * 2.0
	KitProps.ground_tile(parent, Vector3(0, -0.04, 0), apron + Vector2(30, 30), ToonMaterials.asphalt())
	fence(parent, half + Vector2(ArenaBuilder.APRON_M, ArenaBuilder.APRON_M), JU.b(arena, "indoor"))
	for cx: float in [-1.0, 1.0]:
		KitProps.streetlight(parent, w.collision, Vector3(cx * (half.x + ArenaBuilder.APRON_M + 1.0), 0, 0), Vector3(-cx, 0, 0), JU.color(pal.get("secondary"), Color("#FFB347")))
	match JU.s(arena, "theme"):
		"brownstone_block":
			_brownstone_block(parent, w, hoop, lay, pal)
		_:
			_generic(parent, hoop, half, pal)


static func fence(parent: Node3D, half: Vector2, indoor: bool) -> void:
	var post: Material = ToonMaterials.toon(Color("#5A606C"))
	var mesh_mat: StandardMaterial3D = StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.6, 0.65, 0.72, 0.28) if not indoor else Color(0.2, 0.15, 0.25, 0.9)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var h: float = 3.6
	var sides: Array = [[Vector3(0, h * 0.5, -half.y), Vector3(half.x * 2.0, h, 0.04)], [Vector3(-half.x, h * 0.5, 0), Vector3(0.04, h, half.y * 2.0)],
		[Vector3(half.x, h * 0.5, 0), Vector3(0.04, h, half.y * 2.0)], [Vector3(-(half.x + 1.6) * 0.5, h * 0.5, half.y), Vector3(half.x - 1.6, h, 0.04)],
		[Vector3((half.x + 1.6) * 0.5, h * 0.5, half.y), Vector3(half.x - 1.6, h, 0.04)]]
	for sd: Variant in sides:
		var pair: Array = sd
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = MeshLib.box(pair[1])
		mi.material_override = mesh_mat
		mi.position = pair[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
	var x: float = -half.x
	while x <= half.x + 0.01:
		for z: float in [-half.y, half.y]:
			var p: MeshInstance3D = MeshInstance3D.new()
			p.mesh = MeshLib.cylinder(0.05, h)
			p.material_override = post
			p.position = Vector3(x, h * 0.5, z)
			parent.add_child(p)
		x += 3.0
	var gate: MeshInstance3D = MeshInstance3D.new()
	gate.name = "Gate"
	gate.mesh = MeshLib.box(Vector3(3.2, h, 0.08))
	gate.material_override = ToonMaterials.toon(Color("#7A808C"))
	gate.position = Vector3(0, h * 0.5, half.y)
	parent.add_child(gate)
	var lock: MeshInstance3D = MeshInstance3D.new()
	lock.mesh = MeshLib.box(Vector3(0.25, 0.3, 0.12))
	lock.material_override = ToonMaterials.toon(Color("#F4B400"))
	lock.position = Vector3(0, 1.2, half.y + 0.08)
	parent.add_child(lock)


static func _brownstone_block(parent: Node3D, w: SimWorld, hoop: SimHoop, lay: Dictionary, pal: Dictionary) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1101
	var back: float = hoop.rim.z - 1.6
	var face: Material = ToonMaterials.facade(Color("#6B4A3A"), 3.0, 0.7, 1.2)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = MeshLib.box(Vector3(30.0, 14.0, 6.0))
	mi.material_override = face
	mi.position = Vector3(0, 7.0, back - 3.0)
	parent.add_child(mi)
	var door: MeshInstance3D = MeshInstance3D.new()
	door.mesh = MeshLib.box(Vector3(2.0, 3.0, 0.2))
	door.material_override = ToonMaterials.toon(Color("#3A2418"), true, false, Color("#FFB060"), 0.3)
	door.position = Vector3(0, 2.6, back)
	parent.add_child(door)
	var plat: Dictionary = JU.dict(lay, "platform")
	if not plat.is_empty():
		var stone: Material = ToonMaterials.toon(Color("#8A6A58"))
		var base: Vector3 = plat["base"]
		for i: int in int(plat["steps"]):
			var top: float = float(plat["step_h"]) * float(i + 1)
			var d: float = float(plat["depth"]) - float(i) * 0.7
			var c: Vector3 = base + hoop.facing * (d * 0.5)
			var step: MeshInstance3D = MeshInstance3D.new()
			step.mesh = MeshLib.box(Vector3(float(plat["width"]) - float(i) * 0.4, top, d))
			step.material_override = stone
			step.position = Vector3(c.x, top * 0.5, c.z)
			parent.add_child(step)
		for sx: float in [-1.0, 1.0]:
			var rail: MeshInstance3D = MeshInstance3D.new()
			rail.mesh = MeshLib.box(Vector3(0.12, 1.0, float(plat["depth"])))
			rail.material_override = ToonMaterials.toon(Color("#1A1A20"))
			rail.position = base + hoop.facing * (float(plat["depth"]) * 0.5) + Vector3(sx * float(plat["width"]) * 0.5, 1.4, 0)
			parent.add_child(rail)
	for i2: int in 6:
		var win: OmniLight3D = OmniLight3D.new()
		win.light_color = Color("#FFD08A")
		win.light_energy = 0.8
		win.omni_range = 5.0
		win.position = Vector3(-12.0 + float(i2) * 4.8, 6.0 + float(i2 % 2) * 3.0, back + 0.6)
		parent.add_child(win)
	for sx2: float in [-1.0, 1.0]:
		KitBuildings.brownstone(parent, w.collision, Vector3(sx2 * 16.0, 0, back + 2.0), 6.0, 7.0, 4, Vector3(0, 0, 1), rng)


static func _generic(parent: Node3D, hoop: SimHoop, half: Vector2, pal: Dictionary) -> void:
	var col: Color = JU.color(pal.get("primary"), Color("#7B2FF7"))
	var wall: MeshInstance3D = MeshInstance3D.new()
	wall.mesh = MeshLib.box(Vector3(half.x * 2.0 + 10.0, 10.0, 2.0))
	wall.material_override = ToonMaterials.facade(JU.color(pal.get("base"), Color("#1A1530")).lightened(0.15), 9.0, 0.5, 0.0)
	wall.position = Vector3(0, 5.0, hoop.rim.z - 4.0)
	parent.add_child(wall)
	var sign: MeshInstance3D = MeshInstance3D.new()
	sign.mesh = MeshLib.box(Vector3(6.0, 0.3, 0.1))
	sign.material_override = ToonMaterials.neon(col, 3.0)
	sign.position = Vector3(0, 7.5, hoop.rim.z - 2.9)
	parent.add_child(sign)
