extends GutTest
## M8: Brooklyn's three districts carry everything in spec §4.4, and Pickup
## Challenger runs follow their rules.

const DISTRICTS: PackedStringArray = ["bk_bedstuy", "bk_coney", "bk_dumbo"]


func before_each() -> void:
	GameState.new_run("two_way", "brooklyn")


func _count(ch: String) -> int:
	var n: int = 0
	for id: String in DISTRICTS:
		n += MapParser.load_map(id).cells_of(ch).size()
	return n


func test_brooklyn_contents_per_spec_4_4() -> void:
	for id: String in DISTRICTS:
		var m: MapData = MapParser.load_map(id)
		assert_not_null(m, id)
		assert_eq(MapLinter.lint(m).size(), 0, "%s lints clean: %s" % [id, MapLinter.lint(m)])
		assert_eq(m.cells_of("S").size(), 1, "%s: one station" % id)
		assert_gte(JU.a(m.side, "graffiti").size(), 10, "%s: ~10 graffiti tags" % id)
		assert_gte(m.cells_of("^").size(), 2, "%s: a secret" % id)
	assert_eq(_count("D"), 4, "4 bodegas")
	var cats: PackedStringArray = PackedStringArray()
	for id2: String in DISTRICTS:
		for b: Variant in JU.a(MapParser.load_map(id2).side, "bodegas"):
			cats.append(JU.s(b as Dictionary, "cat"))
	cats.sort()
	assert_eq(cats, PackedStringArray(["Bagel", "Brownie", "Mrs. Whiskers", "Tony"]))
	assert_eq(_count("K") + _count("G") + _count("I"), 3, "Plug, Pump & Grip, Ink & Needle")
	assert_eq(_count("M"), 2, "two mini-boss courts")
	assert_eq(_count("X"), 1, "one King court")
	assert_between(_count("$"), 13, 17, "12-16 shoeboxes + the Grail box")
	assert_between(_count("%"), 2, 3, "2-3 Bootlegs")
	assert_between(_count("w"), 2, 3, "2-3 Wire Kicks")
	assert_gte(_count("h"), 6, "6+ crate hoops")
	assert_gte(_count("L") + _count("g"), 3, "3+ one-way shortcuts")
	var pools: Array = []
	for id3: String in DISTRICTS:
		pools.append_array(JU.a(JU.dict(MapParser.load_map(id3).side, "loot"), "$"))
	assert_eq(pools.count("bk_grail"), 1, "one Grail box")
	var extras: Array = []
	for p: Variant in pools:
		extras.append_array(JU.strs(LootRoller.pool(str(p)), "extra"))
	assert_between(extras.filter(func(x: Variant) -> bool: return str(x).begins_with("mixtape_")).size(), 1, 2, "1-2 Mixtapes")
	assert_between(extras.count("punch_card"), 1, 2, "1-2 Punch Cards")
	assert_between(extras.count("sugar_rush"), 1, 2, "1-2 Sugar Rush")
	var flash: int = extras.filter(func(x: Variant) -> bool: return str(x).begins_with("flash_")).size()
	assert_between(flash + 1, 2, 3, "2-3 flash sheets (incl. the Barker's)")
	var challengers: int = 0
	for id4: String in DISTRICTS:
		for n: Variant in JU.a(MapParser.load_map(id4).side, "npcs"):
			if not JU.dict(n as Dictionary, "challenger").is_empty():
				challengers += 1
	assert_gte(challengers, 2, "2 Pickup Challengers")


func test_crossings_link_back() -> void:
	for id: String in DISTRICTS:
		for c: Variant in JU.a(MapParser.load_map(id).side, "crossings"):
			var to: String = JU.s(c as Dictionary, "to")
			if to.begins_with("bk_"):
				var back: bool = false
				for c2: Variant in JU.a(MapParser.load_map(to).side, "crossings"):
					back = back or JU.s(c2 as Dictionary, "to") == id
				assert_true(back, "%s <-> %s" % [id, to])
	var dumbo: Array = JU.a(MapParser.load_map("bk_dumbo").side, "crossings")
	assert_true(dumbo.any(func(c: Variant) -> bool: return JU.s(c as Dictionary, "locked") == "crown_pass"), "the old bridge into the City is locked")


func test_extra_loot_always_drops() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var r: Dictionary = LootRoller.roll("bk_punch", 1, rng)
	assert_true((r["items"] as PackedStringArray).has("punch_card"))


func test_challenger_points_and_check() -> void:
	assert_eq(ChallengerDuel.points_for("mid"), 2)
	assert_eq(ChallengerDuel.points_for("close"), 2)
	assert_eq(ChallengerDuel.points_for("three"), 3)
	assert_eq(ChallengerDuel.points_for("deep"), 3)
	var sim: CombatSim = CombatSim.new()
	var lay: Dictionary = ArenaBuilder.build(sim.world, sim.balls, ChallengerDuel.court_data("brooklyn"), null)
	var p: Hooper = sim.hooper(lay["top_of_key"])
	var r: Hooper = sim.hooper(lay["boss_spot"], {}, false, 1)
	var hoop: SimHoop = lay["hoop"]
	var duel: ChallengerDuel = ChallengerDuel.new(sim.world, sim.balls, p.actor, r.actor, hoop, lay["top_of_key"], 7)
	sim.world.emit("shot_made", {"actor": r.actor.id, "hoop": hoop.id, "zone": "three"})
	assert_eq(int(duel.score[r.actor.id]), 3)
	assert_eq(r.actor.pos, lay["top_of_key"] as Vector3, "make it take it: scorer checks up top")
	sim.world.emit("shot_made", {"actor": p.actor.id, "hoop": hoop.id, "zone": "mid"})
	sim.world.emit("shot_made", {"actor": p.actor.id, "hoop": hoop.id, "zone": "deep"})
	assert_eq(duel.result, "")
	sim.world.emit("shot_made", {"actor": p.actor.id, "hoop": hoop.id, "zone": "mid"})
	assert_eq(duel.result, "victory", "first to 7")
	sim.dispose()


func test_challenger_low_heart_loses_not_dies() -> void:
	var sim: CombatSim = CombatSim.new()
	var lay: Dictionary = ArenaBuilder.build(sim.world, sim.balls, ChallengerDuel.court_data("brooklyn"), null)
	var p: Hooper = sim.hooper(lay["top_of_key"])
	var r: Hooper = sim.hooper(lay["boss_spot"], {}, false, 1)
	var duel: ChallengerDuel = ChallengerDuel.new(sim.world, sim.balls, p.actor, r.actor, lay["hoop"], lay["top_of_key"])
	sim.combat.damage.apply_raw(p.actor, 99999.0)
	duel.step()
	assert_true(p.actor.alive, "cannot die in a pickup run")
	assert_eq(duel.result, "defeat")
	sim.dispose()


func test_challenger_sims_finish() -> void:
	var easy: Dictionary = ChallengerDuel.run_sim(0.4, 1, 0, {"max_s": 400, "seed": 3})
	gut.p("CHALLENGER easy: %s" % easy)
	assert_ne(str(easy["result"]), "timeout", "a run finishes: %s" % easy)
	assert_gt(int(easy["player"]) + int(easy["rival"]), 0, "somebody scored")
