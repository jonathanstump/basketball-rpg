extends GutTest
## M10: crossings, cross-borough fast travel, tiers for all five starts,
## questlines (Pops, Grail Hunt, Lost Cat, Deuce), Pizza Rat King, NG+.

const KINGS: Dictionary = {"bronx": "bx_boom", "brooklyn": "bk_toll", "queens": "qn_atlas", "staten_island": "si_heap", "uptown": "up_highrise"}


func before_each() -> void:
	GameState.new_run("two_way", "brooklyn")


func test_every_crossing_is_live() -> void:
	var n: int = 0
	for id: Variant in WorldIndex.all().keys():
		for c: Variant in JU.a(WorldIndex.all()[id] as Dictionary, "crossings"):
			var cd: Dictionary = c
			var to: String = JU.s(cd, "to")
			n += 1
			if to.begins_with("city_") and not str(id).begins_with("city_"):
				assert_eq(JU.s(cd, "locked"), "crown_pass", "%s -> %s is Crown Pass gated" % [id, to])
				continue
			assert_true(WorldIndex.has_district(to), "%s -> %s exists" % [id, to])
			var back: bool = false
			for c2: Variant in JU.a(WorldIndex.all()[to] as Dictionary, "crossings"):
				back = back or JU.s(c2 as Dictionary, "to") == str(id)
			assert_true(back, "%s <-> %s both ways" % [id, to])
	assert_gt(n, 30)
	var pairs: Array = [["bx_mott_haven", "up_harlem"], ["bx_west_farms", "qn_flushing"], ["qn_astoria", "up_harlem"], ["bk_bedstuy", "qn_roosevelt"], ["bk_coney", "si_narrows"]]
	for p: Variant in pairs:
		var a: String = str((p as Array)[0])
		var found: bool = false
		for c3: Variant in JU.a(WorldIndex.all()[a] as Dictionary, "crossings"):
			found = found or JU.s(c3 as Dictionary, "to") == str((p as Array)[1])
		assert_true(found, "spec §4.2 crossing %s" % str(p))


func test_cross_borough_fast_travel() -> void:
	var st: PackedStringArray = ["bk_st_bedstuy", "bx_st_mott_haven", "qn_st_astoria", "si_st_narrows", "up_st_mecca"]
	for a: String in st:
		for b: String in st:
			if a != b:
				assert_true(FastTravel.can_travel("station", b, st, a), "%s -> %s" % [a, b])
	assert_eq(FastTravel.station_district("up_st_mecca"), "up_mecca")


func test_tier_matrix_all_five_starts() -> void:
	var table: Dictionary = JU.dict(DataDB.tiers(), "start_tiers")
	for start: String in DataSchemas.BOROUGHS:
		GameState.new_run("two_way", start)
		assert_true(CreatorRules.start_available(start), "%s is a playable start" % start)
		for b: String in DataSchemas.BOROUGHS:
			assert_eq(TierManager.tier_of(b), int(JU.dict(table, start)[b]), "start %s: %s" % [start, b])
		assert_eq(TierManager.tier_of(b_or_city()), 6)


func b_or_city() -> String:
	return TierMath.CITY


func test_pops_lessons_one_per_crown() -> void:
	assert_false(Questlines.pops_lesson_ready())
	GameState.award_crown("brooklyn")
	assert_true(Questlines.pops_lesson_ready())
	assert_eq(Questlines.take_pops_lesson(), "self_oop")
	assert_false(Questlines.pops_lesson_ready(), "one per Crown")
	for b: String in ["bronx", "queens", "staten_island", "uptown"]:
		GameState.award_crown(b)
	var learned: PackedStringArray = PackedStringArray()
	while Questlines.pops_lesson_ready():
		learned.append(Questlines.take_pops_lesson())
	assert_eq(learned, PackedStringArray(["euro_glide", "rainbow_lob", "bass_drop", "tunnel"]))
	assert_true(GameState.has_flag("pops_one_more_run"), "then: one more run")


func test_grail_hunt() -> void:
	for _i: int in 4:
		GameState.bump_counter("grails")
	assert_false(Questlines.grail_reward_ready())
	GameState.bump_counter("grails")
	assert_true(Questlines.claim_grail_reward())
	assert_eq(GameState.item_count("kicks_golden_hour"), 1)
	assert_false(Questlines.claim_grail_reward(), "once")
	var grail_pools: int = 0
	for id: Variant in WorldIndex.all().keys():
		for p: Variant in JU.a(JU.dict(WorldIndex.all()[id] as Dictionary, "loot"), "$"):
			if JU.s(LootRoller.pool(str(p)), "tier") == "grail":
				grail_pools += 1
	assert_eq(grail_pools, 5, "one Grail box per borough")


func test_lost_cat() -> void:
	assert_false(Questlines.maybe_start_lost_cat("bk_bodega_1"), "needs a Crown first")
	GameState.award_crown("brooklyn")
	assert_true(Questlines.maybe_start_lost_cat("bk_bodega_1"))
	var lc: Dictionary = Questlines.lost_cat()
	assert_eq(JU.s(lc, "cat"), "Tony")
	assert_ne(JU.s(lc, "district"), "bk_bedstuy", "hiding across the borough")
	assert_eq(WorldIndex.district_borough(JU.s(lc, "district")), "brooklyn")
	var lay: Dictionary = {"start": Vector3.ZERO, "stations": [], "npcs": []}
	DistrictBindings._quest_extras(MapParser.load_map(JU.s(lc, "district")), lay)
	assert_true(lay.has("lost_cat"), "the cat is placed in that district")
	assert_true(Questlines.find_lost_cat())
	assert_eq(GameState.item_count("flash_nine_lives"), 1)
	assert_false(Questlines.maybe_start_lost_cat("bk_bodega_2"), "once per run")


func test_deuce_duels_one_and_two() -> void:
	assert_eq(Questlines.next_deuce(), 0)
	GameState.defeated_bosses.append("bk_stoop")
	assert_eq(Questlines.next_deuce(), 1, "after your first mini-boss")
	GameState.set_flag("beat_challenger_deuce_1")
	assert_eq(Questlines.next_deuce(), 0)
	for b: String in ["brooklyn", "bronx", "queens"]:
		GameState.award_crown(b)
	assert_eq(Questlines.next_deuce(), 2, "after your third Crown")
	var ch: Dictionary = Questlines.deuce_challenger(2)
	assert_eq(JU.s(ch, "drop"), "headband_deuce")
	var r: Dictionary = ChallengerDuel.run_sim(JU.f(ch, "skill"), 2, JU.i(ch, "tier_bonus"), {"points": JU.i(ch, "points"), "max_s": 500, "seed": 4})
	assert_ne(str(r["result"]), "timeout", "Deuce duel resolves: %s" % r)


func test_deuce_appears_in_the_district() -> void:
	GameState.defeated_bosses.append("bk_stoop")
	var lay: Dictionary = {"start": Vector3.ZERO, "stations": [], "npcs": []}
	DistrictBindings._quest_extras(MapParser.load_map("bk_coney"), lay)
	var found: bool = false
	for n: Variant in JU.a(lay, "npcs"):
		found = found or JU.s(n as Dictionary, "id") == "npc_deuce_1"
	assert_true(found)


func test_pizza_rat_king() -> void:
	var b: Dictionary = DataDB.boss("opt_ratking")
	assert_false(b.is_empty())
	assert_eq(JU.strs(b, "tier_regions"), PackedStringArray(["brooklyn", "queens"]))
	var tunnel: bool = false
	for sp: Variant in JU.a(WorldIndex.all()["bk_bedstuy"] as Dictionary, "specials"):
		tunnel = tunnel or JU.s(sp as Dictionary, "boss") == "opt_ratking"
	assert_true(tunnel, "hidden tunnel in Bed-Stuy")
	for t: int in [1, 5]:
		var r: Dictionary = BossSim.run("opt_ratking", t, {"god": true, "max_s": 900, "seed": 2})
		assert_eq(str(r["result"]), "victory", "Rat King T%d: %s" % [t, r])


func test_ng_plus_shift_and_cap() -> void:
	GameState.new_run("two_way", "bronx")
	GameState.award_crown("bronx")
	GameState.tattoos.append_array(["tattoo_rose", "tattoo_claw", "tattoo_mic"])
	GameState.stats["jumper"] = 30
	GameState.add_item("kicks_bronx_3", 1)
	GameState.defeated_bosses.append("bx_boom")
	GameState.start_ng_plus()
	assert_eq(GameState.ng_cycle, 1)
	assert_eq(TierManager.tier_of("bronx"), 3, "+2")
	assert_eq(TierManager.tier_of("staten_island"), 7, "5 + 2 = 7")
	assert_eq(TierManager.tier_of(TierMath.CITY), 7, "City 6 + 2 caps at 7")
	assert_almost_eq(TierManager.mult("hp", 3), TierMath.multiplier(DataDB.tiers(), "hp", 3, 0) * 1.3, 0.001, "x1.3 per cycle")
	assert_true(GameState.crowns.is_empty(), "Crowns reset")
	assert_true(GameState.defeated_bosses.is_empty())
	assert_eq(GameState.stat("jumper"), 30, "stats kept")
	assert_eq(GameState.item_count("kicks_bronx_3"), 1, "gear kept")
	assert_eq(GameState.tattoos.size(), 3, "tattoos kept")
	assert_eq(TattooRules.slots(), 3, "inked slots stay open")
	GameState.start_ng_plus()
	GameState.start_ng_plus()
	assert_eq(TierManager.tier_of("bronx"), 7, "cap 7")
	assert_almost_eq(TierManager.mult("hp", 7), TierMath.multiplier(DataDB.tiers(), "hp", 7, 0) * pow(1.3, 3), 0.01)
