extends Node
## Save system (spec §15.14): JSON with schema_version, 3 slots, atomic write
## (temp file -> rename) plus .bak, per-version migrations.

const SCHEMA_VERSION: int = 1
const SLOTS: int = 3

var save_dir: String = "user://saves"
var active_slot: int = 0
var _pending_autosave_s: float = -1.0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(save_dir)


func _process(delta: float) -> void:
	if _pending_autosave_s >= 0.0:
		_pending_autosave_s -= delta
		if _pending_autosave_s < 0.0:
			save_slot(active_slot)


func slot_path(slot: int) -> String:
	return save_dir.path_join("slot_%d.json" % slot)


func request_autosave(debounce_s: float = 0.0) -> void:
	## Immediate autosave when debounce is 0; otherwise coalesces bursts
	## (item pickups) into one write.
	if debounce_s <= 0.0:
		save_slot(active_slot)
	elif _pending_autosave_s < 0.0:
		_pending_autosave_s = debounce_s


func build_save() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"game": GameState.to_dict(),
	}


func save_slot(slot: int) -> Error:
	return write_json_atomic(slot_path(slot), build_save())


func load_slot(slot: int) -> bool:
	var data: Dictionary = read_save(slot_path(slot))
	if data.is_empty():
		return false
	GameState.from_dict(JU.dict(data, "game"))
	active_slot = slot
	return true


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func delete_slot(slot: int) -> void:
	for p: String in [slot_path(slot), slot_path(slot) + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func slot_summary(slot: int) -> Dictionary:
	var data: Dictionary = read_save(slot_path(slot))
	if data.is_empty():
		return {}
	var g: Dictionary = JU.dict(data, "game")
	return {"level": JU.i(g, "level", 1), "crowns": JU.a(g, "crowns").size(),
		"start": JU.s(g, "start_borough"), "saved_at": JU.s(data, "saved_at"),
		"name": JU.s(JU.dict(g, "profile"), "name", "Rookie")}


static func write_json_atomic(path: String, data: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		var bak: String = path + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(path, bak)
	return DirAccess.rename_absolute(tmp, path)


static func read_save(path: String) -> Dictionary:
	var data: Variant = JU.load_json(path)
	if not (data is Dictionary) and FileAccess.file_exists(path + ".bak"):
		data = JU.load_json(path + ".bak")
	if not (data is Dictionary):
		return {}
	return SaveMigrations.migrate(data as Dictionary, SCHEMA_VERSION)
