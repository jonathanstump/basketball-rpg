extends QAScript
## QA 5x5 tier matrix (spec §16 M10): start a run from each borough, land in
## its start district at Tier 1, then in every borough spawn a common and
## the King and check their Heart against the tier multipliers.

const KINGS: Dictionary = {"bronx": "bx_boom", "brooklyn": "bk_toll", "queens": "qn_atlas", "staten_island": "si_heap", "uptown": "up_highrise"}


func run() -> bool:
	await frames(3)
	for start: String in DataSchemas.BOROUGHS:
		GameState.new_run("two_way", start, {"name": "QA"})
		GameState.set_flag("prologue_done")
		var district: String = FrontEndFlow.start_district(start)
		if not check(WorldIndex.district_borough(district) == start, "%s has its own start district (%s)" % [start, district]):
			return false
		SceneRouter.goto_district(district, {}, false)
		await frames(8)
		var d: District = get_tree().current_scene as District
		if not check(d != null and d.tier == 1, "start %s: home district tier %s" % [start, d.tier if d != null else -1]):
			return false
		var row: PackedStringArray = PackedStringArray()
		for b: String in DataSchemas.BOROUGHS:
			var t: int = TierManager.tier_of(b)
			var sim: CombatSim = CombatSim.new()
			var common: SimActor = EnemyFactory.spawn(sim.world, sim.combat, sim.balls, "ball_hog", Vector3.ZERO, t)
			var want_c: float = JU.f(DataDB.enemy("ball_hog"), "hp") * TierManager.mult("hp", t)
			var king: SimActor = BossFactory.spawn(sim.world, sim.combat, sim.balls, str(KINGS[b]), Vector3(0, 0, -6), t, null)
			var want_k: float = JU.f(JU.dict(DataDB.boss(str(KINGS[b])), "base"), "hp") * TierManager.mult("hp", t)
			var ok: bool = absf(common.hp_max - want_c) < 0.5 and absf(king.hp_max - want_k) < 0.5
			sim.dispose()
			if not check(ok, "start %s, %s T%d: common %.0f/%.0f, king %.0f/%.0f" % [start, b, t, common.hp_max, want_c, king.hp_max, want_k]):
				return false
			row.append("%s T%d" % [b, t])
		print("QA tiers from %s: %s" % [start, ", ".join(row)])
	return true
