class_name DataValidator
extends RefCounted
## Schema checks for /data (spec §15.4: required keys, types, ID references
## resolve, enums valid). Field spec grammar (see DataSchemas):
##   "string" "number" "int" "bool" "array" "dict"   append "?" for optional
##   "enum:a|b|c"  "ref:<catalog>"  "refs:<catalog>" (array of ids)
##   "ref?:<catalog>" / "enum?:..." / "refs?:..." optional variants


static func validate(db: DataStore) -> PackedStringArray:
	var errs: PackedStringArray = PackedStringArray()
	for cat_name: Variant in DataSchemas.CATALOGS.keys():
		var schema: Dictionary = DataSchemas.CATALOGS[cat_name]
		var cat: Dictionary = db.catalog(str(cat_name))
		if cat.is_empty() and not DataSchemas.OPTIONAL_CATALOGS.has(str(cat_name)):
			errs.append("catalog '%s' is missing or empty" % cat_name)
		for id: Variant in cat.keys():
			var entry: Dictionary = cat[id]
			_check_fields(db, "%s/%s" % [cat_name, id], entry, schema, errs)
	for path: Variant in DataSchemas.FILES.keys():
		var data: Variant = db.get_json(str(path))
		if data == null:
			errs.append("required file data/%s.json missing" % path)
			continue
		if not (data is Dictionary):
			errs.append("data/%s.json must be an object" % path)
			continue
		_check_fields(db, str(path), data as Dictionary, DataSchemas.FILES[path], errs)
	for owner: Variant in db.moves_by_owner.keys():
		var bucket: Dictionary = db.moves_by_owner[owner]
		for mid: Variant in bucket.keys():
			_check_fields(db, "moves/%s/%s" % [owner, mid], bucket[mid], DataSchemas.MOVE, errs)
	errs.append_array(DataSchemas.custom_checks(db))
	return errs


static func _check_fields(db: DataStore, where: String, entry: Dictionary, schema: Dictionary, errs: PackedStringArray) -> void:
	for key: Variant in schema.keys():
		var spec: String = schema[key]
		var optional: bool = spec.contains("?")
		spec = spec.replace("?", "")
		if not entry.has(key):
			if not optional:
				errs.append("%s: missing key '%s'" % [where, key])
			continue
		var v: Variant = entry[key]
		var err: String = check_value(db, v, spec)
		if err != "":
			errs.append("%s.%s: %s" % [where, key, err])


static func check_value(db: DataStore, v: Variant, spec: String) -> String:
	if spec.begins_with("enum:"):
		var opts: PackedStringArray = spec.substr(5).split("|")
		if not (v is String) or not opts.has(v):
			return "expected one of %s, got %s" % [opts, v]
		return ""
	if spec.begins_with("ref:"):
		var cat: String = spec.substr(4)
		if not (v is String):
			return "expected id string"
		if v == "" or not _ref_ok(db, cat, v):
			return "unknown %s id '%s'" % [cat, v]
		return ""
	if spec.begins_with("refs:"):
		var cat2: String = spec.substr(5)
		if not (v is Array):
			return "expected array of ids"
		for x: Variant in (v as Array):
			if not (x is String) or not _ref_ok(db, cat2, x):
				return "unknown %s id '%s'" % [cat2, x]
		return ""
	match spec:
		"string":
			return "" if v is String else "expected string"
		"number":
			return "" if (v is float or v is int) else "expected number"
		"int":
			if v is int:
				return ""
			if v is float and is_equal_approx(float(v), roundf(float(v))):
				return ""
			return "expected integer"
		"bool":
			return "" if v is bool else "expected bool"
		"array":
			return "" if v is Array else "expected array"
		"dict":
			return "" if v is Dictionary else "expected object"
		"any":
			return ""
	return "bad schema spec '%s'" % spec


static func _ref_ok(db: DataStore, cat: String, id: String) -> bool:
	if cat == "item":
		return db.catalog_of(id) != ""
	if cat.begins_with("move@"):
		return db.moves_for(cat.substr(5)).has(id)
	return db.has_item(cat, id)
