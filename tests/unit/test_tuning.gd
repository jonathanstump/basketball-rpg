extends GutTest
## M0: tuning values load with spec starting values.


func test_player_tuning() -> void:
	var p: Dictionary = DataDB.tuning("player")
	assert_almost_eq(JU.f(p, "walk_speed"), 3.5, 0.001)
	assert_almost_eq(JU.f(p, "sprint_speed"), 8.5, 0.001)
	assert_eq(JU.i(p, "input_buffer_frames"), 8)
	assert_eq(JU.i(p, "coyote_frames"), 5)
	assert_eq(JU.i(JU.dict(p, "quarter_water"), "start_charges"), 3)


func test_shooting_tuning() -> void:
	var s: Dictionary = DataDB.tuning("shooting")
	assert_almost_eq(JU.f(s, "center"), 0.82, 0.0001)
	assert_almost_eq(JU.f(JU.dict(s, "base_widths"), "perfect"), 0.05, 0.0001)
	assert_almost_eq(JU.f(s, "perfect_cap"), 0.25, 0.0001)


func test_boss_and_economy_tuning() -> void:
	var b: Dictionary = DataDB.tuning("bosses")
	assert_eq(JU.i(JU.dict(b, "mini"), "hp"), 1800)
	assert_eq(JU.i(JU.dict(b, "king"), "hp"), 3200)
	var e: Dictionary = DataDB.tuning("economy")
	assert_almost_eq(JU.f(JU.dict(JU.dict(e, "buckets"), "poster"), "pct"), 0.15, 0.0001)
	assert_eq(JU.i(JU.dict(e, "level_curve"), "c"), 150)


func test_all_tuning_files_present() -> void:
	for n: String in ["player", "stats", "combat", "composure", "shooting", "economy", "bosses", "ai"]:
		assert_false(DataDB.tuning(n).is_empty(), "tuning/%s" % n)
