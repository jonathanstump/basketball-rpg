class_name SideStreets
extends RefCounted
## One hand-written side street per district (NEXT_SESSION step 4,
## data/dialogue/side_streets.json): a named alley with a small crew and
## their leader at the dead end, and a local at the mouth who tells you
## about it. The words are authored per district; the spot is the district's
## longest one-tile cut between buildings, away from the start (or `tile`
## in the data to pin it). The leader holds the middle of the cut.
## Pure and deterministic; District / DistrictSideStreet apply it.

const CREW_MIN_TILES: int = 1
const CREW_MAX_TILES: int = 3
const NPC_PAST_MOUTH: int = 1
const NPC_SEARCH: int = 4
const MIN_FROM_START: int = 10
const BLOCKERS: String = "BTHWDKGI#"


static func entry(district: String) -> Dictionary:
	for s: Variant in JU.a(DataDB.get_dict("dialogue/side_streets"), "streets"):
		if JU.s(s as Dictionary, "district") == district:
			return s
	return {}


static func cleared_flag(district: String) -> String:
	return "side_cleared_" + district


static func is_cleared(district: String) -> bool:
	return GameState.has_flag(cleared_flag(district))


static func plan(m: MapData, start_c: Vector2i, used: Dictionary) -> Dictionary:
	## {} when the district has no side street. Else {name, pool, end: Vector3,
	## leader: {pos, data}, crew: [{enemy, pos}], npc: npc dict}.
	var e: Dictionary = entry(m.id)
	if e.is_empty():
		return {}
	var spot: Vector2i = Vector2i(-1, -1)
	var half: int = 3
	var pin: Array = JU.a(e, "tile")
	if pin.size() == 2 and m.is_walkable(Vector2i(int(pin[0]), int(pin[1]))):
		spot = Vector2i(int(pin[0]), int(pin[1]))
	else:
		var cut: Dictionary = longest_cut(m, start_c, used)
		if not cut.is_empty():
			spot = cut["mid"]
			half = int(cut["half"])
	if spot.x < 0:
		return {}
	used[spot] = true
	var crew: Array = []
	for enemy: String in JU.strs(e, "members"):
		var c2: Vector2i = _walk_tile(m, spot, CREW_MIN_TILES, CREW_MAX_TILES, used)
		if c2.x < 0:
			continue
		used[c2] = true
		crew.append({"enemy": enemy, "pos": m.world_pos(c2, BoroughBuilder.CURB_H)})
	var out: Dictionary = {"name": JU.s(e, "name"), "pool": JU.s(e, "pool", "retail"), "end": m.world_pos(spot, BoroughBuilder.CURB_H),
		"leader": {"pos": m.world_pos(spot, BoroughBuilder.CURB_H), "data": JU.dict(e, "leader")}, "crew": crew, "npc": {}}
	var c3: Vector2i = _walk_tile(m, spot, half + NPC_PAST_MOUTH, half + NPC_PAST_MOUTH + NPC_SEARCH, used)
	if c3.x >= 0:
		used[c3] = true
		var n: Dictionary = JU.dict(e, "npc")
		var lines: PackedStringArray = JU.strs(n, "after") if is_cleared(m.id) else JU.strs(n, "lines")
		out["npc"] = {"id": "side_npc_" + m.id, "name": JU.s(n, "name", "Local"), "lines": lines,
			"pos": m.world_pos(c3, BoroughBuilder.CURB_H), "look": StreetLife._look("side" + m.id), "challenger": {}, "lore": ""}
	return out


static func _is_cut(m: MapData, c: Vector2i, vertical: bool) -> bool:
	## A one-tile alley: sidewalk with walls on both sides.
	if m.at(c) != ",":
		return false
	if vertical:
		return BLOCKERS.contains(m.at(c + Vector2i(-1, 0))) and BLOCKERS.contains(m.at(c + Vector2i(1, 0)))
	return BLOCKERS.contains(m.at(c + Vector2i(0, -1))) and BLOCKERS.contains(m.at(c + Vector2i(0, 1)))


static func longest_cut(m: MapData, start_c: Vector2i, used: Dictionary) -> Dictionary:
	## {mid: Vector2i, half: int} for the longest cut whose middle is free and
	## at least MIN_FROM_START from the start; ties go to the farther one.
	var best: Dictionary = {}
	var best_score: int = -1
	for vertical: bool in [true, false]:
		var step: Vector2i = Vector2i(0, 1) if vertical else Vector2i(1, 0)
		for y: int in range(1, m.height - 1):
			for x: int in range(1, m.width - 1):
				var c: Vector2i = Vector2i(x, y)
				if not _is_cut(m, c, vertical) or _is_cut(m, c - step, vertical):
					continue
				var n: int = 0
				while _is_cut(m, c + step * n, vertical):
					n += 1
				var mid: Vector2i = c + step * (n / 2)
				var far: int = absi(mid.x - start_c.x) + absi(mid.y - start_c.y)
				if n < 3 or far < MIN_FROM_START or used.has(mid):
					continue
				var score: int = n * 10000 + far
				if score > best_score:
					best_score = score
					best = {"mid": mid, "half": n / 2}
	return best


static func _walk_tile(m: MapData, from: Vector2i, dmin: int, dmax: int, used: Dictionary) -> Vector2i:
	## The first free street/sidewalk tile dmin..dmax steps away *walking*
	## (BFS), so nobody stands on the far side of a wall.
	var dist: Dictionary = {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		var dc: int = int(dist[c])
		if dc >= dmin and not used.has(c) and (m.at(c) == "," or m.at(c) == "."):
			return c
		if dc >= dmax:
			continue
		for dv: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if not dist.has(n) and n.x >= 1 and n.y >= 1 and n.x < m.width - 1 and n.y < m.height - 1 and m.is_walkable(n):
				dist[n] = dc + 1
				queue.append(n)
	return Vector2i(-1, -1)
