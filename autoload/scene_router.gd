extends Node
## Loads districts, interiors and arenas (spec §15.3, §5.3). Parameters ride
## along in `pending` and are read once by the target scene (take_params).
## Long trips (fast travel, crossings) show the subway-car loading ride.

signal scene_changed(path: String)

const DISTRICT: String = "res://world/district.tscn"
const INTERIOR: String = "res://world/interiors/interior.tscn"
const ARENA: String = "res://world/arenas/boss_arena.tscn"
const RIDE: String = "res://world/interiors/subway_ride.tscn"

var current_path: String = ""
var pending: Dictionary = {}
var ride_target: Dictionary = {}
var traveling: bool = false


func goto(path: String, params: Dictionary = {}) -> void:
	current_path = path
	pending = params
	get_tree().call_deferred("change_scene_to_file", path)
	scene_changed.emit(path)


func take_params() -> Dictionary:
	var p: Dictionary = pending
	pending = {}
	return p


func goto_district(district: String, arrive: Dictionary = {}, ride: bool = true) -> void:
	var params: Dictionary = {"district": district, "arrive": arrive}
	if ride:
		ride_target = {"path": DISTRICT, "params": params, "title": WorldIndex.district_name(district)}
		goto(RIDE, {})
	else:
		goto(DISTRICT, params)


func goto_interior(kind: String, id: String, return_to: Dictionary) -> void:
	goto(INTERIOR, {"kind": kind, "id": id, "return_to": return_to})


func goto_arena(boss_id: String, return_to: Dictionary) -> void:
	goto(ARENA, {"boss_id": boss_id, "return_to": return_to})


func finish_ride() -> void:
	## Called by the subway ride once its minimum duration has passed.
	var t: Dictionary = ride_target
	ride_target = {}
	goto(str(t.get("path", DISTRICT)), t.get("params", {}))
