class_name DistrictViews
extends Node3D
## Node views for a district's interactive pieces: shoeboxes (brand-colored
## lids), graffiti tags, NPCs, station signs, crossing arches, shortcut
## ladders/gates, rooftop access ladders, court fences, hoops, Wire Kicks.

var d: District
var boxes: Dictionary = {}       # box id -> Node3D
var shortcuts: Dictionary = {}   # shortcut id -> Node3D


func _init(district: District) -> void:
	d = district
	name = "DistrictViews"


func build() -> void:
	var lay: Dictionary = d.layout
	for h: Variant in JU.a(lay, "hoops"):
		d.presenter.add_hoop_view(h as SimHoop)
	for ct: Variant in JU.a(lay, "courts"):
		var cd: Dictionary = ct
		var hoop: SimHoop = cd["hoop"]
		d.presenter.add_hoop_view(hoop)
		CourtFloor.build(self, hoop, cd["size"], (cd["center"] as Vector3) + Vector3(0, 0.01, 0), {"floor": "#3A2A5A", "key": "#7B2FF7"})
		if not bool(cd["open"]):
			ArenaThemes.fence(_holder(cd["center"]), (cd["size"] as Vector2) * 0.5, false)
	for k: Variant in JU.a(lay, "kicks"):
		var kd: Dictionary = k
		if not bool(kd["taken"]):
			var dir: Vector3 = kd["dir"]
			d.presenter.add_wire_kicks_view(str(kd["id"]), kd["pos"], Vector3(dir.z, 0, -dir.x) if dir != Vector3.ZERO else Vector3(1, 0, 0), Color("#FF3EA5"))
	for b: Variant in JU.a(lay, "boxes"):
		_box(b as Dictionary)
	for t: Variant in JU.a(lay, "tags"):
		_tag(t as Dictionary)
	for n: Variant in JU.a(lay, "npcs"):
		_npc(n as Dictionary)
	for s: Variant in JU.a(lay, "stations"):
		_label((s as Dictionary)["pos"] as Vector3 + Vector3(0, 3.0, 0), str((s as Dictionary)["name"]).to_upper() + " STATION", Color("#3CFF8A"), 64)
	for c: Variant in JU.a(lay, "crossings"):
		var cd2: Dictionary = c
		_label((cd2["pos"] as Vector3) + Vector3(0, 4.0, 0), "TO " + str(cd2["name"]).to_upper(), Color("#FFE060"), 56)
	for sc: Variant in JU.a(lay, "shortcuts"):
		_shortcut(sc as Dictionary)
	for se: Variant in JU.a(lay, "secrets"):
		for key: String in ["a", "b"]:
			var p: Vector3 = (se as Dictionary)[key]
			_mesh(MeshLib.box(Vector3(0.6, 3.5, 0.15)), ToonMaterials.toon(Color("#20242C")), p + Vector3(0, 1.75, 0))
	for bd: Variant in JU.a(lay, "bodegas"):
		var door: Vector3 = (bd as Dictionary)["door"]
		GameState.flags["bodega_door_" + JU.s(bd as Dictionary, "id")] = [d.map.cell_of(door).x, d.map.cell_of(door).y]


func _holder(p: Vector3) -> Node3D:
	var n: Node3D = Node3D.new()
	n.position = p
	add_child(n)
	return n


func _mesh(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	add_child(mi)
	return mi


func _label(pos: Vector3, text: String, col: Color, size_px: int) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = tr(text)
	l.font = UIFonts.title()
	l.font_size = size_px
	l.pixel_size = 0.008
	l.modulate = col
	l.outline_modulate = Color("#0B0B10")
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	add_child(l)
	return l


func _box(b: Dictionary) -> void:
	var root: Node3D = _holder(b["pos"])
	var opened: bool = GameState.opened_boxes.has(JU.s(b, "id"))
	var brand_col: Color = Color("#E8E2D8")
	var lid_col: Color = Color("#101014") if JU.s(b, "pool").contains("secret") else (Color("#F4B400") if bool(b["locked"]) else Color("#D7263D"))
	var base: MeshInstance3D = MeshInstance3D.new()
	base.mesh = MeshLib.box(Vector3(0.9, 0.42, 0.55))
	base.material_override = ToonMaterials.toon(brand_col)
	base.position = Vector3(0, 0.21, 0)
	root.add_child(base)
	var lid: MeshInstance3D = MeshInstance3D.new()
	lid.name = "Lid"
	lid.mesh = MeshLib.box(Vector3(0.94, 0.12, 0.6))
	lid.material_override = ToonMaterials.toon(lid_col)
	lid.position = Vector3(0, 0.48, 0) if not opened else Vector3(0.6, 0.06, 0.3)
	root.add_child(lid)
	if bool(b["locked"]) and not opened:
		var lock: MeshInstance3D = MeshInstance3D.new()
		lock.mesh = MeshLib.box(Vector3(0.14, 0.18, 0.08))
		lock.material_override = ToonMaterials.toon(Color("#C8CCD4"))
		lock.position = Vector3(0, 0.36, 0.3)
		root.add_child(lock)
	boxes[JU.s(b, "id")] = root


func open_box_view(id: String) -> void:
	var root: Node3D = boxes.get(id, null)
	if root == null:
		return
	var lid: Node3D = root.get_node_or_null("Lid")
	if lid != null:
		var tw: Tween = lid.create_tween()
		tw.tween_property(lid, "position", Vector3(0.6, 0.06, 0.3), 0.3)


func _tag(t: Dictionary) -> void:
	var l: Label3D = Label3D.new()
	l.text = str(t["text"])
	l.font = UIFonts.graffiti()
	l.font_size = 64
	l.pixel_size = 0.006
	var cols: Array[Color] = [Color("#FF3EA5"), Color("#3EF0FF"), Color("#F4B400"), Color("#7CFF9A")]
	l.modulate = cols[absi(str(t["id"]).hash()) % cols.size()]
	l.outline_modulate = Color("#0B0B10")
	l.outline_size = 8
	var wall: Vector3 = t["wall"]
	l.position = (t["pos"] as Vector3) + Vector3(0, 1.8, 0) - wall * 0.02
	l.rotation.y = atan2(-wall.x, -wall.z)
	l.rotation.z = -0.06
	add_child(l)


func _npc(n: Dictionary) -> void:
	var a: SimActor = SimActor.new()
	a.kind = "npc"
	a.team = 0
	a.pos = n["pos"]
	a.display_name = JU.s(n, "name")
	a.flags["no_pickup"] = true
	d.sim.add_actor(a)
	var look: Dictionary = JU.dict(n, "look")
	if look.is_empty():
		look = {"top_color": "#F2F6FF", "shorts_color": "#5A4A60", "skin": "#6B4226", "hair_style": "bun", "hair_color": "#C8C8C8", "height": 1.25}
	d.add_actor_view(a, look)
	a.anim_state = "idle"


func _shortcut(sc: Dictionary) -> void:
	var root: Node3D = _holder(sc["pos"])
	var open: bool = bool(sc["open"])
	var mat: Material = ToonMaterials.toon(Color("#3A4048") if JU.s(sc, "kind") == "ladder" else Color("#7A808C"))
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Blocker"
	mi.mesh = MeshLib.box(Vector3(MapData.TILE, 3.6, 0.2))
	mi.material_override = mat
	mi.position = Vector3(0, 1.8 if not open else -2.0, 0)
	root.add_child(mi)
	shortcuts[JU.s(sc, "id")] = root


func open_shortcut_view(id: String) -> void:
	var root: Node3D = shortcuts.get(id, null)
	if root == null:
		return
	var b: Node3D = root.get_node_or_null("Blocker")
	if b != null:
		var tw: Tween = b.create_tween()
		tw.tween_property(b, "position:y", -2.0, 0.6)
