class_name SimBall
extends RefCounted
## One ball (spec §15.6). Exactly one owner at a time. States:
## HELD (dribbled by holder) · PASS (kinematic projectile) · SHOT (scripted arc
## playing out the grade chosen at release) · LOOSE (bouncy physics) ·
## IN_NET (dropping through a hoop) · DEAD (lost, awaiting cleanup).

enum State { HELD, PASS, SHOT, LOOSE, IN_NET, DEAD }

var id: int = 0
var state: int = State.LOOSE
var item_id: String = "ball_rec"   # which ball (balls.json)
var holder_id: int = 0             # actor holding it (HELD)
var home_id: int = 0               # whose ball it is (street hoopers each carry one)
var last_touch_id: int = 0
var pos: Vector3 = Vector3.ZERO
var vel: Vector3 = Vector3.ZERO
var spin: float = 0.0

# PASS
var pass_kind: String = ""
var pass_dir: Vector3 = Vector3.ZERO
var pass_speed: float = 0.0
var pass_range_left: float = 0.0
var pierce_left: int = 0
var ricochets_left: int = 0
var hit_ids: Array[int] = []
var returning: bool = false
var passer_id: int = 0
var homing_id: int = 0
var homing: float = 0.0

# SHOT / LOB flights
var flight: ShotFlight = null
var shot_grade: String = ""
var shot_zone: String = ""
var shot_hoop: String = ""
var shooter_id: int = 0
var blocker_id: int = 0
var lob_damage: bool = false

var loose_time: float = 0.0
var state_time: float = 0.0
var bounces: int = 0


func set_state(s: int) -> void:
	state = s
	state_time = 0.0
	if s != State.LOOSE:
		loose_time = 0.0
	if s != State.HELD:
		holder_id = 0


func state_name() -> String:
	return ["HELD", "PASS", "SHOT", "LOOSE", "IN_NET", "DEAD"][state]


func is_free() -> bool:
	return state == State.LOOSE
