class_name HumanInput
extends InputSource
## Reads the device through Godot's InputMap and fills the player's
## ActorInput with camera-relative movement (spec §7.2).

const ACTIONS: PackedStringArray = ["light", "heavy", "dodge", "jump", "shoot", "hands_up",
	"bag_move", "interact", "taunt", "quarter_water", "swap_ball_left", "swap_ball_right", "lock_on"]

var camera: CameraRig = null
var enabled: bool = true


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
		if Input.is_action_just_pressed(a):
			input.press(a)
		elif Input.is_action_pressed(a):
			input.held[a] = true
		elif input.held.has(a):
			input.release(a)
