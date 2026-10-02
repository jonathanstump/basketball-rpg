class_name DataSchemas
extends RefCounted
## Schema registry used by DataValidator. Add a catalog/file here whenever a
## new kind of data is introduced.

const BOROUGHS: PackedStringArray = ["bronx", "brooklyn", "queens", "staten_island", "uptown"]
const STATS: PackedStringArray = ["heart", "wind", "body", "handles", "bounce", "jumper", "hands"]
const RARITIES: String = "enum:common|rare|epic|legendary|grail"
const POSSESSION: String = "enum:any|with_ball|without_ball"

const CATALOGS: Dictionary = {
	"archetypes": {
		"id": "string", "name": "string", "stats": "dict",
		"start_ball": "ref:balls", "start_bag_move": "ref?:bag_moves", "blurb": "string",
	},
	"balls": {
		"id": "string", "name": "string", "rarity": RARITIES, "attack": "number",
		"scaling": "dict", "gather_s": "number", "props": "dict", "source": "string", "flavor": "string",
	},
	"hair_styles": {"id": "string", "name": "string", "parts": "array"},
	"environments": {"id": "string", "sky_top": "string", "sky_horizon": "string", "ambient": "string",
		"ambient_energy": "number", "fog_density": "number", "rim": "string", "moon_energy": "number"},
	"enemies": {"id": "string", "name": "string", "kind": "enum:common|critter|unique|elite|prop_target",
		"hp": "number", "damage": "number", "composure": "number", "speed": "number", "rep": "number",
		"tokens": "number", "behavior": "string", "moves": "refs:move@enemies", "captain_move": "ref?:move@enemies"},
	"bag_moves": {
		"id": "string", "name": "string", "hype": "number", "effect": "string",
		"impl": "string", "source": "string",
	},
}

## Catalogs that may legitimately be empty in early milestones.
const OPTIONAL_CATALOGS: PackedStringArray = []

const FILES: Dictionary = {
	"tiers": {"start_tiers": "dict", "fixed": "dict", "multipliers": "dict", "ng_plus": "dict"},
	"tuning/player": {"walk_speed": "number", "run_speed": "number", "sprint_speed": "number",
		"sprint_wind_per_s": "number", "jump_height_m": "number", "quarter_water": "dict",
		"wind_regen_per_s": "number", "wind_regen_delay_s": "number", "input_buffer_frames": "int",
		"coyote_frames": "int"},
	"tuning/stats": {"heart": "dict", "wind": "dict", "body": "dict", "handles": "dict",
		"bounce": "dict", "hands": "dict", "grades": "dict", "stat_factor_bands": "array"},
	"tuning/combat": {"hype": "dict", "takeover": "dict", "ankle_breaker": "dict", "parry": "dict",
		"guard": "dict", "hitstop": "dict", "bucket_blast": "dict", "street": "dict"},
	"tuning/composure": {"shook_s": "number", "stagger_s": "number", "regen_pct_per_s": "number",
		"regen_delay_s": "number"},
	"tuning/shooting": {"gather_s": "number", "center": "number", "base_widths": "dict",
		"zones": "dict", "modifiers": "dict", "perfect_cap": "number"},
	"tuning/economy": {"level_curve": "dict", "buckets": "dict", "prices": "dict"},
	"tuning/bosses": {"mini": "dict", "king": "dict", "duel": "dict"},
	"tuning/ai": {"alert_radius_m": "number", "leash_m": "number", "max_attackers": "int"},
	"input_map": {"actions": "dict"},
	"tuning/camera": {"explore": "dict", "lockon": "dict", "yaw_speed_rad_s": "number"},
	"tuning/quality": {"presets": "dict"},
	"tuning/ball": {"radius": "number", "bounce": "number", "chest_pass": "dict", "baseball_pass": "dict",
		"lob": "dict", "shot": "dict", "rim": "dict", "lost_ball_s": "number", "spare_ball": "ref:balls"},
	"palettes": {"shared": "dict", "regions": "dict"},
	"poses/hooper": {"poses": "dict", "anims": "dict"},
}

const MOVE: Dictionary = {
	"id": "string", "primitive": "string", "startup": "int", "active": "int",
	"recovery": "int", "damage": "number", "min_tier": "int?", "weight": "number?",
	"cooldown_s": "number?", "possession": "enum?:any|with_ball|without_ball",
}


static func custom_checks(db: DataStore) -> PackedStringArray:
	var errs: PackedStringArray = PackedStringArray()
	var tiers: Dictionary = db.tiers()
	var starts: Dictionary = JU.dict(tiers, "start_tiers")
	for b: String in BOROUGHS:
		if not starts.has(b):
			errs.append("tiers: missing start row " + b)
			continue
		var row: Dictionary = starts[b]
		var seen: Array[int] = []
		for b2: String in BOROUGHS:
			seen.append(JU.i(row, b2, -1))
		var sorted: Array[int] = seen.duplicate()
		sorted.sort()
		if sorted != [1, 2, 3, 4, 5]:
			errs.append("tiers: row %s is not a permutation of 1-5" % b)
		if JU.i(row, b) != 1:
			errs.append("tiers: start borough %s must be tier 1" % b)
	var mults: Dictionary = JU.dict(tiers, "multipliers")
	for k: Variant in mults.keys():
		if (mults[k] as Array).size() != 7:
			errs.append("tiers: multiplier '%s' needs 7 entries" % k)
	for arch_id: Variant in db.catalog("archetypes").keys():
		var stats: Dictionary = JU.dict(db.archetype(str(arch_id)), "stats")
		for st: String in STATS:
			if not stats.has(st):
				errs.append("archetype %s missing stat %s" % [arch_id, st])
	for ball_id: Variant in db.catalog("balls").keys():
		var sc: Dictionary = JU.dict(db.ball(str(ball_id)), "scaling")
		for st2: Variant in sc.keys():
			if not STATS.has(str(st2)):
				errs.append("ball %s scales unknown stat %s" % [ball_id, st2])
			elif not ["S", "A", "B", "C", "D"].has(str(sc[st2])):
				errs.append("ball %s has bad grade %s" % [ball_id, sc[st2]])
	return errs
