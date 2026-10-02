class_name KitProps
extends RefCounted
## Street props (spec §12.3): cobra-head streetlights, hydrants, bodega
## fronts with awnings, neon signs and roll-down gates, ground tiles.


static var batcher: MeshBatcher = null   # when set, meshes are batched instead of instanced


static func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	if batcher != null:
		batcher.add_at(mesh, mat, pos, rot_deg)
		return null
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func streetlight(parent: Node3D, col: WorldCollision, pos: Vector3, arm_dir: Vector3, light_color: Color = Color("#FFB347")) -> OmniLight3D:
	var metal: Material = ToonMaterials.toon(Color("#3A4048"))
	_mesh(parent, MeshLib.cylinder(0.09, 6.0, 0.06), metal, pos + Vector3(0, 3.0, 0))
	var yaw: float = rad_to_deg(atan2(arm_dir.x, arm_dir.z))
	_mesh(parent, MeshLib.box(Vector3(0.08, 0.08, 1.6)), metal, pos + Vector3(0, 5.9, 0) + arm_dir * 0.8, Vector3(0, yaw, 0))
	_mesh(parent, MeshLib.box(Vector3(0.35, 0.16, 0.7)), metal, pos + Vector3(0, 5.85, 0) + arm_dir * 1.6, Vector3(0, yaw, 0))
	_mesh(parent, MeshLib.box(Vector3(0.28, 0.04, 0.55)), ToonMaterials.neon(light_color, 4.0), pos + Vector3(0, 5.76, 0) + arm_dir * 1.6, Vector3(0, yaw, 0))
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = light_color
	light.light_energy = 3.2
	light.omni_range = 14.0
	light.omni_attenuation = 0.9
	light.position = pos + Vector3(0, 5.5, 0) + arm_dir * 1.6
	light.add_to_group("cc_lights")
	parent.add_child(light)
	col.add_box(pos + Vector3(0, 3, 0), Vector3(0.25, 6.0, 0.25), "pole")
	return light


static func hydrant(parent: Node3D, col: WorldCollision, pos: Vector3) -> void:
	var red: Material = ToonMaterials.toon(Color("#C8281E"))
	var cap: Material = ToonMaterials.toon(Color("#F4B400"))
	_mesh(parent, MeshLib.cylinder(0.16, 0.6), red, pos + Vector3(0, 0.3, 0))
	_mesh(parent, MeshLib.sphere(0.16, true), cap, pos + Vector3(0, 0.6, 0))
	_mesh(parent, MeshLib.cylinder(0.06, 0.45), red, pos + Vector3(0, 0.4, 0), Vector3(0, 0, 90))
	col.add_box(pos + Vector3(0, 0.4, 0), Vector3(0.4, 0.8, 0.4), "hydrant")


static func bodega_front(parent: Node3D, col: WorldCollision, face_center: Vector3, front: Vector3, sign_text: String, accent: Color) -> void:
	## Storefront on a building face: awning, neon sign, glowing door,
	## roll-down gate with procedural graffiti stripes.
	var yaw: float = rad_to_deg(atan2(front.x, front.z))
	var side: Vector3 = Vector3(front.z, 0, -front.x)
	_mesh(parent, MeshLib.box(Vector3(6.0, 0.12, 1.6)), ToonMaterials.toon(accent), face_center + Vector3(0, 3.0, 0) + front * 0.8, Vector3(-15, yaw, 0))
	_mesh(parent, MeshLib.box(Vector3(5.2, 0.7, 0.12)), ToonMaterials.toon(Color("#101018")), face_center + Vector3(0, 3.6, 0) + front * 0.08, Vector3(0, yaw, 0))
	var sign: Label3D = Label3D.new()
	sign.text = sign_text
	sign.font_size = 72
	sign.pixel_size = 0.006
	sign.modulate = Color("#FFE060")
	sign.outline_modulate = Color("#FF3EA5")
	sign.outline_size = 10
	sign.shaded = false
	sign.position = face_center + Vector3(0, 3.6, 0) + front * 0.16
	sign.rotation_degrees = Vector3(0, yaw, 0)
	parent.add_child(sign)
	_mesh(parent, MeshLib.box(Vector3(1.3, 2.3, 0.1)), ToonMaterials.toon(Color("#FFE0A0"), false, false, Color("#FFC870"), 1.6), face_center + Vector3(0, 1.15, 0) + side * 1.2 + front * 0.03, Vector3(0, yaw, 0))
	var gate: Material = ToonMaterials.toon(Color("#8A8E98"))
	_mesh(parent, MeshLib.box(Vector3(2.6, 2.4, 0.08)), gate, face_center + Vector3(0, 1.2, 0) - side * 1.3 + front * 0.05, Vector3(0, yaw, 0))
	var tags: Array[Color] = [Color("#FF3EA5"), Color("#12C2B0"), Color("#F4B400")]
	for i: int in tags.size():
		_mesh(parent, MeshLib.box(Vector3(1.6 - 0.3 * float(i), 0.22, 0.02)), ToonMaterials.toon(tags[i], false), face_center + Vector3(0.1 * float(i), 0.7 + 0.45 * float(i), 0) - side * 1.3 + front * 0.1, Vector3(0, yaw, 8.0 - 6.0 * float(i)))
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color("#FFD27A")
	glow.light_energy = 1.4
	glow.omni_range = 6.0
	glow.position = face_center + Vector3(0, 2.4, 0) + front * 1.4
	glow.add_to_group("cc_lights")
	parent.add_child(glow)


static func ground_tile(parent: Node3D, center: Vector3, size: Vector2, mat: Material, height: float = 0.0) -> MeshInstance3D:
	if height > 0.01:
		return _mesh(parent, MeshLib.box(Vector3(size.x, height, size.y)), mat, center + Vector3(0, height * 0.5, 0))
	return _mesh(parent, MeshLib.plane(size), mat, center + Vector3(0, 0.001, 0))
