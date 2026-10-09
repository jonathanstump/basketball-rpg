extends GutTest
## Playtest R7: the basketball-first boss model. Boss shot odds, boss
## offense (shot mix, stationary shooters), turnovers, ball security, the
## punch multiplier on offense, contest timing and boss buckets.


func test_every_boss_has_a_valid_hoops_profile() -> void:
	for id: Variant in DataDB.catalog("bosses").keys():
		var b: Dictionary = DataDB.boss(str(id))
		assert_eq(BossHoops.validate(str(id), b).size(), 0, "%s: %s" % [id, BossHoops.validate(str(id), b)])
		assert_false(JU.dict(b, "hoops").is_empty(), "%s has its own hoops block" % id)
		var p: Dictionary = BossHoops.profile(b)
		assert_ne(JU.s(p, "theme"), "", "%s has a theme" % id)
		assert_eq((p["ratings"] as Dictionary).size(), BossHoops.RATINGS.size())


func test_shot_odds_follow_the_defense() -> void:
	var open: float = BossShotOdds.make_chance("mid", 70.0, 99.0, 10, 0.0)
	assert_gt(BossShotOdds.make_chance("mid", 90.0, 99.0, 10, 0.0), open, "better shooter, better odds")
	assert_lt(BossShotOdds.make_chance("mid", 70.0, 0.8, 10, 0.0), open, "a hand in the face lowers it")
	assert_lt(BossShotOdds.make_chance("layup", 70.0, 0.8, 50, 0.0), BossShotOdds.make_chance("layup", 70.0, 0.8, 10, 0.0), "Body walls off the rim")
	assert_lt(BossShotOdds.make_chance("mid", 70.0, 99.0, 10, 1.0), open, "a healthy defender is harder to score on")
	assert_lt(BossShotOdds.make_chance("mid", 70.0, 0.8, 10, 0.5, BossShotOdds.ALTERED), BossShotOdds.make_chance("mid", 70.0, 0.8, 10, 0.5), "altered")
	assert_eq(BossShotOdds.make_chance("mid", 99.0, 0.8, 10, 0.5, BossShotOdds.BLOCKED), 0.0, "blocked")


func test_contest_timing_windows_grow_with_hands() -> void:
	assert_eq(BossShotOdds.timing_grade(0, 10), BossShotOdds.BLOCKED)
	assert_eq(BossShotOdds.timing_grade(10, 10), BossShotOdds.ALTERED)
	assert_eq(BossShotOdds.timing_grade(10, 40), BossShotOdds.BLOCKED, "good hands block later presses")
	assert_eq(BossShotOdds.timing_grade(30, 10), "")
	assert_eq(BossShotOdds.timing_grade(-1, 10), "", "no press")


func test_boss_score_costs_heart_by_kind() -> void:
	assert_gt(BossShotOdds.score_damage("dunk", 300.0, 1), BossShotOdds.score_damage("layup", 300.0, 1))
	assert_gt(BossShotOdds.score_damage("three", 300.0, 5), BossShotOdds.score_damage("three", 300.0, 1), "tier-scaled")


func _duel(boss_id: String, tier: int = 1) -> Dictionary:
	var sim: CombatSim = CombatSim.new(3)
	sim.combat.damage.hitstop_enabled = false
	var data: Dictionary = DataDB.boss(boss_id)
	var lay: Dictionary = ArenaBuilder.build(sim.world, sim.balls, data, null)
	var p: Hooper = sim.hooper(lay["player_start"], {}, true)
	var boss: SimActor = BossFactory.spawn(sim.world, sim.combat, sim.balls, boss_id, lay["boss_spot"], tier, lay["hoop"])
	var ctl: DuelController = DuelController.new(sim.world, sim.balls, sim.combat, boss, p.actor, lay["hoop"], data, lay)
	ctl.start()
	return {"sim": sim, "p": p, "boss": boss, "ctl": ctl, "lay": lay}


func _run(d: Dictionary, frames: int) -> void:
	for i: int in frames:
		(d["sim"] as CombatSim).run(1)
		(d["ctl"] as DuelController).step()


func _boss_gets_ball(d: Dictionary) -> void:
	var sim: CombatSim = d["sim"]
	var p: SimActor = (d["p"] as Hooper).actor
	var boss: SimActor = d["boss"]
	var b: SimBall = sim.balls.take_from(p)
	sim.balls.give(b, boss)
	(d["ctl"] as DuelController).duel.feed("boss_took")
	(d["ctl"] as DuelController).rules.step()


func test_punches_are_light_on_offense() -> void:
	var d: Dictionary = _duel("bk_stoop")
	var ctl: DuelController = d["ctl"]
	_run(d, 80)
	assert_eq(ctl.duel.state, PossessionDuel.PLAYER_OFFENSE)
	assert_almost_eq(float((d["boss"] as SimActor).flags["duel_strike_mult"]), JU.f(ctl.rules.r7, "offense_strike_mult"), 0.001)
	_boss_gets_ball(d)
	assert_almost_eq(float((d["boss"] as SimActor).flags["duel_strike_mult"]), 1.0, 0.001, "full damage on defense")
	(d["sim"] as CombatSim).dispose()


func test_taking_hits_on_offense_turns_it_over() -> void:
	var d: Dictionary = _duel("bk_stoop")
	var ctl: DuelController = d["ctl"]
	var p: SimActor = (d["p"] as Hooper).actor
	var boss: SimActor = d["boss"]
	_run(d, 80)
	var limit: float = ctl.rules.turnover_limit()
	ctl.rules.on_hit({"result": "hit", "damage": limit * 0.6, "attacker": boss.id, "target": p.id, "move": "chancla"})
	assert_true(p.has_ball, "one hit: still yours")
	ctl.rules.on_hit({"result": "hit", "damage": limit * 0.6, "attacker": boss.id, "target": p.id, "move": "chancla"})
	assert_false(p.has_ball, "past the limit: coughed up")
	assert_eq(ctl.duel.state, PossessionDuel.LOOSE_BALL)
	(d["sim"] as CombatSim).dispose()


func test_hitting_the_boss_on_defense_knocks_it_loose() -> void:
	var d: Dictionary = _duel("bx_silverback")
	var ctl: DuelController = d["ctl"]
	var boss: SimActor = d["boss"]
	var p: SimActor = (d["p"] as Hooper).actor
	_run(d, 80)
	_boss_gets_ball(d)
	assert_eq(ctl.duel.state, PossessionDuel.BOSS_OFFENSE)
	var limit: float = ctl.rules.security_limit()
	ctl.rules.on_hit({"result": "hit", "damage": limit * 0.5, "attacker": p.id, "target": boss.id, "move": "shove"})
	assert_true(boss.has_ball, "not enough yet")
	ctl.rules.on_hit({"result": "hit", "damage": limit * 0.6, "attacker": p.id, "target": boss.id, "move": "shove"})
	assert_false(boss.has_ball, "coughed it up")
	assert_eq(ctl.duel.state, PossessionDuel.LOOSE_BALL)
	(d["sim"] as CombatSim).dispose()


func test_perfect_contest_blocks_the_boss_shot() -> void:
	var d: Dictionary = _duel("bx_silverback")
	var ctl: DuelController = d["ctl"]
	var boss: SimActor = d["boss"]
	var p: SimActor = (d["p"] as Hooper).actor
	_run(d, 80)
	_boss_gets_ball(d)
	p.pos = boss.pos + Vector3(0, 0, boss.radius + 1.0)
	ctl.rules.contest_frame = (d["sim"] as CombatSim).world.frame
	ctl.rules.on_release("mid")
	assert_false(boss.has_ball)
	assert_eq(int(ctl.rules.stats["blocks"]), 1)
	assert_eq(ctl.duel.state, PossessionDuel.LOOSE_BALL)
	(d["sim"] as CombatSim).dispose()


func test_uncontested_release_puts_up_a_real_shot() -> void:
	var d: Dictionary = _duel("bx_silverback")
	var ctl: DuelController = d["ctl"]
	var boss: SimActor = d["boss"]
	_run(d, 80)
	_boss_gets_ball(d)
	ctl.rules.on_release("mid")
	assert_false(boss.has_ball, "the ball is in the air")
	assert_eq(int(ctl.rules.stats["boss_shots"]), 1)
	var after: Array[String] = []
	(d["sim"] as CombatSim).world.sim_event.connect(func(ev: Dictionary) -> void:
		if str(ev["type"]) in ["shot_made", "shot_missed"] and int(ev.get("actor", 0)) == boss.id:
			after.append(ctl.duel.state))
	for i: int in 150:
		_run(d, 1)
		if not after.is_empty():
			break
	assert_eq(after.size(), 1, "the shot came down")
	assert_true(ctl.duel.state in [PossessionDuel.CHECK, PossessionDuel.LOOSE_BALL], "made: CHECK; missed: LOOSE (%s)" % ctl.duel.state)
	(d["sim"] as CombatSim).dispose()


func test_boss_bucket_costs_heart_then_check() -> void:
	var d: Dictionary = _duel("bx_silverback")
	var ctl: DuelController = d["ctl"]
	var boss: SimActor = d["boss"]
	var p: SimActor = (d["p"] as Hooper).actor
	_run(d, 80)
	_boss_gets_ball(d)
	var hp0: float = p.hp
	var hp_boss: float = boss.hp
	ctl.rules.last_kind = "three"
	ctl.rules.on_made()
	ctl.step()
	assert_almost_eq(hp0 - p.hp, BossShotOdds.score_damage("three", p.hp_max, boss.tier), 0.5, "Heart lost")
	assert_eq(boss.hp, hp_boss, "no boss heal")
	assert_true(ctl.duel.state == PossessionDuel.CHECK or ctl.duel.state == PossessionDuel.PLAYER_OFFENSE, "your ball")
	(d["sim"] as CombatSim).dispose()


func test_statement_dunk_scores_instead_of_healing() -> void:
	var duel: PossessionDuel = PossessionDuel.new()
	duel.start()
	duel.feed("check_done")
	duel.feed("boss_took")
	duel.take_events()
	duel.feed("statement_landed")
	var types: Array[String] = []
	for e: Dictionary in duel.take_events():
		types.append(str(e["type"]))
	assert_true(types.has("boss_bucket"), "a bucket on you")
	assert_false(types.has("boss_heal"), "no heal")
	assert_eq(duel.state, PossessionDuel.CHECK)


func test_boss_with_the_ball_plays_offense() -> void:
	## Over a passive run a mobile boss takes real shots, not only dunks.
	var r: Dictionary = BossSim.run("bx_silverback", 1, {"god": true, "max_s": 150, "seed": 4, "passive_bot": true})
	var st: Dictionary = r["stats"]
	assert_gt(int(st.get("boss_shots", 0)) + int(st.get("statements", 0)), 2, "the boss plays offense: %s" % st)


func test_stationary_boss_shoots_from_its_seat() -> void:
	var d: Dictionary = _duel("bk_stoop")
	var boss: SimActor = d["boss"]
	var iq: BossCourtIQ = (boss.controller as BossBrain).iq
	assert_true((boss.controller as BossBrain).stationary, "phase 1 Stoop Queen sits")
	var hoop: SimHoop = (d["lay"] as Dictionary)["hoop"]
	assert_eq(iq.pick_kind(), "layup", "revision 11: she only lays it in")
	iq.offense = {}
	assert_eq(iq.pick_kind(), BossCourtIQ.zone_kind(hoop.flat_distance(boss.pos)), "a sitting boss with no style shoots its zone")
	(d["sim"] as CombatSim).dispose()


func test_stoop_queen_takes_her_time_with_the_ball() -> void:
	## Revision 11: she settles before a slow layup, so you can run up and
	## punch it loose; she stays calm until you start swinging.
	var d: Dictionary = _duel("bk_stoop")
	var boss: SimActor = d["boss"]
	var brain: BossBrain = boss.controller as BossBrain
	var ctl: DuelController = d["ctl"]
	_run(d, 80)
	_boss_gets_ball(d)
	ctl.duel.boss_cleared = true
	brain.runner.interrupt()   # whatever she was throwing on your possession
	brain.recover_s = 0.0
	var settle_f: int = int(JU.f(brain.iq.offense, "settle_s") * 60.0)
	var started: Array[String] = []
	for i: int in settle_f - 10:
		_run(d, 1)
		if brain.runner.running:
			started.append(JU.s(brain.runner.move, "id"))
	assert_eq(started.size(), 0, "no shot and no swing while she settles, unprovoked: %s" % [started])
	_run(d, 20)
	assert_true(brain.runner.running and JU.s(brain.runner.move, "id") == "boss_shot", "then a layup")
	assert_eq(str(brain.runner.move.get("shot_kind", "")), "layup")
	assert_eq(brain.runner.startup(), JU.i(brain.iq.offense, "gather_f"), "a slow gather")
	(d["sim"] as CombatSim).dispose()


func test_stoop_queen_fights_back_once_hit() -> void:
	var d: Dictionary = _duel("bk_stoop")
	var boss: SimActor = d["boss"]
	var brain: BossBrain = boss.controller as BossBrain
	var p: SimActor = (d["p"] as Hooper).actor
	_run(d, 80)
	_boss_gets_ball(d)
	assert_true(brain.iq.calm(), "calm with the ball")
	p.pos = boss.pos + boss.forward() * (boss.radius + 1.0)
	brain.on_hit({"result": "hit", "attacker": p.id, "target": boss.id})
	assert_true(brain.iq.provoked())
	assert_false(brain.iq.calm())
	var swung: bool = false
	for i: int in 90:
		_run(d, 1)
		if brain.runner.running and JU.s(brain.runner.move, "id") != "boss_shot":
			swung = true
			break
	assert_true(swung, "she swings back")
	(d["sim"] as CombatSim).dispose()


func test_body_up_slows_a_drive() -> void:
	var cfg: Dictionary = JU.dict(JU.dict(DataDB.tuning("bosses"), "duel"), "r7")
	var sim: CombatSim = CombatSim.new(1)
	var boss: SimActor = SimActor.new()
	boss.radius = 1.0
	var h: Hooper = sim.hooper(Vector3(0, 0, -1.6), {"body": 10}, false)
	h.actor.hp = h.actor.hp_max * 0.2
	assert_eq(BossCourtIQ.body_up_mult(boss, h.actor, Vector3(0, 0, 1), 60.0, cfg), 1.0, "nobody in the lane")
	var weak: float = BossCourtIQ.body_up_mult(boss, h.actor, Vector3(0, 0, -1), 60.0, cfg)
	h.actor.hp = h.actor.hp_max
	h.actor.stats["body"] = 50
	var strong: float = BossCourtIQ.body_up_mult(boss, h.actor, Vector3(0, 0, -1), 60.0, cfg)
	assert_lt(weak, 1.0, "bodying up slows it")
	assert_lt(strong, weak, "a healthy, strong defender slows it more")
	sim.dispose()


func test_collapsed_boss_cannot_hold_the_ball_at_game_point() -> void:
	## Seen in a balance sim: you miss at GAME POINT, the SHOOK boss scoops
	## the rebound by contact and holds it forever. Nobody could finish.
	var d: Dictionary = _duel("bk_stoop")
	var ctl: DuelController = d["ctl"]
	var boss: SimActor = d["boss"]
	_run(d, 80)
	boss.hp = 0.5
	_run(d, 2)
	assert_eq(ctl.duel.state, PossessionDuel.GAME_POINT)
	assert_true(bool(boss.flags.get("no_pickup", false)), "no pickups while collapsed")
	_boss_gets_ball(d)
	_run(d, 2)
	assert_false(boss.has_ball, "the ball pops back out")
	(d["sim"] as CombatSim).dispose()
