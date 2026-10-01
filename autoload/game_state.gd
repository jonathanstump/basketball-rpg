extends Node
## Run state (spec §15.3): start borough, tiers, crowns, flags, discovered
## stations, map reveal, inventory, equipment, stats, Rep, tokens, chain, NG+.

signal state_reset()

var archetype: String = "two_way"
var start_borough: String = "brooklyn"
var ng_cycle: int = 0
var level: int = 1
var stats: Dictionary = {}            # stat -> int
var rep: int = 0
var tokens: int = 0
var crowns: PackedStringArray = PackedStringArray()
var garden_tickets: PackedStringArray = PackedStringArray()
var flags: Dictionary = {}            # flag -> Variant
var discovered_stations: PackedStringArray = PackedStringArray()
var map_reveal: Dictionary = {}       # district_id -> PackedByteArray (base64 in saves)
var inventory: Dictionary = {}        # item_id -> count
var equipment: Dictionary = {}        # slot -> item_id
var ball_upgrades: Dictionary = {}    # ball_id -> level
var tattoos: PackedStringArray = PackedStringArray()
var flash_sheets: PackedStringArray = PackedStringArray()
var known_bag_moves: PackedStringArray = PackedStringArray()
var quarter_water_max: int = 3
var quarter_waters: int = 3
var sugar_rush: int = 0
var chain: Dictionary = {}            # {district, pos:[x,y,z], rep}
var respawn_bodega: String = ""
var current_district: String = ""
var profile: Dictionary = {}          # character creator profile
var counters: Dictionary = {}         # style counters for nickname/achievements
var nickname: String = ""
var defeated_bosses: PackedStringArray = PackedStringArray()
var opened_boxes: PackedStringArray = PackedStringArray()
var play_time_s: float = 0.0


func new_run(arch_id: String, start: String, prof: Dictionary = {}) -> void:
	var arch: Dictionary = DataDB.archetype(arch_id)
	archetype = arch_id
	start_borough = start
	ng_cycle = 0
	level = 1
	stats = JU.dict(arch, "stats").duplicate()
	for k: Variant in stats.keys():
		stats[k] = int(stats[k])
	rep = 0
	tokens = 0
	crowns = PackedStringArray()
	garden_tickets = PackedStringArray()
	flags = {}
	discovered_stations = PackedStringArray()
	map_reveal = {}
	inventory = {}
	equipment = {}
	ball_upgrades = {}
	tattoos = PackedStringArray()
	flash_sheets = PackedStringArray()
	known_bag_moves = PackedStringArray()
	var start_ball: String = JU.s(arch, "start_ball", "ball_rec")
	inventory[start_ball] = 1
	equipment["ball_1"] = start_ball
	var bm: String = JU.s(arch, "start_bag_move")
	if bm != "":
		known_bag_moves.append(bm)
		equipment["bag_move"] = bm
	var qw: Dictionary = JU.dict(DataDB.tuning("player"), "quarter_water")
	quarter_water_max = JU.i(qw, "start_charges", 3)
	if Settings.get_bool("rookie_mode"):
		quarter_water_max += JU.i(JU.dict(DataDB.tuning("player"), "rookie"), "extra_waters", 2)
	quarter_waters = quarter_water_max
	sugar_rush = 0
	chain = {}
	respawn_bodega = ""
	current_district = ""
	profile = prof.duplicate(true)
	counters = {}
	nickname = ""
	defeated_bosses = PackedStringArray()
	opened_boxes = PackedStringArray()
	play_time_s = 0.0
	state_reset.emit()


func stat(name: String) -> int:
	return int(stats.get(name, 10))


func add_tokens(n: int) -> void:
	tokens = maxi(0, tokens + n)
	EventBus.tokens_changed.emit(tokens)


func add_rep(n: int) -> void:
	rep = maxi(0, rep + n)
	EventBus.rep_changed.emit(rep)


func add_item(id: String, n: int = 1) -> void:
	inventory[id] = int(inventory.get(id, 0)) + n
	if int(inventory[id]) <= 0:
		inventory.erase(id)
	EventBus.item_acquired.emit(id, n)


func item_count(id: String) -> int:
	return int(inventory.get(id, 0))


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value
	EventBus.quest_flag_set.emit(flag)


func has_flag(flag: String) -> bool:
	return flags.has(flag) and flags[flag] != null and flags[flag] != false


func bump_counter(key: String, n: int = 1) -> int:
	counters[key] = int(counters.get(key, 0)) + n
	return int(counters[key])


func counter(key: String) -> int:
	return int(counters.get(key, 0))


func has_crown(borough: String) -> bool:
	return crowns.has(borough)


func award_crown(borough: String) -> void:
	if not crowns.has(borough):
		crowns.append(borough)
		EventBus.crown_awarded.emit(borough)


func has_crown_pass() -> bool:
	for b: String in DataSchemas.BOROUGHS:
		if not crowns.has(b):
			return false
	return true


func to_dict() -> Dictionary:
	return {
		"archetype": archetype, "start_borough": start_borough, "ng_cycle": ng_cycle,
		"level": level, "stats": stats, "rep": rep, "tokens": tokens,
		"crowns": Array(crowns), "garden_tickets": Array(garden_tickets), "flags": flags,
		"discovered_stations": Array(discovered_stations), "map_reveal": _reveal_to_save(),
		"inventory": inventory, "equipment": equipment, "ball_upgrades": ball_upgrades,
		"tattoos": Array(tattoos), "flash_sheets": Array(flash_sheets),
		"known_bag_moves": Array(known_bag_moves), "quarter_water_max": quarter_water_max,
		"quarter_waters": quarter_waters, "sugar_rush": sugar_rush, "chain": chain,
		"respawn_bodega": respawn_bodega, "current_district": current_district,
		"profile": profile, "counters": counters, "nickname": nickname,
		"defeated_bosses": Array(defeated_bosses), "opened_boxes": Array(opened_boxes),
		"play_time_s": play_time_s,
	}


func from_dict(d: Dictionary) -> void:
	archetype = JU.s(d, "archetype", "two_way")
	start_borough = JU.s(d, "start_borough", "brooklyn")
	ng_cycle = JU.i(d, "ng_cycle")
	level = JU.i(d, "level", 1)
	stats = {}
	var sd: Dictionary = JU.dict(d, "stats")
	for k: Variant in sd.keys():
		stats[str(k)] = int(sd[k])
	rep = JU.i(d, "rep")
	tokens = JU.i(d, "tokens")
	crowns = JU.strs(d, "crowns")
	garden_tickets = JU.strs(d, "garden_tickets")
	flags = JU.dict(d, "flags").duplicate(true)
	discovered_stations = JU.strs(d, "discovered_stations")
	map_reveal = _reveal_from_save(JU.dict(d, "map_reveal"))
	inventory = _int_dict(JU.dict(d, "inventory"))
	equipment = JU.dict(d, "equipment").duplicate()
	ball_upgrades = _int_dict(JU.dict(d, "ball_upgrades"))
	tattoos = JU.strs(d, "tattoos")
	flash_sheets = JU.strs(d, "flash_sheets")
	known_bag_moves = JU.strs(d, "known_bag_moves")
	quarter_water_max = JU.i(d, "quarter_water_max", 3)
	quarter_waters = JU.i(d, "quarter_waters", quarter_water_max)
	sugar_rush = JU.i(d, "sugar_rush")
	chain = JU.dict(d, "chain").duplicate(true)
	respawn_bodega = JU.s(d, "respawn_bodega")
	current_district = JU.s(d, "current_district")
	profile = JU.dict(d, "profile").duplicate(true)
	counters = _int_dict(JU.dict(d, "counters"))
	nickname = JU.s(d, "nickname")
	defeated_bosses = JU.strs(d, "defeated_bosses")
	opened_boxes = JU.strs(d, "opened_boxes")
	play_time_s = JU.f(d, "play_time_s")
	state_reset.emit()


func _int_dict(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in src.keys():
		out[str(k)] = int(src[k])
	return out


func _reveal_to_save() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in map_reveal.keys():
		var bytes: PackedByteArray = map_reveal[k]
		out[str(k)] = Marshalls.raw_to_base64(bytes)
	return out


func _reveal_from_save(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in src.keys():
		out[str(k)] = Marshalls.base64_to_raw(str(src[k]))
	return out
