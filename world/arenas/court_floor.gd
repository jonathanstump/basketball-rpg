class_name CourtFloor
extends RefCounted
## Builds a half-court floor slab with procedural lines (court.gdshader)
## aligned to a SimHoop. Used by labs, park courts and boss arenas.

const COURT: Shader = preload("res://rendering/shaders/court.gdshader")


static func build(parent: Node3D, hoop: SimHoop, size: Vector2, center: Vector3, colors: Dictionary = {}) -> MeshInstance3D:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = COURT
	mat.set_shader_parameter("hoop_floor", hoop.floor_point())
	mat.set_shader_parameter("hoop_facing", hoop.facing)
	mat.set_shader_parameter("floor_color", JU.color(colors.get("floor", "#2C5D8F")))
	mat.set_shader_parameter("key_color", JU.color(colors.get("key", "#8C1F2A")))
	mat.set_shader_parameter("line_color", JU.color(colors.get("line", "#F2F6FF")))
	mat.set_shader_parameter("wood", 1.0 if bool(colors.get("wood", false)) else 0.0)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "CourtFloor"
	mi.mesh = MeshLib.box(Vector3(size.x, 0.04, size.y))
	mi.material_override = mat
	mi.position = center + Vector3(0, 0.0, 0)
	parent.add_child(mi)
	return mi


static func set_arc_glow(floor_mi: MeshInstance3D, on: bool) -> void:
	(floor_mi.material_override as ShaderMaterial).set_shader_parameter("arc_glow", 1.0 if on else 0.0)
