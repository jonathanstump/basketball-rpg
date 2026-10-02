class_name BossView
extends ActorView
## Renders a boss: data-built rig + procedural animation (spec §15.11):
## breathing idle, windup lean-back, strike lunge, red flash on unblockable
## telegraphs, slump when SHOOK, stand-up between phases, scale per phase.

var _t: float = 0.0
var _phase_scale: float = 1.0
var boss_data: Dictionary = {}


static func create_boss(a: SimActor, data: Dictionary) -> BossView:
	var v: BossView = BossView.new()
	v.actor = a
	v.boss_data = data
	v.name = "Boss_" + a.archetype
	v.body = Node3D.new()
	v.add_child(v.body)
	v.rig = BossBuilder.build(JU.dict(data, "look"))
	v.body.add_child(v.rig)
	v.animator = PuppetAnimator.new("hooper")
	var blob: MeshInstance3D = ActorView._blob_shadow()
	blob.scale = Vector3.ONE * (a.radius / 0.32)
	v.add_child(blob)
	v.position = a.pos
	v.physics_synced()
	v.physics_synced()
	return v


func _process(delta: float) -> void:
	if actor == null:
		return
	_t += delta
	var f: float = Engine.get_physics_interpolation_fraction()
	position = _prev_pos.lerp(_curr_pos, f)
	rotation.y = actor.facing
	var want_scale: float = float(actor.flags.get("scale", 1.0))
	_phase_scale = lerpf(_phase_scale, want_scale, clampf(delta * 2.0, 0.0, 1.0))
	body.scale = Vector3.ONE * _phase_scale
	BossBuilder.set_tag_visible(rig, "chair", want_scale <= 1.01)
	var torso: Node3D = rig.joint("torso")
	var head: Node3D = rig.joint("head")
	var arm_r: Node3D = rig.joint("arm_r")
	var arm_l: Node3D = rig.joint("arm_l")
	var lean: float = 0.0
	var arm: float = 0.0
	var breath: float = sin(_t * 2.2) * 0.03
	match actor.anim_state:
		"windup":
			lean = -0.25
			arm = -1.8
		"attack":
			lean = 0.35
			arm = 1.2
		"recover":
			lean = 0.1
			arm = 0.4
		"shook", "stagger":
			lean = 0.6
			arm = 0.3
			breath = sin(_t * 9.0) * 0.05
		"transition":
			lean = -0.2 + sin(_t * 6.0) * 0.1
		"walk":
			lean = 0.08
			breath = sin(_t * 8.0) * 0.06
	if torso != null:
		torso.rotation.x = lerpf(torso.rotation.x, -lean, clampf(delta * 10.0, 0.0, 1.0))
		torso.scale = Vector3(1.0 - breath * 0.5, 1.0 + breath, 1.0 - breath * 0.5)
	if head != null:
		head.rotation.x = lerpf(head.rotation.x, 0.3 if actor.anim_state == "shook" else 0.0, clampf(delta * 6.0, 0.0, 1.0))
	if arm_r != null:
		arm_r.rotation.x = lerpf(arm_r.rotation.x, arm, clampf(delta * 12.0, 0.0, 1.0))
	if arm_l != null:
		arm_l.rotation.x = lerpf(arm_l.rotation.x, arm * 0.4, clampf(delta * 8.0, 0.0, 1.0))
	var blob: Node3D = get_node_or_null("Blob")
	if blob != null:
		blob.global_position.y = actor.ground_y + 0.02
	var red: bool = bool(actor.flags.get("unblockable_flash", false)) and fmod(_t, 0.2) < 0.1
	if _flash_t > 0.0:
		_flash_t -= delta
	rig.set_tint(Color(2.2, 0.3, 0.3) if red else (Color(2.0, 2.0, 2.0) if _flash_t > 0.0 else Color.WHITE))
