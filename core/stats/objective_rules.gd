class_name ObjectiveRules
extends RefCounted
## What to do next (spec §3.2 structure): a pure function of GameState and
## the world data. Act I: take your home borough's Crown (minis first, then
## the King), then the next-lowest-tier borough; Act II: the five City
## landmarks; Finale: Midnight at the Garden. Also routes between districts
## over the crossings (City crossings need the Crown Pass) so the HUD can
## point at the next court or the crossing that leads toward it.

const ACT_BOROUGHS: PackedStringArray = ["bronx", "brooklyn", "queens", "staten_island", "uptown"]


static func boss_district(boss_id: String) -> String:
	var all: Dictionary = WorldIndex.all()
	for d: Variant in all.keys():
		var fights: Dictionary = JU.dict(all[d] as Dictionary, "fights")
		for k: Variant in fights.keys():
			if JU.strs(fights, str(k)).has(boss_id):
				return str(d)
	return ""


static func borough_cast(borough: String) -> Dictionary:
	## {minis: [ids], king: id} for a borough's main path (optional bosses excluded).
	var minis: Array[String] = []
	var king: String = ""
	var cat: Dictionary = DataDB.catalog("bosses")
	var ids: Array = cat.keys()
	ids.sort()
	for id_v: Variant in ids:
		var id: String = str(id_v)
		var b: Dictionary = cat[id_v]
		if JU.s(b, "borough") != borough or id.begins_with("opt_") or JU.b(b, "optional"):
			continue
		if JU.s(b, "kind") == "mini":
			minis.append(id)
		elif JU.s(b, "kind") == "king":
			king = id
	return {"minis": minis, "king": king}


static func _undefeated(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in ids:
		if str(id) != "" and not GameState.defeated_bosses.has(str(id)):
			out.append(str(id))
	return out


static func focus_borough() -> String:
	## Home borough until it's crowned, then the uncrowned borough with the lowest tier.
	var home: String = GameState.start_borough if GameState.start_borough != "" else "brooklyn"
	if not GameState.has_crown(home):
		return home
	var best: String = ""
	var best_tier: int = 99
	for b: String in ACT_BOROUGHS:
		if GameState.has_crown(b):
			continue
		var t: int = TierManager.tier_of(b)
		if t < best_tier:
			best = b
			best_tier = t
	return best


static func current(from_district: String = "") -> Dictionary:
	## {} before the prologue is done. Else {title, detail, boss, district,
	## done, total}. `from_district` picks the nearest remaining fight.
	if not GameState.has_flag("prologue_done"):
		return {}
	if GameState.has_flag("ending_daybreak") or GameState.has_flag("ending_overtime"):
		return {"title": "Run it back", "detail": "The night's yours. Chase Pops, the Rat King, the Grails, or start NG+.", "boss": "", "district": "", "done": 0, "total": 0}
	var borough: String = focus_borough()
	if borough != "":
		var cast: Dictionary = borough_cast(borough)
		var left: Array[String] = _undefeated(cast["minis"])
		if left.is_empty():
			left = _undefeated([cast["king"]])
		var total: int = (cast["minis"] as Array).size() + 1
		var done: int = total - _undefeated(cast["minis"]).size() - _undefeated([cast["king"]]).size()
		var target: String = _nearest(left, from_district)
		var bname: String = JU.s(DataDB.item("boroughs", borough), "name", borough.capitalize())
		var role: String = "the Borough King" if JU.s(DataDB.boss(target), "kind") == "king" else "a mini-boss"
		return {"title": "Take the %s Crown" % bname, "boss": target, "district": boss_district(target), "done": done, "total": total,
			"detail": "Beat %s, %s, at %s (%d/%d)" % [JU.s(DataDB.boss(target), "name"), role, WorldIndex.district_name(boss_district(target)), done, total]}
	var marks: Array[String] = []
	for id_v: Variant in DataDB.catalog("bosses").keys():
		if JU.s(DataDB.boss(str(id_v)), "kind") == "landmark":
			marks.append(str(id_v))
	marks.sort()
	var lm_left: Array[String] = _undefeated(marks)
	if not lm_left.is_empty():
		var t2: String = _nearest(lm_left, from_district)
		var d2: int = marks.size() - lm_left.size()
		return {"title": "Into the City", "boss": t2, "district": boss_district(t2), "done": d2, "total": marks.size(),
			"detail": "Five Crowns opened the bridges. Beat %s at %s (%d/%d)" % [JU.s(DataDB.boss(t2), "name"), WorldIndex.district_name(boss_district(t2)), d2, marks.size()]}
	return {"title": "The Garden", "boss": "fin_midnight", "district": boss_district("fin_midnight"), "done": 0, "total": 1,
		"detail": "Every clock still says three. Midnight is waiting at the Garden in %s." % WorldIndex.district_name(boss_district("fin_midnight"))}


static func _nearest(ids: Array[String], from_district: String) -> String:
	if ids.is_empty():
		return ""
	if from_district == "":
		return ids[0]
	var best: String = ids[0]
	var best_len: int = 9999
	for id: String in ids:
		var r: Array[String] = route(from_district, boss_district(id))
		var n: int = r.size() if not r.is_empty() or boss_district(id) == from_district else 9999
		if n < best_len:
			best = id
			best_len = n
	return best


static func can_enter(district: String) -> bool:
	return WorldIndex.district_borough(district) != "city" or GameState.has_crown_pass()


static func route(from_district: String, to_district: String) -> Array[String]:
	## Districts to walk through after `from_district` (last = target), or []
	## when already there / unreachable.
	if from_district == to_district or from_district == "" or to_district == "":
		return []
	var all: Dictionary = WorldIndex.all()
	var prev: Dictionary = {from_district: ""}
	var queue: Array[String] = [from_district]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		if cur == to_district:
			break
		for x: Variant in JU.a(all.get(cur, {}) as Dictionary, "crossings"):
			var nxt: String = JU.s(x as Dictionary, "to")
			if nxt != "" and not prev.has(nxt) and all.has(nxt) and can_enter(nxt):
				prev[nxt] = cur
				queue.append(nxt)
	if not prev.has(to_district):
		return []
	var path: Array[String] = []
	var c: String = to_district
	while c != from_district:
		path.push_front(c)
		c = str(prev[c])
	return path


static func story_tokens(borough: String) -> Dictionary:
	## Fills Pops' lines: {borough}, {cast} (who rules which court), {first},
	## {objective} and {detail} (the current objective).
	var cast: Dictionary = borough_cast(borough)
	var parts: PackedStringArray = PackedStringArray()
	for m: Variant in cast["minis"]:
		parts.append("%s, in %s." % [JU.s(DataDB.boss(str(m)), "name"), WorldIndex.district_name(boss_district(str(m)))])
	var king: String = str(cast["king"])
	if king != "":
		parts.append("Then the King: %s, in %s." % [JU.s(DataDB.boss(king), "name"), WorldIndex.district_name(boss_district(king))])
	var obj: Dictionary = current()
	var first: String = JU.s(DataDB.boss(JU.s(obj, "boss")), "name", "the nearest court")
	return {"borough": JU.s(DataDB.item("boroughs", borough), "name", borough.capitalize()), "cast": " ".join(parts),
		"first": first, "objective": JU.s(obj, "title", "Keep hooping"), "detail": JU.s(obj, "detail", "Run it back")}


static func fill(lines: PackedStringArray, borough: String) -> PackedStringArray:
	var t: Dictionary = story_tokens(borough)
	var out: PackedStringArray = PackedStringArray()
	for l: String in lines:
		out.append(l.format(t))
	return out
