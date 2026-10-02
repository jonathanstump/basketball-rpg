class_name CameraRig
extends Node3D
## High-angle third-person camera (spec D2): exploration orbit (50°, 12 m,
## FOV 45, free yaw), lock-on framing (38°, 9-14 m, player + target + hoop),
## occlusion cutaway via the cc_focus_pos shader global, shake and punch-in.

var camera: Camera3D
var cfg: Dictionary = {}
var follow: SimActor = null
var lock_target: SimActor = null
var hoop_pos: Vector3 = Vector3.INF
var yaw: float = 0.0
var pitch_deg: float = 50.0
var distance: float = 12.0
var focus: Vector3 = Vector3.ZERO
var shake: float = 0.0
var punch: float = 0.0
var input_enabled: bool = true
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	cfg = DataDB.tuning("camera")
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = JU.f(JU.dict(cfg, "explore"), "fov_deg", 45.0)
	camera.current = true
	camera.far = 400.0
	add_child(camera)
	pitch_deg = JU.f(JU.dict(cfg, "explore"), "pitch_deg", 50.0)
	distance = JU.f(JU.dict(cfg, "explore"), "distance_m", 12.0)
	RenderingServer.global_shader_parameter_set("cc_cutaway_radius", JU.f(cfg, "cutaway_radius_m", 2.6))
	EventBus.screen_shake_requested.connect(func(s: float) -> void: add_shake(s))


func snap() -> void:
	if follow != null:
		focus = follow.pos + Vector3.UP * JU.f(cfg, "focus_height_m", 0.9)
	_apply(1.0)


func add_shake(strength: float) -> void:
	shake = maxf(shake, strength * Settings.get_float("screen_shake"))


func punch_in(amount: float = -1.0) -> void:
	punch = JU.f(cfg, "punch_in_m", 2.0) if amount < 0.0 else amount


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = event
		yaw -= mm.relative.x * JU.f(cfg, "mouse_sensitivity", 0.005) * Settings.get_float("camera_sensitivity")


func _process(delta: float) -> void:
	if input_enabled and lock_target == null:
		var stick: float = Input.get_axis("cam_left", "cam_right")
		yaw -= stick * JU.f(cfg, "yaw_speed_rad_s", 2.6) * Settings.get_float("camera_sensitivity") * delta
	_apply(clampf(delta * JU.f(cfg, "follow_lerp", 10.0), 0.0, 1.0))
	shake = lerpf(shake, 0.0, clampf(delta * JU.f(cfg, "shake_decay", 6.0), 0.0, 1.0))
	punch = lerpf(punch, 0.0, clampf(delta * 6.0, 0.0, 1.0))


func _apply(k: float) -> void:
	if follow == null:
		return
	var player_pos: Vector3 = follow.pos
	var target_focus: Vector3 = player_pos + Vector3.UP * JU.f(cfg, "focus_height_m", 0.9)
	var want_pitch: float = JU.f(JU.dict(cfg, "explore"), "pitch_deg", 50.0)
	var want_dist: float = JU.f(JU.dict(cfg, "explore"), "distance_m", 12.0)
	if lock_target != null and lock_target.alive:
		var fr: Dictionary = CameraMath.lockon_framing(player_pos, lock_target.pos, hoop_pos, hoop_pos != Vector3.INF, cfg, 16.0 / 9.0, lock_target.height)
		target_focus = fr["focus"]
		want_pitch = fr["pitch"]
		want_dist = fr["distance"]
		var rk: float = clampf(k * JU.f(cfg, "rotate_lerp", 8.0) / maxf(JU.f(cfg, "follow_lerp", 10.0), 0.01), 0.0, 1.0)
		yaw = lerp_angle(yaw, float(fr["yaw"]), rk)
	focus = focus.lerp(target_focus, k)
	pitch_deg = lerpf(pitch_deg, want_pitch, k)
	distance = lerpf(distance, want_dist, k)
	var xf: Transform3D = CameraMath.orbit_transform(focus, yaw, pitch_deg, maxf(3.0, distance - punch))
	if shake > 0.001:
		xf.origin += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * shake * 0.25
	global_transform = xf
	RenderingServer.global_shader_parameter_set("cc_focus_pos", player_pos + Vector3.UP * 0.8)


func auto_yaw(col: WorldCollision) -> void:
	## Picks the exploration yaw whose camera line to the player crosses the
	## fewest walls (looking down a street instead of into a building).
	if follow == null:
		return
	var best: float = yaw
	var best_score: int = 999
	var dist: float = JU.f(JU.dict(cfg, "explore"), "distance_m", 12.0)
	for i: int in 8:
		var y: float = float(i) * TAU / 8.0
		var cam: Vector3 = CameraMath.orbit_transform(follow.pos + Vector3.UP, y, JU.f(JU.dict(cfg, "explore"), "pitch_deg", 50.0), dist).origin
		var score: int = 0
		for k: int in range(1, 6):
			var p: Vector3 = follow.pos.lerp(Vector3(cam.x, follow.pos.y, cam.z), float(k) / 5.0)
			if col.blocked(p + Vector3(0, 0.5, 0), 0.6):
				score += 6 - k
		if score < best_score:
			best_score = score
			best = y
	yaw = best
	snap()


func forward_flat() -> Vector3:
	## Camera forward on the ground plane, for camera-relative movement.
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func right_flat() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))
