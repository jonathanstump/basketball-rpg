class_name DataStore
extends Node
## Loads and validates every JSON file under res://data (spec §15.3, D5).
## Files are addressable by relative path without extension ("tuning/player").
## Top-level arrays of {"id": ...} dicts become id-indexed catalogs that merge
## across files ("balls", "kicks", "enemies"...). Boss files become the
## "bosses" catalog; move files are scoped per owner (moves/<owner>.json).

const DATA_ROOT: String = "res://data"

var files: Dictionary = {}          # rel path -> parsed JSON
var catalogs: Dictionary = {}       # catalog name -> {id -> Dictionary}
var moves_by_owner: Dictionary = {} # owner -> {move_id -> Dictionary}
var load_errors: PackedStringArray = PackedStringArray()
var loaded: bool = false


func _ready() -> void:
	load_all()
	var errs: PackedStringArray = validate()
	for e: String in errs:
		push_error("DataDB: " + e)


func load_all() -> void:
	files.clear()
	catalogs.clear()
	moves_by_owner.clear()
	load_errors.clear()
	_scan(DATA_ROOT, "")
	_index()
	loaded = true


func validate() -> PackedStringArray:
	var errs: PackedStringArray = load_errors.duplicate()
	errs.append_array(DataValidator.validate(self))
	return errs


func _scan(dir_path: String, rel: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		load_errors.append("cannot open " + dir_path)
		return
	var names: PackedStringArray = dir.get_files()
	for n: String in names:
		if not n.ends_with(".json"):
			continue
		var full: String = dir_path.path_join(n)
		var key: String = (rel.path_join(n) if rel != "" else n).trim_suffix(".json")
		var data: Variant = JU.load_json(full)
		if data == null:
			load_errors.append("failed to parse " + full)
			continue
		files[key] = data
	for d: String in dir.get_directories():
		_scan(dir_path.path_join(d), rel.path_join(d) if rel != "" else d)


func _index() -> void:
	var keys: Array = files.keys()
	keys.sort()
	for key_v: Variant in keys:
		var key: String = key_v
		var data: Variant = files[key]
		if key.begins_with("moves/"):
			_index_moves(key, data)
			continue
		if key.begins_with("bosses/") and data is Dictionary:
			_add("bosses", data as Dictionary, key)
			continue
		if data is Dictionary:
			var dd: Dictionary = data
			for k: Variant in dd.keys():
				var v: Variant = dd[k]
				if v is Array and _is_id_list(v as Array):
					for item: Variant in (v as Array):
						_add(str(k), item as Dictionary, key)


func _index_moves(key: String, data: Variant) -> void:
	var owner: String = key.trim_prefix("moves/").get_base_dir()
	var list: Array = []
	if data is Dictionary and (data as Dictionary).has("moves"):
		owner = key.trim_prefix("moves/")
		list = JU.a(data as Dictionary, "moves")
	elif data is Dictionary:
		list = [data]
	if not moves_by_owner.has(owner):
		moves_by_owner[owner] = {}
	var bucket: Dictionary = moves_by_owner[owner]
	for m: Variant in list:
		if m is Dictionary:
			var md: Dictionary = m
			var id: String = JU.s(md, "id")
			if bucket.has(id):
				load_errors.append("duplicate move %s/%s" % [owner, id])
			md["_owner"] = owner
			bucket[id] = md


func _is_id_list(arr: Array) -> bool:
	if arr.is_empty():
		return false
	for item: Variant in arr:
		if not (item is Dictionary and (item as Dictionary).has("id")):
			return false
	return true


func _add(catalog: String, item: Dictionary, source: String) -> void:
	if not catalogs.has(catalog):
		catalogs[catalog] = {}
	var cat: Dictionary = catalogs[catalog]
	var id: String = JU.s(item, "id")
	if cat.has(id):
		load_errors.append("duplicate id '%s' in catalog '%s' (%s)" % [id, catalog, source])
	item["_source"] = source
	cat[id] = item


# ---------------------------------------------------------------- accessors

func get_json(path: String) -> Variant:
	return files.get(path, null)


func get_dict(path: String) -> Dictionary:
	var v: Variant = files.get(path, {})
	return v if v is Dictionary else {}


func catalog(name: String) -> Dictionary:
	var v: Variant = catalogs.get(name, {})
	return v if v is Dictionary else {}


func item(catalog_name: String, id: String) -> Dictionary:
	var cat: Dictionary = catalog(catalog_name)
	var v: Variant = cat.get(id, {})
	return v if v is Dictionary else {}


func has_item(catalog_name: String, id: String) -> bool:
	return catalog(catalog_name).has(id)


func find_any(id: String) -> Dictionary:
	## Looks an id up across every catalog (items are globally unique by convention).
	for c: Variant in catalogs.keys():
		var cat: Dictionary = catalogs[c]
		if cat.has(id):
			var d: Dictionary = cat[id]
			return d
	return {}


func catalog_of(id: String) -> String:
	for c: Variant in catalogs.keys():
		var cat: Dictionary = catalogs[c]
		if cat.has(id):
			return str(c)
	return ""


func tiers() -> Dictionary:
	return get_dict("tiers")


func tuning(name: String) -> Dictionary:
	return get_dict("tuning/" + name)


func tune_f(file: String, key: String, def: float = 0.0) -> float:
	return JU.f(tuning(file), key, def)


func archetype(id: String) -> Dictionary:
	return item("archetypes", id)


func ball(id: String) -> Dictionary:
	return item("balls", id)


func boss(id: String) -> Dictionary:
	return item("bosses", id)


func enemy(id: String) -> Dictionary:
	return item("enemies", id)


func moves_for(owner: String) -> Dictionary:
	var v: Variant = moves_by_owner.get(owner, {})
	return v if v is Dictionary else {}


func move(owner: String, id: String) -> Dictionary:
	var v: Variant = moves_for(owner).get(id, {})
	return v if v is Dictionary else {}
