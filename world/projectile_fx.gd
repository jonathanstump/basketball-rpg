class_name ProjectileFx
extends Node3D
## Revision 11: draws the sim's live projectile hitboxes (the Stoop Queen's
## chancla, pigeon streams, thrown bottles...) and wide gust arcs, so what hits
## you is what you see. Pure view: reads game.combat.hitboxes, never mutates.
## Looks come from the move's `projectile` block via hitbox tags: look
## (orb | slipper), color, visual_radius.

const WIDE_ARC_M: float = 5.0
const DEFAULT_COLOR: Color = Color("#FFB000")

var game: GameWorld
var combat: CombatSystem = null   # taken from `game` when unset (tests set these directly)
var world: SimWorld = null
var views: Dictionary = {}   # hitbox instance id -> Node3D


static func wants(hb: Hitbox) -> String:
	## "proj" | "arc" | "" — which hitboxes get a view.
	if hb.delay > 0 or hb.frames_left <= 0:
		return ""
	if hb.projectile:
		return "proj"
	if hb.volume.shape == "arc" and hb.volume.radius >= WIDE_ARC_M and hb.team != 0:
		return "arc"
	return ""


func _process(delta: float) -> void:
	if combat == null and game != null:
		combat = game.combat
		world = game.sim
	if combat == null:
		return
	var seen: Dictionary = {}
	for hb: Hitbox in combat.hitboxes:
		var kind: String = wants(hb)
		if kind == "":
			continue
		var key: int = hb.get_instance_id()
		seen[key] = true
		var v: Node3D = views.get(key, null)
		if v == null:
			v = _projectile_view(hb) if kind == "proj" else _arc_view(hb)
			add_child(v)
			views[key] = v
		var vol: HitVolume = hb.volume
		if kind == "proj":
			v.position = vol.center() + Vector3(0, vol.y_offset + vol.height * 0.5, 0)
			var flat: Vector3 = Vector3(hb.velocity.x, 0, hb.velocity.z)
			if flat.length() > 0.01:
				v.rotation.y = atan2(-flat.x, -flat.z)
			var body: Node3D = v.get_node("Body") as Node3D
			body.rotation.x -= delta * 18.0   # tumbling end over end
			var shadow: Node3D = v.get_node("Shadow") as Node3D
			var gy: float = world.collision.ground_height(v.position) if world != null else 0.0
			shadow.global_position = Vector3(v.position.x, gy + 0.04, v.position.z)
		else:
			v.position = vol.origin + Vector3(0, vol.y_offset + 0.15, 0)
			v.rotation.y = vol.yaw
	for k: Variant in views.keys():
		if not seen.has(k):
			(views[k] as Node).queue_free()
			views.erase(k)


func _projectile_view(hb: Hitbox) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Projectile"
	var col: Color = Color(str(hb.tags.get("color", DEFAULT_COLOR.to_html())))
	var r: float = float(hb.tags.get("visual_radius", maxf(0.35, hb.volume.radius)))
	var body: MeshInstance3D = MeshInstance3D.new()
	body.name = "Body"
	if str(hb.tags.get("look", "orb")) == "slipper":
		body.mesh = MeshLib.box(Vector3(r * 1.1, r * 0.35, r * 2.2))
	else:
		body.mesh = MeshLib.sphere(r)
	body.material_override = ToonMaterials.toon(col, true, false, col, 1.6)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	## Glow halo + a streak behind it so it reads at speed from the camera.
	var halo: MeshInstance3D = MeshInstance3D.new()
	halo.mesh = MeshLib.sphere(r * 1.6)
	halo.material_override = _alpha_mat(col, 0.28)
	root.add_child(halo)
	var trail: MeshInstance3D = MeshInstance3D.new()
	trail.mesh = MeshLib.cylinder(r * 0.7, r * 6.0, r * 0.05)
	trail.material_override = _alpha_mat(col, 0.35)
	trail.rotation.x = -PI * 0.5
	trail.position = Vector3(0, 0, r * 3.4)
	root.add_child(trail)
	var shadow: MeshInstance3D = MeshInstance3D.new()
	shadow.name = "Shadow"
	shadow.mesh = MeshLib.cylinder(r * 1.2, 0.02)
	shadow.material_override = _alpha_mat(Color(0, 0, 0), 0.45)
	root.add_child(shadow)
	return root


func _arc_view(hb: Hitbox) -> Node3D:
	## A translucent fan on the ground covering the gust's reach.
	var root: Node3D = Node3D.new()
	root.name = "GustArc"
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = fan_mesh(hb.volume.radius, hb.volume.angle)
	mi.material_override = _alpha_mat(Color("#BFF4FF"), 0.35)
	root.add_child(mi)
	return root


static func fan_mesh(radius: float, angle_deg: float) -> ArrayMesh:
	## Flat fan around local -Z (the hit volume's forward at yaw 0).
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = maxi(4, int(angle_deg / 8.0))
	var half: float = deg_to_rad(angle_deg) * 0.5
	for i: int in n:
		var a0: float = -half + float(i) / float(n) * half * 2.0
		var a1: float = -half + float(i + 1) / float(n) * half * 2.0
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(-sin(a1), 0, -cos(a1)) * radius)
		st.add_vertex(Vector3(-sin(a0), 0, -cos(a0)) * radius)
	return st.commit()


static func _alpha_mat(col: Color, alpha: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
