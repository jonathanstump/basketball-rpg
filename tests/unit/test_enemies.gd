extends GutTest
## M4: aggro/leash, token caps, tier multipliers, min_tier filtering,
## captains, archetype quirks, respawn rules, rewards.

var sim: CombatSim


func before_each() -> void:
	sim = CombatSim.new()
	sim.combat.damage.hitstop_enabled = false
	GameState.new_run("two_way", "brooklyn")


func after_each() -> void:
	sim.dispose()


func _player(pos: Vector3 = Vector3.ZERO, with_ball: bool = true) -> Hooper:
	return sim.hooper(pos, {}, with_ball)


func test_every_enemy_def_has_valid_moves() -> void:
	for id: Variant in DataDB.catalog("enemies").keys():
		var d: Dictionary = DataDB.enemy(str(id))
		for m: String in JU.strs(d, "moves"):
			assert_false(DataDB.move("enemies", m).is_empty(), "%s move %s" % [id, m])
		if JU.s(d, "captain_move") != "":
			assert_false(DataDB.move("enemies", JU.s(d, "captain_move")).is_empty())


func test_tier_multipliers_on_spawn() -> void:
	for tier: int in [1, 3, 5, 7]:
		var a: SimActor = sim.enemy("ball_hog", Vector3(50 + tier * 3, 0, 0), tier)
		assert_almost_eq(a.hp_max, 120.0 * TierMath.multiplier(DataDB.tiers(), "hp", tier), 0.01, "hp t%d" % tier)
		assert_almost_eq(a.composure.max_value, 40.0 * TierMath.multiplier(DataDB.tiers(), "composure", tier), 0.01)
		assert_eq(int(a.flags["reward_rep"]), int(round(50.0 * TierMath.multiplier(DataDB.tiers(), "rep", tier))))
		var runner: MoveRunner = sim.brain(a).runner
		runner.move = DataDB.move("enemies", "hog_combo")
		assert_almost_eq(runner.damage(), 25.0 * TierMath.multiplier(DataDB.tiers(), "damage", tier), 0.01)


func test_ng_plus_scales_spawns() -> void:
	GameState.ng_cycle = 1
	var a: SimActor = sim.enemy("ball_hog", Vector3(0, 0, -30), 3)
	assert_almost_eq(a.hp_max, 120.0 * 2.6 * 1.3, 0.01)
	GameState.ng_cycle = 0


func test_min_tier_filtering() -> void:
	var d: Dictionary = DataDB.enemy("ball_hog").duplicate(true)
	var fake: Dictionary = {"id": "fake_t3", "primitive": "melee_arc", "startup": 1, "active": 1, "recovery": 1, "damage": 1, "min_tier": 3}
	DataDB.moves_for("enemies")["fake_t3"] = fake
	var ids: PackedStringArray = JU.strs(d, "moves")
	ids.append("fake_t3")
	d["moves"] = Array(ids)
	var low: Array[Dictionary] = EnemyFactory.move_list(d, 2, false)
	var high: Array[Dictionary] = EnemyFactory.move_list(d, 3, false)
	assert_eq(low.size(), 2)
	assert_eq(high.size(), 3)
	DataDB.moves_for("enemies").erase("fake_t3")


func test_crew_captain() -> void:
	var a: SimActor = sim.enemy("ball_hog", Vector3(0, 0, -20), 1, {"captain": true})
	assert_almost_eq(a.hp_max, 120.0 * 1.6, 0.01)
	assert_eq(int(a.flags["reward_rep"]), 150)
	var ids: Array[String] = []
	for m: Dictionary in sim.brain(a).moves:
		ids.append(JU.s(m, "id"))
	assert_true(ids.has("hog_spin"), "one extra move")


func test_aggro_sight_fov_and_range() -> void:
	var p: Hooper = _player()
	var front: SimActor = sim.enemy("ball_hog", Vector3(0, 0, -15), 1, {"facing": PI})
	var behind: SimActor = sim.enemy("ball_hog", Vector3(4, 0, 15), 1, {"facing": PI})
	var far: SimActor = sim.enemy("ball_hog", Vector3(-25, 0, 0), 1, {"facing": -PI * 0.5})
	sim.run(2)
	assert_eq(sim.brain(front).state, "engage", "in FOV within 18 m")
	assert_eq(sim.brain(behind).state, "idle", "facing away")
	assert_eq(sim.brain(far).state, "idle", "too far")
	p.actor.flags["last_combat_frame"] = sim.world.frame
	behind.pos = Vector3(0, 0, 10)
	behind.home = behind.pos
	sim.run(2)
	assert_eq(sim.brain(behind).state, "engage", "hears combat within 12 m")


func test_leash_returns_home_and_heals() -> void:
	var p: Hooper = _player(Vector3(0, 0, 0))
	var a: SimActor = sim.enemy("ball_hog", Vector3(0, 0, -10), 1, {"facing": PI})
	sim.run(2)
	a.pos = Vector3(0, 0, 30)
	a.hp = 10.0
	sim.run(2)
	assert_eq(sim.brain(a).state, "leash")
	p.actor.pos = Vector3(0, 0, 90)
	sim.run(60 * 12)
	assert_eq(sim.brain(a).state, "idle")
	assert_eq(a.hp, a.hp_max)


func test_attack_token_cap() -> void:
	var p: Hooper = _player()
	p.actor.flags["cannot_die"] = true
	for i: int in 4:
		sim.enemy("ball_hog", Vector3(float(i) - 1.5, 0, -1.6), 1, {"facing": PI})
	var max_seen: int = 0
	for _f: int in 400:
		sim.run(1)
		max_seen = maxi(max_seen, sim.world.attack_tokens.count(p.actor.id) if sim.world.attack_tokens != null else 0)
		var attacking: int = 0
		for a: SimActor in sim.world.actors:
			if a.controller is EnemyBrain and (a.controller as EnemyBrain).runner.running:
				attacking += 1
		assert_lte(attacking, 2)
	assert_eq(max_seen, 2)


func test_token_cap_tier5() -> void:
	var t: AttackTokenManager = AttackTokenManager.new()
	var a: SimActor = SimActor.new()
	a.tier = 5
	for i: int in 4:
		a.id = 100 + i
		t.request(a, 1)
	assert_eq(t.count(1), 3)


func _combo_hits(tier: int, x: float) -> int:
	var a: SimActor = sim.enemy("ball_hog", Vector3(x, 0, -30), tier)
	var r: MoveRunner = sim.brain(a).runner
	var before: int = sim.combat.hitboxes.size()
	r.start(DataDB.move("enemies", "hog_combo"))
	while r.step():
		pass
	return sim.combat.hitboxes.size() - before


func test_tier5_commons_get_combo_hit_and_faster_recovery() -> void:
	var a: SimActor = sim.enemy("ball_hog", Vector3(0, 0, -40), 5)
	assert_almost_eq(sim.brain(a).runner.speed_mult, 0.8, 0.001, "20% faster recovery")
	assert_eq(_combo_hits(1, 10.0), 2)
	assert_eq(_combo_hits(5, 20.0), 3, "+1 combo hit at Tier 5+")


func test_strip_disarms_and_enemy_runs_for_ball() -> void:
	var p: Hooper = _player(Vector3.ZERO, false)
	var a: SimActor = sim.enemy("ball_hog", Vector3(0, 0, -1.6), 1, {"facing": PI})
	(p.actor.input_source as ScriptedInput).press_at(0, "hands_up")
	sim.run(1)
	var hb: Hitbox = Hitbox.new()
	hb.owner_id = a.id
	hb.team = 1
	hb.kind = "ball"
	hb.damage = 10.0
	hb.world_space = true
	hb.volume = HitVolume.from_dict({"shape": "sphere", "radius": 3.0})
	sim.combat.add(hb)
	sim.run(1)
	assert_true(bool(a.flags.get("disarmed", false)))
	sim.run(240)
	assert_true(a.has_ball, "ran back for its ball")
	assert_false(bool(a.flags.get("disarmed", false)))


func test_pickpocket_steals_and_escape_gives_spare() -> void:
	var p: Hooper = _player()
	p.actor.flags["cannot_die"] = true
	var pp: SimActor = sim.enemy("pickpocket", Vector3(0, 0, -2.5), 1, {"facing": PI})
	sim.run(120)
	assert_eq(sim.count("ball_stolen"), 1)
	assert_true(pp.has_ball)
	assert_eq(sim.brain(pp).state, "flee")
	pp.pos = Vector3(0, 0, -40)
	sim.run(60)
	assert_eq(sim.count("pickpocket_escaped"), 1)
	assert_true(p.actor.has_ball, "spare ball")
	assert_true(GameState.has_flag("lost_and_found"))


func test_big_man_dunk_on_you_needs_downed_target() -> void:
	var p: Hooper = _player()
	var big: SimActor = sim.enemy("big_man", Vector3(0, 0, -2.0), 1, {"facing": PI})
	var br: EnemyBrain = sim.brain(big)
	br.target = p.actor
	var m: Dictionary = DataDB.move("enemies", "big_dunk_on_you")
	assert_false(br.move_usable(m, 2.0))
	p.actor.flags["downed"] = true
	assert_true(br.move_usable(m, 2.0))


func test_hype_man_aura_and_boombox() -> void:
	_player(Vector3(0, 0, 20))
	var hm: SimActor = sim.enemy("hype_man", Vector3(0, 0, 0), 1)
	var ally: SimActor = sim.enemy("ball_hog", Vector3(3, 0, 0), 1)
	sim.run(2)
	assert_gt(int(ally.flags.get("aura_until", -1)), sim.world.frame - 1, "aura buffs allies within 8 m")
	var box: SimActor = sim.world.actor_by_id(int(hm.flags["boombox_id"]))
	sim.combat.damage.apply_raw(box, 500.0)
	assert_true(box.alive, "fixed 1 damage per hit")
	sim.combat.damage.apply_raw(box, 500.0)
	assert_false(box.alive, "2 hits smash it")
	sim.run(3)
	assert_false(bool(hm.flags.get("aura_active", true)))


func test_showboat_hit_while_taunting_staggers() -> void:
	var a: SimActor = sim.enemy("showboat", Vector3(0, 0, -5), 1)
	var br: EnemyBrain = sim.brain(a)
	br.runner.start(DataDB.move("enemies", "show_taunt"))
	sim.run(10)
	br.on_hit({"result": "hit", "damage": 5.0, "attacker": 0})
	assert_eq(a.composure.broken, "stagger")


func test_respawn_rules() -> void:
	var common: SimActor = sim.enemy("ball_hog", Vector3(10, 0, 0), 1)
	var cap: SimActor = sim.enemy("ball_hog", Vector3(12, 0, 0), 1, {"captain": true})
	var boot: SimActor = sim.enemy("bootleg", Vector3(14, 0, 0), 1)
	for a: SimActor in [common, cap, boot]:
		sim.combat.damage.apply_raw(a, 99999.0)
	assert_eq(sim.spawner.alive_count(), 0)
	var n: int = sim.spawner.respawn_commons()
	assert_eq(n, 1, "only commons respawn")
	assert_eq(sim.spawner.alive_count(), 1)


func test_rewards_on_kill() -> void:
	var a: SimActor = sim.enemy("big_man", Vector3(0, 0, -5), 3)
	sim.combat.damage.apply_raw(a, 99999.0)
	sim.world.emit("actor_killed", {"actor": a.id, "attacker": 0, "kind": a.kind, "archetype": a.archetype})
	var ev: Dictionary = sim.last("enemy_defeated")
	assert_eq(int(ev["rep"]), int(round(120 * 4.0)))
	assert_eq(int(ev["tokens"]), int(round(20 * 3.0)))


func test_bootleg_dormant_until_close() -> void:
	var p: Hooper = _player(Vector3(0, 0, 6))
	var b: SimActor = sim.enemy("bootleg", Vector3.ZERO, 1)
	sim.run(10)
	assert_eq(sim.brain(b).state, "dormant")
	p.actor.pos = Vector3(0, 0, 1.8)
	sim.run(2)
	assert_eq(sim.count("bootleg_revealed"), 1)


func test_keeper_summons_and_scatter() -> void:
	var p: Hooper = _player(Vector3(0, 0, 0))
	p.actor.flags["cannot_die"] = true
	var k: SimActor = sim.enemy("pigeon_keeper", Vector3(0, 0, -8), 1, {"facing": PI})
	sim.run(200)
	assert_gt(sim.count("summon"), 0)
	var pigeons: int = 0
	for a: SimActor in sim.world.actors:
		if a.archetype == "pigeon" and a.alive:
			pigeons += 1
	assert_gt(pigeons, 0)
	sim.combat.damage.apply_raw(k, 99999.0)
	sim.world.emit("actor_killed", {"actor": k.id, "attacker": 0, "kind": k.kind, "archetype": k.archetype})
	assert_gt(sim.count("summon_scattered"), 0, "kill the keeper and the swarm scatters")


func test_gull_snatches_tokens_and_returns_on_kill() -> void:
	GameState.tokens = 1000
	var p: Hooper = _player()
	p.actor.flags["cannot_die"] = true
	var g: SimActor = sim.enemy("gull", Vector3(0, 0, -5), 1, {"facing": PI})
	sim.run(200)
	assert_eq(GameState.tokens, 950, "5% snatched")
	assert_eq(int(g.flags.get("snatched_tokens", 0)), 50)
	sim.combat.damage.apply_raw(g, 99999.0)
	assert_eq(int(EnemyRewards.compute(g, sim.world.rng)["tokens"]), 50, "kill to get them back")


func test_tourist_flash_blinds() -> void:
	var p: Hooper = _player()
	sim.enemy("tourist", Vector3(0, 0, -4), 1)
	sim.run(60 * 5)
	assert_gt(sim.count("camera_flash"), 0)
	assert_eq(p.actor.alive, true)
