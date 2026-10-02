extends GutTest
## M12: Midnight (three phases, player-side SHOOK, borrowed moves, the
## countdown finale), the Garden gate, Deuce duel 3, Pops superboss, both
## endings and NG+ from each.


func before_each() -> void:
	GameState.new_run("two_way", "brooklyn")


func _duel(boss_id: String, tier: int) -> Dictionary:
	var sim: CombatSim = CombatSim.new(3)
	sim.combat.damage.hitstop_enabled = false
	var data: Dictionary = DataDB.boss(boss_id)
	var lay: Dictionary = ArenaBuilder.build(sim.world, sim.balls, data, null)
	var p: Hooper = sim.hooper(lay["player_start"])
	var boss: SimActor = BossFactory.spawn(sim.world, sim.combat, sim.balls, boss_id, lay["boss_spot"], tier, lay["hoop"])
	var ctl: DuelController = DuelController.new(sim.world, sim.balls, sim.combat, boss, p.actor, lay["hoop"], data, lay)
	ctl.start()
	return {"sim": sim, "p": p, "boss": boss, "ctl": ctl, "brain": boss.controller}


func _run(d: Dictionary, frames: int) -> void:
	for _i: int in frames:
		(d["sim"] as CombatSim).run(1)
		(d["ctl"] as DuelController).step()


func test_midnight_data() -> void:
	var b: Dictionary = DataDB.boss("fin_midnight")
	assert_eq(JU.s(b, "kind"), "final")
	assert_eq(TierManager.tier_of(TierMath.GARDEN), 7)
	assert_eq(BossGating.phase_count(b, 7), 3, "three phases")
	var p2: Array[Dictionary] = BossGating.moves_for_phase(b, 2, 7)
	var ids: PackedStringArray = PackedStringArray()
	for m: Dictionary in p2:
		ids.append(JU.s(m, "id"))
	for sig: String in ["bass_drop", "cable_whip", "compactor", "finger_wag", "replay", "death_roll", "talon_dive", "cable_lash"]:
		assert_true(ids.has(sig), "Prime borrows %s" % sig)


func test_midnight_sim_per_phase() -> void:
	for ph: int in [1, 2, 3]:
		var r: Dictionary = BossSim.run("fin_midnight", 7, {"god": true, "max_s": 900, "seed": 2, "start_phase": ph})
		gut.p("SIM Midnight from P%d: %s in %.0fs (phases %s)" % [ph, r["result"], float(r["time_s"]), r["phases_seen"]])
		assert_eq(str(r["result"]), "victory", "Midnight P%d: %s" % [ph, r])
		assert_true((r["phases_seen"] as Array).has(3), "GAME POINT only comes in Phase 3")


func test_separate_heart_bars() -> void:
	var d: Dictionary = _duel("fin_midnight", 7)
	var boss: SimActor = d["boss"]
	_run(d, 80)
	boss.hp = 2.0
	_run(d, 2)
	assert_eq((d["ctl"] as DuelController).duel.state, PossessionDuel.PHASE_TRANSITION, "P1 bar empty -> transition, not game point")
	_run(d, 200)
	assert_eq((d["ctl"] as DuelController).duel.phase, 2)
	assert_almost_eq(boss.hp, boss.hp_max, 1.0, "a fresh Heart bar for Prime")
	(d["sim"] as CombatSim).dispose()


func test_player_side_shook() -> void:
	var d: Dictionary = _duel("fin_midnight", 7)
	var brain: BossBrain = d["brain"]
	var g: MidnightGimmick = brain.gimmick as MidnightGimmick
	var h: Hooper = d["p"]
	brain.target = h.actor
	h.actor.pos = brain.actor.pos + Vector3(0, 0, 2.0)
	brain.run_event_move("warmup_crossover")
	(d["sim"] as CombatSim).world.emit("action_started", {"actor": h.actor.id, "move": "crossover"})
	assert_eq(g.player_shooks, 1)
	assert_eq(h.action, "player_shook", "dodged into his crossover: YOU go SHOOK")
	(d["sim"] as CombatSim).dispose()


func test_midnight_countdown_and_finale() -> void:
	var d: Dictionary = _duel("fin_midnight", 7)
	var brain: BossBrain = d["brain"]
	var g: MidnightGimmick = brain.gimmick as MidnightGimmick
	var p: SimActor = (d["p"] as Hooper).actor
	_run(d, 80)
	(d["ctl"] as DuelController).duel.phase = 3
	brain.set_phase(3)
	(d["sim"] as CombatSim).world.emit("duel_phase_changed", {"phase": 3})
	assert_almost_eq(g.clock_s, 60.0, 0.01, "60 s to midnight")
	var hp0: float = p.hp
	(d["sim"] as CombatSim).world.emit("hit_resolved", {"attacker": brain.actor.id, "target": p.id, "move": "midnight", "result": "hit"})
	assert_almost_eq(hp0 - p.hp, p.hp_max * 0.9, 1.0, "miss: 90% max Heart, not instant death")
	assert_almost_eq(g.clock_s, 30.0, 0.01, "clock resets to 30 s")
	(d["sim"] as CombatSim).world.emit("hit_resolved", {"attacker": brain.actor.id, "target": p.id, "move": "midnight", "result": "ankle_breaker"})
	assert_true(g.broken)
	assert_true(brain.actor.is_shook())
	_run(d, 3)
	assert_eq((d["ctl"] as DuelController).duel.state, PossessionDuel.GAME_POINT, "perfect crossover -> SHOOK -> GAME POINT")
	(d["sim"] as CombatSim).dispose()


func test_garden_gate_needs_five_stubs() -> void:
	assert_false(Endings.garden_open())
	for id: String in ["city_chainlink", "city_suspension", "city_primetime", "city_gator"]:
		GameState.garden_tickets.append(id)
	assert_false(Endings.garden_open())
	GameState.garden_tickets.append("city_gargoyle")
	assert_true(Endings.garden_open())
	assert_true(JU.strs(JU.dict(MapParser.load_map("city_midtown").side, "fights"), "X").has("fin_midnight"), "the Garden is in Midtown")


func test_deuce_three_and_pops() -> void:
	GameState.set_flag("beat_challenger_deuce_1")
	GameState.set_flag("beat_challenger_deuce_2")
	assert_eq(Questlines.next_deuce(), 0)
	for i: int in 5:
		GameState.garden_tickets.append("t%d" % i)
	assert_eq(Questlines.next_deuce(), 3, "in the Garden tunnel")
	var lay: Dictionary = {"start": Vector3.ZERO, "stations": [], "npcs": []}
	DistrictBindings._quest_extras(MapParser.load_map("bk_coney"), lay)
	assert_true(JU.a(lay, "npcs").is_empty(), "duel 3 only in Midtown")
	DistrictBindings._quest_extras(MapParser.load_map("city_midtown"), lay)
	assert_eq(JU.s(JU.a(lay, "npcs")[0] as Dictionary, "id"), "npc_deuce_3")
	GameState.set_flag("pops_one_more_run")
	var lay2: Dictionary = {"start": Vector3.ZERO, "stations": [], "npcs": []}
	DistrictBindings._quest_extras(MapParser.load_map("bk_bedstuy"), lay2)
	var pops: bool = false
	for sp: Variant in JU.a(lay2, "specials"):
		pops = pops or JU.s(sp as Dictionary, "boss") == "opt_pops"
	assert_true(pops, "Pops waits on your home court")
	var r: Dictionary = BossSim.run("opt_pops", 6, {"god": true, "max_s": 900, "seed": 2})
	assert_eq(str(r["result"]), "victory", "Pops in his prime: %s" % r)


func test_endings_and_ng_plus() -> void:
	GameState.award_crown("brooklyn")
	Endings.daybreak()
	assert_true(GameState.has_flag("ending_daybreak"))
	assert_true(GameState.has_flag("dawn"), "the overworld stays at dawn")
	Endings.ng_plus_after_daybreak()
	assert_eq(GameState.ng_cycle, 1, "NG+ from Daybreak")
	assert_false(GameState.has_flag("dawn"), "the night returns in NG+")
	assert_true(GameState.crowns.is_empty())
	GameState.new_run("two_way", "queens")
	Endings.overtime()
	assert_true(GameState.has_flag("ending_overtime"))
	assert_eq(GameState.item_count("crown_midnight"), 1, "you take his crown")
	assert_eq(GameState.ng_cycle, 1, "Overtime starts NG+ immediately")
	assert_eq(TierManager.tier_of("queens"), 3)
