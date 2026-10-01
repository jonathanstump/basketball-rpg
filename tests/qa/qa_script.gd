class_name QAScript
extends Node
## Base class for scripted QA sequences. Override run(); call fail() and
## return false on a problem. Helpers wait frames and swap scenes.

var failure: String = ""


func run() -> bool:
	return true


func fail(reason: String) -> bool:
	if failure == "":
		failure = reason
	return false


func check(cond: bool, reason: String) -> bool:
	if not cond:
		fail(reason)
	return cond


func frames(n: int) -> void:
	for _i: int in n:
		await get_tree().physics_frame


func goto_scene(path: String) -> Node:
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	return get_tree().current_scene
