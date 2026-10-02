extends QAScript
## QA full run (spec §16 M12): from each of the five starting boroughs, a new
## game reaches the Garden with debug skips (Crowns and ticket stubs granted),
## the Garden gate opens from Midtown, the arena loads, the god-mode bot beats
## Midnight, and an ending is chosen (alternating Daybreak / Overtime).


func run() -> bool:
	await frames(3)
	var first: bool = true
	for start: String in DataSchemas.BOROUGHS:
		GameState.new_run("two_way", start, {"name": "QA " + start})
		GameState.set_flag("prologue_done")
		SceneRouter.goto_district(FrontEndFlow.start_district(start), {}, false)
		await frames(8)
		if not check(get_tree().current_scene is District, "%s: start district did not load" % start):
			return false
		## Debug skips: the Crowns and the five landmark stubs.
		for b: String in DataSchemas.BOROUGHS:
			GameState.award_crown(b)
		for lm: String in ["city_chainlink", "city_suspension", "city_primetime", "city_gator", "city_gargoyle"]:
			GameState.garden_tickets.append(lm)
		SceneRouter.goto_district("city_midtown", {}, false)
		await frames(8)
		var d: District = get_tree().current_scene as District
		var court: Dictionary = {}
		for it: Dictionary in d.interact.items:
			if str(it["kind"]) == "court" and JU.s(it["data"] as Dictionary, "boss") == "fin_midnight":
				court = it
		if not check(not court.is_empty(), "no Garden entrance in Midtown"):
			return false
		DistrictActions.trigger(d, court)
		await frames(10)
		if not check(get_tree().current_scene is BossArena, "%s: the Garden did not load" % start):
			return false
		var arena: BossArena = get_tree().current_scene as BossArena
		if not check(arena.tier == 7, "Garden tier %d" % arena.tier):
			return false
		var opts: Dictionary = {"god": true, "max_s": 900, "seed": 2}
		if not first:
			opts["start_phase"] = 3
		var r: Dictionary = BossSim.run("fin_midnight", 7, opts)
		print("QA full run from %s: Midnight %s in %.0fs" % [start, r["result"], float(r["time_s"])])
		if not check(str(r["result"]) == "victory", "%s: Midnight not beaten" % start):
			return false
		BossArena.grant_rewards("fin_midnight", BossFactory.rewards(DataDB.boss("fin_midnight"), 7))
		var daybreak: bool = DataSchemas.BOROUGHS.find(start) % 2 == 0
		arena.choose_ending("run" if daybreak else "stop")
		for _i: int in 300:
			await frames(1)
			if get_tree().current_scene is District:
				break
		if not check(get_tree().current_scene is District, "%s: credits did not hand back to the world" % start):
			return false
		if daybreak:
			if not check(GameState.has_flag("ending_daybreak") and GameState.has_flag("dawn"), "%s: Daybreak flags" % start):
				return false
		elif not check(GameState.has_flag("ending_overtime") and GameState.ng_cycle == 1 and GameState.item_count("crown_midnight") == 1, "%s: Overtime -> NG+" % start):
			return false
		first = false
	return true
