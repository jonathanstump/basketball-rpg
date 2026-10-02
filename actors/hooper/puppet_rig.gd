class_name PuppetRig
extends Node3D
## Segmented "puppet" rig (spec §15.11): body parts are separate meshes on
## pivot nodes; no skinned meshes. Poses are per-joint euler rotations.

const JOINTS: PackedStringArray = ["hips", "torso", "head", "upper_arm_l", "lower_arm_l", "hand_l",
	"upper_arm_r", "lower_arm_r", "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]

var joints: Dictionary = {}     # name -> Node3D pivot
var rest: Dictionary = {}       # name -> Vector3 rest position
var hips_rest: Vector3 = Vector3.ZERO
var squash: float = 0.0         # >0 squashes (land), <0 stretches (jump)
var ball_anchor: Node3D = null  # hand_r child where a held ball sits


func add_joint(joint_name: String, parent_name: String, offset: Vector3) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = joint_name
	pivot.position = offset
	var parent: Node3D = self if parent_name == "" else joints[parent_name]
	parent.add_child(pivot)
	joints[joint_name] = pivot
	rest[joint_name] = offset
	if joint_name == "hips":
		hips_rest = offset
	return pivot


func add_part(joint_name: String, mesh: Mesh, mat: Material, offset: Vector3, rot_deg: Vector3 = Vector3.ZERO, scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = offset
	mi.rotation_degrees = rot_deg
	mi.scale = scale_v
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(joints[joint_name] as Node3D).add_child(mi)
	return mi


func joint(joint_name: String) -> Node3D:
	return joints.get(joint_name, null)


func apply_pose(pose: Dictionary) -> void:
	for jn: String in JOINTS:
		if not joints.has(jn):
			continue
		var j: Node3D = joints[jn]
		var e: Vector3 = pose.get(jn, Vector3.ZERO)
		j.rotation = Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z))
	var hips: Node3D = joints.get("hips", null)
	if hips != null:
		var off: Vector3 = pose.get("_root", Vector3.ZERO)
		var rr: Vector3 = pose.get("_root_rot", Vector3.ZERO)
		hips.position = hips_rest + off * (hips_rest.y / 0.5)
		hips.rotation = Vector3(deg_to_rad(rr.x), deg_to_rad(rr.y), deg_to_rad(rr.z))
	var s: float = clampf(squash, -0.4, 0.4)
	scale = Vector3(1.0 + s * 0.5, 1.0 - s, 1.0 + s * 0.5)


var _tint: Color = Color.WHITE
var _meshes: Array[MeshInstance3D] = []


func set_tint(c: Color) -> void:
	## Hit-flash / glow tint through the toon shader's instance uniform.
	if c == _tint:
		return
	_tint = c
	if _meshes.is_empty():
		for n: Node in find_children("*", "MeshInstance3D", true, false):
			_meshes.append(n as MeshInstance3D)
	for mi: MeshInstance3D in _meshes:
		mi.set_instance_shader_parameter("tint", c)
