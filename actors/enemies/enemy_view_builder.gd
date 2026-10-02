class_name EnemyViewBuilder
extends RefCounted
## Builds views for enemies from their `look`/`rig` data (spec §12.4): taller,
## chunkier humanoids (1.6-2.2 m), captain bandanas that glow, big-head
## mascots, fixie bikes, and toy critters/props on a one-joint puppet rig.


static func create(a: SimActor) -> ActorView:
	var d: Dictionary = DataDB.enemy(a.archetype)
	var rig_kind: String = JU.s(d, "rig", "humanoid")
	if rig_kind == "humanoid" or rig_kind == "":
		var look: Dictionary = JU.dict(d, "look").duplicate()
		if bool(a.flags.get("captain", false)):
			look["headband"] = "#FFD000"
		var v: ActorView = ActorView.create(a, look)
		if JU.b(look, "big_head"):
			(v.rig.joint("head") as Node3D).scale = Vector3.ONE * 1.9
		if bool(a.flags.get("captain", false)):
			_glow(v)
		if JU.b(d, "bike"):
			_bike(v)
		return v
	var v2: ActorView = ActorView.new()
	v2.actor = a
	v2.name = "View_%d" % a.id
	v2.body = Node3D.new()
	v2.add_child(v2.body)
	v2.rig = PuppetRig.new()
	v2.rig.add_joint("hips", "", Vector3.ZERO)
	v2.body.add_child(v2.rig)
	v2.animator = PuppetAnimator.new("hooper")
	match rig_kind:
		"pigeon":
			_critter(v2.rig, Color("#8A8E9A"), 0.16, Color("#5A6A8A"), 0.1, 0.0)
		"gull":
			_critter(v2.rig, Color("#F2F2F2"), 0.22, Color("#E8E8E8"), 0.12, 1.4)
		"rat", "pizza_rat":
			_rat(v2.rig, rig_kind == "pizza_rat")
		"deer":
			_deer(v2.rig)
		"shoebox":
			_shoebox(v2.rig)
		"boombox":
			_boombox(v2.rig)
	v2.position = a.pos
	v2.add_child(ActorView._blob_shadow())
	v2.physics_synced()
	v2.physics_synced()
	return v2


static func _part(rig: PuppetRig, mesh: Mesh, col: Color, pos: Vector3, rot: Vector3 = Vector3.ZERO, sc: Vector3 = Vector3.ONE, emit: float = 0.0) -> MeshInstance3D:
	return rig.add_part("hips", mesh, ToonMaterials.toon(col, true, false, col if emit > 0.0 else Color.BLACK, emit), pos, rot, sc)


static func _critter(rig: PuppetRig, body: Color, r: float, wing: Color, head_r: float, hover: float) -> void:
	_part(rig, MeshLib.sphere(r), body, Vector3(0, r + hover, 0), Vector3.ZERO, Vector3(1, 0.85, 1.3))
	_part(rig, MeshLib.sphere(head_r), body.lightened(0.1), Vector3(0, r * 1.7 + hover, -r * 0.9))
	_part(rig, MeshLib.cylinder(0.02, 0.06, 0.0), Color("#F4B400"), Vector3(0, r * 1.65 + hover, -r * 0.9 - head_r), Vector3(-90, 0, 0))
	for sx: float in [-1.0, 1.0]:
		_part(rig, MeshLib.box(Vector3(0.04, r * 0.8, r * 1.6)), wing, Vector3(sx * r * 0.95, r * 1.1 + hover, r * 0.1), Vector3(0, 0, sx * 20.0))


static func _rat(rig: PuppetRig, pizza: bool) -> void:
	_part(rig, MeshLib.capsule(0.11, 0.42), Color("#5A5058"), Vector3(0, 0.12, 0), Vector3(90, 0, 0))
	_part(rig, MeshLib.sphere(0.08), Color("#6A6068"), Vector3(0, 0.14, -0.24))
	_part(rig, MeshLib.cylinder(0.015, 0.4, 0.005), Color("#C89090"), Vector3(0, 0.08, 0.38), Vector3(70, 0, 0))
	if pizza:
		_part(rig, MeshLib.box(Vector3(0.28, 0.02, 0.22)), Color("#F4C430"), Vector3(0, 0.2, -0.38), Vector3(10, 30, 0))
		_part(rig, MeshLib.sphere(0.03), Color("#C8281E"), Vector3(0.05, 0.22, -0.38))


static func _deer(rig: PuppetRig) -> void:
	var fur: Color = Color("#8A5A3A")
	_part(rig, MeshLib.capsule(0.3, 1.2), fur, Vector3(0, 1.05, 0), Vector3(90, 0, 0))
	_part(rig, MeshLib.capsule(0.12, 0.6), fur, Vector3(0, 1.45, -0.6), Vector3(-40, 0, 0))
	_part(rig, MeshLib.sphere(0.17), fur, Vector3(0, 1.75, -0.8), Vector3.ZERO, Vector3(0.9, 0.9, 1.3))
	for lx: float in [-0.18, 0.18]:
		for lz: float in [-0.4, 0.4]:
			_part(rig, MeshLib.cylinder(0.06, 0.85), fur.darkened(0.2), Vector3(lx, 0.42, lz))
		_part(rig, MeshLib.cylinder(0.025, 0.35, 0.01), Color("#E8DCC0"), Vector3(lx, 2.0, -0.78), Vector3(0, 0, lx * 120.0))
	for ex: float in [-0.09, 0.09]:
		_part(rig, MeshLib.sphere(0.035), Color("#B8FF6A"), Vector3(ex, 1.8, -0.97), Vector3.ZERO, Vector3.ONE, 2.5)


static func _shoebox(rig: PuppetRig) -> void:
	_part(rig, MeshLib.box(Vector3(0.9, 0.42, 0.55)), Color("#E8E2D8"), Vector3(0, 0.21, 0))
	var lid: MeshInstance3D = _part(rig, MeshLib.box(Vector3(0.94, 0.12, 0.6)), Color("#C8281E"), Vector3(0, 0.48, 0))
	lid.name = "Lid"
	for i: int in 6:
		_part(rig, MeshLib.cylinder(0.035, 0.08, 0.0), Color("#F8F8F8"), Vector3(-0.35 + 0.14 * float(i), 0.4, -0.27), Vector3(180, 0, 0))


static func _boombox(rig: PuppetRig) -> void:
	_part(rig, MeshLib.box(Vector3(0.7, 0.4, 0.25)), Color("#1A1A22"), Vector3(0, 0.2, 0))
	for sx: float in [-0.2, 0.2]:
		_part(rig, MeshLib.cylinder(0.12, 0.04), Color("#FF3EA5"), Vector3(sx, 0.2, -0.13), Vector3(90, 0, 0), Vector3.ONE, 1.5)
	_part(rig, MeshLib.box(Vector3(0.5, 0.04, 0.04)), Color("#C0C4CC"), Vector3(0, 0.45, 0))


static func _glow(v: ActorView) -> void:
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = Color("#FFD000")
	l.light_energy = 1.2
	l.omni_range = 3.0
	l.position = Vector3(0, 2.0, 0)
	v.add_child(l)


static func _bike(v: ActorView) -> void:
	var frame: Node3D = Node3D.new()
	frame.name = "Bike"
	v.body.add_child(frame)
	var metal: Material = ToonMaterials.toon(Color("#12C2B0"))
	for z: float in [-0.55, 0.55]:
		var wheel: MeshInstance3D = MeshInstance3D.new()
		wheel.mesh = MeshLib.torus(0.28, 0.33)
		wheel.material_override = ToonMaterials.toon(Color("#101014"))
		wheel.position = Vector3(0, 0.33, z)
		wheel.rotation_degrees = Vector3(0, 0, 90)
		frame.add_child(wheel)
	var bar: MeshInstance3D = MeshInstance3D.new()
	bar.mesh = MeshLib.box(Vector3(0.05, 0.05, 1.1))
	bar.material_override = metal
	bar.position = Vector3(0, 0.6, 0)
	frame.add_child(bar)
