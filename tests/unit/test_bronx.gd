extends BoroughTest
## M9a: The Bronx — King Crab, Silverback, Grandmaster Boom (+ BeatClock),
## three districts per spec §4.4/§4.5.

const BOSSES: PackedStringArray = ["bx_crab", "bx_silverback", "bx_boom"]


func before_each() -> void:
	GameState.new_run("two_way", "bronx")


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


func test_boss_data() -> void:
	check_boss_data(BOSSES, "bx_boom", "bronx")


func test_boss_sims_t1_t3_t5() -> void:
	sim_tiers(BOSSES)


func test_districts() -> void:
	check_districts(["bx_mott_haven", "bx_west_farms", "bx_highbridge"], ["Papi", "Chulo", "Biscuit", "Mami"])


func test_beat_clock() -> void:
	var c: BeatClock = BeatClock.new(92.0, 0)
	assert_almost_eq(c.frames_per_beat(), 3600.0 / 92.0, 0.001)
	assert_true(c.is_beat_frame(0) or c.beat_index(0) == 0)
	assert_eq(c.beat_in_bar(0), 1)
	assert_eq(c.beat_in_bar(int(ceil(c.frames_per_beat() * 1.0))), 2)
	assert_true(c.is_on_beat(int(round(c.frames_per_beat() * 3.0)), 2))
	assert_false(c.is_on_beat(int(round(c.frames_per_beat() * 3.5)), 6), "half a beat off")
	var f: int = 100
	var w: int = c.frames_to_next_beat(f)
	assert_true(c.is_on_beat(f + w, 1), "frames_to_next_beat lands on a beat")
	var b_before: int = c.beat_index(500)
	c.set_bpm(100.0, 500)
	assert_eq(c.beat_index(500), b_before, "tempo change keeps the count")


func test_shell_up_blocks_front_not_flank() -> void:
	var d: Dictionary = _duel("bx_crab", 1)
	var sim: CombatSim = d["sim"]
	var boss: SimActor = d["boss"]
	var p: SimActor = (d["p"] as Hooper).actor
	(d["brain"] as BossBrain).run_event_move("shell_up")
	sim.run(14)
	assert_eq(float(boss.flags.get("guard_chip", 1.0)), 0.0)
	assert_almost_eq(float(boss.flags.get("turn_mult", 1.0)), 0.25, 0.001, "turns slowly while shelled")
	p.pos = boss.pos + boss.forward() * 2.0
	var hp0: float = boss.hp
	var hb: Hitbox = Hitbox.new()
	hb.owner_id = p.id
	hb.team = 0
	hb.damage = 100.0
	hb.volume = HitVolume.from_dict({"shape": "sphere", "radius": 3.0})
	hb.volume.origin = boss.pos
	hb.world_space = true
	var res: Dictionary = sim.combat.damage.resolve(hb, boss)
	assert_eq(str(res["result"]), "guarded")
	assert_almost_eq(boss.hp, hp0, 0.001, "frontal damage fully blocked")
	p.pos = boss.pos - boss.forward() * 2.0
	var res2: Dictionary = sim.combat.damage.resolve(hb, boss)
	assert_eq(str(res2["result"]), "hit", "flank/back hits land")
	sim.dispose()


func test_chest_pound_buffs_damage() -> void:
	var d: Dictionary = _duel("bx_silverback", 1)
	var sim: CombatSim = d["sim"]
	var brain: BossBrain = d["brain"]
	var boss: SimActor = d["boss"]
	brain.run_event_move("chest_pound")
	sim.run(140)
	assert_gt(sim.world.frame, 0)
	assert_almost_eq(float(boss.flags.get("buff_mult", 0.0)), 1.2, 0.001, "+20% after a finished Chest Pound")
	assert_gt(int(boss.flags.get("buff_until", -1)), sim.world.frame)
	brain.runner.start(DataDB.move("bx_silverback", "ground_slam"), null)
	var buffed: float = brain.runner.damage()
	boss.flags["buff_until"] = -1
	assert_almost_eq(buffed / brain.runner.damage(), 1.2, 0.01)
	sim.dispose()


func test_boom_attacks_land_on_the_beat_and_on_beat_hype() -> void:
	var d: Dictionary = _duel("bx_boom", 1)
	var sim: CombatSim = d["sim"]
	var brain: BossBrain = d["brain"]
	var g: BoomGimmick = brain.gimmick as BoomGimmick
	assert_not_null(g)
	var actives: Array[int] = []
	sim.world.sim_event.connect(func(ev: Dictionary) -> void:
		if str(ev.get("type", "")) == "move_started" and int(ev["actor"]) == brain.actor.id:
			var m: Dictionary = DataDB.move("bx_boom", str(ev["move"]))
			actives.append(int(ev["frame"]) + JU.i(m, "startup") + 1))
	_run(d, 60 * 20)
	assert_gt(actives.size(), 0, "Boom attacked")
	for f: int in actives:
		assert_true(g.clock.is_on_beat(f, 2), "active frame %d on the beat" % f)
	var p: SimActor = (d["p"] as Hooper).actor
	var h0: float = p.hype.value
	sim.world.frame = g.clock.origin_frame + int(round(g.clock.frames_per_beat() * 40.0))
	sim.world.emit("action_started", {"actor": p.id, "move": "crossover"})
	assert_almost_eq(p.hype.value - h0, 5.0, 0.01, "ON BEAT +5 Hype")
	sim.dispose()


func test_boom_speakers_and_rewind() -> void:
	var d: Dictionary = _duel("bx_boom", 3)
	var sim: CombatSim = d["sim"]
	var brain: BossBrain = d["brain"]
	var g: BoomGimmick = brain.gimmick as BoomGimmick
	g.spawn_speakers()
	assert_eq(g.speakers.size(), 2)
	var rings: Array[int] = []
	sim.world.sim_event.connect(func(ev: Dictionary) -> void:
		if str(ev.get("type", "")) == "move_started" and str(ev["move"]) == "speaker_pulse":
			rings.append(int(ev["frame"])))
	_run(d, 60 * 6)
	assert_gt(rings.size(), 2, "speakers pulse on beats 2 and 4")
	for f: int in rings:
		var bar: int = g.clock.nearest_beat_in_bar(f + JU.i(DataDB.move("bx_boom", "speaker_pulse"), "startup") + 1)
		assert_true(bar == 2 or bar == 4, "pulse lands on beat %d" % bar)
	g.speakers[0].hp = 0.0
	sim.run(2)
	assert_eq(g.speakers.size(), 1, "a destroyed tower stops")
	brain.history = ["bass_drop", "scratch", "mic_toss", "sample"]
	sim.world.emit("mirror_requested", {"actor": brain.actor.id, "move": "rewind"})
	assert_eq(g.queue, ["sample", "mic_toss", "scratch"] as Array[String], "last three, reversed")
	sim.world.emit("arena_event", {"actor": brain.actor.id, "event": "breakbeat", "move": {"duration_s": 10}})
	assert_true(g.offbeat(), "Breakbeat: off-beat for 10 s")
	sim.dispose()
