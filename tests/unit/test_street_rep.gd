extends GutTest
## NEXT_SESSION steps 3-4 + hit feedback: street rep ("Buzz") before a
## lieutenant shows, hand-written side streets, and enemy health bars /
## status tags that make landed hits and finisher windows readable.


func before_each() -> void:
	GameState.new_run("nobody", "brooklyn")
	GameState.set_flag("prologue_done")


func _district(id: String) -> District:
	SceneRouter.pending = {"district": id, "arrive": {}}
	var d: District = (load("res://world/district.tscn") as PackedScene).instantiate() as District
	add_child_autofree(d)
	return d


func _lieutenant(d: District, boss_id: String) -> SimActor:
	for a: SimActor in d.sim.actors:
		if str(a.flags.get("lieutenant", "")) == boss_id and a.alive:
			return a
	return null


# ------------------------------------------------------------ Buzz rules

func test_buzz_counts_once_per_thing_and_every_crew() -> void:
	var pts: Dictionary = JU.dict(StreetRep.cfg(), "points")
	assert_eq(StreetRep.earn("bk_bedstuy", "tag_read", "tag_1"), JU.i(pts, "tag_read"))
	assert_eq(StreetRep.earn("bk_bedstuy", "tag_read", "tag_1"), 0, "the same tag only counts once")
	assert_eq(StreetRep.earn("bk_bedstuy", "crew_beaten"), JU.i(pts, "crew_beaten"))
	assert_eq(StreetRep.earn("bk_bedstuy", "crew_beaten"), JU.i(pts, "crew_beaten"), "every crew you beat counts")
	assert_eq(StreetRep.points("bk_bedstuy"), JU.i(pts, "tag_read") + 2 * JU.i(pts, "crew_beaten"))
	assert_eq(StreetRep.points("bk_coney"), 0, "Buzz is per district")
	assert_eq(StreetRep.earn("", "tag_read", "x"), 0)


func test_need_scales_with_the_court() -> void:
	assert_gt(StreetRep.need_for("bk_toll"), StreetRep.need_for("bk_stoop"), "a King's block wants more")
	assert_eq(StreetRep.district_need("bk_bedstuy"), StreetRep.need_for("bk_stoop"))
	assert_eq(StreetRep.gated_courts("bk_bedstuy"), ["bk_stoop"] as Array[String])
	assert_false(StreetRep.known_for("bk_stoop"))
	GameState.bump_counter("buzz_bk_bedstuy", StreetRep.need_for("bk_stoop"))
	assert_true(StreetRep.known_for("bk_stoop"))


func test_every_gated_district_can_earn_its_buzz_without_fighting() -> void:
	## Tags + people + boxes + the side street must cover the need, so a
	## player who'd rather explore than brawl is never stuck.
	var pts: Dictionary = JU.dict(StreetRep.cfg(), "points")
	for id: String in MapParser.list_maps():
		var need: int = StreetRep.district_need(id)
		if need == 0:
			continue
		var m: MapData = MapParser.load_map(id)
		var w: SimWorld = SimWorld.new(1)
		var root: Node3D = Node3D.new()
		var lay: Dictionary = BoroughBuilder.build(m, w, BallSystem.new(w), root)
		var plan: Dictionary = StreetLife.plan(m, lay)
		var talkers: int = (plan["rumors"] as Array).size() + (0 if JU.dict(JU.dict(plan, "side"), "npc").is_empty() else 1)
		for n: Variant in JU.a(lay, "npcs"):
			if JU.dict(n as Dictionary, "challenger").is_empty():
				talkers += 1
		var calm: int = (lay["tags"] as Array).size() * JU.i(pts, "tag_read") + talkers * JU.i(pts, "npc_talked") \
			+ ((lay["boxes"] as Array).size() + (plan["caches"] as Array).size()) * JU.i(pts, "stash_found")
		assert_gte(calm, need, "%s: %d Buzz without a fight (need %d)" % [id, calm, need])
		w.dispose()
		root.free()


# ------------------------------------------------------------ in a district

func test_no_lieutenant_until_the_block_knows_you() -> void:
	var d: District = _district("bk_bedstuy")
	await wait_physics_frames(3)
	assert_null(_lieutenant(d, "bk_stoop"), "Lil' Deacon hasn't heard of you yet")
	var court: Dictionary = d.interact.find("court_bk_stoop")
	DistrictActions.trigger(d, court)
	assert_true(d.dialogue.open, "the chained gate says why")
	assert_string_contains(str(CourtGate.status("bk_stoop")["text"]), "knows your name")
	d.dialogue.open = false
	var tags: Array[Dictionary] = []
	for it: Dictionary in d.interact.items:
		if str(it["kind"]) == "tag":
			tags.append(it)
	assert_gte(tags.size(), StreetRep.need_for("bk_stoop"), "enough walls to read in Bed-Stuy")
	for i: int in StreetRep.need_for("bk_stoop") - 1:
		DistrictActions.trigger(d, tags[i])
		DistrictActions.trigger(d, tags[i])   # reading the same wall twice doesn't count
		d.dialogue.open = false
	assert_eq(StreetRep.points("bk_bedstuy"), StreetRep.need_for("bk_stoop") - 1)
	assert_null(_lieutenant(d, "bk_stoop"), "one short")
	DistrictActions.trigger(d, tags[StreetRep.need_for("bk_stoop") - 1])
	await wait_physics_frames(2)
	var lt: SimActor = _lieutenant(d, "bk_stoop")
	assert_not_null(lt, "word got around: Lil' Deacon shows up")
	assert_true(d.views.has(lt.id), "and you can see him")
	assert_eq(str(CourtGate.status("bk_stoop")["need"]), "lieutenant")
	d.spawn_lieutenants()
	var n: int = 0
	for a: SimActor in d.sim.actors:
		if str(a.flags.get("lieutenant", "")) == "bk_stoop":
			n += 1
	assert_eq(n, 1, "spawning again doesn't double him")


func test_beating_crews_earns_buzz() -> void:
	var d: District = _district("bk_bedstuy")
	await wait_physics_frames(3)
	var crew: SimActor = null
	for a: SimActor in d.sim.actors:
		if a.kind == "enemy" and a.team != 0 and not bool(a.flags.get("captain", false)) and not a.flags.has("side_crew") and not a.flags.has("prop_target"):
			crew = a
			break
	assert_not_null(crew)
	d.combat.damage.apply_raw(crew, crew.hp + 1.0)
	d.sim.emit("actor_killed", {"actor": crew.id, "attacker": d.player.id, "kind": crew.kind, "archetype": crew.archetype})
	assert_eq(StreetRep.points("bk_bedstuy"), JU.i(JU.dict(StreetRep.cfg(), "points"), "crew_beaten"))


# ------------------------------------------------------------ side streets

func test_every_district_has_a_side_street_that_fits() -> void:
	var pools: Array = []
	for p: Variant in JU.a(DataDB.get_dict("loot_tables"), "pools"):
		pools.append(JU.s(p as Dictionary, "id"))
	for id: String in MapParser.list_maps():
		var e: Dictionary = SideStreets.entry(id)
		assert_false(e.is_empty(), "%s has a side street" % id)
		assert_true(pools.has(JU.s(e, "pool")), "%s loot pool %s exists" % [id, JU.s(e, "pool")])
		assert_false(DataDB.enemy(JU.s(JU.dict(e, "leader"), "enemy")).is_empty(), "%s leader enemy exists" % id)
		for en: String in JU.strs(e, "members"):
			assert_false(DataDB.enemy(en).is_empty(), "%s crew %s exists" % [id, en])
		assert_false(JU.strs(e, "intro").is_empty())
		assert_false(JU.strs(e, "defeat").is_empty())
		assert_false(JU.strs(JU.dict(e, "npc"), "after").is_empty(), "%s: the local has something to say after" % id)
		var m: MapData = MapParser.load_map(id)
		var w: SimWorld = SimWorld.new(1)
		var root: Node3D = Node3D.new()
		var lay: Dictionary = BoroughBuilder.build(m, w, BallSystem.new(w), root)
		var side: Dictionary = JU.dict(StreetLife.plan(m, lay), "side")
		assert_false(side.is_empty(), "%s: the side street found an alley" % id)
		if not side.is_empty():
			assert_eq((side["crew"] as Array).size(), JU.strs(e, "members").size(), "%s: whole crew placed" % id)
			assert_false(JU.dict(side, "npc").is_empty(), "%s: the local is placed" % id)
			var lp: Vector3 = JU.dict(side, "leader")["pos"]
			assert_false(w.collision.blocked(lp + Vector3(0, 0.1, 0), 0.4), "%s leader not in a wall" % id)
			for c: Variant in side["crew"]:
				var cp: Vector3 = (c as Dictionary)["pos"]
				assert_true(m.is_walkable(m.cell_of(cp)), "%s crew on a walkable tile" % id)
				assert_false(w.collision.blocked(cp + Vector3(0, 0.1, 0), 0.4), "%s crew not in a wall" % id)
		w.dispose()
		root.free()


func test_clearing_the_side_street() -> void:
	var d: District = _district("bk_bedstuy")
	await wait_physics_frames(3)
	assert_not_null(d.side_street)
	assert_eq(d.side_street.remaining(), 1 + JU.strs(SideStreets.entry("bk_bedstuy"), "members").size(), "leader + crew at the dead end")
	var npc: Dictionary = d.interact.find("side_npc_bk_bedstuy")
	assert_false(npc.is_empty(), "the local by the alley")
	DistrictActions.trigger(d, npc)
	d.dialogue.open = false
	var buzz0: int = StreetRep.points("bk_bedstuy")
	var tokens0: int = GameState.tokens
	var items0: int = GameState.inventory.size()
	for id: int in d.side_street.crew_ids.duplicate():
		var a: SimActor = d.sim.actor_by_id(id)
		d.combat.damage.apply_raw(a, a.hp + 1.0)
		d.sim.emit("actor_killed", {"actor": a.id, "attacker": d.player.id, "kind": a.kind, "archetype": a.archetype})
	assert_true(SideStreets.is_cleared("bk_bedstuy"), "cleared")
	assert_eq(StreetRep.points("bk_bedstuy") - buzz0, JU.i(JU.dict(StreetRep.cfg(), "points"), "side_street_cleared"), "the alley's Buzz (crew kills don't double up)")
	assert_true(GameState.tokens > tokens0 or GameState.inventory.size() > items0, "the alley's loot")
	assert_eq(JU.strs(npc["data"] as Dictionary, "lines"), JU.strs(JU.dict(SideStreets.entry("bk_bedstuy"), "npc"), "after"), "the local thanks you")


func test_cleared_side_street_stays_cleared() -> void:
	GameState.set_flag(SideStreets.cleared_flag("bk_bedstuy"))
	var d: District = _district("bk_bedstuy")
	await wait_physics_frames(3)
	assert_eq(d.side_street.remaining(), 0, "no crew comes back")


# ------------------------------------------------------------ hit feedback

func test_enemy_bar_rules() -> void:
	var a: SimActor = SimActor.new()
	a.kind = "enemy"
	a.team = 1
	a.hp_max = 100.0
	a.hp = 60.0
	a.set_composure(100.0, 1)
	assert_true(EnemyBars.is_street_hostile(a))
	assert_false(EnemyBars.should_show(a, 99.0, 3.0), "untouched commons stay clean")
	assert_true(EnemyBars.should_show(a, 1.0, 3.0), "shows right after you hurt them")
	assert_eq(EnemyBars.status_of(a), "")
	a.flags["knocked"] = true
	assert_eq(EnemyBars.status_of(a), "DOWN", "ankles knock a crew member down")
	assert_true(EnemyBars.finisher_open(a))
	assert_true(EnemyBars.should_show(a, 99.0, 3.0), "an open enemy always shows")
	assert_true(ActorView.open_pulse(a), "and glows gold")
	a.flags["knocked"] = false
	a.composure.force_break("shook")
	assert_eq(EnemyBars.status_of(a), "SHOOK")
	a.composure.force_break("stagger")
	assert_eq(EnemyBars.status_of(a), "STAGGERED")
	assert_false(EnemyBars.finisher_open(a), "stagger isn't a finisher window")
	a.composure.broken = ""
	a.flags["lieutenant"] = "bk_stoop"
	assert_true(EnemyBars.should_show(a, 99.0, 10.0), "named enemies show when you're close")
	assert_false(EnemyBars.should_show(a, 99.0, 30.0))
	var boss: SimActor = SimActor.new()
	boss.kind = "boss"
	boss.team = 1
	assert_false(EnemyBars.is_street_hostile(boss), "bosses have their own bar")


func test_hits_on_street_enemies_draw_a_bar() -> void:
	var d: District = _district("bk_bedstuy")
	await wait_physics_frames(3)
	var bars: EnemyBars = d.get_node_or_null("EnemyBars") as EnemyBars
	assert_not_null(bars, "the district has enemy bars")
	var crew: SimActor = null
	for a: SimActor in d.sim.actors:
		if a.kind == "enemy" and a.team != 0:
			crew = a
			break
	crew.hp -= 20.0
	EventBus.actor_damaged.emit(crew.id, 20.0, d.player.id)
	assert_almost_eq(float(bars._chip[crew.id]), 1.0, 0.001, "chip trail starts at the pre-hit health")
	assert_true(EnemyBars.should_show(crew, float(bars._hit_t[crew.id]), 3.0))
