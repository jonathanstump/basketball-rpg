class_name TimeFX
extends Node
## Presentation time effects (spec §7.14): slow-mo (ankle breakers, POSTER
## freeze), controller rumble. Real-time based so slow-mo can't extend itself.
## Hitstop lives in the sim (SimWorld.hitstop) so it stays frame-exact.

var _until_ms: int = 0
var _scale: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.slowmo_requested.connect(slowmo)


func slowmo(time_scale: float, duration_s: float) -> void:
	_scale = time_scale
	_until_ms = Time.get_ticks_msec() + int(duration_s * 1000.0)
	Engine.time_scale = time_scale


func rumble(weak: float, strong: float, duration_s: float) -> void:
	if not Settings.get_bool("rumble"):
		return
	for pad: int in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, weak, strong, duration_s)


func _process(_delta: float) -> void:
	if _until_ms > 0 and Time.get_ticks_msec() >= _until_ms:
		_until_ms = 0
		Engine.time_scale = 1.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0
