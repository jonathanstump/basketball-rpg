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
var explore_pitch: float = 38.0      # player look up/down (respects invert Y)
var collision: WorldCollision = null  # walls the camera pulls in front of
var duel_boss: SimActor = null        # set in boss duels: frame the hoop, not the boss
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
	camera.far = JU.f(cfg, "far_m", 900.0)
	add_child(camera)
	explore_pitch = JU.f(JU.dict(cfg, "explore"), "pitch_deg", 38.0)
	pitch_deg = explore_pitch
	distance = float(CameraMath.explore_shape(explore_pitch, cfg)["distance"])
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
		## Same per-pixel rate as yaw, in degrees.
		_add_pitch(rad_to_deg(mm.relative.y * JU.f(cfg, "mouse_sensitivity", 0.005)))


func _process(delta: float) -> void:
	if input_enabled and lock_target == null:
		var stick: float = Input.get_axis("cam_left", "cam_right")
		yaw -= stick * JU.f(cfg, "yaw_speed_rad_s", 2.6) * Settings.get_float("camera_sensitivity") * delta
		if InputMap.has_action("cam_up") and InputMap.has_action("cam_down"):
			_add_pitch(Input.get_axis("cam_up", "cam_down") * JU.f(cfg, "pitch_pad_deg_s", 90.0) * delta)
	_apply(clampf(delta * JU.f(cfg, "follow_lerp", 10.0), 0.0, 1.0))
	shake = lerpf(shake, 0.0, clampf(delta * JU.f(cfg, "shake_decay", 6.0), 0.0, 1.0))
	punch = lerpf(punch, 0.0, clampf(delta * 6.0, 0.0, 1.0))


func _apply(k: float) -> void:
	if follow == null:
		return
	var player_pos: Vector3 = follow.pos
	var shape: Dictionary = CameraMath.explore_shape(explore_pitch, cfg)
	var target_focus: Vector3 = player_pos + Vector3.UP * float(shape["lift"]) + right_flat() * float(shape["shoulder"])
	var want_pitch: float = explore_pitch
	var want_dist: float = shape["distance"]
	var rk: float = clampf(k * JU.f(cfg, "rotate_lerp", 8.0) / maxf(JU.f(cfg, "follow_lerp", 10.0), 0.01), 0.0, 1.0)
	if duel_boss != null and duel_boss.alive and hoop_pos != Vector3.INF:
		var dfr: Dictionary = CameraMath.duel_framing(player_pos, duel_boss.pos, hoop_pos, cfg, yaw, 16.0 / 9.0, duel_boss.height * float(duel_boss.flags.get("scale", 1.0)), duel_boss.radius, collision)
		target_focus = dfr["focus"]
		want_pitch = dfr["pitch"]
		want_dist = dfr["distance"]
		yaw = lerp_angle(yaw, float(dfr["yaw"]), rk)
	elif lock_target != null and lock_target.alive:
		var fr: Dictionary = CameraMath.lockon_framing(player_pos, lock_target.pos, hoop_pos, hoop_pos != Vector3.INF, cfg, 16.0 / 9.0, lock_target.height)
		target_focus = fr["focus"]
		want_pitch = fr["pitch"]
		want_dist = fr["distance"]
		yaw = lerp_angle(yaw, float(fr["yaw"]), rk)
	focus = focus.lerp(target_focus, k)
	pitch_deg = lerpf(pitch_deg, want_pitch, k)
	distance = lerpf(distance, want_dist, k)
	var d: float = CameraMath.pull_in(focus, yaw, pitch_deg, maxf(JU.f(cfg, "min_distance_m", 2.2), distance - punch), collision, JU.f(cfg, "min_distance_m", 2.2))
	var xf: Transform3D = CameraMath.orbit_transform(focus, yaw, pitch_deg, d)
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
	var dist: float = CameraMath.explore_shape(explore_pitch, cfg)["distance"]
	for i: int in 8:
		var y: float = float(i) * TAU / 8.0
		var cam: Vector3 = CameraMath.orbit_transform(follow.pos + Vector3.UP, y, explore_pitch, dist).origin
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


func _add_pitch(amount: float) -> void:
	## Vertical look; "Invert camera Y" flips it (spec §14).
	var sgn: float = -1.0 if Settings.get_bool("camera_invert_y") else 1.0
	explore_pitch = CameraMath.clamp_pitch(explore_pitch + amount * sgn * Settings.get_float("camera_sensitivity"), cfg)
