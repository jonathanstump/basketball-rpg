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
var _flash_col: Color = Color(2.2, 2.2, 2.2)
var _punch_t: float = 0.0
var _base_scale: Vector3 = Vector3.ONE
var _pulse_t: float = 0.0
var aura: TelegraphAura   # red "about to attack" glow above hostile heads


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
	v._base_scale = v.body.scale
	v.animator = PuppetAnimator.new("hooper")
	v._prev_pos = a.pos
	v._curr_pos = a.pos
	v.position = a.pos
	v.add_child(_blob_shadow())
	v.aura = TelegraphAura.create(a)
	v.add_child(v.aura)
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
	_flash_col = Color(2.2, 2.2, 2.2)


func hit_react(heavy: bool) -> void:
	## Street enemies: a hot red-white flash and a squash so every landed
	## hit reads, bigger on heavy hits.
	_flash_t = 0.16 if heavy else 0.11
	_flash_col = Color(2.6, 1.3, 1.2)
	_punch_t = 0.22 if heavy else 0.15


static func open_pulse(a: SimActor) -> bool:
	## Downed / SHOOK street enemies glow gold: Dunk Finisher window.
	return a.team != 0 and a.kind == "enemy" and a.alive and (bool(a.flags.get("knocked", false)) or a.is_shook())


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
	if aura != null:
		aura.update_aura(delta, actor.height)
	if _punch_t > 0.0:
		_punch_t = maxf(0.0, _punch_t - delta)
		var k: float = _punch_t / 0.22
		body.scale = _base_scale * Vector3(1.0 + 0.18 * k, 1.0 - 0.16 * k, 1.0 + 0.18 * k)
	if _flash_t > 0.0:
		_flash_t -= delta
		rig.set_tint(_flash_col if _flash_t > 0.0 else Color.WHITE)
	elif open_pulse(actor):
		_pulse_t += delta
		rig.set_tint(Color.WHITE.lerp(Color(1.9, 1.6, 0.5), 0.5 + 0.5 * sin(_pulse_t * 10.0)))
	elif _pulse_t > 0.0:
		_pulse_t = 0.0
		rig.set_tint(Color.WHITE)
