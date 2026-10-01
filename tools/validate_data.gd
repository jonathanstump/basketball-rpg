extends SceneTree
## Validates every /data file against DataSchemas (spec §15.4).
## Usage: $GODOT --headless --path . -s res://tools/validate_data.gd


func _initialize() -> void:
	var db: DataStore = DataStore.new()
	db.load_all()
	var errs: PackedStringArray = db.validate()
	for e: String in errs:
		print("DATA PROBLEM: " + e)
	var count: int = 0
	for c: Variant in db.catalogs.keys():
		count += (db.catalogs[c] as Dictionary).size()
	print("VALIDATE DATA: %d files, %d catalog entries, %d problems" % [db.files.size(), count, errs.size()])
	db.free()
	quit(1 if errs.size() > 0 else 0)
