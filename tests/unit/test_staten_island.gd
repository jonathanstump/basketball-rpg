extends BoroughTest
## M9c: Staten Island — The Ferryman (tide, waves, overboard, undertow), The
## General (cannon backfire, Dismount), King of the Heap (armor, gull shot
## clock), three districts per spec §4.4/§4.5.

const BOSSES: PackedStringArray = ["si_ferryman", "si_general", "si_heap"]


func before_each() -> void:
	GameState.new_run("two_way", "staten_island")


func _duel(boss_id: String, tier: int) -> Dictionary:
	var sim: CombatSim = CombatSim.new(3)
	sim.combat.damage.hitstop_enabled = false
	var data: Dictionary = DataDB.boss(boss_id)
	var lay: Dictionary = ArenaBuilder.build(sim.world, sim.balls, data, null)
	var p: Hooper = sim.hooper(lay["player_start"])
	var boss: SimActor = BossFactory.spawn(sim.world, sim.combat, sim.balls, boss_id, lay["boss_spot"], tier, lay["hoop"])
	var ctl: DuelController = DuelController.new(sim.world, sim.balls, sim.combat, boss, p.actor, lay["hoop"], data, lay)
	ctl.start()
	return {"sim": sim, "p": p, "boss": boss, "ctl": ctl, "brain": boss.controller, "lay": lay}


func _run(d: Dictionary, frames: int) -> void:
	for _i: int in frames:
		(d["sim"] as CombatSim).run(1)
		(d["ctl"] as DuelController).step()


func test_boss_data() -> void:
	check_boss_data(BOSSES, "si_heap", "staten_island")


func test_boss_sims_t1_t3_t5() -> void:
	sim_tiers(BOSSES)


func test_districts() -> void:
	check_districts(["si_st_george", "si_narrows", "si_heap"], ["Gus", "Rocco", "Pickles", "Ferry"])


func test_ferryman_tide_wave_and_overboard() -> void:
	var d: Dictionary = _duel("si_ferryman", 1)
	var brain: BossBrain = d["brain"]
	var g: FerrymanGimmick = brain.gimmick as FerrymanGimmick
	var p: SimActor = (d["p"] as Hooper).actor
	_run(d, 90)
	brain.target = p
	g.tide_s = 0.01
	var x0: float = p.pos.x
	_run(d, 3)
	assert_ne(g.tilt_dir, Vector3.ZERO, "the deck tilts")
	assert_gt(absf(p.pos.x - x0), 1.0, "the wave pushed you")
	var hp0: float = p.hp
	p.pos = Vector3(g.half.x + 2.5, 0, 0)
	g._check_overboard(p)
	assert_eq(g.overboards, 1)
	assert_lt(p.hp, hp0, "overboard hurts")
	assert_lt(absf(p.pos.x), g.half.x, "back on deck")
	(d["sim"] as CombatSim).dispose()


func test_general_cannon_backfire_and_dismount() -> void:
	var d: Dictionary = _duel("si_general", 3)
	var sim: CombatSim = d["sim"]
	var brain: BossBrain = d["brain"]
	var g: GeneralGimmick = brain.gimmick as GeneralGimmick
	sim.world.emit("arena_event", {"actor": brain.actor.id, "event": "volley", "move": {}})
	assert_true(g.fuses_lit())
	var comp0: float = brain.actor.composure.value
	var hp0: float = brain.actor.hp
	var ball: SimBall = sim.balls.balls[0]
	ball.set_state(SimBall.State.PASS)
	ball.passer_id = (d["p"] as Hooper).actor.id
	ball.pos = g.cannons[0] + Vector3(0, 1, 0)
	g.on_step(brain)
	assert_eq(g.backfires, 1, "a pass into a lit cannon backfires")
	assert_true(brain.actor.composure.value > comp0 or brain.actor.composure.broken != "", "big composure hit")
	assert_lt(brain.actor.hp, hp0)
	sim.world.emit("duel_phase_changed", {"phase": 2})
	assert_eq(g.split.parts.size(), 1, "the horse splits off")
	sim.dispose()


func test_heap_armor_and_gull_shot_clock() -> void:
	var d: Dictionary = _duel("si_heap", 1)
	var brain: BossBrain = d["brain"]
	var g: HeapGimmick = brain.gimmick as HeapGimmick
	var boss: SimActor = d["boss"]
	assert_gt(float(boss.flags["armor"]), 0.0, "starts armored")
	var hp0: float = boss.hp
	(d["sim"] as CombatSim).combat.damage.apply_raw(boss, 100.0)
	assert_almost_eq(boss.hp, hp0, 0.01, "armor soaks first")
	var p: SimActor = (d["p"] as Hooper).actor
	brain.target = p
	_run(d, 80)
	assert_eq((d["ctl"] as DuelController).duel.state, PossessionDuel.PLAYER_OFFENSE)
	assert_true(p.has_ball)
	_run(d, int(6.2 * 60.0))
	assert_gt(g.snatches, 0, "held 6 s: the gulls took it")
	(d["sim"] as CombatSim).dispose()


func test_summons_leave_after_their_duration() -> void:
	var sim: CombatSim = CombatSim.new()
	var a: SimActor = EnemyFactory.spawn(sim.world, sim.combat, sim.balls, "ball_hog", Vector3.ZERO, 1)
	a.flags["despawn_frame"] = sim.world.frame + 30
	sim.run(31)
	assert_false(a.alive, "timed summon left")
	sim.dispose()
