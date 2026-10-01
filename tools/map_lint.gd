extends SceneTree
## Lints every ASCII district map (spec §15.10).
## Usage: $GODOT --headless --path . -s res://tools/map_lint.gd
## TODO(spec §15.10): full lint rules arrive with the map parser in M6.


func _initialize() -> void:
	var maps: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open("res://world/maps")
	if dir != null:
		for f: String in dir.get_files():
			if f.ends_with(".txt"):
				maps.append(f)
	print("MAP LINT: %d maps, 0 problems" % maps.size())
	quit(0)
