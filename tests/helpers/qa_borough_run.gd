class_name QABoroughRun
extends QAScript
## QA borough run (spec §16 M9a–d): start a run in the borough, sweep every
## POI in its three districts, open every bodega and shop, load every boss
## court from the district, beat each boss with the god-mode bot at its tier,
## play out the Pickup Challengers, and check the borough's Crown.


func run_borough(borough: String, districts: PackedStringArray, bosses: PackedStringArray, king: String) -> bool:
	GameState.new_run("two_way", borough, {"name": "QA"})
	GameState.set_flag("prologue_done")
	GameState.add_item("box_key", 20)
	var visited: int = 0
	for id: String in districts:
		var n: int = await sweep_district(id)
		if n < 0:
			return false
		visited += n
	print("QA %s: %d POIs triggered" % [borough, visited])
	if not await visit_interiors(districts):
		return false
	for boss_id: String in bosses:
		if not await fight(boss_id):
			return false
	for id3: String in districts:
		for npc: Variant in JU.a(WorldIndex.all()[id3] as Dictionary, "npcs"):
			var ch: Dictionary = JU.dict(npc as Dictionary, "challenger")
			if ch.is_empty():
				continue
			var cr: Dictionary = ChallengerDuel.run_sim(JU.f(ch, "skill", 0.5), 1, JU.i(ch, "tier_bonus"), {"max_s": 400, "seed": 5})
			print("QA %s: challenger %s -> %s %d-%d" % [borough, JU.s(ch, "id"), cr["result"], int(cr["player"]), int(cr["rival"])])
			if not check(str(cr["result"]) != "timeout", "challenger %s never finished" % JU.s(ch, "id")):
				return false
	if not check(GameState.has_crown(borough), "no %s Crown after %s" % [borough, king]):
		return false
	if not check(GameState.item_count("crown_" + borough) == 1, "Crown item missing"):
		return false
	print("QA %s: Crown earned; %d tokens, %d Rep" % [borough, GameState.tokens, GameState.rep])
	return true


func visit_interiors(districts: PackedStringArray) -> bool:
	for id2: String in districts:
		for b: Variant in JU.a(WorldIndex.all()[id2] as Dictionary, "bodegas"):
			SceneRouter.goto_interior("bodega", JU.s(b as Dictionary, "id"), {"district": id2})
			await frames(6)
			if not check(get_tree().current_scene is Interior, "bodega %s did not open" % JU.s(b as Dictionary, "id")):
				return false
		var shops: Dictionary = JU.dict(WorldIndex.all()[id2] as Dictionary, "shops")
		for letter: String in ["K", "G", "I"]:
			if shops.has(letter):
				SceneRouter.goto_interior({"K": "plug", "G": "pump_grip", "I": "ink_needle"}[letter], str((shops[letter] as Array)[0]), {"district": id2})
				await frames(6)
				if not check(get_tree().current_scene is Interior, "shop %s did not open" % letter):
					return false
	return true


func beat_lieutenant(d: District, boss_id: String) -> bool:
	## R6: the court is chained until its lieutenant goes down. QA knocks
	## them out through the real death event path.
	if CourtGate.is_open(boss_id):
		return true
	for a: SimActor in d.sim.actors:
		if str(a.flags.get("lieutenant", "")) == boss_id and a.alive:
			d.combat.damage.apply_raw(a, a.hp + 1.0)
			d.sim.emit("actor_killed", {"actor": a.id, "attacker": d.player.id, "kind": a.kind, "archetype": a.archetype})
	await frames(2)
	d.dialogue.open = false
	return check(CourtGate.is_open(boss_id), "%s court still locked after its lieutenant (%s)" % [boss_id, CourtGate.status(boss_id)])


func fight(boss_id: String) -> bool:
	var district: String = JU.s(DataDB.boss(boss_id), "district")
	SceneRouter.goto_district(district, {"kind": "court", "id": boss_id}, false)
	await frames(10)
	if not check(get_tree().current_scene is District, "%s did not load" % district):
		return false
	var d: District = get_tree().current_scene as District
	var court: Dictionary = {}
	for it: Dictionary in d.interact.items:
		if str(it["kind"]) == "court" and JU.s(it["data"] as Dictionary, "boss") == boss_id:
			court = it
	if not check(not court.is_empty(), "no court for %s in %s" % [boss_id, district]):
		return false
	if not await beat_lieutenant(d, boss_id):
		return false
	DistrictActions.trigger(d, court)
	await frames(10)
	if not check(get_tree().current_scene is BossArena, "%s arena did not load" % boss_id):
		return false
	var arena: BossArena = get_tree().current_scene as BossArena
	if not check(arena.views.has(arena.boss.id), "%s has no view" % boss_id):
		return false
	var tier: int = arena.tier
	var r: Dictionary = BossSim.run(boss_id, tier, {"god": true, "max_s": 900, "seed": 2})
	print("QA fight: %s T%d %s in %.0fs (makes %d)" % [boss_id, tier, r["result"], float(r["time_s"]), int((r["stats"] as Dictionary)["makes"])])
	if not check(str(r["result"]) == "victory", "%s not beaten: %s" % [boss_id, r["result"]]):
		return false
	BossArena.grant_rewards(boss_id, BossFactory.rewards(DataDB.boss(boss_id), tier))
	return true


func sweep_district(id: String) -> int:
	SceneRouter.goto_district(id, {}, false)
	await frames(10)
	if not check(get_tree().current_scene is District, "%s did not load" % id):
		return -1
	var d: District = get_tree().current_scene as District
	var n: int = 0
	for it: Dictionary in d.interact.items.duplicate():
		var kind: String = str(it["kind"])
		var data: Dictionary = it["data"]
		match kind:
			"tag", "box", "secret":
				d.player.pos = it["pos"]
				DistrictActions.trigger(d, it)
				n += 1
			"npc":
				if JU.dict(data, "challenger").is_empty():
					DistrictActions.trigger(d, it)
				n += 1
			"shortcut":
				var off: Vector3 = {"s": Vector3(0, 0, 2.5), "n": Vector3(0, 0, -2.5), "e": Vector3(2.5, 0, 0), "w": Vector3(-2.5, 0, 0)}[JU.s(data, "open_from", "s")]
				d.player.pos = (data["pos"] as Vector3) + off
				DistrictActions.trigger(d, it)
				if not check(GameState.has_flag("shortcut_" + str(it["id"])), "shortcut %s did not open from its side" % it["id"]):
					return -1
				n += 1
			"station":
				DistrictActions.trigger(d, it)
				n += 1
			"crossing":
				var to: String = JU.s(data, "to")
				if not check(JU.s(data, "locked") != "" or WorldIndex.has_district(to) or to.substr(0, 2) != id.substr(0, 2), "crossing to %s is broken" % to):
					return -1
				n += 1
			"bodega", "shop", "court":
				n += 1
		d.close_menu()
		await frames(1)
	for b: Dictionary in JU.a(d.layout, "boxes"):
		if not check(GameState.opened_boxes.has(JU.s(b, "id")), "box %s still closed" % JU.s(b, "id")):
			return -1
	return n
