class_name WireKicksView
extends Node3D
## Sneakers hanging on a power line (spec §5.5). Knocked down by a pass hit;
## they tumble to the street where loot pickup takes over.

var kicks_id: String = ""
var shoes: Node3D
var _falling: bool = false
var _vel: Vector3 = Vector3.ZERO
var _ground_y: float = 0.0


static func create(id: String, pos: Vector3, wire_dir: Vector3, color: Color) -> WireKicksView:
	var v: WireKicksView = WireKicksView.new()
	v.kicks_id = id
	v.name = "WireKicks_" + id
	var wire: MeshInstance3D = MeshInstance3D.new()
	wire.mesh = MeshLib.box(Vector3(0.025, 0.025, 14.0))
	wire.material_override = ToonMaterials.toon(Color("#101014"), false)
	wire.position = pos + Vector3(0, 0.35, 0)
	wire.rotation.y = atan2(wire_dir.x, wire_dir.z)
	v.add_child(wire)
	v.shoes = Node3D.new()
	v.shoes.position = pos
	v.add_child(v.shoes)
	var shoe_mat: Material = ToonMaterials.toon(color)
	var sole: Material = ToonMaterials.toon(Color("#F4F4F4"))
	for sx: float in [-0.09, 0.09]:
		var s: MeshInstance3D = MeshInstance3D.new()
		s.mesh = MeshLib.box(Vector3(0.12, 0.1, 0.28))
		s.material_override = shoe_mat
		s.position = Vector3(sx, -0.25, 0)
		s.rotation_degrees = Vector3(70, 0, sx * 80.0)
		v.shoes.add_child(s)
		var so: MeshInstance3D = MeshInstance3D.new()
		so.mesh = MeshLib.box(Vector3(0.125, 0.03, 0.29))
		so.material_override = sole
		so.position = Vector3(0, -0.06, 0)
		s.add_child(so)
		var lace: MeshInstance3D = MeshInstance3D.new()
		lace.mesh = MeshLib.box(Vector3(0.01, 0.35, 0.01))
		lace.material_override = sole
		lace.position = Vector3(sx * 0.5, -0.05, 0)
		v.shoes.add_child(lace)
	return v


func knock_down(ground_y: float) -> void:
	_falling = true
	_ground_y = ground_y
	_vel = Vector3(0.5, 2.0, 0.3)


func _process(delta: float) -> void:
	if not _falling:
		shoes.rotation.z = sin(float(Time.get_ticks_msec()) * 0.002) * 0.08
		return
	_vel.y -= 14.0 * delta
	shoes.position += _vel * delta
	shoes.rotation.x += delta * 6.0
	if shoes.position.y <= _ground_y + 0.15:
		shoes.position.y = _ground_y + 0.15
		_falling = false
		shoes.rotation = Vector3(0, shoes.rotation.y, 0)
