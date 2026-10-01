class_name InputBuffer
extends RefCounted
## Frame-based press buffer (spec §7.14: 8-frame buffering for attacks/dodges).
## A press stays consumable for `window` frames after it happened.

var window: int = 8
var _presses: Dictionary = {}  # action -> frame pressed


func _init(window_frames: int = 8) -> void:
	window = window_frames


func press(action: String, frame: int) -> void:
	_presses[action] = frame


func peek(action: String, frame: int) -> bool:
	if not _presses.has(action):
		return false
	return frame - int(_presses[action]) <= window


func consume(action: String, frame: int) -> bool:
	if peek(action, frame):
		_presses.erase(action)
		return true
	return false


func clear() -> void:
	_presses.clear()
