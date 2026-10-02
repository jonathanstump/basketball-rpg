class_name FastTravel
extends RefCounted
## Subway fast travel rules (spec §5.3): stations are fast-travel points;
## tapping in the first time discovers it; travel works from any bodega or
## station to any discovered station (any borough). City stations need the
## Crown Pass.


static func can_open_menu(from_kind: String) -> bool:
	return from_kind == "bodega" or from_kind == "station"


static func destinations(discovered: PackedStringArray) -> PackedStringArray:
	var out: PackedStringArray = discovered.duplicate()
	out.sort()
	return out


static func can_travel(from_kind: String, target_station: String, discovered: PackedStringArray, current_station: String = "") -> bool:
	if not can_open_menu(from_kind):
		return false
	if not discovered.has(target_station):
		return false
	if target_station == current_station:
		return false
	if target_station.begins_with("city_") and not GameState.has_crown_pass():
		return false
	return true


static func tap_in(station_id: String, district: String) -> bool:
	## Returns true on first discovery (also reveals that district's streets).
	if GameState.discovered_stations.has(station_id):
		return false
	GameState.discovered_stations.append(station_id)
	GameState.set_flag("streets_" + district)
	EventBus.station_discovered.emit(station_id)
	return true


static func station_district(station_id: String) -> String:
	## Station registry from the map sidecars (station id -> district id).
	for id: String in MapParser.list_maps():
		var side: Variant = JU.load_json(MapParser.MAP_DIR.path_join(id + ".json"))
		if side is Dictionary:
			for st: Variant in JU.a(side as Dictionary, "stations"):
				if JU.s(st as Dictionary, "id") == station_id:
					return id
	return ""
