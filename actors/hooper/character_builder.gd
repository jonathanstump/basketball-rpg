class_name CharacterBuilder
extends RefCounted
## Customization profile -> puppet rig (spec §6.1, §6.2, §15.11). One body base,
## no gendered options. Profile keys default to DEFAULT_PROFILE.

const DEFAULT_PROFILE: Dictionary = {
	"skin": "#8D5524", "hair_style": "high_top", "hair_color": "#1A1210", "eye_color": "#3B2414",
	"top_color": "#7B2FF7", "shorts_color": "#12C2B0", "shoe_color": "#F2F6FF", "sock_color": "#FFFFFF",
	"height": 1.0, "headband": "", "facial_hair": "none", "freckles": false, "brows": 0, "mouth": 0,
}


static func profile_value(profile: Dictionary, key: String) -> Variant:
	return profile.get(key, DEFAULT_PROFILE.get(key))


static func color_of(profile: Dictionary, key: String) -> Color:
	return JU.color(profile_value(profile, key), Color.WHITE)


static func build(profile: Dictionary = {}) -> PuppetRig:
	var rig: PuppetRig = PuppetRig.new()
	rig.name = "PuppetRig"
	var skin: Material = ToonMaterials.toon(color_of(profile, "skin"))
	var top: Material = ToonMaterials.toon(color_of(profile, "top_color"))
	var shorts: Material = ToonMaterials.toon(color_of(profile, "shorts_color"))
	var shoe: Material = ToonMaterials.toon(color_of(profile, "shoe_color"))
	var sock: Material = ToonMaterials.toon(color_of(profile, "sock_color"))
	var dark: Material = ToonMaterials.toon(Color("#0B0B10"), false)
	var white: Material = ToonMaterials.toon(Color("#F8F8F8"), false)

	rig.add_joint("hips", "", Vector3(0, 0.54, 0))
	rig.add_part("hips", MeshLib.capsule(0.13, 0.36), shorts, Vector3(0, -0.05, 0), Vector3(0, 0, 90), Vector3(1, 1, 0.85))
	rig.add_joint("torso", "hips", Vector3(0, 0.02, 0))
	rig.add_part("torso", MeshLib.capsule(0.165, 0.4), top, Vector3(0, 0.18, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
	rig.add_joint("head", "torso", Vector3(0, 0.36, 0))
	rig.add_part("head", MeshLib.capsule(0.06, 0.12), skin, Vector3(0, 0.02, 0))
	rig.add_part("head", MeshLib.sphere(0.26), skin, Vector3(0, 0.25, 0), Vector3.ZERO, JU.vec3(_opt("face_shapes", profile, "face_shape").get("scale"), Vector3.ONE))
	_build_face(rig, profile, skin, dark, white)
	_build_hair(rig, profile)
	for side: String in ["l", "r"]:
		var sx: float = -1.0 if side == "l" else 1.0
		rig.add_joint("upper_arm_" + side, "torso", Vector3(0.2 * sx, 0.3, 0))
		rig.add_part("upper_arm_" + side, MeshLib.sphere(0.075), top, Vector3(0, -0.02, 0))
		rig.add_part("upper_arm_" + side, MeshLib.capsule(0.055, 0.22), skin, Vector3(0, -0.1, 0))
		rig.add_joint("lower_arm_" + side, "upper_arm_" + side, Vector3(0, -0.2, 0))
		rig.add_part("lower_arm_" + side, MeshLib.capsule(0.05, 0.2), skin, Vector3(0, -0.09, 0))
		rig.add_joint("hand_" + side, "lower_arm_" + side, Vector3(0, -0.18, 0))
		rig.add_part("hand_" + side, MeshLib.sphere(0.068), skin, Vector3(0, -0.03, 0))
		rig.add_joint("thigh_" + side, "hips", Vector3(0.09 * sx, -0.02, 0))
		rig.add_part("thigh_" + side, MeshLib.capsule(0.072, 0.26), skin, Vector3(0, -0.12, 0))
		rig.add_joint("shin_" + side, "thigh_" + side, Vector3(0, -0.24, 0))
		rig.add_part("shin_" + side, MeshLib.capsule(0.062, 0.24), skin, Vector3(0, -0.1, 0))
		rig.add_part("shin_" + side, MeshLib.cylinder(0.066, 0.08), sock, Vector3(0, -0.17, 0))
		rig.add_joint("foot_" + side, "shin_" + side, Vector3(0, -0.22, 0))
		rig.add_part("foot_" + side, MeshLib.box(Vector3(0.13, 0.09, 0.24)), shoe, Vector3(0, -0.03, -0.04))
		rig.add_part("foot_" + side, MeshLib.box(Vector3(0.135, 0.025, 0.25)), white, Vector3(0, -0.075, -0.04))
	var band: String = str(profile_value(profile, "headband"))
	if band != "":
		rig.add_part("head", MeshLib.torus(0.245, 0.29), ToonMaterials.toon(JU.color(band, Color.RED)), Vector3(0, 0.33, 0), Vector3(-8, 0, 0), Vector3(1, 0.6, 1))
	var anchor: Node3D = Node3D.new()
	anchor.name = "BallAnchor"
	anchor.position = Vector3(0, -0.13, -0.02)
	rig.joint("hand_r").add_child(anchor)
	rig.ball_anchor = anchor
	return rig


static func _opt(list: String, profile: Dictionary, key: String) -> Dictionary:
	## Creator option by index (data/creator.json), {} when unset/out of range.
	var arr: Array = JU.a(DataDB.get_dict("creator"), list)
	var v: Variant = profile.get(key, 0)
	var i: int = int(v) if (v is int or v is float) else 0
	return arr[i] as Dictionary if i >= 0 and i < arr.size() and arr[i] is Dictionary else {}


static func _build_face(rig: PuppetRig, profile: Dictionary, skin: Material, dark: Material, white: Material) -> void:
	var eye: Material = ToonMaterials.toon(color_of(profile, "eye_color"), false)
	var eye_o: Dictionary = _opt("eye_shapes", profile, "eye_shape")
	var eye_sc: Vector3 = JU.vec3(eye_o.get("scale"), Vector3(1, 1.25, 0.6))
	var brow: Dictionary = _opt("brows", profile, "brows")
	var bsize: Array = JU.a(brow, "size")
	var bw: float = float(bsize[0]) if bsize.size() > 0 else 0.1
	var bh: float = float(bsize[1]) if bsize.size() > 1 else 0.022
	for sx: float in [-1.0, 1.0]:
		rig.add_part("head", MeshLib.sphere(0.062), white, Vector3(0.095 * sx, 0.28, -0.205), Vector3(0, 0, JU.f(eye_o, "tilt") * sx), eye_sc)
		rig.add_part("head", MeshLib.sphere(0.034), eye, Vector3(0.095 * sx, 0.275, -0.245))
		rig.add_part("head", MeshLib.box(Vector3(bw, bh, 0.03)), dark, Vector3(0.095 * sx, 0.37, -0.22), Vector3(0, 0, (JU.f(brow, "tilt", -8.0)) * sx))
		rig.add_part("head", MeshLib.sphere(0.055), skin, Vector3(0.255 * sx, 0.25, 0.0))
	var nose: Dictionary = _opt("noses", profile, "nose")
	rig.add_part("head", MeshLib.sphere(JU.f(nose, "r", 0.032)), skin, Vector3(0, 0.215, -0.26 - JU.f(nose, "z")))
	var mouth: Dictionary = _opt("mouths", profile, "mouth")
	rig.add_part("head", MeshLib.box(Vector3(JU.f(mouth, "w", 0.09), 0.018, 0.03)), dark, Vector3(0, 0.15, -0.235), Vector3(0, 0, JU.f(mouth, "tilt", 4.0)))
	if JU.b(mouth, "curve"):
		for sx2: float in [-1.0, 1.0]:
			rig.add_part("head", MeshLib.box(Vector3(0.025, 0.018, 0.03)), dark, Vector3(0.055 * sx2, 0.16, -0.232), Vector3(0, 0, -35.0 * sx2))
	_build_marks(rig, profile, dark, skin)


static func _build_marks(rig: PuppetRig, profile: Dictionary, dark: Material, skin: Material) -> void:
	var hair_col: Material = ToonMaterials.toon(color_of(profile, "hair_color"), false)
	var dot: Material = ToonMaterials.toon(color_of(profile, "skin").darkened(0.35), false)
	match str(profile.get("marks", "none")):
		"freckles":
			for p: Vector3 in [Vector3(-0.12, 0.22, -0.225), Vector3(-0.09, 0.2, -0.235), Vector3(0.12, 0.22, -0.225), Vector3(0.09, 0.2, -0.235)]:
				rig.add_part("head", MeshLib.sphere(0.01), dot, p)
		"beauty_mark":
			rig.add_part("head", MeshLib.sphere(0.012), dark, Vector3(0.08, 0.17, -0.235))
		"cheek_scar":
			rig.add_part("head", MeshLib.box(Vector3(0.05, 0.008, 0.02)), dot, Vector3(-0.13, 0.22, -0.215), Vector3(0, 0, 30))
		"brow_slit":
			rig.add_part("head", MeshLib.box(Vector3(0.008, 0.03, 0.035)), skin, Vector3(0.11, 0.37, -0.222))
		"dimples":
			for sx: float in [-1.0, 1.0]:
				rig.add_part("head", MeshLib.sphere(0.01), dot, Vector3(0.1 * sx, 0.15, -0.228))
	match str(profile.get("facial_hair", "none")):
		"stubble":
			rig.add_part("head", MeshLib.sphere(0.2), ToonMaterials.toon(color_of(profile, "skin").darkened(0.18), false), Vector3(0, 0.15, -0.06), Vector3.ZERO, Vector3(1.05, 0.5, 0.95))
		"mustache":
			rig.add_part("head", MeshLib.box(Vector3(0.11, 0.022, 0.03)), hair_col, Vector3(0, 0.18, -0.24))
		"goatee":
			rig.add_part("head", MeshLib.box(Vector3(0.05, 0.05, 0.04)), hair_col, Vector3(0, 0.1, -0.22))
		"chin_strap":
			rig.add_part("head", MeshLib.torus(0.17, 0.2), hair_col, Vector3(0, 0.16, -0.05), Vector3(70, 0, 0), Vector3(1.1, 1, 0.8))
		"full_beard":
			rig.add_part("head", MeshLib.sphere(0.21), hair_col, Vector3(0, 0.12, -0.07), Vector3.ZERO, Vector3(1.1, 0.7, 1.0))


static func _build_hair(rig: PuppetRig, profile: Dictionary) -> void:
	var style: Dictionary = DataDB.item("hair_styles", str(profile_value(profile, "hair_style")))
	var mat: Material = ToonMaterials.toon(color_of(profile, "hair_color"))
	var head_center: Vector3 = Vector3(0, 0.25, 0)
	for p: Variant in JU.a(style, "parts"):
		var part: Dictionary = p
		var mesh: Mesh = MeshLib.from_recipe(JU.s(part, "shape"), JU.a(part, "size"))
		var pos: Vector3 = head_center + JU.vec3(part.get("pos"))
		var rot: Vector3 = JU.vec3(part.get("rot"))
		var sc: Vector3 = JU.vec3(part.get("scale"), Vector3.ONE)
		rig.add_part("head", mesh, mat, pos, rot, sc)
