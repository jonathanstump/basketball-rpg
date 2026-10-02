class_name ActorInput
extends RefCounted
## Per-actor virtual controller (spec §15.5): one interface fed either by the
## human (InputRouter/HumanInput) or an AI brain. Presses are buffered for
## 8 frames so inputs during an action fire when it ends (§7.14).

var move: Vector2 = Vector2.ZERO   # desired world XZ direction, length 0..1
var aim: Vector3 = Vector3.ZERO     # optional aim point (lob target, pass aim)
var held: Dictionary = {}           # action -> true while held
var buffer: InputBuffer = InputBuffer.new(8)
var frame: int = 0
var released: Dictionary = {}       # action -> frame released


func press(action: String) -> void:
	buffer.press(action, frame)
	held[action] = true


func release(action: String) -> void:
	if held.has(action):
		held.erase(action)
		released[action] = frame


func set_held(action: String, on: bool) -> void:
	if on:
		held[action] = true
	else:
		release(action)


func pressed(action: String) -> bool:
	return buffer.consume(action, frame)


func peek(action: String) -> bool:
	return buffer.peek(action, frame)


func is_held(action: String) -> bool:
	return held.has(action)


func just_released(action: String) -> bool:
	return int(released.get(action, -99)) == frame


func move3() -> Vector3:
	return Vector3(move.x, 0.0, move.y)


func clear() -> void:
	move = Vector2.ZERO
	held.clear()
	buffer.clear()
	released.clear()
