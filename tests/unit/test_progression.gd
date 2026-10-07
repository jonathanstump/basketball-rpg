extends GutTest
## Playtest R6: progression before the bosses. Courts are chained until the
## street knows your name (lieutenants; Kings want the borough's best first),
## lore lives with the people on the street, alleys hide stashes.


func before_each() -> void:
	GameState.new_run("nobody", "brooklyn")
	GameState.set_flag("prologue_done")


func test_every_gated_boss_has_lore_and_a_lieutenant() -> void:
	for id: Variant in DataDB.catalog("bosses").keys():
		var b: Dictionary = DataDB.boss(str(id))
		var kind: String = JU.s(b, "kind")
		var e: Dictionary = LoreBook.entry(str(id))
		assert_false(e.is_empty(), "%s has lore" % id)
		assert_gte(JU.strs(e, "who").size(), 1, "%s: who they were" % id)
		if kind in ["mini", "king", "landmark"] and not str(id).begins_with("opt_"):
			var lt: Dictionary = LoreBook.lieutenant(str(id))
			assert_false(lt.is_empty(), "%s has a lieutenant" % id)
			assert_false(DataDB.enemy(JU.s(lt, "enemy")).is_empty(), "%s lieutenant enemy %s exists" % [id, JU.s(lt, "enemy")])
			assert_gte(JU.strs(lt, "intro").size(), 1)
			assert_gte(JU.strs(lt, "defeat").size(), 1)
			assert_eq(JU.a(e, "rumors").size(), 2, "%s: two people talk about them" % id)


func test_mini_court_opens_after_its_lieutenant() -> void:
	var s: Dictionary = CourtGate.status("bk_stoop")
	assert_false(bool(s["open"]))
	assert_eq(str(s["need"]), "rep", "Bed-Stuy has to know your name first")
	GameState.bump_counter("buzz_bk_bedstuy", StreetRep.need_for("bk_stoop"))
	s = CourtGate.status("bk_stoop")
	assert_eq(str(s["need"]), "lieutenant")
	assert_string_contains(str(s["text"]), "Lil' Deacon")
	CourtGate.mark_lieutenant_beaten("bk_stoop")
	assert_true(CourtGate.is_open("bk_stoop"))


func test_king_wants_the_boroughs_best_first() -> void:
	var cast: Dictionary = ObjectiveRules.borough_cast("brooklyn")
	var king: String = cast["king"]
	assert_eq(str(CourtGate.status(king)["need"]), "minis")
	for m: Variant in cast["minis"]:
		GameState.defeated_bosses.append(str(m))
	assert_eq(str(CourtGate.status(king)["need"]), "rep", "then the King's district has to know you")
	GameState.bump_counter("buzz_" + ObjectiveRules.boss_district(king), StreetRep.need_for(king))
	assert_eq(str(CourtGate.status(king)["need"]), "lieutenant", "then the King's own lieutenant")
	CourtGate.mark_lieutenant_beaten(king)
	assert_true(CourtGate.is_open(king))


func test_beaten_final_and_optional_courts_are_open() -> void:
	GameState.defeated_bosses.append("bx_crab")
	assert_true(CourtGate.is_open("bx_crab"), "beaten: open court")
	assert_true(CourtGate.is_open("opt_ratking"))
	assert_true(CourtGate.is_open("fin_midnight"), "the Garden keeps its own ticket gate")


func test_street_life_plan_is_walkable_and_deterministic() -> void:
	for id: String in ["bk_bedstuy", "bk_coney", "qn_flushing", "si_st_george", "city_midtown"]:
		var m: MapData = MapParser.load_map(id)
		var w: SimWorld = SimWorld.new(1)
		var root: Node3D = Node3D.new()
		var lay: Dictionary = BoroughBuilder.build(m, w, BallSystem.new(w), root)
		var p: Dictionary = StreetLife.plan(m, lay)
		var p2: Dictionary = StreetLife.plan(m, lay)
		assert_eq(str(p), str(p2), "%s: same plan every load" % id)
		assert_eq((p["lieutenants"] as Array).size(), (lay["courts"] as Array).filter(func(c: Variant) -> bool: return not LoreBook.lieutenant(JU.s(c as Dictionary, "boss")).is_empty()).size(), "%s: a lieutenant per court" % id)
		for l: Variant in p["lieutenants"]:
			var c: Vector2i = m.cell_of((l as Dictionary)["pos"])
			assert_true(m.is_walkable(c), "%s lieutenant on a walkable tile" % id)
			assert_false(w.collision.blocked((l as Dictionary)["pos"] + Vector3(0, 0.1, 0), 0.4), "%s lieutenant not inside a wall" % id)
		for n: Variant in p["rumors"]:
			assert_true(m.is_walkable(m.cell_of((n as Dictionary)["pos"])), "%s rumor NPC on the sidewalk" % id)
			assert_false(JU.strs(n as Dictionary, "lines").is_empty())
		assert_gt((p["rumors"] as Array).size(), 0, "%s: people talk about the court here" % id)
		for b: Variant in p["caches"]:
			assert_true(m.is_walkable(m.cell_of((b as Dictionary)["pos"])), "%s stash reachable" % id)
		w.dispose()
		root.free()


func test_lieutenant_in_district_and_beating_them_opens_the_court() -> void:
	GameState.bump_counter("buzz_bk_bedstuy", StreetRep.need_for("bk_stoop"))
	SceneRouter.pending = {"district": "bk_bedstuy", "arrive": {}}
	var d: District = (load("res://world/district.tscn") as PackedScene).instantiate() as District
	add_child_autofree(d)
	await wait_physics_frames(3)
	var lt: SimActor = null
	for a: SimActor in d.sim.actors:
		if str(a.flags.get("lieutenant", "")) == "bk_stoop":
			lt = a
	assert_not_null(lt, "Lil' Deacon guards the block")
	assert_true(bool(lt.flags.get("captain", false)), "a crew captain")
	var court: Dictionary = d.interact.find("court_bk_stoop")
	assert_string_contains(str(court["prompt"]), "locked")
	DistrictActions.trigger(d, court)
	assert_true(d.dialogue.open, "the chained gate says why")
	assert_true(SceneRouter.pending.is_empty() or not SceneRouter.pending.has("boss"), "no arena")
	d.dialogue.open = false
	d.combat.damage.apply_raw(lt, lt.hp + 1.0)
	d.sim.emit("actor_killed", {"actor": lt.id, "attacker": d.player.id, "kind": lt.kind, "archetype": lt.archetype})
	assert_true(CourtGate.is_open("bk_stoop"), "court open")
	assert_true(LoreBook.heard("bk_stoop"), "and you heard who she is")
	assert_string_contains(str(d.interact.find("court_bk_stoop")["prompt"]), "Challenge")


func test_rumor_npcs_fill_the_journal() -> void:
	SceneRouter.pending = {"district": "bk_bedstuy", "arrive": {}}
	var d: District = (load("res://world/district.tscn") as PackedScene).instantiate() as District
	add_child_autofree(d)
	await wait_physics_frames(3)
	var rumor: Dictionary = {}
	for it: Dictionary in d.interact.items:
		if str(it["kind"]) == "npc" and JU.s(it["data"] as Dictionary, "lore") != "":
			rumor = it
	assert_false(rumor.is_empty(), "a rumor NPC in Bed-Stuy")
	assert_false(LoreBook.heard("bk_stoop"))
	DistrictActions.trigger(d, rumor)
	assert_true(d.dialogue.open)
	assert_true(LoreBook.heard("bk_stoop"))
	var opts: Array[Dictionary] = JournalMenu.options()
	assert_eq(str(opts[0]["id"]), "bk_stoop", "Word on the Street lists her")
	assert_string_contains(str(opts[0]["detail"]), "Odessa")


func test_alley_stashes_are_searchable() -> void:
	SceneRouter.pending = {"district": "bk_bedstuy", "arrive": {}}
	var d: District = (load("res://world/district.tscn") as PackedScene).instantiate() as District
	add_child_autofree(d)
	await wait_physics_frames(3)
	var stash: Dictionary = {}
	for it: Dictionary in d.interact.items:
		if str(it["id"]).begins_with("stash_"):
			stash = it
	assert_false(stash.is_empty(), "an alley stash")
	assert_eq(str(stash["prompt"]), "Search the stash")
	var tokens0: int = GameState.tokens
	var items0: int = GameState.inventory.size()
	DistrictActions.trigger(d, stash)
	assert_true(GameState.opened_boxes.has(str(stash["id"])))
	assert_true(GameState.tokens > tokens0 or GameState.inventory.size() > items0, "found something")
