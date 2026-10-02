extends SceneTree
## Lints every ASCII district map (spec §15.10) with MapLinter.
## Usage: $GODOT --headless --path . -s res://tools/map_lint.gd


func _initialize() -> void:
	var ids: PackedStringArray = MapParser.list_maps()
	var problems: int = 0
	for id: String in ids:
		var m: MapData = MapParser.load_map(id)
		var errs: PackedStringArray = MapLinter.lint(m)
		for e: String in errs:
			print("MAP PROBLEM: " + e)
		problems += errs.size()
		print("MAP %s: %dx%d, %d problems" % [id, m.width, m.height, errs.size()])
	print("MAP LINT: %d maps, %d problems" % [ids.size(), problems])
	quit(1 if problems > 0 else 0)
