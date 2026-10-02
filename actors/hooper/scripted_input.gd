class_name ScriptedInput
extends InputSource
## Deterministic input timeline for tests and QA bots. Frames are relative to
## the first fill() call.

var _moves: Array[Dictionary] = []    # {at, move: Vector2}
var _presses: Array[Dictionary] = []  # {at, action}
var _holds: Array[Dictionary] = []    # {from, to, action}
var _aims: Array[Dictionary] = []     # {at, aim: Vector3}
var _start: int = -1
var local_frame: int = 0


func move_at(f: int, dir: Vector2) -> ScriptedInput:
	_moves.append({"at": f, "move": dir})
	return self


func press_at(f: int, action: String) -> ScriptedInput:
	_presses.append({"at": f, "action": action})
	return self


func hold(from_f: int, to_f: int, action: String) -> ScriptedInput:
	_holds.append({"from": from_f, "to": to_f, "action": action})
	return self


func aim_at(f: int, p: Vector3) -> ScriptedInput:
	_aims.append({"at": f, "aim": p})
	return self


func fill(input: ActorInput, _actor: SimActor, world: SimWorld) -> void:
	if _start < 0:
		_start = world.frame
	local_frame = world.frame - _start
	for m: Dictionary in _moves:
		if int(m["at"]) == local_frame:
			input.move = m["move"]
	for a: Dictionary in _aims:
		if int(a["at"]) == local_frame:
			input.aim = a["aim"]
	for h: Dictionary in _holds:
		var act: String = h["action"]
		if local_frame == int(h["from"]):
			input.press(act)
		elif local_frame > int(h["from"]) and local_frame <= int(h["to"]):
			input.held[act] = true
		elif local_frame == int(h["to"]) + 1:
			input.release(act)
	for p: Dictionary in _presses:
		if int(p["at"]) == local_frame:
			var act2: String = p["action"]
			input.press(act2)
			input.release(act2)
