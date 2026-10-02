class_name KitBuildings
extends RefCounted
## Procedural NYC building kit (spec §12.3): brownstones with stoops and
## cornices, walk-ups with fire escapes and AC units, high-rises, warehouses,
## rooftop water towers. Each builder adds meshes under `parent` and matching
## collision blocks. `front` is the facade normal (unit XZ axis).

const FLOOR_H: float = 3.0


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func _yaw_for(front: Vector3) -> float:
	return rad_to_deg(atan2(front.x, front.z))


static func building(parent: Node3D, col: WorldCollision, center: Vector3, size: Vector3, wall: Color, seed_value: float, lit: float = 0.4) -> MeshInstance3D:
	## Generic massing box with the window-light facade shader.
	var mi: MeshInstance3D = _mesh(parent, MeshLib.box(size), ToonMaterials.facade(wall, seed_value, lit), center + Vector3(0, size.y * 0.5, 0))
	mi.name = "Building"
	col.add_box(center + Vector3(0, size.y * 0.5, 0), size, "building")
	return mi


static func brownstone(parent: Node3D, col: WorldCollision, center: Vector3, width: float, depth: float, floors: int, front: Vector3, rng: RandomNumberGenerator) -> void:
	var h: float = float(floors) * FLOOR_H + 1.2
	var size: Vector3 = Vector3(width, h, depth) if absf(front.z) > 0.5 else Vector3(depth, h, width)
	var tone: Color = Color("#6B4A3A").lerp(Color("#8A5A44"), rng.randf())
	building(parent, col, center, size, tone, rng.randf() * 100.0, 0.45)
	var trim: Material = ToonMaterials.toon(tone.darkened(0.35))
	var half_d: float = (size.z if absf(front.z) > 0.5 else size.x) * 0.5
	var face: Vector3 = center + front * half_d
	var side: Vector3 = Vector3(front.z, 0, -front.x)
	var yaw: float = _yaw_for(front)
	# Cornice.
	_mesh(parent, MeshLib.box(Vector3(width + 0.4, 0.5, 0.6)), trim, face + Vector3(0, h - 0.3, 0) + front * 0.1, Vector3(0, yaw, 0))
	# Stoop: stepped platforms up to a parlor-floor door, offset to one side.
	var door_off: float = width * 0.25 * (1.0 if rng.randf() > 0.5 else -1.0)
	var stoop_base: Vector3 = face + side * door_off
	for i: int in 4:
		var step_top: float = 0.3 * float(i + 1)
		var step_c: Vector3 = stoop_base + front * (2.0 - 0.45 * float(i) - 0.25)
		var step_size: Vector3 = Vector3(1.6, step_top, 0.5) if absf(front.z) > 0.5 else Vector3(0.5, step_top, 1.6)
		_mesh(parent, MeshLib.box(step_size), trim, step_c + Vector3(0, step_top * 0.5, 0))
		col.add_box(step_c + Vector3(0, step_top * 0.5, 0), step_size, "stoop")
	_mesh(parent, MeshLib.box(Vector3(1.0, 2.2, 0.15)), ToonMaterials.toon(Color("#3A2418")), stoop_base + Vector3(0, 1.2 + 1.1, 0) + front * 0.02, Vector3(0, yaw, 0))
	# Bay window.
	if rng.randf() > 0.4:
		var bay_c: Vector3 = face - side * door_off + front * 0.4 + Vector3(0, FLOOR_H * 1.5 + 1.2, 0)
		_mesh(parent, MeshLib.box(Vector3(2.0, FLOOR_H * 1.6, 0.8)), ToonMaterials.facade(tone.lightened(0.05), rng.randf() * 50.0, 0.5, 0.0), bay_c, Vector3(0, yaw, 0))
	if rng.randf() > 0.5:
		water_tower(parent, center + Vector3(rng.randf_range(-1, 1), h, rng.randf_range(-1, 1)))


static func walkup(parent: Node3D, col: WorldCollision, center: Vector3, width: float, depth: float, floors: int, front: Vector3, rng: RandomNumberGenerator) -> void:
	var h: float = float(floors) * FLOOR_H + 0.6
	var size: Vector3 = Vector3(width, h, depth) if absf(front.z) > 0.5 else Vector3(depth, h, width)
	var tone: Color = Color("#7A3B2E").lerp(Color("#9A6A4A"), rng.randf())
	building(parent, col, center, size, tone, rng.randf() * 100.0, 0.4)
	var half_d: float = (size.z if absf(front.z) > 0.5 else size.x) * 0.5
	var face: Vector3 = center + front * half_d
	var side: Vector3 = Vector3(front.z, 0, -front.x)
	var yaw: float = _yaw_for(front)
	var metal: Material = ToonMaterials.toon(Color("#20242C"))
	# Fire escape: landing per floor + zigzag ladders.
	var fe_c: Vector3 = face + side * (width * 0.2) + front * 0.6
	for f: int in range(1, floors):
		var y: float = float(f) * FLOOR_H + 0.3
		_mesh(parent, MeshLib.box(Vector3(3.2, 0.08, 1.1)), metal, fe_c + Vector3(0, y, 0), Vector3(0, yaw, 0))
		_mesh(parent, MeshLib.box(Vector3(3.2, 0.9, 0.05)), metal, fe_c + Vector3(0, y + 0.45, 0) + front * 0.52, Vector3(0, yaw, 0))
		_mesh(parent, MeshLib.box(Vector3(0.5, 0.06, 3.3)), metal, fe_c + Vector3(0, y + 1.5, 0) + side * (0.9 if f % 2 == 0 else -0.9), Vector3(55, yaw + 90.0, 0))
	# Window AC units.
	var ac: Material = ToonMaterials.toon(Color("#B8BCC4"))
	for i: int in 3:
		var f2: int = rng.randi_range(1, floors - 1)
		var off: float = rng.randf_range(-width * 0.45, width * 0.1)
		_mesh(parent, MeshLib.box(Vector3(0.7, 0.45, 0.5)), ac, face + side * off + front * 0.25 + Vector3(0, float(f2) * FLOOR_H + 3.6, 0), Vector3(0, yaw, 0))
	if rng.randf() > 0.3:
		water_tower(parent, center + Vector3(rng.randf_range(-1.5, 1.5), h, rng.randf_range(-1.5, 1.5)))


static func water_tower(parent: Node3D, base: Vector3) -> void:
	var wood: Material = ToonMaterials.toon(Color("#6A4A32"))
	var dark: Material = ToonMaterials.toon(Color("#2A2228"))
	for lx: float in [-0.8, 0.8]:
		for lz: float in [-0.8, 0.8]:
			_mesh(parent, MeshLib.cylinder(0.08, 2.2), dark, base + Vector3(lx, 1.1, lz))
	_mesh(parent, MeshLib.cylinder(1.2, 2.6), wood, base + Vector3(0, 3.5, 0))
	_mesh(parent, MeshLib.cylinder(1.3, 1.0, 0.05), dark, base + Vector3(0, 5.3, 0))
	_mesh(parent, MeshLib.torus(1.18, 1.26), dark, base + Vector3(0, 3.0, 0))
	_mesh(parent, MeshLib.torus(1.18, 1.26), dark, base + Vector3(0, 4.2, 0))
