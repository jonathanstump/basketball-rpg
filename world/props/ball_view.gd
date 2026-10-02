class_name BallView
extends Node3D
## Renders a SimBall. HELD balls are dribbled procedurally (hand-to-floor arc
## synced to the holder's stride, squash on the floor); other states
## interpolate the simulated position.

var ball: SimBall
var game: GameWorld
var mesh: MeshInstance3D
var _prev: Vector3
var _curr: Vector3
var _phase: float = 0.0
var _fire: GPUParticles3D = null


static func create(b: SimBall, g: GameWorld) -> BallView:
	var v: BallView = BallView.new()
	v.ball = b
	v.game = g
	v.name = "Ball_%d" % b.id
	v.mesh = MeshInstance3D.new()
	v.mesh.mesh = MeshLib.sphere(0.12)
	v.mesh.material_override = ToonMaterials.toon(_ball_color(b.item_id))
	v.add_child(v.mesh)
	var seam: MeshInstance3D = MeshInstance3D.new()
	seam.mesh = MeshLib.torus(0.115, 0.128)
	seam.material_override = ToonMaterials.toon(Color("#1A0E08"), false)
	v.mesh.add_child(seam)
	var seam2: MeshInstance3D = MeshInstance3D.new()
	seam2.mesh = seam.mesh
	seam2.material_override = seam.material_override
	seam2.rotation_degrees = Vector3(90, 0, 0)
	v.mesh.add_child(seam2)
	v._prev = b.pos
	v._curr = b.pos
	v.position = b.pos
	return v


static func _ball_color(item_id: String) -> Color:
	var c: Variant = {"ball_pinkie": "#FF6FB5", "ball_granite": "#7A7A84", "ball_midnight": "#1A1A40",
		"ball_glow": "#B8FF6A", "ball_beach": "#FFFFFF", "ball_chrome": "#D8DEE8", "ball_neon": "#3EF0FF",
		"ball_gator": "#E8E0C8", "ball_bass": "#F4B400", "ball_taped": "#9A8A6A"}.get(item_id, "#E8692A")
	return Color(str(c))


func physics_synced() -> void:
	_prev = _curr
	_curr = ball.pos


func _process(delta: float) -> void:
	if ball == null:
		return
	if ball.state == SimBall.State.HELD:
		_dribble(delta)
		return
	mesh.scale = Vector3.ONE
	var f: float = Engine.get_physics_interpolation_fraction()
	position = _prev.lerp(_curr, f)
	mesh.rotate_x(delta * (8.0 if ball.state != SimBall.State.LOOSE else ball.vel.length() * 3.0))


func _dribble(delta: float) -> void:
	var holder_view: ActorView = game.views.get(ball.holder_id, null) as ActorView
	if holder_view == null:
		position = ball.pos
		return
	var a: SimActor = holder_view.actor
	var speed: float = Vector2(a.desired_vel.x, a.desired_vel.z).length()
	_phase += delta * (2.3 + speed * 0.35)
	var hand: Vector3 = holder_view.rig.ball_anchor.global_position if holder_view.rig.ball_anchor != null else a.pos + Vector3(0, 1.0, 0)
	var floor_p: Vector3 = holder_view.global_position + a.right() * 0.3 + a.forward() * (0.25 + speed * 0.05)
	floor_p.y = a.ground_y + 0.12
	if not a.on_ground or a.anim_state == "shot_gather" or a.anim_state == "pass_charge":
		position = hand
		mesh.scale = Vector3.ONE
		return
	var u: float = absf(cos(_phase * PI))
	position = floor_p.lerp(hand, u)
	var squash: float = clampf(1.0 - u * 8.0, 0.0, 1.0) * 0.22
	mesh.scale = Vector3(1.0 + squash * 0.5, 1.0 - squash, 1.0 + squash * 0.5)
	mesh.rotate_x(delta * 6.0)


func set_on_fire(on: bool) -> void:
	## Takeover "ON FIRE" (spec §7.8): flame particles on the ball.
	if on and _fire == null:
		_fire = GPUParticles3D.new()
		var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pm.direction = Vector3.UP
		pm.spread = 25.0
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 1.4
		pm.gravity = Vector3(0, 1.5, 0)
		pm.scale_min = 0.5
		pm.scale_max = 1.0
		pm.color = Color(1.0, 0.5, 0.1)
		_fire.process_material = pm
		_fire.draw_pass_1 = MeshLib.sphere(0.06)
		_fire.material_override = ToonMaterials.neon(Color("#FF7A20"), 4.0)
		_fire.amount = 24
		_fire.lifetime = 0.45
		add_child(_fire)
	if _fire != null:
		_fire.emitting = on
