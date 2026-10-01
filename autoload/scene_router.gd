extends Node
## Loads districts, interiors and arenas (spec §15.3).
## TODO(spec §5.3): subway-ride loading scene arrives in M6.

signal scene_changed(path: String)

var current_path: String = ""


func goto(path: String) -> void:
	current_path = path
	get_tree().call_deferred("change_scene_to_file", path)
	scene_changed.emit(path)
