class_name BossBuilder
extends RefCounted
## Composes a boss silhouette from primitive recipes in the boss file's
## "look" (spec §15.11): joints (pivot positions) + parts (shape, size, pos,
## rot, scale, color key, optional tag/emit). Tagged parts can be toggled
## per phase (the Stoop Queen's lawn chair disappears when she stands).


static func build(look: Dictionary) -> PuppetRig:
	var rig: PuppetRig = PuppetRig.new()
	rig.name = "BossRig"
	var joints: Dictionary = JU.dict(look, "joints")
	var order: PackedStringArray = ["hips", "torso", "head", "arm_l", "arm_r", "leg_l", "leg_r", "tail", "extra"]
	var parents: Dictionary = {"hips": "", "torso": "hips", "head": "torso", "arm_l": "torso", "arm_r": "torso", "leg_l": "hips", "leg_r": "hips", "tail": "hips", "extra": "hips"}
	for jn: String in order:
		if joints.has(jn) or jn == "hips":
			var parent_name: String = str(parents[jn])
			while parent_name != "" and not rig.joints.has(parent_name):
				parent_name = str(parents.get(parent_name, ""))
			var pos: Vector3 = JU.vec3(joints.get(jn, [0, 0, 0]))
			if parent_name != "":
				pos -= _abs_pos(joints, parent_name, parents)
			rig.add_joint(jn, parent_name, pos)
	var colors: Dictionary = JU.dict(look, "colors")
	var tagged: Dictionary = {}
	for p: Variant in JU.a(look, "parts"):
		var part: Dictionary = p
		var jn2: String = JU.s(part, "joint", "hips")
		if not rig.joints.has(jn2):
			jn2 = "hips"
		var key: String = JU.s(part, "color", "#FF00FF")
		var col: Color = JU.color(colors.get(key, key), Color.MAGENTA)
		var emit: float = JU.f(part, "emit", 0.0)
		var mat: Material = ToonMaterials.toon(col, JU.b(part, "outline", true), false, col if emit > 0.0 else Color.BLACK, emit)
		var mi: MeshInstance3D = rig.add_part(jn2, MeshLib.from_recipe(JU.s(part, "shape", "sphere"), JU.a(part, "size")), mat,
			JU.vec3(part.get("pos")), JU.vec3(part.get("rot")), JU.vec3(part.get("scale"), Vector3.ONE))
		var tag: String = JU.s(part, "tag")
		if tag != "":
			if not tagged.has(tag):
				tagged[tag] = []
			(tagged[tag] as Array).append(mi)
	rig.set_meta("tagged", tagged)
	return rig


static func _abs_pos(joints: Dictionary, jn: String, parents: Dictionary) -> Vector3:
	return JU.vec3(joints.get(jn, [0, 0, 0]))


static func set_tag_visible(rig: PuppetRig, tag: String, on: bool) -> void:
	var tagged: Dictionary = rig.get_meta("tagged", {})
	for mi: Variant in tagged.get(tag, []):
		(mi as MeshInstance3D).visible = on
