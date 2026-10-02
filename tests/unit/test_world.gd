extends GutTest
## M6: map lint, bindings, builder determinism, fast-travel rules, reveal
## radii, loot shift, navigation, shortcuts.


func before_each() -> void:
	GameState.new_run("two_way", "brooklyn")


func test_lint_all_maps() -> void:
	var ids: PackedStringArray = MapParser.list_maps()
	assert_gt(ids.size(), 0)
	for id: String in ids:
		var errs: PackedStringArray = MapLinter.lint(MapParser.load_map(id))
		assert_eq(errs.size(), 0, "%s: %s" % [id, errs])


func test_lint_catches_problems() -> void:
	var bad: MapData = MapParser.parse("bad", "#####\n#@.D#\n#..Q#\n####\n", {"bodegas": []})
	var errs: PackedStringArray = MapLinter.lint(bad)
	var joined: String = "\n".join(errs)
	assert_string_contains(joined, "row 3")
	var walled: MapData = MapParser.parse("walled", "#######\n#@.#..#\n#..#.S#\n#######\n", {"stations": [{"id": "x"}]})
	assert_string_contains("\n".join(MapLinter.lint(walled)), "unreachable")
	var counts: MapData = MapParser.parse("counts", "#####\n#@D.#\n#####\n", {"bodegas": []})
	assert_string_contains("\n".join(MapLinter.lint(counts)), "sidecar bodegas")


func test_binding_rule_row_major() -> void:
	var m: MapData = MapParser.load_map("bk_bedstuy")
	var first: Dictionary = m.bound("D", 0)
	var second: Dictionary = m.bound("D", 1)
	assert_eq(JU.s(first, "id"), "bk_bodega_1")
	assert_eq(JU.s(second, "id"), "bk_bodega_2")
	assert_lt(m.cells_of("D")[0].y, m.cells_of("D")[1].y, "row-major order")
	assert_eq(JU.s(m.bound(">", 0), "to"), "bk_dumbo")
	assert_eq(str(m.bound("M", 0)), "bk_stoop")


func _build(m: MapData) -> Dictionary:
	var w: SimWorld = SimWorld.new(1)
	var b: BallSystem = BallSystem.new(w)
	var root: Node3D = Node3D.new()
	var lay: Dictionary = BoroughBuilder.build(m, w, b, root)
	lay["_blocks"] = w.collision.blocks.size()
	root.free()
	w.dispose()
	return lay


func test_builder_determinism() -> void:
	var m: MapData = MapParser.load_map("bk_bedstuy")
	var a: Dictionary = _build(m)
	var b: Dictionary = _build(m)
	assert_eq(int(a["hash"]), int(b["hash"]), "same seed -> same geometry")
	var m2: MapData = MapParser.load_map("bk_bedstuy")
	m2.side["seed"] = 999
	var c: Dictionary = _build(m2)
	assert_ne(int(a["hash"]), int(c["hash"]), "different seed -> different geometry")


func test_builder_layout_contents() -> void:
	var lay: Dictionary = _build(MapParser.load_map("bk_bedstuy"))
	assert_eq((lay["bodegas"] as Array).size(), 2)
	assert_eq((lay["stations"] as Array).size(), 1)
	assert_eq((lay["shops"] as Array).size(), 3)
	assert_eq((lay["courts"] as Array).size(), 1)
	assert_eq((lay["crossings"] as Array).size(), 3)
	assert_eq((lay["boxes"] as Array).size(), 6)
	assert_eq((lay["tags"] as Array).size(), 10)
	assert_eq((lay["shortcuts"] as Array).size(), 2)
	assert_eq((lay["secrets"] as Array).size(), 1)
	assert_gt((lay["spawns"] as Array).size(), 8)
	assert_lt(int(lay["draw_groups"]), 1200, "draw-call budget (x2 for outlines < 2,500)")


func test_build_time_budget() -> void:
	var t0: int = Time.get_ticks_msec()
	_build(MapParser.load_map("bk_bedstuy"))
	assert_lt(Time.get_ticks_msec() - t0, 3000, "district build < 3 s")


func test_fast_travel_rules() -> void:
	var disc: PackedStringArray = PackedStringArray(["bk_st_bedstuy", "bx_st_mott"])
	assert_true(FastTravel.can_open_menu("bodega"))
	assert_true(FastTravel.can_open_menu("station"))
	assert_false(FastTravel.can_open_menu("street"))
	assert_true(FastTravel.can_travel("bodega", "bx_st_mott", disc))
	assert_false(FastTravel.can_travel("bodega", "qn_st_astoria", disc), "undiscovered")
	assert_false(FastTravel.can_travel("street", "bx_st_mott", disc), "not from the street")
	assert_false(FastTravel.can_travel("station", "bk_st_bedstuy", disc, "bk_st_bedstuy"), "already there")
	assert_false(FastTravel.can_travel("bodega", "city_st_x", PackedStringArray(["city_st_x"])), "City needs the Crown Pass")


func test_tap_in_discovers_and_reveals_streets() -> void:
	assert_true(FastTravel.tap_in("bk_st_bedstuy", "bk_bedstuy"))
	assert_false(FastTravel.tap_in("bk_st_bedstuy", "bk_bedstuy"), "only the first time")
	assert_true(GameState.discovered_stations.has("bk_st_bedstuy"))
	assert_true(MapReveal.streets_known("bk_bedstuy"))


func test_reveal_radii() -> void:
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(64 * 64)
	var r_walk: float = MapReveal.radius_tiles(MapReveal.WALK_RADIUS_M)
	assert_almost_eq(r_walk, 6.25, 0.0001, "25 m walking")
	MapReveal.reveal(mask, 64, 64, Vector2i(32, 32), r_walk)
	assert_true(MapReveal.is_revealed(mask, 64, Vector2i(38, 32)))
	assert_false(MapReveal.is_revealed(mask, 64, Vector2i(39, 32)))
	assert_true(MapReveal.is_revealed(mask, 64, Vector2i(36, 36)), "diagonal within 25 m")
	var walked: int = MapReveal.count(mask)
	assert_almost_eq(float(walked), PI * r_walk * r_walk, 12.0)
	MapReveal.reveal(mask, 64, 64, Vector2i(32, 32), MapReveal.radius_tiles(MapReveal.REST_RADIUS_M))
	assert_almost_eq(MapReveal.radius_tiles(MapReveal.REST_RADIUS_M), 20.0, 0.0001, "80 m resting")
	assert_true(MapReveal.is_revealed(mask, 64, Vector2i(52, 32)))
	assert_false(MapReveal.is_revealed(mask, 64, Vector2i(53, 32)))


func test_loot_odds_shift_by_tier() -> void:
	var t1: Dictionary = LootRoller.odds("retail", 1)
	assert_almost_eq(JU.f(t1, "common"), 70.0, 0.001)
	var t5: Dictionary = LootRoller.odds("retail", 5)
	assert_almost_eq(JU.f(t5, "common"), 50.0, 0.001, "20 points moved up")
	assert_almost_eq(JU.f(t5, "rare"), 25.0 + 12.0, 0.001)
	assert_almost_eq(JU.f(t5, "epic"), 5.0 + 6.0, 0.001)
	assert_almost_eq(JU.f(t5, "legendary"), 2.0, 0.001)
	var lim: Dictionary = LootRoller.odds("limited", 3)
	assert_almost_eq(JU.f(lim, "rare"), 50.0, 0.001, "limited shifts from rare")


func test_loot_roll_deterministic() -> void:
	var r1: RandomNumberGenerator = RandomNumberGenerator.new()
	r1.seed = 42
	var r2: RandomNumberGenerator = RandomNumberGenerator.new()
	r2.seed = 42
	assert_eq(LootRoller.roll("bk_retail", 2, r1), LootRoller.roll("bk_retail", 2, r2))
	var g: Dictionary = LootRoller.roll("bk_grail", 1, r1)
	assert_eq(str(g["rarity"]), "grail")


func test_nav_paths_reach_bodegas() -> void:
	var m: MapData = MapParser.load_map("bk_bedstuy")
	var w: SimWorld = SimWorld.new(1)
	var root: Node3D = Node3D.new()
	var lay: Dictionary = BoroughBuilder.build(m, w, BallSystem.new(w), root)
	var nav: NavGrid = NavGrid.create(m, w.collision)
	nav.bake()
	for b: Variant in (lay["bodegas"] as Array):
		var p: PackedVector2Array = nav.path(lay["start"], (b as Dictionary)["door"])
		assert_gt(p.size(), 1, "path to %s" % JU.s(b as Dictionary, "id"))
	root.free()
	w.dispose()


func test_shortcut_blocks_until_opened() -> void:
	var m: MapData = MapParser.load_map("bk_bedstuy")
	var w: SimWorld = SimWorld.new(1)
	var root: Node3D = Node3D.new()
	var lay: Dictionary = BoroughBuilder.build(m, w, BallSystem.new(w), root)
	var sc: Dictionary = (lay["shortcuts"] as Array)[0]
	var p: Vector3 = sc["pos"]
	assert_true(w.collision.blocked(p + Vector3(0, 0.2, 0), 0.35), "closed")
	w.collision.remove_tag("shortcut:" + JU.s(sc, "id"))
	assert_false(w.collision.blocked(p + Vector3(0, 0.2, 0), 0.35), "open")
	root.free()
	w.dispose()


func test_interactables_nearest() -> void:
	var it: Interactables = Interactables.new()
	it.add("a", "box", Vector3(0, 0, 0), "A", {}, 2.0)
	it.add("b", "box", Vector3(1.5, 0, 0), "B", {}, 2.0)
	assert_eq(str(it.nearest(Vector3(1.2, 0, 0))["id"]), "b")
	assert_true(it.nearest(Vector3(9, 0, 0)).is_empty())
	it.remove("b")
	assert_eq(str(it.nearest(Vector3(1.2, 0, 0))["id"]), "a")


func test_bodega_rest_and_punch_card() -> void:
	GameState.quarter_waters = 0
	BodegaService.rest("bk_bodega_1")
	assert_eq(GameState.quarter_waters, GameState.quarter_water_max)
	assert_eq(GameState.respawn_bodega, "bk_bodega_1")
	assert_true(GameState.has_flag("pet_tony"))
	GameState.add_item("punch_card", 1)
	var before: int = GameState.quarter_water_max
	assert_true(BodegaService.punch_card_trade())
	assert_eq(GameState.quarter_water_max, before + 1)
	assert_false(BodegaService.punch_card_trade(), "no cards left")
