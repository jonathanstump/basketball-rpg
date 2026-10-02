class_name SimActor
extends RefCounted
## State of one simulated body (player, enemy, boss, critter). Controllers
## (Hooper, brains) mutate it; SimWorld integrates movement and collisions.

var id: int = 0
var kind: String = "hooper"       # hooper | enemy | boss | critter | prop
var archetype: String = ""
var display_name: String = ""
var team: int = 0                 # 0 = player side, 1 = hostile
var pos: Vector3 = Vector3.ZERO
var vel: Vector3 = Vector3.ZERO
var desired_vel: Vector3 = Vector3.ZERO   # horizontal velocity requested this frame
var facing: float = 0.0           # yaw; forward = Basis(UP, facing) * FORWARD
var radius: float = 0.35
var height: float = 1.35
var gravity_scale: float = 1.0
var on_ground: bool = true
var ground_y: float = 0.0
var frames_since_ground: int = 0
var landed: bool = false
var steer_locked: bool = false    # actions drive velocity directly
var tier: int = 1
var home: Vector3 = Vector3.ZERO

var input: ActorInput = ActorInput.new()
var input_source: InputSource = null
var controller: RefCounted = null  # must implement step()

var stats: Dictionary = {}
var hp: float = 300.0
var hp_max: float = 300.0
var wind: WindPool = WindPool.new()
var hype: float = 0.0
var composure: float = 0.0
var composure_max: float = 100.0
var poise: float = 0.0
var alive: bool = true
var invulnerable: bool = false    # i-frames active this frame
var hyper_armor: bool = false
var has_ball: bool = true

# Presentation hints (views read these; sim never depends on them).
var anim_state: String = "idle"
var anim_frame: int = 0
var anim_speed: float = 0.0
var flags: Dictionary = {}


func forward() -> Vector3:
	return Vector3(-sin(facing), 0.0, -cos(facing))


func right() -> Vector3:
	return Vector3(cos(facing), 0.0, -sin(facing))


func face_dir(dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length() > 0.0001:
		facing = atan2(-dir.x, -dir.z)


static func yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func turn_toward(dir: Vector3, max_rad: float) -> void:
	if Vector2(dir.x, dir.z).length() < 0.0001:
		return
	var target: float = yaw_of(dir)
	var diff: float = wrapf(target - facing, -PI, PI)
	facing = wrapf(facing + clampf(diff, -max_rad, max_rad), -PI, PI)


func stat(name: String) -> int:
	return int(stats.get(name, 10))


func flat_pos() -> Vector2:
	return Vector2(pos.x, pos.z)


func dist_to(other: SimActor) -> float:
	return flat_pos().distance_to(other.flat_pos())


func center() -> Vector3:
	return pos + Vector3(0.0, height * 0.5, 0.0)
