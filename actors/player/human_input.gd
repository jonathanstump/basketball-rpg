class_name HumanInput
extends InputSource
## Reads the device through Godot's InputMap and fills the player's
## ActorInput with camera-relative movement (spec §7.2).

const ACTIONS: PackedStringArray = ["light", "heavy", "dodge", "jump", "shoot", "hands_up",
	"bag_move", "interact", "taunt", "quarter_water", "swap_ball_left", "swap_ball_right", "lock_on"]

var camera: CameraRig = null
var enabled: bool = true
var guard_latched: bool = false


func fill(input: ActorInput, _actor: SimActor, _world: SimWorld) -> void:
	if not enabled:
		input.move = Vector2.ZERO
		for a0: String in ACTIONS:
			input.release(a0)
		return
	var v: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var fwd: Vector3 = camera.forward_flat() if camera != null else Vector3.FORWARD
	var rgt: Vector3 = camera.right_flat() if camera != null else Vector3.RIGHT
	var world_dir: Vector3 = rgt * v.x - fwd * v.y
	input.move = Vector2(world_dir.x, world_dir.z).limit_length(1.0)
	for a: String in ACTIONS:
		if a == "hands_up" and not Settings.get_bool("hold_to_guard"):
			## Toggle guard (spec §14 hold/toggle): tap = parry + latch the guard.
			if Input.is_action_just_pressed(a):
				input.press(a)
				guard_latched = not guard_latched
			if guard_latched:
				input.held[a] = true
			elif input.held.has(a) and not Input.is_action_pressed(a):
				input.release(a)
			continue
		if Input.is_action_just_pressed(a):
			input.press(a)
		elif Input.is_action_pressed(a):
			input.held[a] = true
		elif input.held.has(a):
			input.release(a)
