extends GutTest
## M8: creator options and names, start borough availability + tier map,
## earned nickname, tutorial tracking, new-game flow state.


func before_each() -> void:
	GameState.new_run("two_way", "brooklyn")


func test_creator_option_counts_match_spec_6_2() -> void:
	assert_eq(CreatorRules.values("skin").size(), 16, "16 skin swatches")
	assert_eq(CreatorRules.values("face_shape").size(), 5)
	assert_eq(CreatorRules.values("eye_shape").size(), 8)
	assert_eq(CreatorRules.values("eye_color").size(), 10)
	assert_eq(CreatorRules.values("brows").size(), 6)
	assert_eq(CreatorRules.values("nose").size(), 5)
	assert_eq(CreatorRules.values("mouth").size(), 5)
	assert_eq(CreatorRules.values("marks").size(), 6)
	assert_eq(CreatorRules.values("facial_hair").size(), 6)
	assert_eq(CreatorRules.values("hair_style").size(), 16)
	assert_eq(CreatorRules.values("hair_color").size(), 12)
	assert_eq(CreatorRules.values("voice").size(), 3)
	var h: Array = CreatorRules.values("height")
	assert_almost_eq(float(h[0]), 0.95, 0.001)
	assert_almost_eq(float(h[h.size() - 1]), 1.05, 0.001)


func test_cycle_wraps_both_ways() -> void:
	var p: Dictionary = CreatorRules.default_profile()
	p["face_shape"] = 0
	CreatorRules.cycle(p, "face_shape", -1)
	assert_eq(int(p["face_shape"]), 4)
	CreatorRules.cycle(p, "face_shape", 1)
	assert_eq(int(p["face_shape"]), 0)


func test_every_random_look_builds() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 9
	for _i: int in 12:
		var p: Dictionary = CreatorRules.randomize(rng)
		var rig: PuppetRig = CharacterBuilder.build(p)
		assert_not_null(rig)
		assert_true(CreatorRules.is_allowed(str(p["name"])), str(p["name"]))
		rig.free()


func test_names_and_profanity_filter() -> void:
	assert_eq(CreatorRules.compose_name("Lil'", "Handles"), "Lil' Handles")
	assert_eq(CreatorRules.compose_name("", "Glide"), "Glide")
	assert_true(CreatorRules.is_allowed("Big Static"))
	assert_true(CreatorRules.is_allowed("Cassidy"), "no false positive on 'ass' inside a word")
	assert_false(CreatorRules.is_allowed("ShitStorm"))
	assert_false(CreatorRules.is_allowed("sh1t"))
	assert_false(CreatorRules.is_allowed("big ass"))
	assert_false(CreatorRules.is_allowed("x"), "too short")
	assert_eq(CreatorRules.clean_name("  Dimes<>{}!! McGee the Third and More  "), "Dimes McGee the Th")


func test_start_boroughs_and_tier_map() -> void:
	assert_true(CreatorRules.start_available("brooklyn"))
	var prev: String = CreatorRules.tier_preview("brooklyn")
	assert_string_contains(prev, "Brooklyn  T1")
	assert_string_contains(prev, "Staten Island  T5")
	assert_string_contains(prev, "The Bronx  T4")
	assert_eq(FrontEndFlow.start_district("brooklyn"), "bk_bedstuy")
	assert_eq(FrontEndFlow.first_bodega("bk_bedstuy"), "bk_bodega_1")


func test_nickname_from_most_used_style() -> void:
	assert_eq(NicknameRules.pick({}), NicknameRules.FALLBACK)
	assert_eq(NicknameRules.pick({"ankle_breakers": 3, "posters": 5}), "Poster Child")
	assert_eq(NicknameRules.pick({"threes": 9, "strips": 2}), "Long Range")
	assert_eq(NicknameRules.pick({"ankle_breakers": 4, "posters": 4}), "Ankle Taker", "ties go to the first style")
	assert_eq(NicknameRules.award_if_first_crown(), "", "no Crown yet")
	GameState.counters = {"taunts": 7}
	GameState.award_crown("brooklyn")
	assert_eq(NicknameRules.award_if_first_crown(), "All Mouth")
	GameState.counters = {"posters": 70}
	GameState.award_crown("bronx")
	assert_eq(NicknameRules.award_if_first_crown(), "", "named once")
	assert_eq(GameState.nickname, "All Mouth")
	GameState.profile = {"name": "Lil' Knots"}
	assert_eq(NicknameRules.display_name(), "Lil' Knots \"All Mouth\"")


func test_tutorial_tracker_steps() -> void:
	var t: TutorialTracker = TutorialTracker.new(1)
	assert_eq(t.current_id(), "walk_up")
	t.mark("reach_court")
	t.mark("called_next")
	t.mark("moved")
	assert_eq(t.current_id(), "strike")
	t.feed({"type": "hit_resolved", "attacker": 1, "target": 5, "result": "hit"})
	t.feed({"type": "action_started", "actor": 1, "move": "crossover"})
	t.feed({"type": "hit_resolved", "attacker": 5, "target": 1, "result": "ankle_breaker"})
	t.feed({"type": "shot_made", "actor": 1, "hoop_kind": "regulation"})
	assert_eq(t.current_id(), "shoot", "only the crate hoop counts")
	t.feed({"type": "shot_made", "actor": 1, "hoop_kind": "crate"})
	t.feed({"type": "qw_used", "actor": 1})
	assert_false(t.tutorial_complete(), "strip still open (out of order is fine)")
	assert_eq(t.current_id(), "strip")
	t.feed({"type": "hit_resolved", "attacker": 1, "target": 5, "result": "strip"})
	assert_true(t.tutorial_complete())
	assert_eq(t.current_id(), "cameo")


func test_new_game_state() -> void:
	GameState.new_run("nobody", "brooklyn", {"name": "Rook"})
	assert_eq(str(GameState.profile["name"]), "Rook")
	assert_eq(GameState.stat("heart"), 9)
	assert_false(GameState.has_flag("prologue_done"))
