class_name DistrictBindings
extends RefCounted
## Resolves map markers + sidecar bindings into gameplay entries (spec
## §15.10): stations, NPCs, crossings, courts, shortcuts, secrets, shoeboxes,
## Bootlegs, Wire Kicks, crate hoops, spawns and graffiti tags.


static func collect(bb: BoroughBuilder) -> void:
	var m: MapData = bb.map
	var lay: Dictionary = bb.layout
	## Default start: the '@' tile, else the station (never inside a block).
	var start_cells: Array[Vector2i] = m.cells_of("@")
	if start_cells.is_empty():
		start_cells = m.cells_of("S")
	for c: Vector2i in start_cells:
		lay["start"] = m.world_pos(c, BoroughBuilder.CURB_H) + (Vector3(1.5, 0, 0) if m.at(c) == "S" else Vector3.ZERO)
	var k: int = 0
	for c2: Vector2i in m.cells_of("S"):
		var st: Dictionary = _dict(m.bound("S", k))
		(lay["stations"] as Array).append({"id": JU.s(st, "id", "%s_station_%d" % [m.id, k]), "name": JU.s(st, "name", "Station"), "line": JU.s(st, "line", "gray"), "pos": m.world_pos(c2, BoroughBuilder.CURB_H)})
		k += 1
	k = 0
	for c3: Vector2i in m.cells_of("n"):
		var npc: Dictionary = _dict(m.bound("n", k))
		(lay["npcs"] as Array).append({"id": JU.s(npc, "id", "%s_npc_%d" % [m.id, k]), "name": JU.s(npc, "name", "Neighbor"), "lines": JU.strs(npc, "lines"), "pos": m.world_pos(c3, BoroughBuilder.CURB_H), "look": JU.dict(npc, "look"), "challenger": JU.dict(npc, "challenger")})
		k += 1
	_quest_extras(m, lay)
	k = 0
	for c4: Vector2i in m.cells_of(">"):
		var cr: Dictionary = _dict(m.bound(">", k))
		(lay["crossings"] as Array).append({"to": JU.s(cr, "to"), "via": JU.s(cr, "via"), "name": JU.s(cr, "name", JU.s(cr, "to")), "locked": JU.s(cr, "locked"), "pos": m.world_pos(c4), "index": k})
		k += 1
	for letter: String in ["M", "X"]:
		k = 0
		for c5: Vector2i in m.cells_of(letter):
			var boss_id: Variant = m.bound(letter, k)
			_court(bb, c5, str(boss_id) if boss_id != null else "", letter)
			k += 1
	k = 0
	for letter2: String in ["L", "g"]:
		var kk: int = 0
		for c6: Vector2i in m.cells_of(letter2):
			var sc: Dictionary = _dict(m.bound(letter2, kk))
			var id: String = JU.s(sc, "id", "%s_shortcut_%d" % [m.id, k])
			var p: Vector3 = m.world_pos(c6)
			bb.sim.collision.add_box(p + Vector3(0, 2.0, 0), Vector3(MapData.TILE, 4.0, MapData.TILE), "shortcut:" + id)
			var opened: bool = GameState.has_flag("shortcut_" + id)
			if opened:
				bb.sim.collision.remove_tag("shortcut:" + id)
			(lay["shortcuts"] as Array).append({"id": id, "pos": p, "open_from": JU.s(sc, "open_from", "s"), "kind": JU.s(sc, "kind", "gate" if letter2 == "g" else "ladder"), "open": opened})
			kk += 1
			k += 1
	var sec: Array[Vector2i] = m.cells_of("^")
	for i: int in range(0, sec.size() - 1, 2):
		var a: Dictionary = _dict(m.bound("^", i))
		(lay["secrets"] as Array).append({"id": JU.s(a, "id", "%s_secret_%d" % [m.id, i / 2]), "a": m.world_pos(sec[i], BoroughBuilder.CURB_H), "b": m.world_pos(sec[i + 1], BoroughBuilder.CURB_H)})
	var loot: Dictionary = JU.dict(m.side, "loot")
	var box_pools: Variant = loot.get("$", "retail")
	k = 0
	for c7: Vector2i in m.cells_of("$"):
		var pool: String = str((box_pools as Array)[k]) if box_pools is Array and k < (box_pools as Array).size() else str(box_pools)
		(lay["boxes"] as Array).append({"id": "%s_box_%d" % [m.id, k], "pos": m.world_pos(c7, BoroughBuilder.CURB_H if bb.surface(c7) == "," else 0.0), "pool": pool, "locked": pool.contains("locked"), "grail": pool.contains("grail")})
		k += 1
	k = 0
	for c8: Vector2i in m.cells_of("%"):
		(lay["spawns"] as Array).append({"enemy": "bootleg", "pos": m.world_pos(c8, BoroughBuilder.CURB_H), "captain": false, "id": "%s_bootleg_%d" % [m.id, k]})
		k += 1
	k = 0
	for c9: Vector2i in m.cells_of("w"):
		var kid: String = "%s_kicks_%d" % [m.id, k]
		var kp: Vector3 = m.world_pos(c9, 6.0)
		if not GameState.opened_boxes.has(kid):
			bb.balls.add_wire_kicks(kid, kp)
		(lay["kicks"] as Array).append({"id": kid, "pos": kp, "pool": str(loot.get("w", "wire")), "taken": GameState.opened_boxes.has(kid), "dir": DistrictDressing._road_dir(m, c9)})
		k += 1
	k = 0
	for c10: Vector2i in m.cells_of("h"):
		var rd: Vector3 = DistrictDressing._road_dir(m, c10)
		var hoop: SimHoop = SimHoop.crate("%s_crate_%d" % [m.id, k], m.world_pos(c10, BoroughBuilder.CURB_H), rd if rd != Vector3.ZERO else Vector3(0, 0, 1))
		hoop.tier = TierMath.tier_for(DataDB.tiers(), GameState.start_borough, m.borough(), GameState.ng_cycle)
		hoop.first_make_paid = GameState.has_flag("crate_paid_" + hoop.id)
		bb.balls.add_hoop(hoop)
		bb.sim.collision.add_box(m.world_pos(c10) + Vector3(0, 1.6, 0), Vector3(0.3, 3.2, 0.3), "pole")
		(lay["hoops"] as Array).append(hoop)
		k += 1
	var spawns: Dictionary = JU.dict(m.side, "spawns")
	for letter3: String in ["e", "E", "c"]:
		var list: PackedStringArray = JU.strs(spawns, letter3)
		k = 0
		for c11: Vector2i in m.cells_of(letter3):
			var entry: String = list[k % list.size()] if list.size() > 0 else "ball_hog"
			var cap: bool = entry.begins_with("captain:") or letter3 == "E"
			(lay["spawns"] as Array).append({"enemy": entry.trim_prefix("captain:"), "pos": m.world_pos(c11, BoroughBuilder.CURB_H), "captain": cap, "id": "%s_%s_%d" % [m.id, letter3, k]})
			k += 1
	_graffiti(bb)


static func _dict(v: Variant) -> Dictionary:
	return v if v is Dictionary else {}


static func _court(bb: BoroughBuilder, gate: Vector2i, boss_id: String, letter: String) -> void:
	var m: MapData = bb.map
	var cells: Array[Vector2i] = m.cells_of("C")
	var near: Array[Vector2i] = []
	for c: Vector2i in cells:
		if c.distance_to(gate) < 14.0:
			near.append(c)
	if near.is_empty():
		return
	var mn: Vector2i = near[0]
	var mx: Vector2i = near[0]
	for c2: Vector2i in near:
		mn = Vector2i(mini(mn.x, c2.x), mini(mn.y, c2.y))
		mx = Vector2i(maxi(mx.x, c2.x), maxi(mx.y, c2.y))
	var a: Vector3 = m.world_pos(mn)
	var b: Vector3 = m.world_pos(mx)
	var center: Vector3 = (a + b) * 0.5
	var gate_pos: Vector3 = m.world_pos(gate)
	var toward_gate: Vector3 = (gate_pos - center)
	toward_gate.y = 0.0
	var axis: Vector3 = Vector3(0, 0, signf(toward_gate.z)) if absf(toward_gate.z) >= absf(toward_gate.x) else Vector3(signf(toward_gate.x), 0, 0)
	var half_len: float = (absf(b.z - a.z) if absf(axis.z) > 0.5 else absf(b.x - a.x)) * 0.5 + MapData.TILE * 0.5
	var hoop_floor: Vector3 = center - axis * (half_len - 1.2)
	var defeated: bool = GameState.defeated_bosses.has(boss_id)
	var hoop: SimHoop = SimHoop.regulation("%s_court_%s" % [m.id, boss_id if boss_id != "" else letter], hoop_floor, axis)
	hoop.enabled = defeated
	bb.balls.add_hoop(hoop)
	var hx: float = absf(b.x - a.x) * 0.5 + MapData.TILE * 0.5 + 0.3
	var hz: float = absf(b.z - a.z) * 0.5 + MapData.TILE * 0.5 + 0.3
	if not defeated:
		bb.sim.collision.add_block(Vector2(center.x - hx, center.z - hz), Vector2(center.x + hx, center.z + hz), 3.6, "court:" + boss_id)
	(bb.layout["courts"] as Array).append({"boss": boss_id, "kind": letter, "gate": gate_pos, "center": center, "size": Vector2(hx, hz) * 2.0, "hoop": hoop, "open": defeated})


static func _graffiti(bb: BoroughBuilder) -> void:
	var m: MapData = bb.map
	var texts: PackedStringArray = JU.strs(m.side, "graffiti")
	if texts.is_empty():
		return
	var cands: Array[Dictionary] = []
	for y: int in m.height:
		for x: int in m.width:
			var c: Vector2i = Vector2i(x, y)
			if m.at(c) != ",":
				continue
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if m.at(c + d) in ["B", "T", "W", "H"]:
					cands.append({"tile": c, "wall": Vector3(float(d.x), 0, float(d.y))})
					break
	if cands.is_empty():
		return
	var step: int = maxi(1, cands.size() / texts.size())
	for i: int in texts.size():
		var cd: Dictionary = cands[(i * step + bb.rng.randi_range(0, step - 1)) % cands.size()]
		var wall: Vector3 = cd["wall"]
		var pos: Vector3 = m.world_pos(cd["tile"], BoroughBuilder.CURB_H) + wall * (MapData.TILE * 0.5 - 0.05)
		(bb.layout["tags"] as Array).append({"id": "%s_tag_%d" % [m.id, i], "text": texts[i], "pos": pos, "wall": wall})


static func _quest_extras(m: MapData, lay: Dictionary) -> void:
	## Questline actors placed at load (spec §3.5): Deuce by the station when a
	## duel is due; the lost cat in an alley; authored "specials" (tunnels).
	var anchor: Vector3 = lay["start"]
	if not JU.a(lay, "stations").is_empty():
		anchor = (JU.a(lay, "stations")[0] as Dictionary)["pos"]
	var n: int = Questlines.next_deuce()
	if n == 3 and m.id != "city_midtown":
		n = 0   # the third duel happens in the Garden tunnel only
	if n > 0:
		var deuce: Dictionary = Questlines.deuce_npc(n)
		deuce["pos"] = anchor + Vector3(-2.5, 0, 1.5)
		(lay["npcs"] as Array).append(deuce)
	var lc: Dictionary = Questlines.lost_cat()
	if not lc.is_empty() and not bool(lc.get("found", false)) and JU.s(lc, "district") == m.id:
		var spot: Vector3 = anchor + Vector3(2.5, 0, 2.5)
		var alleys: Array[Vector2i] = m.cells_of("L")
		alleys.append_array(m.cells_of("g"))
		if not alleys.is_empty():
			spot = m.world_pos(alleys[0] + Vector2i(0, 2), BoroughBuilder.CURB_H)
		lay["lost_cat"] = {"pos": spot, "cat": JU.s(lc, "cat")}
	lay["specials"] = []
	for sp: Variant in JU.a(m.side, "specials"):
		var sd: Dictionary = sp
		var tile: Array = JU.a(sd, "tile")
		(lay["specials"] as Array).append({"kind": JU.s(sd, "kind"), "name": JU.s(sd, "name"), "boss": JU.s(sd, "boss"),
			"pos": m.world_pos(Vector2i(int(tile[0]), int(tile[1])), BoroughBuilder.CURB_H)})
	if GameState.has_flag("pops_one_more_run") and not GameState.defeated_bosses.has("opt_pops") and m.id == FrontEndFlow.start_district(GameState.start_borough):
		## Pops waits on your home court after five Crowns (spec §9.3 opt_pops).
		(lay["specials"] as Array).append({"kind": "boss_tunnel", "boss": "opt_pops", "name": "Pops is waiting: one more run", "pos": anchor + Vector3(2.5, 0, -1.5)})
