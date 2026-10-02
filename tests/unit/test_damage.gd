extends GutTest
## M3: §7.12 damage formula, guard, composure break/regen, Hype, chain rules.


func test_formula_components() -> void:
	# (base + attack × scaling) × upgrade × crit × buffs × (1 - DR)
	var scaling: float = StatFormulas.scaling(10, "C")   # 0.4 × 0.5
	assert_almost_eq(scaling, 0.2, 0.0001)
	var d: float = DamageMath.raw(22.0, 20.0, 10, "C", 0, 1.0, 1.0, 0.0)
	assert_almost_eq(d, 22.0 + 20.0 * 0.2, 0.0001)
	var d2: float = DamageMath.raw(22.0, 20.0, 10, "C", 5, 1.5, 1.25, 0.1)
	assert_almost_eq(d2, 26.0 * 1.4 * 1.5 * 1.25 * 0.9, 0.0001)


func test_upgrade_mult() -> void:
	assert_almost_eq(DamageMath.upgrade_mult(0), 1.0, 0.0001)
	assert_almost_eq(DamageMath.upgrade_mult(10), 1.8, 0.0001)


func test_stat_factor_soft_caps() -> void:
	assert_almost_eq(StatFormulas.stat_factor(20), 1.0, 0.0001)
	assert_almost_eq(StatFormulas.stat_factor(40), 1.5, 0.0001)
	assert_almost_eq(StatFormulas.stat_factor(60), 1.75, 0.0001)
	assert_almost_eq(StatFormulas.stat_factor(70), 1.8, 0.0001)
	assert_eq(StatFormulas.scaling(30, ""), 0.0, "no grade -> no scaling")


func test_grades_map() -> void:
	for g: String in ["S", "A", "B", "C", "D"]:
		assert_almost_eq(StatFormulas.grade_mult(g), {"S": 1.0, "A": 0.8, "B": 0.6, "C": 0.4, "D": 0.2}[g], 0.0001)


func test_body_dr_cap() -> void:
	assert_almost_eq(StatFormulas.body_dr(10), 0.0, 0.0001)
	assert_almost_eq(StatFormulas.body_dr(30), 0.08, 0.0001)
	assert_almost_eq(StatFormulas.body_dr(80), 0.20, 0.0001, "capped 20%")


func test_hooper_pound_damage_on_rec_ball() -> void:
	var a: SimActor = SimActor.new()
	a.stats = JU.dict(DataDB.archetype("two_way"), "stats").duplicate()
	BallProps.apply(a, "ball_rec")
	var m: Dictionary = DataDB.move("hooper", "pound")
	assert_almost_eq(DamageMath.hooper_damage(m, a), 22.0 + 20.0 * 0.2, 0.0001)


func test_enemy_damage_uses_tier() -> void:
	assert_almost_eq(DamageMath.enemy_damage(25.0, 1), 25.0, 0.0001)
	assert_almost_eq(DamageMath.enemy_damage(25.0, 5), 25.0 * 3.1, 0.0001)


func test_hit_applies_dr_and_guard_chip() -> void:
	var sim: CombatSim = CombatSim.new()
	sim.combat.damage.hitstop_enabled = false
	var h: Hooper = sim.hooper(Vector3.ZERO, SimFixture.stats_with({"body": 20}), false)
	var d: TrainingDummy = sim.dummy(Vector3(0, 0, -1.5))
	h.actor.facing = 0.0
	var hb: Hitbox = Hitbox.new()
	hb.owner_id = d.actor.id
	hb.team = 1
	hb.damage = 100.0
	hb.volume = HitVolume.from_dict({"shape": "sphere", "radius": 3.0})
	hb.volume.origin = h.actor.pos
	hb.world_space = true
	sim.combat.add(hb)
	sim.run(1)
	assert_almost_eq(h.actor.hp_max - h.actor.hp, 100.0 * (1.0 - 0.04), 0.01, "Body 20 = 4% DR")
	sim.dispose()


func test_guard_chip_wind_and_break() -> void:
	var sim: CombatSim = CombatSim.new()
	sim.combat.damage.hitstop_enabled = false
	var h: Hooper = sim.hooper(Vector3.ZERO, {}, false)
	var d: TrainingDummy = sim.dummy(Vector3(0, 0, -1.5))
	(h.actor.input_source as ScriptedInput).hold(0, 300, "hands_up")
	sim.run(20)
	assert_eq(h.action, "guard")
	var hp0: float = h.actor.hp
	var wind0: float = h.actor.wind.value
	var hb: Hitbox = Hitbox.new()
	hb.owner_id = d.actor.id
	hb.team = 1
	hb.damage = 40.0
	hb.volume = HitVolume.from_dict({"shape": "sphere", "radius": 3.0})
	hb.volume.origin = h.actor.pos
	hb.world_space = true
	sim.combat.add(hb)
	sim.run(1)
	assert_eq(sim.results()[0], "guarded")
	assert_almost_eq(hp0 - h.actor.hp, 10.0, 0.01, "25% chip")
	assert_almost_eq(wind0 - h.actor.wind.value, 32.0, 0.6, "Wind = dmg × 0.8")
	var hb2: Hitbox = Hitbox.new()
	hb2.owner_id = d.actor.id
	hb2.team = 1
	hb2.damage = 200.0
	hb2.volume = hb.volume
	hb2.world_space = true
	sim.combat.add(hb2)
	sim.run(1)
	assert_eq(sim.results()[1], "guard_break")
	assert_eq(h.action, "guard_break")
	assert_eq(h.action_total, 72, "1.2 s stagger")
	sim.dispose()


func test_composure_break_and_durations() -> void:
	var c: Composure = Composure.new(100.0, 1)
	assert_eq(c.add(60.0, "shook"), "")
	assert_eq(c.add(50.0, "shook"), "shook")
	assert_almost_eq(c.broken_left_s, 3.0, 0.0001)
	assert_eq(c.add(10.0, "stagger"), "", "no damage while broken")
	for _i: int in 179:
		c.tick(1.0 / 60.0, false)
	assert_eq(c.broken, "shook")
	assert_eq(c.tick(2.0 / 60.0, false), "recovered")
	assert_eq(c.value, 0.0)
	assert_almost_eq(Composure.new(100.0, 4).duration("shook"), 2.8, 0.0001)
	assert_almost_eq(Composure.new(100.0, 7).duration("shook"), 2.2, 0.0001)
	assert_almost_eq(Composure.new(100.0, 7).duration("stagger"), 1.4, 0.0001, "floor 1.4")
	assert_almost_eq(Composure.new(100.0, 1).duration("stagger"), 2.0, 0.0001)


func test_composure_regen() -> void:
	var c: Composure = Composure.new(200.0, 1)
	c.add(100.0, "shook")
	c.tick(1.9, false)
	assert_almost_eq(c.value, 100.0, 0.0001, "no regen before 2 s")
	c.tick(0.1, false)
	c.tick(1.0, false)
	assert_almost_eq(c.value, 100.0 - 1.2 - 12.0, 0.01, "6%/s (incl. the 0.1 s tick that crossed 2 s)")
	c.tick(1.0, true)
	assert_almost_eq(c.value, 100.0 - 1.2 - 12.0 - 24.0, 0.01, "x2 with the ball")


func test_hype_gain_and_decay() -> void:
	var hm: HypeMeter = HypeMeter.new()
	hm.gain("ankle_breaker")
	hm.gain("poster")
	assert_almost_eq(hm.value, 37.0, 0.001)
	hm.tick(7.9)
	assert_almost_eq(hm.value, 37.0, 0.001)
	hm.tick(0.1)
	hm.tick(1.0)
	assert_almost_eq(hm.value, 37.0 - 0.2 - 2.0, 0.01, "2/s after 8 s")
	hm.add(500.0)
	assert_eq(hm.value, 100.0)
	assert_true(hm.spend(30.0))
	assert_false(hm.spend(80.0))


func test_chain_rules() -> void:
	var chains: Array = ChainRules.on_death([], 900, "bk_bedstuy", Vector3(1, 0, 2), false)
	assert_eq(chains.size(), 1)
	assert_eq(ChainRules.total_rep(chains), 900)
	var far: Dictionary = ChainRules.touch(chains, "bk_bedstuy", Vector3(10, 0, 10))
	assert_eq(int(far["rep"]), 0)
	var near: Dictionary = ChainRules.touch(chains, "bk_bedstuy", Vector3(1.5, 0, 2))
	assert_eq(int(near["rep"]), 900)
	assert_eq((near["chains"] as Array).size(), 0)
	var died_twice: Array = ChainRules.on_death(chains, 0, "bk_bedstuy", Vector3.ZERO, false)
	assert_eq(died_twice.size(), 0, "die again first and it's gone")
	var wrong_district: Dictionary = ChainRules.touch(chains, "bx_mott", Vector3(1, 0, 2))
	assert_eq(int(wrong_district["rep"]), 0)


func test_nine_lives_chain() -> void:
	var chains: Array = ChainRules.on_death([], 500, "d", Vector3.ZERO, true)
	chains = ChainRules.on_death(chains, 200, "d", Vector3(5, 0, 0), true)
	assert_eq(chains.size(), 2, "first chain survives one extra death")
	chains = ChainRules.on_death(chains, 0, "d", Vector3.ZERO, true)
	assert_eq(ChainRules.total_rep(chains), 200)
