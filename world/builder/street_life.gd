class_name StreetLife
extends RefCounted
## People and places that make a district worth walking (playtest R6),
## placed from the map so the 17 ASCII maps stay untouched:
## - a Lieutenant on the street near each locked court (beat them first);
## - rumor NPCs by the bodegas and the station, telling who the boss was;
## - alley stashes in dead-end alleys away from the start;
## - the district's hand-written side street (SideStreets) in its longest
##   alley cut.
## Placement is pure and deterministic from the map; District applies it.

const LT_MIN_TILES: int = 4
const LT_MAX_TILES: int = 7
const CACHE_MIN_FROM_START: int = 14
const MAX_CACHES: int = 2


static func plan(m: MapData, lay: Dictionary) -> Dictionary:
	## {lieutenants: [{boss, pos, data}], rumors: [npc dicts], caches: [box dicts],
	##  side: SideStreets.plan or {}}
	var used: Dictionary = {}
	var start_c: Vector2i = m.cell_of(lay.get("start", Vector3.ZERO))
	var out: Dictionary = {"lieutenants": [], "rumors": [], "caches": []}
	var here: Array[String] = []
	for ct: Variant in JU.a(lay, "courts"):
		var cd: Dictionary = ct
		var boss_id: String = JU.s(cd, "boss")
		here.append(boss_id)
		var lt: Dictionary = LoreBook.lieutenant(boss_id)
		if lt.is_empty() or GameState.defeated_bosses.has(boss_id) or GameState.has_flag(CourtGate.lieutenant_flag(boss_id)):
			continue
		var c: Vector2i = _lieutenant_tile(m, m.cell_of(cd["gate"]), start_c, used)
		if c.x >= 0:
			used[c] = true
			(out["lieutenants"] as Array).append({"boss": boss_id, "pos": m.world_pos(c, BoroughBuilder.CURB_H), "data": lt})
	var anchors: Array[Vector2i] = []
	for b: Variant in JU.a(lay, "bodegas"):
		anchors.append(m.cell_of((b as Dictionary)["door"]))
	for s: Variant in JU.a(lay, "stations"):
		anchors.append(m.cell_of((s as Dictionary)["pos"]))
	var k: int = 0
	for boss_id2: String in here:
		var rumors: Array = JU.a(LoreBook.entry(boss_id2), "rumors")
		for r: Variant in rumors:
			if anchors.is_empty():
				break
			var c2: Vector2i = _near_tile(m, anchors[k % anchors.size()], 2, 4, used)
			k += 1
			if c2.x < 0:
				continue
			used[c2] = true
			var rd: Dictionary = r
			(out["rumors"] as Array).append({"id": "rumor_%s_%d" % [boss_id2, k], "name": JU.s(rd, "name", "Neighbor"),
				"lines": JU.strs(rd, "lines"), "pos": m.world_pos(c2, BoroughBuilder.CURB_H), "look": _look(m.id + str(k)),
				"challenger": {}, "lore": boss_id2})
	var pools: Array = JU.a(JU.dict(m.side, "loot"), "$")
	var pool: String = str(pools[0]) if not pools.is_empty() else "bk_retail"
	var ends: Array[Vector2i] = dead_ends(m, start_c)
	for i: int in mini(MAX_CACHES, ends.size()):
		var c3: Vector2i = ends[i]
		if used.has(c3):
			continue
		used[c3] = true
		(out["caches"] as Array).append({"id": "stash_%s_%d" % [m.id, i], "pos": m.world_pos(c3, BoroughBuilder.CURB_H),
			"pool": pool, "locked": false, "grail": false, "prompt": "Search the stash"})
	out["side"] = SideStreets.plan(m, start_c, used)
	return out


static func dead_ends(m: MapData, start_c: Vector2i) -> Array[Vector2i]:
	## Sidewalk/alley tiles with one walkable neighbor, far from the start,
	## in a stable order (by a hash of the tile and map seed).
	var out: Array[Vector2i] = []
	for y: int in range(1, m.height - 1):
		for x: int in range(1, m.width - 1):
			var c: Vector2i = Vector2i(x, y)
			if m.at(c) != ",":
				continue
			var n: int = 0
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if m.is_walkable(c + d):
					n += 1
			if n == 1 and absi(c.x - start_c.x) + absi(c.y - start_c.y) >= CACHE_MIN_FROM_START:
				out.append(c)
	var seed_v: int = m.seed_value()
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return hash([a, seed_v]) < hash([b, seed_v]))
	return out


static func _lieutenant_tile(m: MapData, gate: Vector2i, start_c: Vector2i, used: Dictionary) -> Vector2i:
	## A plain street tile 4-7 tiles from the gate, preferring the side you
	## arrive from (closest to the district start).
	var best: Vector2i = Vector2i(-1, -1)
	var best_score: int = 1 << 30
	for y: int in range(gate.y - LT_MAX_TILES, gate.y + LT_MAX_TILES + 1):
		for x: int in range(gate.x - LT_MAX_TILES, gate.x + LT_MAX_TILES + 1):
			var c: Vector2i = Vector2i(x, y)
			if x < 1 or y < 1 or x >= m.width - 1 or y >= m.height - 1 or used.has(c):
				continue
			var dg: int = absi(x - gate.x) + absi(y - gate.y)
			if dg < LT_MIN_TILES or dg > LT_MAX_TILES or not (m.at(c) == "." or m.at(c) == ","):
				continue
			var score: int = (absi(x - start_c.x) + absi(y - start_c.y)) * 100 + y * 64 + x
			if score < best_score:
				best_score = score
				best = c
	return best


static func _near_tile(m: MapData, at: Vector2i, rmin: int, rmax: int, used: Dictionary) -> Vector2i:
	for r: int in range(rmin, rmax + 1):
		for y: int in range(at.y - r, at.y + r + 1):
			for x: int in range(at.x - r, at.x + r + 1):
				var c: Vector2i = Vector2i(x, y)
				if absi(x - at.x) + absi(y - at.y) != r or used.has(c):
					continue
				if x >= 1 and y >= 1 and x < m.width - 1 and y < m.height - 1 and m.at(c) == ",":
					return c
	return Vector2i(-1, -1)


static func _look(key: String) -> Dictionary:
	## A plausible neighbor, varied by a hash so rumor NPCs don't all match.
	var h: int = absi(key.hash())
	var tops: Array[String] = ["#F2F6FF", "#E8344A", "#3EF0FF", "#F4B400", "#7CFF9A", "#B48CFF"]
	var skins: Array[String] = ["#6B4226", "#8D5524", "#C68642", "#E0AC69", "#3B2219"]
	var hairs: Array[String] = ["bun", "fade", "bald", "afro", "braids", "locs", "waves", "puffs"]
	return {"top_color": tops[h % tops.size()], "shorts_color": "#3A3A48", "skin": skins[(h / 7) % skins.size()],
		"hair_style": hairs[(h / 13) % hairs.size()], "hair_color": "#1A1A1A", "height": 1.2 + float((h / 17) % 3) * 0.08}
