class_name ActorView
extends Node3D
## Renders one SimActor: interpolates its transform between physics ticks and
## drives the puppet animator. Pure presentation; never mutates the sim.

var actor: SimActor
var rig: PuppetRig
var animator: PuppetAnimator
var body: Node3D
var _prev_pos: Vector3
var _curr_pos: Vector3
var _flash_t: float = 0.0


static func create(a: SimActor, profile: Dictionary = {}) -> ActorView:
	var v: ActorView = ActorView.new()
	v.actor = a
	v.name = "View_%d" % a.id
	v.body = Node3D.new()
	v.body.name = "Body"
	v.add_child(v.body)
	v.rig = CharacterBuilder.build(profile)
	v.body.add_child(v.rig)
	var h: float = float(CharacterBuilder.profile_value(profile, "height"))
	v.body.scale = Vector3.ONE * h
	v.animator = PuppetAnimator.new("hooper")
	v._prev_pos = a.pos
	v._curr_pos = a.pos
	v.position = a.pos
	v.add_child(_blob_shadow())
	return v


static func _blob_shadow() -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	m.name = "Blob"
	m.mesh = MeshLib.cylinder(0.32, 0.01)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = Vector3(0, 0.02, 0)
	return m


func physics_synced() -> void:
	## Called by GameWorld right after each sim step.
	_prev_pos = _curr_pos
	_curr_pos = actor.pos


func flash(duration_s: float = 0.08) -> void:
	_flash_t = duration_s


func _process(delta: float) -> void:
	if actor == null:
		return
	var f: float = Engine.get_physics_interpolation_fraction()
	position = _prev_pos.lerp(_curr_pos, f)
	rotation.y = actor.facing
	animator.update(rig, actor, delta)
	var blob: Node3D = get_node_or_null("Blob")
	if blob != null:
		blob.global_position.y = actor.ground_y + 0.02
	if _flash_t > 0.0:
		_flash_t -= delta
		rig.set_tint(Color(2.2, 2.2, 2.2) if _flash_t > 0.0 else Color.WHITE)
