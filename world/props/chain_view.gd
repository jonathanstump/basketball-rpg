class_name ChainView
extends Node3D
## Your dropped chain (spec §5.4): a glowing gold rope chain on the ground
## where you got cooked, under a gold light beam you can see over the
## rooftops (revision 8). Touch it to run it back.

const BEAM_H: float = 90.0

var index: int = 0


static func create(pos: Vector3, rep: int) -> ChainView:
	var v: ChainView = ChainView.new()
	v.name = "Chain"
	v.position = pos
	var gold: Material = ToonMaterials.toon(Color("#F4B400"), true, false, Color("#FFC830"), 1.4)
	for i: int in 9:
		var link: MeshInstance3D = MeshInstance3D.new()
		link.mesh = MeshLib.torus(0.05, 0.09)
		link.material_override = gold
		var a: float = float(i) / 9.0 * TAU
		link.position = Vector3(cos(a) * 0.35, 0.1, sin(a) * 0.35)
		link.rotation = Vector3(PI * 0.5 * float(i % 2), a, 0)
		v.add_child(link)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color("#FFC830")
	light.light_energy = 1.5
	light.omni_range = 4.0
	light.position = Vector3(0, 0.6, 0)
	v.add_child(light)
	var label: Label3D = Label3D.new()
	label.text = "%d REP" % rep
	label.font_size = 48
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("#FFE060")
	label.position = Vector3(0, 1.2, 0)
	v.add_child(label)
	v.add_child(_beam(0.55, 0.22))
	v.add_child(_beam(0.16, 0.6))
	return v


static func _beam(radius: float, alpha: float) -> MeshInstance3D:
	## An additive, unlit column: no light, no shadow (§15.17 budgets).
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Beam"
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = radius * 0.6
	cyl.bottom_radius = radius
	cyl.height = BEAM_H
	cyl.radial_segments = 12
	cyl.cap_top = false
	cyl.cap_bottom = false
	mi.mesh = cyl
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.0, 0.78, 0.2, alpha)
	m.disable_receive_shadows = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0, BEAM_H * 0.5, 0)
	return mi


func _process(delta: float) -> void:
	rotate_y(delta * 0.8)
