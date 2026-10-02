class_name QAWalker
extends InputSource
## QA bot movement: follows the district nav grid toward a target and can
## press Interact on arrival. Used by district_walk and the slice QA run.

var target: Vector3 = Vector3.INF
var press_interact: bool = false
var arrive_radius: float = 1.2
var arrived: bool = false
var _pressed_at: int = -1


func go(t: Vector3, interact: bool = false, radius: float = 1.2) -> void:
	target = t
	press_interact = interact
	arrive_radius = radius
	arrived = false
	_pressed_at = -1


func fill(input: ActorInput, a: SimActor, w: SimWorld) -> void:
	input.move = Vector2.ZERO
	input.release("interact")
	if target == Vector3.INF:
		return
	var to: Vector3 = target - a.pos
	to.y = 0.0
	if to.length() <= arrive_radius:
		arrived = true
		if press_interact and (_pressed_at < 0 or w.frame - _pressed_at > 20):
			input.press("interact")
			_pressed_at = w.frame
		return
	var dir: Vector3 = to.normalized()
	if w.nav != null:
		dir = w.nav.call("steer", a.pos, target, dir)
	input.move = Vector2(dir.x, dir.z)
