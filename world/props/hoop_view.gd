class_name HoopView
extends Node3D
## Regulation hoop (pole, backboard, rim, chain/nylon net) or a street hoop
## (same parts, block-sized; rim and shooter square glow while its Bucket
## Blast is ready). Mirrors a SimHoop.

var hoop: SimHoop
var net: ChainNet = null
var crate_mat: ShaderMaterial = null
var _ready_glow: bool = true


static func create(h: SimHoop) -> HoopView:
	var v: HoopView = HoopView.new()
	v.hoop = h
	v.name = "Hoop_" + h.id
	if h.kind == "crate":
		v._build_crate()
	else:
		v._build_regulation()
	return v


func _box(size: Vector3, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = MeshLib.box(size)
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


func _build_regulation() -> void:
	var f: Vector3 = hoop.facing
	var yaw: float = atan2(f.x, f.z)
	var board: Vector3 = hoop.rim - f * 0.38
	var metal: Material = ToonMaterials.toon(Color("#2A2E38"))
	var pole_base: Vector3 = hoop.rim - f * 1.4
	pole_base.y = hoop.rim.y - 3.05
	var pole: MeshInstance3D = MeshInstance3D.new()
	pole.mesh = MeshLib.cylinder(0.11, hoop.rim.y + 0.4 - pole_base.y)
	pole.material_override = metal
	pole.position = pole_base + Vector3(0, (hoop.rim.y + 0.4 - pole_base.y) * 0.5, 0)
	add_child(pole)
	var arm_mid: Vector3 = (pole_base + board) * 0.5
	arm_mid.y = hoop.rim.y + 0.3
	_box(Vector3(0.14, 0.14, 1.05), metal, arm_mid, Vector3(0, yaw, 0))
	_box(Vector3(1.8, 1.05, 0.05), ToonMaterials.toon(Color("#F2F4F8")), board + Vector3(0, 0.3, 0), Vector3(0, yaw, 0))
	_box(Vector3(0.59, 0.45, 0.06), ToonMaterials.toon(Color("#E8692A"), false), board + Vector3(0, 0.15, 0) + f * 0.005, Vector3(0, yaw, 0))
	_box(Vector3(0.5, 0.36, 0.07), ToonMaterials.toon(Color("#F2F4F8"), false), board + Vector3(0, 0.15, 0) + f * 0.008, Vector3(0, yaw, 0))
	var rim: MeshInstance3D = MeshInstance3D.new()
	rim.mesh = MeshLib.torus(hoop.radius - 0.012, hoop.radius + 0.012)
	rim.material_override = ToonMaterials.toon(Color("#FF5A1A"), true, false, Color("#FF5A1A"), 0.4)
	rim.position = hoop.rim
	add_child(rim)
	if hoop.net != "none":
		net = ChainNet.new()
		net.kind = hoop.net
		net.rim_radius = hoop.radius
		net.position = hoop.rim
		add_child(net)


func _build_crate() -> void:
	## Street hoop (revision 10): the same pole, backboard, orange rim and chain
	## net as the court hoops, scaled for the block. The old crate glow (Bucket
	## Blast ready) now lights the rim and the board's shooter square.
	var f: Vector3 = hoop.facing
	var yaw: float = atan2(f.x, f.z)
	var metal: Material = ToonMaterials.toon(Color("#5E6672"))
	var pole_xz: Vector3 = hoop.rim - f * 0.25
	var top: float = hoop.rim.y + 0.75
	var pole: MeshInstance3D = MeshInstance3D.new()
	pole.mesh = MeshLib.cylinder(0.09, top)
	pole.material_override = metal
	pole.position = Vector3(pole_xz.x, top * 0.5, pole_xz.z)
	add_child(pole)
	var board: Vector3 = hoop.rim - f * 0.16
	_box(Vector3(1.3, 0.9, 0.05), ToonMaterials.toon(Color("#E8EAF0"), true, false, Color("#A8B0C8"), 0.45), board + Vector3(0, 0.28, 0), Vector3(0, yaw, 0))
	_box(Vector3(1.38, 0.98, 0.03), metal, board + Vector3(0, 0.28, 0) - f * 0.02, Vector3(0, yaw, 0))
	crate_mat = ShaderMaterial.new()
	crate_mat.shader = ToonMaterials.TOON
	crate_mat.set_shader_parameter("albedo", Color("#E8692A"))
	crate_mat.set_shader_parameter("emission_color", Color("#4AD8FF"))
	crate_mat.set_shader_parameter("emission_energy", 1.2)
	crate_mat.next_pass = ToonMaterials.outline_mat(0.012)
	_box(Vector3(0.46, 0.34, 0.06), crate_mat, board + Vector3(0, 0.14, 0) + f * 0.005, Vector3(0, yaw, 0))
	_box(Vector3(0.38, 0.26, 0.07), ToonMaterials.toon(Color("#E8EAF0"), false), board + Vector3(0, 0.14, 0) + f * 0.008, Vector3(0, yaw, 0))
	var rim: MeshInstance3D = MeshInstance3D.new()
	rim.mesh = MeshLib.torus(hoop.radius - 0.012, hoop.radius + 0.012)
	rim.material_override = crate_mat
	rim.position = hoop.rim
	add_child(rim)
	net = ChainNet.new()
	net.kind = "chain"
	net.rim_radius = hoop.radius
	net.position = hoop.rim
	add_child(net)


func on_make() -> void:
	if net != null:
		net.swish(1.4)


func _process(_delta: float) -> void:
	if crate_mat == null:
		return
	var ready_now: bool = hoop.is_ready()
	if ready_now != _ready_glow:
		_ready_glow = ready_now
		crate_mat.set_shader_parameter("emission_energy", 1.2 if ready_now else 0.0)
