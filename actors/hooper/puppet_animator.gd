class_name PuppetAnimator
extends RefCounted
## Plays PoseLibrary animations on a PuppetRig with crossfades and procedural
## layers (spec §15.11): locomotion bob, lean into turns, squash/stretch on
## land and jump, head look-at.

var lib: PoseLibrary
var anim: String = "idle"
var t: float = 0.0
var blend_from: Dictionary = {}
var blend_t: float = 1.0
var blend_time: float = 0.1
var last_pose: Dictionary = {}
var last_yaw: float = 0.0
var lean: float = 0.0
var squash_v: float = 0.0
var look_target: Vector3 = Vector3.INF


func _init(pose_set: String = "hooper") -> void:
	lib = PoseLibrary.get_set(pose_set)


func play(name: String, restart: bool = false) -> void:
	if name == anim and not restart:
		return
	blend_from = last_pose.duplicate()
	blend_t = 0.0
	anim = name
	t = 0.0


func update(rig: PuppetRig, actor: SimActor, delta: float) -> void:
	var want: String = lib.anim_for_state(actor.anim_state)
	if actor.anim_state != "" and want != anim:
		play(want)
	var rate: float = 1.0
	if anim == "walk" or anim == "run" or anim == "sprint":
		rate = clampf(actor.anim_speed / {"walk": 3.5, "run": 6.0, "sprint": 8.5}[anim], 0.5, 1.6)
	t += delta * rate
	var pose: Dictionary = lib.sample(anim, t)
	if blend_t < 1.0:
		blend_t = minf(1.0, blend_t + delta / blend_time)
		pose = PoseLibrary.blend(blend_from, pose, blend_t)
	last_pose = pose
	# Lean into turns.
	var yaw_rate: float = wrapf(actor.facing - last_yaw, -PI, PI) / maxf(delta, 0.0001)
	last_yaw = actor.facing
	lean = lerpf(lean, clampf(-yaw_rate * 2.0, -14.0, 14.0) * clampf(actor.anim_speed / 6.0, 0.0, 1.0), clampf(delta * 8.0, 0.0, 1.0))
	var layered: Dictionary = pose.duplicate()
	var torso: Vector3 = layered.get("torso", Vector3.ZERO)
	layered["torso"] = torso + Vector3(0, 0, lean)
	# Locomotion bob.
	if anim == "walk" or anim == "run" or anim == "sprint":
		var root: Vector3 = layered.get("_root", Vector3.ZERO)
		var period: float = lib.duration(anim)
		layered["_root"] = root + Vector3(0, absf(sin(t / maxf(period, 0.01) * TAU)) * 0.035, 0)
	# Squash on land, stretch on jump.
	if actor.landed:
		squash_v = 0.22
	elif anim == "jump" and actor.vel.y > 2.0:
		squash_v = -0.12
	squash_v = lerpf(squash_v, 0.0, clampf(delta * 10.0, 0.0, 1.0))
	rig.squash = squash_v
	# Head look-at (yaw only, clamped).
	if look_target != Vector3.INF:
		var to: Vector3 = look_target - actor.pos
		var rel: float = wrapf(SimActor.yaw_of(to) - actor.facing, -PI, PI)
		var head: Vector3 = layered.get("head", Vector3.ZERO)
		layered["head"] = head + Vector3(0, rad_to_deg(clampf(rel, -1.0, 1.0)), 0)
	rig.apply_pose(layered)
