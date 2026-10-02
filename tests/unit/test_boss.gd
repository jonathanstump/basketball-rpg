extends GutTest
## M5: gating at T1/T2/T3/T5, boss stats, bucket damage, duel integration
## (statement dunk heal, Rejected punish), Stoop Queen sims.


func _ids(ms: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for m: Dictionary in ms:
		out.append(JU.s(m, "id"))
	return out


func test_gating_t1() -> void:
	var b: Dictionary = DataDB.boss("bk_stoop")
	assert_eq(BossGating.phase_count(b, 1), 1, "T1: phase 1 only")
	var ids: Array[String] = _ids(BossGating.moves_for_phase(b, 1, 1))
	assert_false(ids.has("double_lob"), "no T2 moves")
	assert_true(ids.has("chancla"))
	assert_true(BossGating.t5_event(b, 1).is_empty())


func test_gating_t2() -> void:
	var b: Dictionary = DataDB.boss("bk_stoop")
	assert_eq(BossGating.phase_count(b, 2), 1)
	assert_true(_ids(BossGating.moves_for_phase(b, 1, 2)).has("double_lob"), "T2 adds (T2) moves")


func test_gating_t3() -> void:
	var b: Dictionary = DataDB.boss("bk_stoop")
	assert_eq(BossGating.phase_count(b, 3), 2, "T3: phase 2 at 50%")
	assert_almost_eq(BossGating.phase_threshold(b, 2, 3), 0.5, 0.0001)
	assert_true(_ids(BossGating.moves_for_phase(b, 2, 3)).has("lawn_chair_slam"))
	assert_true(BossGating.t5_event(b, 4).is_empty(), "no T5 event at T4")


func test_gating_t5() -> void:
	var b: Dictionary = DataDB.boss("bk_stoop")
	assert_eq(BossGating.phase_count(b, 5), 2)
	assert_eq(JU.s(BossGating.t5_event(b, 5), "move"), "block_party_call")
	assert_almost_eq(JU.f(BossGating.t5_event(b, 5), "at_hp_pct"), 0.25, 0.0001)


func test_boss_stats_by_tier() -> void:
	var sim: CombatSim = CombatSim.new()
	var h: SimHoop = sim.balls.add_hoop(SimHoop.regulation("h", Vector3(0, 0, -8), Vector3(0, 0, 1)))
	var t1: SimActor = BossFactory.spawn(sim.world, sim.combat, sim.balls, "bk_stoop", Vector3.ZERO, 1, h)
	var t5: SimActor = BossFactory.spawn(sim.world, sim.combat, sim.balls, "bk_stoop", Vector3(5, 0, 0), 5, h)
	assert_almost_eq(t1.hp_max, 1800.0, 0.01)
	assert_almost_eq(t5.hp_max, 1800.0 * 5.0, 0.01)
	assert_almost_eq(t1.composure.max_value, 200.0, 0.01)
	assert_almost_eq(t5.composure.max_value, 200.0 * 2.3, 0.01)
	var r: Dictionary = BossFactory.rewards(DataDB.boss("bk_stoop"), 3)
	assert_eq(int(r["rep"]), 10000)
	assert_eq(int(r["tokens"]), 2400)
	sim.dispose()


func test_bucket_damage_table_and_cap() -> void:
	var hp: float = 10000.0
	assert_almost_eq(float(BucketDamage.compute("close", hp, 0.0, 10, "", false, false, false)["damage"]), 400.0, 0.01)
	assert_almost_eq(float(BucketDamage.compute("mid", hp, 0.0, 10, "", false, false, false)["damage"]), 500.0, 0.01)
	assert_almost_eq(float(BucketDamage.compute("three", hp, 0.0, 10, "", false, false, false)["damage"]), 750.0, 0.01)
	assert_almost_eq(float(BucketDamage.compute("deep", hp, 0.0, 10, "", false, false, false)["damage"]), 1000.0, 0.01)
	assert_almost_eq(float(BucketDamage.compute("dunk", hp, 0.0, 10, "", false, false, false)["damage"]), 800.0, 0.01)
	assert_almost_eq(float(BucketDamage.compute("three", hp, 0.0, 10, "", true, false, false)["damage"]), 1050.0, 0.01, "perfect x1.4")
	var capped: Dictionary = BucketDamage.compute("poster", hp, 40.0, 60, "S", true, true, true)
	assert_almost_eq(float(capped["damage"]), 2200.0, 0.01, "cap 22%")
	assert_eq(float(capped["composure"]), 60.0)
	var with_stat: float = float(BucketDamage.compute("mid", hp, 20.0, 20, "C", false, false, false)["damage"])
	assert_almost_eq(with_stat, 500.0 + 20.0 * 0.4 * 1.0 * 0.5, 0.01, "stat bonus = attack x scaling x 0.5")


func _arena(tier: int = 1) -> Dictionary:
	var sim: CombatSim = CombatSim.new(3)
	sim.combat.damage.hitstop_enabled = false
	var data: Dictionary = DataDB.boss("bk_stoop")
	var lay: Dictionary = ArenaBuilder.build(sim.world, sim.balls, data, null)
	var p: Hooper = sim.hooper(lay["player_start"])
	var boss: SimActor = BossFactory.spawn(sim.world, sim.combat, sim.balls, "bk_stoop", lay["boss_spot"], tier, lay["hoop"])
	var ctl: DuelController = DuelController.new(sim.world, sim.balls, sim.combat, boss, p.actor, lay["hoop"], data, lay)
	return {"sim": sim, "p": p, "boss": boss, "ctl": ctl, "lay": lay}


func test_check_gives_player_the_ball_at_top_of_key() -> void:
	var a: Dictionary = _arena()
	var ctl: DuelController = a["ctl"]
	var p: Hooper = a["p"]
	ctl.start()
	assert_true(p.actor.has_ball)
	assert_almost_eq(p.actor.pos.distance_to((a["lay"] as Dictionary)["top_of_key"]), 0.0, 0.01)
	(a["sim"] as CombatSim).dispose()


func test_statement_dunk_heals_boss() -> void:
	var a: Dictionary = _arena()
	var sim: CombatSim = a["sim"]
	var ctl: DuelController = a["ctl"]
	var boss: SimActor = a["boss"]
	ctl.start()
	ctl.duel.state = PossessionDuel.BOSS_OFFENSE
	ctl.duel.boss_cleared = true
	var b: SimBall = sim.balls.take_from((a["p"] as Hooper).actor)
	sim.balls.give(b, boss)
	boss.hp = boss.hp_max * 0.5
	(a["p"] as Hooper).actor.pos = Vector3(0, 0, 8)
	(boss.controller as BossBrain).run_event_move("stoop_statement")
	for _i: int in 100:
		sim.run(1)
		ctl.step()
	assert_almost_eq(boss.hp, boss.hp_max * 0.58, 1.0, "+8% Heart")
	assert_eq(ctl.stats["statements"], 1)
	sim.dispose()


func test_rejected_punish_damages_player() -> void:
	var a: Dictionary = _arena()
	var sim: CombatSim = a["sim"]
	var ctl: DuelController = a["ctl"]
	var p: Hooper = a["p"]
	ctl.start()
	ctl.duel.state = PossessionDuel.PLAYER_OFFENSE
	var hp0: float = p.actor.hp
	sim.balls.take_from(p.actor)   # a real Rejection knocks the ball away
	sim.world.emit("shot_rejected", {"ball": 1, "actor": p.actor.id, "blocker": (a["boss"] as SimActor).id})
	ctl.step()
	assert_almost_eq(hp0 - p.actor.hp, p.actor.hp_max * 0.18, 0.5, "18% of max Heart at T1")
	assert_eq(ctl.duel.state, PossessionDuel.BOSS_OFFENSE)
	sim.dispose()


func test_player_bucket_damages_boss_through_duel() -> void:
	var a: Dictionary = _arena()
	var sim: CombatSim = a["sim"]
	var ctl: DuelController = a["ctl"]
	var boss: SimActor = a["boss"]
	ctl.start()
	ctl.duel.state = PossessionDuel.PLAYER_OFFENSE
	ctl.duel.player_cleared = true
	var hoop: SimHoop = (a["lay"] as Dictionary)["hoop"]
	sim.world.emit("shot_made", {"actor": (a["p"] as Hooper).actor.id, "hoop": hoop.id, "zone": "three", "grade": "GOOD"})
	ctl.step()
	assert_lt(boss.hp, boss.hp_max)
	assert_almost_eq(boss.hp_max - boss.hp, 1800.0 * 0.075 + 20.0 * StatFormulas.scaling(10, "C") * 0.5, 0.5)
	sim.dispose()


func test_sim_win_path_t1() -> void:
	var r: Dictionary = BossSim.run("bk_stoop", 1, {"god": true, "boss_hp_pct": 0.12, "max_s": 240})
	assert_eq(str(r["result"]), "victory", "debug win path: %s" % r)


func test_sim_loss_path() -> void:
	var r: Dictionary = BossSim.run("bk_stoop", 5, {"player_hp": 1.0, "passive_bot": true, "max_s": 120})
	assert_eq(str(r["result"]), "defeat", "debug loss path")


func test_sim_t5_reaches_phase_2_and_t5_event() -> void:
	var r: Dictionary = BossSim.run("bk_stoop", 5, {"god": true, "boss_hp_pct": 0.3, "max_s": 240})
	assert_true((r["phases_seen"] as Array).has(2), "phase 2 at T5: %s" % r)
	assert_gt(int((r["events"] as Dictionary).get("t5_event", 0)), 0, "Block Party Call at 25%")


func test_sim_t1_full_fight_runs_clean() -> void:
	var r: Dictionary = BossSim.run("bk_stoop", 1, {"god": true, "max_s": 180, "seed": 4})
	assert_gt(int((r["stats"] as Dictionary)["makes"]), 0, "bot scored: %s" % r)
	assert_true((r["phases_seen"] as Array).size() == 1, "T1 never leaves phase 1")
