class_name StreetRep
extends RefCounted
## Street rep, shown in-game as "Buzz" so it doesn't read like the Rep
## currency (NEXT_SESSION step 3). Each district has to know your name
## before a lieutenant shows up by the court: beat crews, read the walls,
## talk to people, find stashes, clear the side street. Each tag, NPC, stash
## and side street counts once; crews count every time they go down.
## Pure: GameState counters "buzz_<district>" and flags "buzz_seen_<id>".


static func cfg() -> Dictionary:
	return DataDB.tuning("street_rep")


static func points(district: String) -> int:
	return GameState.counter("buzz_" + district)


static func need_for(boss_id: String) -> int:
	var kind: String = JU.s(DataDB.boss(boss_id), "kind", "mini")
	return JU.i(JU.dict(cfg(), "need"), kind, JU.i(JU.dict(cfg(), "need"), "mini", 6))


static func district_need(district: String) -> int:
	## The most any court in the district asks for (what the HUD counts to).
	var best: int = 0
	for b: String in gated_courts(district):
		best = maxi(best, need_for(b))
	return best


static func known_for(boss_id: String) -> bool:
	## The district this court is in knows you well enough for its lieutenant.
	var d: String = ObjectiveRules.boss_district(boss_id)
	return d == "" or points(d) >= need_for(boss_id)


static func earn(district: String, source: String, once_id: String = "") -> int:
	## Adds the configured points for `source`. With `once_id`, only the first
	## time counts. Returns the points added (0 if already counted).
	if district == "":
		return 0
	if once_id != "":
		var key: String = "buzz_seen_" + once_id
		if GameState.has_flag(key):
			return 0
		GameState.set_flag(key)
	var n: int = JU.i(JU.dict(cfg(), "points"), source, 0)
	if n > 0:
		GameState.bump_counter("buzz_" + district, n)
	return n


static func gated_courts(district: String) -> Array[String]:
	## Courts in the district that have a lieutenant to earn.
	var out: Array[String] = []
	var fights: Dictionary = JU.dict(WorldIndex.all().get(district, {}) as Dictionary, "fights")
	for k: Variant in fights.keys():
		for id: String in JU.strs(fights, str(k)):
			if not id.begins_with("opt_") and not LoreBook.lieutenant(id).is_empty():
				out.append(id)
	return out
