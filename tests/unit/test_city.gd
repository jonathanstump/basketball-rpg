extends GutTest
## M11: Crown Pass gating, Downtown + Midtown, City crews, five landmark
## bosses at Tier 6 (Chain Link, Suspension, Prime Time, The Gator, The
## Gargoyle) and their Garden Ticket stubs.

const LANDMARKS: PackedStringArray = ["city_chainlink", "city_suspension", "city_primetime", "city_gator", "city_gargoyle"]


func before_each() -> void:
	GameState.new_run("two_way", "brooklyn")


func _duel(boss_id: String) -> Dictionary:
	var sim: CombatSim = CombatSim.new(3)
	sim.combat.damage.hitstop_enabled = false
	var data: Dictionary = DataDB.boss(boss_id)
	var lay: Dictionary = ArenaBuilder.build(sim.world, sim.balls, data, null)
	var p: Hooper = sim.hooper(lay["player_start"])
	var boss: SimActor = BossFactory.spawn(sim.world, sim.combat, sim.balls, boss_id, lay["boss_spot"], 6, lay["hoop"])
	var ctl: DuelController = DuelController.new(sim.world, sim.balls, sim.combat, boss, p.actor, lay["hoop"], data, lay)
	ctl.start()
	return {"sim": sim, "p": p, "boss": boss, "ctl": ctl, "brain": boss.controller}


func _run(d: Dictionary, frames: int) -> void:
	for _i: int in frames:
		(d["sim"] as CombatSim).run(1)
		(d["ctl"] as DuelController).step()


func test_landmark_data_and_tier() -> void:
	assert_eq(TierManager.tier_of(TierMath.CITY), 6)
	for id: String in LANDMARKS:
		var b: Dictionary = DataDB.boss(id)
		assert_eq(JU.s(b, "kind"), "landmark", id)
		assert_eq(BossGating.phase_count(b, 6), 2, "%s: Tier 6 has everything" % id)
		for ph: Variant in JU.a(b, "phases"):
			for m: Variant in JU.a(ph as Dictionary, "moves"):
				assert_false(DataDB.move(id, str(m)).is_empty(), "%s move %s" % [id, m])
		for d: String in JU.strs(b, "drops"):
			assert_ne(DataDB.catalog_of(d), "", "%s drop %s" % [id, d])
		assert_eq(str(BossFactory.rewards(b, 6)["garden_ticket"]), id)


func test_landmark_sims_t6() -> void:
	for id: String in LANDMARKS:
		var r: Dictionary = BossSim.run(id, 6, {"god": true, "max_s": 900, "seed": 2})
		gut.p("SIM %s T6: %s in %.0fs" % [id, r["result"], float(r["time_s"])])
		assert_eq(str(r["result"]), "victory", "%s T6: %s" % [id, r])
		assert_true((r["phases_seen"] as Array).has(2))


func test_crown_pass_gating() -> void:
	var gated: int = 0
	for id: Variant in WorldIndex.all().keys():
		if str(id).begins_with("city_"):
			continue
		for c: Variant in JU.a(WorldIndex.all()[id] as Dictionary, "crossings"):
			if JU.s(c as Dictionary, "to").begins_with("city_"):
				gated += 1
				assert_eq(JU.s(c as Dictionary, "locked"), "crown_pass")
	assert_eq(gated, 4, "Uptown gate, Brooklyn bridge, Staten Island ferry, Queens tunnel")
	var st: PackedStringArray = ["bk_st_bedstuy", "city_st_midtown"]
	assert_false(GameState.has_crown_pass())
	assert_false(FastTravel.can_travel("station", "city_st_midtown", st, "bk_st_bedstuy"), "no City trains without the Pass")
	for b: String in DataSchemas.BOROUGHS:
		GameState.award_crown(b)
	assert_true(GameState.has_crown_pass())
	assert_true(FastTravel.can_travel("station", "city_st_midtown", st, "bk_st_bedstuy"))


func test_city_districts() -> void:
	var cats: PackedStringArray = PackedStringArray()
	var landmarks: PackedStringArray = PackedStringArray()
	for id: String in ["city_downtown", "city_midtown"]:
		var m: MapData = MapParser.load_map(id)
		assert_eq(MapLinter.lint(m).size(), 0, id)
		assert_eq(m.borough(), "city")
		for b: Variant in JU.a(m.side, "bodegas"):
			cats.append(JU.s(b as Dictionary, "cat"))
		for x: String in JU.strs(JU.dict(m.side, "fights"), "X"):
			if JU.s(DataDB.boss(x), "kind") == "landmark":
				landmarks.append(x)
		for e: Variant in JU.strs(JU.dict(m.side, "spawns"), "e"):
			assert_true(str(e) in ["suit", "big_head_mascot", "tourist"], "City crews: %s" % e)
	cats.sort()
	assert_eq(cats, PackedStringArray(["Broadway", "Chairman", "Lex", "Penny"]))
	landmarks.sort()
	var want: PackedStringArray = LANDMARKS.duplicate()
	want.sort()
	assert_eq(landmarks, want, "all five landmark courts")


func test_garden_ticket_stubs() -> void:
	for id: String in LANDMARKS:
		BossArena.grant_rewards(id, BossFactory.rewards(DataDB.boss(id), 6))
	assert_eq(GameState.garden_tickets.size(), 5)
	BossArena.grant_rewards("city_gator", BossFactory.rewards(DataDB.boss("city_gator"), 6))
	assert_eq(GameState.garden_tickets.size(), 5, "one stub per landmark")


func test_chainlink_cage_shrinks_and_no_call() -> void:
	var d: Dictionary = _duel("city_chainlink")
	var brain: BossBrain = d["brain"]
	var g: ChainLinkGimmick = brain.gimmick as ChainLinkGimmick
	_run(d, 90)
	var h0: Vector2 = g.cage_half()
	g.shrink_s = 0.01
	_run(d, 2)
	assert_almost_eq(h0.x - g.cage_half().x, ChainLinkGimmick.STEP_M, 0.001, "walls move in 1.5 m")
	brain.runner.interrupt()
	(d["sim"] as CombatSim).world.emit("hit_resolved", {"attacker": (d["p"] as Hooper).actor.id, "target": brain.actor.id, "result": "strip", "move": "reach_in"})
	assert_eq(JU.s(brain.runner.move, "id"), "no_call")
	(d["sim"] as CombatSim).dispose()


func test_suspension_snaps_anchor() -> void:
	var d: Dictionary = _duel("city_suspension")
	var brain: BossBrain = d["brain"]
	var g: SuspensionGimmick = brain.gimmick as SuspensionGimmick
	var p: SimActor = (d["p"] as Hooper).actor
	brain.target = p
	p.pos = g.anchors[0] + Vector3(0.5, 0, 0)
	var c0: float = brain.actor.composure.value
	(d["sim"] as CombatSim).world.emit("action_started", {"actor": p.id, "move": "pound"})
	assert_true(g.snapped[0], "strike at an anchor snaps the cable")
	assert_gt(brain.actor.composure.value, c0)
	(d["sim"] as CombatSim).dispose()


func test_primetime_records_and_flashes() -> void:
	var d: Dictionary = _duel("city_primetime")
	var brain: BossBrain = d["brain"]
	var g: PrimeTimeGimmick = brain.gimmick as PrimeTimeGimmick
	var p: SimActor = (d["p"] as Hooper).actor
	brain.target = p
	for mvid: String in ["pound", "crossover", "pound", "euro_step", "stepback", "pound"]:
		(d["sim"] as CombatSim).world.emit("action_started", {"actor": p.id, "move": mvid})
	assert_eq(g.recorded.size(), 5, "last 5 moves")
	g.flash_s = 0.01
	var blinded: bool = false
	for _i: int in 40:
		_run(d, 1)
		blinded = blinded or StatusEffects.has(p, "blind")
	assert_true(blinded, "tourist flash after the cue")
	(d["sim"] as CombatSim).world.emit("duel_phase_changed", {"phase": 2})
	assert_eq(g.split.parts.size(), 2, "three channel bodies")
	(d["sim"] as CombatSim).dispose()


func test_gator_flood_and_gargoyle_wind() -> void:
	var d: Dictionary = _duel("city_gator")
	var g: GatorGimmick = (d["brain"] as BossBrain).gimmick as GatorGimmick
	g.high = true
	assert_true(g.in_water(Vector3.ZERO))
	assert_false(g.in_water(Vector3(g.half.x - 0.5, 0, 0)), "platform edges are dry")
	(d["sim"] as CombatSim).dispose()
	var d2: Dictionary = _duel("city_gargoyle")
	var gg: GargoyleGimmick = (d2["brain"] as BossBrain).gimmick as GargoyleGimmick
	var p: SimActor = (d2["p"] as Hooper).actor
	(d2["brain"] as BossBrain).target = p
	_run(d2, 90)
	gg.gust_in = 0.01
	_run(d2, 3)
	assert_ne(float(p.flags.get("wind_drift", 0.0)), 0.0, "gusts curve your shots")
	(d2["sim"] as CombatSim).dispose()
