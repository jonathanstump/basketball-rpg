class_name ChainView
extends Node3D
## Your dropped chain (spec §5.4): a glowing gold rope chain on the ground
## where you got cooked. Touch it to run it back.

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
	return v


func _process(delta: float) -> void:
	rotate_y(delta * 0.8)
