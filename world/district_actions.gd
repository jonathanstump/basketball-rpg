class_name DistrictActions
extends RefCounted
## Interaction handlers for a district (spec §5): bodegas, stations (tap in +
## fast travel), shops, courts, crossings, shoeboxes (Box Keys), Wire Kicks
## loot, graffiti tags, NPCs, one-way shortcuts and rooftop secrets.


static func register(d: District) -> void:
	var lay: Dictionary = d.layout
	for b: Variant in JU.a(lay, "bodegas"):
		var bd: Dictionary = b
		d.interact.add(JU.s(bd, "id"), "bodega", bd["door"], "Enter %s" % JU.s(bd, "name"), bd, 2.6)
	for s: Variant in JU.a(lay, "stations"):
		var sd: Dictionary = s
		d.interact.add(JU.s(sd, "id"), "station", sd["pos"], "Subway: %s" % JU.s(sd, "name"), sd, 2.4)
	for sh: Variant in JU.a(lay, "shops"):
		var shd: Dictionary = sh
		var nm: String = {"plug": "The Plug", "pump_grip": "Pump & Grip", "ink_needle": "Ink & Needle"}.get(JU.s(shd, "kind"), "Shop")
		d.interact.add(JU.s(shd, "id"), "shop", shd["door"], "Enter " + nm, shd, 2.6)
	for c: Variant in JU.a(lay, "courts"):
		var cd: Dictionary = c
		d.interact.add("court_" + JU.s(cd, "boss"), "court", cd["gate"], court_prompt(cd), cd, 2.6)
	for x: Variant in JU.a(lay, "crossings"):
		var xd: Dictionary = x
		d.interact.add("cross_%d" % int(xd["index"]), "crossing", xd["pos"], "Go to %s" % JU.s(xd, "name"), xd, 3.0)
	for bx: Variant in JU.a(lay, "boxes"):
		var bxd: Dictionary = bx
		if not GameState.opened_boxes.has(JU.s(bxd, "id")):
			d.interact.add(JU.s(bxd, "id"), "box", bxd["pos"], JU.s(bxd, "prompt", "Open shoebox" if not bool(bxd["locked"]) else "Locked shoebox"), bxd, 1.6)
	for t: Variant in JU.a(lay, "tags"):
		var td: Dictionary = t
		d.interact.add(JU.s(td, "id"), "tag", td["pos"], "Read tag", td, 2.0)
	for n: Variant in JU.a(lay, "npcs"):
		var nd: Dictionary = n
		var run_it: bool = not JU.dict(nd, "challenger").is_empty()
		d.interact.add(JU.s(nd, "id"), "npc", nd["pos"], ("Run it with %s" if run_it else "Talk to %s") % JU.s(nd, "name"), nd, 2.2)
	for sc: Variant in JU.a(lay, "shortcuts"):
		var scd: Dictionary = sc
		if not bool(scd["open"]):
			d.interact.add(JU.s(scd, "id"), "shortcut", scd["pos"], "Kick down the ladder" if JU.s(scd, "kind") == "ladder" else "Unlatch the gate", scd, 3.2)
	if lay.has("lost_cat"):
		var lc: Dictionary = lay["lost_cat"]
		d.interact.add("lost_cat", "lost_cat", lc["pos"], "Pick up %s" % JU.s(lc, "cat"), lc, 2.0)
		var cat: MeshInstance3D = MeshInstance3D.new()
		cat.name = "LostCat"
		cat.mesh = MeshLib.sphere(0.25)
		cat.material_override = ToonMaterials.toon(Color("#E8913A"))
		cat.position = (lc["pos"] as Vector3) + Vector3(0, 0.25, 0)
		d.level_root.add_child(cat)
	for sp: Variant in JU.a(lay, "specials"):
		var spd: Dictionary = sp
		d.interact.add("special_" + JU.s(spd, "kind"), "special", spd["pos"], JU.s(spd, "name", "Look closer"), spd, 2.4)
	for se: Variant in JU.a(lay, "secrets"):
		var sed: Dictionary = se
		d.interact.add(JU.s(sed, "id") + "_a", "secret", sed["a"], "Climb", {"to": sed["b"]}, 1.6)
		d.interact.add(JU.s(sed, "id") + "_b", "secret", sed["b"], "Climb back", {"to": sed["a"]}, 1.6)


static func court_prompt(cd: Dictionary) -> String:
	var boss_id: String = JU.s(cd, "boss")
	var boss_name: String = JU.s(DataDB.boss(boss_id), "name", "the court")
	if bool(cd["open"]):
		return "Court"
	return "Challenge %s" % boss_name if CourtGate.is_open(boss_id) else "%s's court (locked)" % CourtGate._title(boss_name)


static func trigger(d: District, it: Dictionary) -> void:
	var data: Dictionary = it["data"]
	match str(it["kind"]):
		"bodega":
			SceneRouter.goto_interior("bodega", JU.s(data, "id"), {"district": d.district_id, "arrive": {"kind": "bodega", "id": JU.s(data, "id")}})
		"shop":
			SceneRouter.goto_interior(JU.s(data, "kind"), JU.s(data, "id"), {"district": d.district_id, "arrive": {"kind": "shop", "id": JU.s(data, "id")}})
		"station":
			station(d, data)
		"court":
			if JU.s(DataDB.boss(JU.s(data, "boss")), "kind") == "final" and not Endings.garden_open():
				EventBus.popup_text.emit("THE GARDEN: %d / 5 TICKET STUBS" % GameState.garden_tickets.size(), d.player.pos, "bad")
				return
			GameState.set_flag("seen_court_" + JU.s(data, "boss"))
			var gate: Dictionary = CourtGate.status(JU.s(data, "boss"))
			if not bool(data["open"]) and not bool(gate["open"]):
				## R6: earn it on the street first.
				LoreBook.hear(JU.s(data, "boss"))
				EventBus.dialogue_requested.emit("", PackedStringArray(["(The gate is chained. %s)" % JU.s(gate, "text")]))
				return
			if bool(data["open"]):
				EventBus.popup_text.emit("OPEN COURT", d.player.pos, "good")
			else:
				SceneRouter.goto_arena(JU.s(data, "boss"), {"district": d.district_id, "arrive": {"kind": "court", "id": JU.s(data, "boss")}})
		"crossing":
			crossing(d, data)
		"box":
			open_box(d, str(it["id"]), data)
		"tag":
			EventBus.dialogue_requested.emit("Graffiti", PackedStringArray([JU.s(data, "text")]))
			GameState.bump_counter("tags_read")
		"npc":
			if not JU.dict(data, "challenger").is_empty():
				challenge(d, data)
			else:
				EventBus.dialogue_requested.emit(JU.s(data, "name"), JU.strs(data, "lines"))
				if LoreBook.hear(JU.s(data, "lore")):
					EventBus.popup_text.emit("WORD ON THE STREET", d.player.pos + Vector3(0, 0.8, 0), "style")
		"shortcut":
			shortcut(d, str(it["id"]), data)
		"lost_cat":
			if Questlines.find_lost_cat():
				EventBus.dialogue_requested.emit(JU.s(data, "cat"), PackedStringArray(["(The cat purrs and climbs onto your shoulder. Time to go home.)", "(Back at the bodega, the owner presses something into your hand: a Nine Lives flash sheet.)"]))
				EventBus.popup_text.emit("NINE LIVES FLASH", d.player.pos, "style")
				d.interact.remove("lost_cat")
				var cm: Node = d.level_root.get_node_or_null("LostCat")
				if cm != null:
					cm.queue_free()
				SaveSystem.request_autosave()
		"special":
			match JU.s(data, "kind"):
				"boss_tunnel":
					SceneRouter.goto_arena(JU.s(data, "boss"), {"district": d.district_id, "arrive": {"kind": "pos", "pos": [d.player.pos.x, d.player.pos.y, d.player.pos.z]}})
		"secret":
			d.player.pos = JU.vec3(data["to"]) + Vector3(0.8, 0.2, 0)
			d.camera_rig.snap()
			EventBus.popup_text.emit("OVER THE ROOFTOPS", d.player.pos, "good")
		"loot":
			var items: PackedStringArray = data["items"]
			for item: String in items:
				GameState.add_item(item, 1)
				EventBus.popup_text.emit(item_name(item), d.player.pos, "tokens")
			GameState.opened_boxes.append(str(it["id"]))
			d.interact.remove(str(it["id"]))
			if data.has("node"):
				(data["node"] as Node).queue_free()


static func challenge(d: District, data: Dictionary) -> void:
	## Pickup Challenger (spec §8.4): their line, then run it or walk away.
	var ch: Dictionary = JU.dict(data, "challenger")
	var beaten: bool = GameState.has_flag("beat_challenger_" + JU.s(ch, "id"))
	var lines: PackedStringArray = JU.strs(data, "lines")
	var opts: Array[Dictionary] = [
		{"id": "run", "label": "Run it (first to %d)" % JU.i(ch, "points", 7), "detail": ("Beat them before. Rematch for Rep." if beaten else "Win and they hand over something good.")},
		{"id": "_leave", "label": "Not now"}]
	var m: ListMenu = ListMenu.new()
	m.set_options(JU.s(data, "name").to_upper(), opts, lines[0] if lines.size() > 0 else "")
	m.chosen.connect(func(id: String) -> void:
		d.close_menu()
		if id == "run":
			SceneRouter.goto_challenger(data, {"district": d.district_id, "arrive": {"kind": "pos", "pos": [d.player.pos.x, d.player.pos.y, d.player.pos.z]}}))
	m.cancelled.connect(d.close_menu)
	d.open_menu(m)


static func station(d: District, data: Dictionary) -> void:
	if FastTravel.tap_in(JU.s(data, "id"), d.district_id):
		EventBus.popup_text.emit("STATION FOUND - MAP UPDATED", d.player.pos, "style")
		SaveSystem.request_autosave()
	var opts: Array[Dictionary] = []
	for st: String in FastTravel.destinations(GameState.discovered_stations):
		var info: Dictionary = WorldIndex.station(st)
		opts.append({"id": st, "label": JU.s(info, "name", st), "detail": WorldIndex.district_name(JU.s(info, "district")),
			"enabled": FastTravel.can_travel("station", st, GameState.discovered_stations, JU.s(data, "id"))})
	opts.append({"id": "_leave", "label": "Stay here"})
	var m: ListMenu = ListMenu.new()
	m.set_options("SUBWAY", opts, "Travel to any station you've tapped into.")
	m.chosen.connect(func(id: String) -> void:
		d.close_menu()
		if id != "_leave":
			travel_to_station(id))
	m.cancelled.connect(d.close_menu)
	d.open_menu(m)


static func travel_to_station(station_id: String) -> void:
	var info: Dictionary = WorldIndex.station(station_id)
	if info.is_empty():
		return
	GameState.flags["hp_ratio"] = GameState.flags.get("hp_ratio", 1.0)
	SceneRouter.goto_district(JU.s(info, "district"), {"kind": "station", "id": station_id}, true)


static func crossing(d: District, data: Dictionary) -> void:
	var to: String = JU.s(data, "to")
	if JU.s(data, "locked") == "crown_pass" and not GameState.has_crown_pass():
		EventBus.popup_text.emit("LOCKED - NEED THE CROWN PASS", d.player.pos, "bad")
		return
	if not WorldIndex.has_district(to):
		EventBus.popup_text.emit("ROAD CLOSED", d.player.pos, "miss")
		return
	SceneRouter.goto_district(to, {"kind": "crossing", "from": d.district_id}, true)


static func open_box(d: District, id: String, data: Dictionary) -> void:
	if bool(data["locked"]):
		if GameState.item_count("box_key") <= 0:
			EventBus.popup_text.emit("NEEDS A BOX KEY", d.player.pos, "bad")
			return
		GameState.add_item("box_key", -1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = id.hash() + GameState.ng_cycle
	var loot: Dictionary = LootRoller.roll(JU.s(data, "pool"), d.tier, rng)
	_grant(d, loot)
	GameState.opened_boxes.append(id)
	if bool(data.get("grail", false)):
		GameState.bump_counter("grails")
	d.interact.remove(id)
	d.views_extra.open_box_view(id)
	EventBus.box_opened.emit(id, loot["items"])
	SaveSystem.request_autosave(1.0)


static func _grant(d: District, loot: Dictionary) -> void:
	var tokens: int = PlayerBuild.reward_tokens(int(loot["tokens"]))
	if tokens > 0:
		GameState.add_tokens(tokens)
		EventBus.popup_text.emit("+%d TOKENS" % tokens, d.player.pos, "tokens")
	for item: String in (loot["items"] as PackedStringArray):
		GameState.add_item(item, 1)
		EventBus.popup_text.emit(item_name(item), d.player.pos + Vector3(0, 0.6, 0), "style")


static func item_name(id: String) -> String:
	var it: Dictionary = DataDB.find_any(id)
	return JU.s(it, "name", id.replace("_", " ").to_upper())


static func drop_loot(d: District, pool_id: String, pos: Vector3) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(pos.x * 100.0) + int(pos.z * 7.0)
	_grant(d, LootRoller.roll(pool_id, d.tier, rng))


static func kicks_down(d: District, id: String, pos: Vector3) -> void:
	var ground: Vector3 = Vector3(pos.x, d.sim.collision.ground_height(Vector3(pos.x, 1.0, pos.z)), pos.z)
	var pool: String = "wire"
	for k: Variant in JU.a(d.layout, "kicks"):
		if JU.s(k as Dictionary, "id") == id:
			pool = JU.s(k as Dictionary, "pool", "wire")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = id.hash()
	var loot: Dictionary = LootRoller.roll(pool, d.tier, rng)
	d.interact.add(id, "loot", ground, "Grab the kicks", {"items": loot["items"]}, 2.0)


static func shortcut(d: District, id: String, data: Dictionary) -> void:
	var p: Vector3 = data["pos"]
	var rel: Vector3 = d.player.pos - p
	var ok: bool = false
	match JU.s(data, "open_from"):
		"s":
			ok = rel.z > 0.5
		"n":
			ok = rel.z < -0.5
		"e":
			ok = rel.x > 0.5
		"w":
			ok = rel.x < -0.5
	if not ok:
		EventBus.popup_text.emit("WON'T BUDGE FROM THIS SIDE", d.player.pos, "miss")
		return
	d.sim.collision.remove_tag("shortcut:" + id)
	d.nav.open_tile(d.map.cell_of(p))
	GameState.set_flag("shortcut_" + id)
	d.interact.remove(id)
	d.views_extra.open_shortcut_view(id)
	EventBus.shortcut_opened.emit(id)
	EventBus.popup_text.emit("SHORTCUT OPENED", d.player.pos, "style")
