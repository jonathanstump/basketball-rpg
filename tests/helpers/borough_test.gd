class_name BoroughTest
extends GutTest
## Shared checks for a borough milestone (spec §16 M9a–d): boss data is
## complete, boss sims at Tier 1/3/5, and the borough's three districts carry
## everything in §4.4.


func check_boss_data(ids: PackedStringArray, king_id: String, borough: String) -> void:
	for id: String in ids:
		var b: Dictionary = DataDB.boss(id)
		assert_false(b.is_empty(), id)
		for ph: Variant in JU.a(b, "phases"):
			for m: Variant in JU.a(ph as Dictionary, "moves"):
				assert_false(DataDB.move(id, str(m)).is_empty(), "%s move %s" % [id, m])
		assert_false(DataDB.move(id, JU.s(JU.dict(b, "t5_event"), "move")).is_empty(), "%s T5 move" % id)
		assert_eq(BossGating.phase_count(b, 1), 1, "%s: T1 phase 1 only" % id)
		assert_eq(BossGating.phase_count(b, 3), 2, "%s: T3 adds phase 2" % id)
		for d: String in JU.strs(b, "drops"):
			assert_ne(DataDB.catalog_of(d), "", "%s drop %s exists" % [id, d])
		var t2: bool = false
		for m2: Variant in DataDB.moves_for(id).values():
			t2 = t2 or JU.i(m2 as Dictionary, "min_tier") == 2
		assert_true(t2, "%s has a (T2) move" % id)
	assert_eq(JU.s(DataDB.boss(king_id), "kind"), "king")
	assert_true(JU.strs(DataDB.boss(king_id), "drops").has("crown_" + borough), "King drops the Crown")


func sim_tiers(ids: PackedStringArray, tiers: Array = [1, 3, 5]) -> void:
	for id: String in ids:
		for t: Variant in tiers:
			var r: Dictionary = BossSim.run(id, int(t), {"god": true, "max_s": 900, "seed": 2})
			gut.p("SIM %s T%d: %s in %.0fs (makes %d, phases %s)" % [id, int(t), r["result"], float(r["time_s"]), int((r["stats"] as Dictionary)["makes"]), r["phases_seen"]])
			assert_eq(str(r["result"]), "victory", "%s T%d: god-mode bot wins: %s" % [id, int(t), r])
			if int(t) >= 3:
				assert_true((r["phases_seen"] as Array).has(2), "%s T%d reaches phase 2" % [id, int(t)])
			else:
				assert_eq((r["phases_seen"] as Array).size(), 1, "%s T1 phase 1 only" % id)
			if int(t) >= 5:
				assert_gt(int((r["events"] as Dictionary).get("t5_event", 0)), 0, "%s T5 event" % id)


func check_districts(districts: PackedStringArray, cats: PackedStringArray) -> void:
	var count: Dictionary = {}
	var pools: Array = []
	var found_cats: PackedStringArray = PackedStringArray()
	var challengers: int = 0
	for id: String in districts:
		var m: MapData = MapParser.load_map(id)
		assert_not_null(m, id)
		if m == null:
			continue
		assert_eq(MapLinter.lint(m).size(), 0, "%s lints clean: %s" % [id, MapLinter.lint(m)])
		assert_eq(m.cells_of("S").size(), 1, "%s: one station" % id)
		assert_gte(JU.a(m.side, "graffiti").size(), 10, "%s: ~10 graffiti tags" % id)
		assert_gte(m.cells_of("^").size(), 2, "%s: a secret" % id)
		for ch: String in ["D", "K", "G", "I", "M", "X", "$", "%", "w", "h", "L", "g"]:
			count[ch] = int(count.get(ch, 0)) + m.cells_of(ch).size()
		pools.append_array(JU.a(JU.dict(m.side, "loot"), "$"))
		for b: Variant in JU.a(m.side, "bodegas"):
			found_cats.append(JU.s(b as Dictionary, "cat"))
		for n: Variant in JU.a(m.side, "npcs"):
			if not JU.dict(n as Dictionary, "challenger").is_empty():
				challengers += 1
	assert_eq(int(count["D"]), 4, "4 bodegas")
	found_cats.sort()
	var want: PackedStringArray = cats.duplicate()
	want.sort()
	assert_eq(found_cats, want, "bodega cats")
	assert_eq(int(count["K"]) + int(count["G"]) + int(count["I"]), 3, "Plug, Pump & Grip, Ink & Needle")
	assert_eq(int(count["M"]), 2, "two mini-boss courts")
	assert_eq(int(count["X"]), 1, "one King court")
	assert_between(int(count["$"]), 13, 17, "12-16 shoeboxes + the Grail box")
	assert_between(int(count["%"]), 2, 3, "2-3 Bootlegs")
	assert_between(int(count["w"]), 2, 3, "2-3 Wire Kicks")
	assert_gte(int(count["h"]), 6, "6+ crate hoops")
	assert_gte(int(count["L"]) + int(count["g"]), 3, "3+ one-way shortcuts")
	assert_gte(challengers, 2, "2 Pickup Challengers")
	var grails: int = 0
	var extras: Array = []
	for p: Variant in pools:
		if JU.s(LootRoller.pool(str(p)), "tier") == "grail":
			grails += 1
		extras.append_array(JU.strs(LootRoller.pool(str(p)), "extra"))
		assert_false(LootRoller.pool(str(p)).is_empty(), "pool %s exists" % p)
	assert_eq(grails, 1, "one Grail box")
	assert_between(extras.filter(func(x: Variant) -> bool: return str(x).begins_with("mixtape_")).size(), 1, 2, "1-2 Mixtapes")
	assert_between(extras.count("punch_card"), 1, 2, "1-2 Punch Cards")
	assert_between(extras.count("sugar_rush"), 1, 2, "1-2 Sugar Rush")
	assert_between(extras.filter(func(x: Variant) -> bool: return str(x).begins_with("flash_")).size(), 1, 3, "flash sheets in boxes")
	for id2: String in districts:
		for c: Variant in JU.a(MapParser.load_map(id2).side, "crossings"):
			var to: String = JU.s(c as Dictionary, "to")
			if WorldIndex.has_district(to) and JU.s(c as Dictionary, "locked") == "":
				var back: bool = false
				for c2: Variant in JU.a(MapParser.load_map(to).side, "crossings"):
					back = back or JU.s(c2 as Dictionary, "to") == id2
				assert_true(back, "crossing %s <-> %s" % [id2, to])
