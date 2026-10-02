class_name Questlines
extends RefCounted
## The four small questlines (spec §3.5) as pure rules over GameState:
## Old Head Lessons (Pops), Grail Hunt (The Plug), Lost Cat, Rival (Deuce).

const POPS_LESSONS: PackedStringArray = ["self_oop", "euro_glide", "rainbow_lob", "bass_drop", "tunnel"]
const GRAILS_NEEDED: int = 5
const GOLDEN_HOUR: String = "kicks_golden_hour"
const NINE_LIVES_FLASH: String = "flash_nine_lives"
const DEUCE_BAND: String = "headband_deuce"
const DEUCE_TAPE: String = "mixtape_iso"


# ------------------------------------------------------------ Pops

static func pops_lessons_taken() -> int:
	return int(GameState.flags.get("pops_lessons", 0))


static func pops_lesson_ready() -> bool:
	## One lesson per Crown, in order.
	return pops_lessons_taken() < mini(GameState.crowns.size(), POPS_LESSONS.size())


static func take_pops_lesson() -> String:
	if not pops_lesson_ready():
		return ""
	var n: int = pops_lessons_taken()
	var move: String = POPS_LESSONS[n]
	if not GameState.known_bag_moves.has(move):
		GameState.known_bag_moves.append(move)
	GameState.flags["pops_lessons"] = n + 1
	if n + 1 >= POPS_LESSONS.size():
		GameState.set_flag("pops_one_more_run")
	return move


# ------------------------------------------------------------ Grail Hunt

static func grails_found() -> int:
	return GameState.counter("grails")


static func grail_reward_ready() -> bool:
	return grails_found() >= GRAILS_NEEDED and not GameState.has_flag("grail_hunt_done")


static func claim_grail_reward() -> bool:
	if not grail_reward_ready():
		return false
	GameState.add_item(GOLDEN_HOUR, 1)
	GameState.set_flag("grail_hunt_done")
	return true


# ------------------------------------------------------------ Lost Cat

static func lost_cat() -> Dictionary:
	return GameState.flags.get("lost_cat", {})


static func maybe_start_lost_cat(bodega_id: String) -> bool:
	## The first rest after your first Crown: this bodega's cat is gone; it's
	## hiding in another district of the same borough.
	if GameState.crowns.is_empty() or not lost_cat().is_empty() or GameState.has_flag("lost_cat_done"):
		return false
	var info: Dictionary = WorldIndex.bodega(bodega_id)
	var home: String = JU.s(info, "district")
	var borough: String = WorldIndex.district_borough(home)
	var ids: Array = WorldIndex.all().keys()
	ids.sort()
	var target: String = ""
	for d: Variant in ids:
		if str(d) != home and WorldIndex.district_borough(str(d)) == borough:
			target = str(d)
			break
	if target == "":
		return false
	GameState.flags["lost_cat"] = {"bodega": bodega_id, "cat": JU.s(info, "cat"), "district": target, "found": false}
	return true


static func find_lost_cat() -> bool:
	var lc: Dictionary = lost_cat()
	if lc.is_empty() or bool(lc.get("found", false)):
		return false
	lc["found"] = true
	GameState.flags["lost_cat"] = lc
	GameState.set_flag("lost_cat_done")
	GameState.add_item(NINE_LIVES_FLASH, 1)
	return true


# ------------------------------------------------------------ Deuce

static func deuce_ready(n: int) -> bool:
	## Duel 1 after your first mini-boss, duel 2 after your third Crown.
	if GameState.has_flag("beat_challenger_deuce_%d" % n):
		return false
	match n:
		1:
			for b: String in GameState.defeated_bosses:
				if JU.s(DataDB.boss(b), "kind") == "mini":
					return true
			return false
		2:
			return GameState.has_flag("beat_challenger_deuce_1") and GameState.crowns.size() >= 3
	return false


static func next_deuce() -> int:
	for n: int in [1, 2]:
		if deuce_ready(n):
			return n
	return 0


static func deuce_challenger(n: int) -> Dictionary:
	return {"id": "deuce_%d" % n, "skill": 0.7 + 0.1 * float(n), "tier_bonus": n, "points": 7 + 2 * (n - 1),
		"drop": DEUCE_TAPE if n == 1 else DEUCE_BAND, "deuce": n}


static func deuce_npc(n: int) -> Dictionary:
	var lines: PackedStringArray = ["Heard you beat somebody. Lucky.", "Run it. Me and you. First to seven."] if n == 1 else \
		["Three Crowns? Okay. OKAY. Now you gotta beat ME.", "First to nine. No excuses this time."]
	return {"id": "npc_deuce_%d" % n, "name": "Deuce", "lines": lines, "challenger": deuce_challenger(n),
		"look": {"skin": "#8D5524", "top_color": "#141418", "shorts_color": "#C8102E", "hair_style": "high_top", "headband": "#D8263A"}}
