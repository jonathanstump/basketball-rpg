class_name WorldIndex
extends RefCounted
## Cross-district lookups from the map sidecars (stations, bodegas,
## crossings), cached after the first scan.

static var _built: bool = false
static var stations: Dictionary = {}   # station id -> {district, name, line}
static var bodegas: Dictionary = {}    # bodega id -> {district, cat, name}
static var districts: Dictionary = {}  # district id -> sidecar dict


static func _ensure() -> void:
	if _built:
		return
	_built = true
	for id: String in MapParser.list_maps():
		var side: Variant = JU.load_json(MapParser.MAP_DIR.path_join(id + ".json"))
		if not (side is Dictionary):
			continue
		var sd: Dictionary = side
		districts[id] = sd
		for st: Variant in JU.a(sd, "stations"):
			var s: Dictionary = st
			stations[JU.s(s, "id")] = {"district": id, "name": JU.s(s, "name"), "line": JU.s(s, "line", "gray"), "borough": JU.s(sd, "borough")}
		for b: Variant in JU.a(sd, "bodegas"):
			var bd: Dictionary = b
			bodegas[JU.s(bd, "id")] = {"district": id, "cat": JU.s(bd, "cat"), "name": JU.s(bd, "name", "Bodega")}


static func all() -> Dictionary:
	## district id -> sidecar, built on first use.
	_ensure()
	return districts


static func reset() -> void:
	_built = false
	stations.clear()
	bodegas.clear()
	districts.clear()


static func station(id: String) -> Dictionary:
	_ensure()
	return stations.get(id, {})


static func bodega(id: String) -> Dictionary:
	_ensure()
	return bodegas.get(id, {})


static func has_district(id: String) -> bool:
	_ensure()
	return districts.has(id)


static func district_name(id: String) -> String:
	_ensure()
	return JU.s(districts.get(id, {}), "name", id)


static func district_borough(id: String) -> String:
	_ensure()
	return JU.s(districts.get(id, {}), "borough", "")


static func all_cats() -> PackedStringArray:
	_ensure()
	var out: PackedStringArray = PackedStringArray()
	for k: Variant in bodegas.keys():
		out.append(JU.s(bodegas[k], "cat"))
	return out
