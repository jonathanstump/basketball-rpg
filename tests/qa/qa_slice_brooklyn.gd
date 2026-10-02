extends QAScript
## QA slice run (spec §16 M8): new game in Brooklyn -> creator -> tutorial
## "I Got Next" -> wake in the bodega -> every POI in Bed-Stuy, Coney Island
## and DUMBO -> every fight (god-mode bot, T1) -> the Brooklyn Crown and an
## earned nickname.

const DISTRICTS: PackedStringArray = ["bk_bedstuy", "bk_coney", "bk_dumbo"]
const BOSSES: PackedStringArray = ["bk_stoop", "bk_barker", "bk_toll"]


func run() -> bool:
	await frames(5)
	if not check(get_tree().current_scene is TitleScreen, "boot did not land on the title"):
		return false
	# ---- New game: creator -> prologue.
	SceneRouter.goto(FrontEndFlow.CREATOR, {"slot": 2})
	await frames(8)
	if not check(get_tree().current_scene is CreatorScreen, "creator did not open"):
		return false
	var cr: CreatorScreen = get_tree().current_scene as CreatorScreen
	cr._on_look("_random")
	cr.profile["name"] = "QA Glide"
	FrontEndFlow.start_new_game("slasher", "brooklyn", cr.profile.duplicate(), 2)
	await frames(8)
	if not check(get_tree().current_scene is Prologue, "prologue did not open"):
		return false
	var pro: Prologue = get_tree().current_scene as Prologue
	pro.player.pos = pro.lay["top_of_key"]
	await frames(4)
	if not check(pro.phase == "call", "walk-up step did not complete"):
		return false
	pro.call_next()
	await frames(30)
	pro.player.pos += Vector3(5, 0, 0)
	await frames(4)
	var si: ScriptedInput = ScriptedInput.new()
	pro.use_scripted_input(si)
	pro.player.flags["qw"] = 3
	si.press_at(pro.sim.frame + 2, "dodge")
	si.press_at(pro.sim.frame + 70, "quarter_water")
	await frames(160)
	for k: String in ["moved", "crossover", "qw_used"]:
		if not check(pro.tracker.done.has({"moved": "move", "crossover": "crossover", "qw_used": "quarter_water"}[k]), "tutorial step %s not detected from play" % k):
			return false
	# Timing-based steps (strike/ankle/crate/strip) are driven by tests/unit;
	# here the QA marks them to keep the run deterministic.
	for k2: String in ["strike", "ankle_breaker", "crate_make", "strip"]:
		pro.tracker.mark(k2)
	await frames(400)
	if not check(GameState.has_flag("prologue_done"), "cameo did not hand off to the bodega"):
		return false
	await frames(10)
	if not check(get_tree().current_scene is Interior, "did not wake up in a bodega"):
		return false
	print("QA slice: prologue done, woke up in %s" % GameState.respawn_bodega)
	# ---- Every POI.
	GameState.add_item("box_key", 20)
	var visited: int = 0
	for id: String in DISTRICTS:
		var n: int = await _sweep_district(id)
		if n < 0:
			return false
		visited += n
	print("QA slice: %d POIs triggered" % visited)
	for id2: String in DISTRICTS:
		for b: Variant in JU.a(WorldIndex.districts[id2] as Dictionary, "bodegas"):
			SceneRouter.goto_interior("bodega", JU.s(b as Dictionary, "id"), {"district": id2})
			await frames(6)
			if not check(get_tree().current_scene is Interior, "bodega %s did not open" % JU.s(b as Dictionary, "id")):
				return false
	for kind: String in ["plug", "pump_grip", "ink_needle"]:
		SceneRouter.goto_interior(kind, "bk_" + kind, {"district": "bk_bedstuy"})
		await frames(6)
		if not check(get_tree().current_scene is Interior, "%s did not open" % kind):
			return false
	# ---- Every fight: the court loads from the district, then the god-mode bot plays it out.
	for boss_id: String in BOSSES:
		var district: String = JU.s(DataDB.boss(boss_id), "district")
		SceneRouter.goto_district(district, {"kind": "court", "id": boss_id}, false)
		await frames(10)
		var d: District = get_tree().current_scene as District
		var court: Dictionary = {}
		for it: Dictionary in d.interact.items:
			if str(it["kind"]) == "court" and JU.s(it["data"] as Dictionary, "boss") == boss_id:
				court = it
		if not check(not court.is_empty(), "no court for %s in %s" % [boss_id, district]):
			return false
		DistrictActions.trigger(d, court)
		await frames(10)
		if not check(get_tree().current_scene is BossArena, "%s arena did not load" % boss_id):
			return false
		var r: Dictionary = BossSim.run(boss_id, 1, {"god": true, "max_s": 600, "seed": 31})
		print("QA slice: %s T1 %s in %.0fs (makes %d)" % [boss_id, r["result"], float(r["time_s"]), int((r["stats"] as Dictionary)["makes"])])
		if not check(str(r["result"]) == "victory", "%s not beaten: %s" % [boss_id, r["result"]]):
			return false
		BossArena.grant_rewards(boss_id, BossFactory.rewards(DataDB.boss(boss_id), 1))
	# ---- Pickup Challengers.
	for id3: String in DISTRICTS:
		for npc: Variant in JU.a(WorldIndex.districts[id3] as Dictionary, "npcs"):
			var ch: Dictionary = JU.dict(npc as Dictionary, "challenger")
			if ch.is_empty():
				continue
			var cr2: Dictionary = ChallengerDuel.run_sim(JU.f(ch, "skill", 0.5), 1, JU.i(ch, "tier_bonus"), {"max_s": 400, "seed": 5})
			print("QA slice: challenger %s -> %s %d-%d" % [JU.s(ch, "id"), cr2["result"], int(cr2["player"]), int(cr2["rival"])])
			if not check(str(cr2["result"]) != "timeout", "challenger %s never finished" % JU.s(ch, "id")):
				return false
	# ---- The Crown.
	if not check(GameState.has_crown("brooklyn"), "no Brooklyn Crown"):
		return false
	if not check(GameState.item_count("crown_brooklyn") == 1, "Crown item missing"):
		return false
	if not check(GameState.nickname != "", "no earned nickname"):
		return false
	if not check(TattooRules.slots() == 3, "Crown did not open a tattoo slot"):
		return false
	if not check(GameState.known_bag_moves.has("toll_booth"), "Toll Booth Bag Move not learned"):
		return false
	print("QA slice: Crown earned, nickname \"%s\", level %d, %d tokens, %d Rep" % [GameState.nickname, GameState.level, GameState.tokens, GameState.rep])
	return true


func _sweep_district(id: String) -> int:
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
				if not check(JU.s(data, "locked") != "" or WorldIndex.has_district(JU.s(data, "to")) or not JU.s(data, "to").begins_with("bk_"), "crossing to %s is broken" % JU.s(data, "to")):
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
