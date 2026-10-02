extends GutTest
## M8: The Barker (mirror clones, Shell Game, Tilt) and The Toll (Pay Up
## booth, strip spill, Toll Gate, Rush Hour), plus boss sims for all three
## Brooklyn bosses at Tier 1 and Tier 5.

const BROOKLYN: PackedStringArray = ["bk_stoop", "bk_barker", "bk_toll"]


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
	return {"sim": sim, "p": p, "boss": boss, "ctl": ctl, "lay": lay, "brain": boss.controller}


func test_brooklyn_boss_data_complete() -> void:
	for id: String in BROOKLYN:
		var b: Dictionary = DataDB.boss(id)
		assert_false(b.is_empty(), id)
		for ph: Variant in JU.a(b, "phases"):
			for m: Variant in JU.a(ph as Dictionary, "moves"):
				assert_false(DataDB.move(id, str(m)).is_empty(), "%s move %s" % [id, m])
		assert_false(DataDB.move(id, JU.s(JU.dict(b, "t5_event"), "move")).is_empty(), "%s T5 move" % id)
		for d: String in JU.strs(b, "drops"):
			assert_ne(DataDB.catalog_of(d), "", "%s drop %s exists" % [id, d])
	assert_eq(JU.s(DataDB.boss("bk_toll"), "kind"), "king")
	assert_true(JU.strs(DataDB.boss("bk_toll"), "drops").has("crown_brooklyn"))


func test_barker_clones_spawn_and_shatter_roots_player() -> void:
	var d: Dictionary = _duel("bk_barker", 1)
	var sim: CombatSim = d["sim"]
	var brain: BossBrain = d["brain"]
	var g: BarkerGimmick = brain.gimmick as BarkerGimmick
	assert_not_null(g)
	brain.run_event_move("step_right_up")
	sim.run(40)
	assert_eq(g.clones.size(), 3, "Step Right Up: 3 clones")
	var c: SimActor = g.clones[0]
	var p: SimActor = (d["p"] as Hooper).actor
	sim.world.emit("hit_resolved", {"attacker": p.id, "target": c.id, "result": "hit", "move": "strike_1"})
	assert_eq(g.clones.size(), 2, "clone shattered")
	assert_true(StatusEffects.has(p, "rooted"), "hitting a clone stuns you")
	sim.run(31)
	assert_false(StatusEffects.has(p, "rooted"), "stun lasts 0.5 s")
	sim.world.emit("duel_check", {})
	assert_eq(g.clones.size(), 0, "clones clear on CHECK")
	sim.dispose()


func test_barker_tilt_slides_player_in_phase_2() -> void:
	var d: Dictionary = _duel("bk_barker", 3)
	var sim: CombatSim = d["sim"]
	var brain: BossBrain = d["brain"]
	brain.set_phase(2)
	var g: BarkerGimmick = brain.gimmick as BarkerGimmick
	g.tilt_timer_s = 0.01
	var p: SimActor = (d["p"] as Hooper).actor
	brain.target = p
	var before: Vector3 = p.pos
	sim.run(60)
	assert_ne(g.tilt_dir, Vector3.ZERO)
	assert_gt(p.pos.distance_to(before), 0.5, "the floor slid you")
	sim.dispose()


func test_toll_pay_up_and_strip_spill() -> void:
	GameState.tokens = 1000
	var d: Dictionary = _duel("bk_toll", 1)
	var sim: CombatSim = d["sim"]
	var boss: SimActor = d["boss"]
	var p: SimActor = (d["p"] as Hooper).actor
	var g: TollGimmick = (d["brain"] as BossBrain).gimmick as TollGimmick
	sim.world.emit("hit_resolved", {"attacker": boss.id, "target": p.id, "result": "hit", "move": "pay_up"})
	assert_eq(GameState.tokens, 900, "Pay Up takes 10%")
	assert_eq(g.booth, 100)
	assert_true(g.booth_glowing())
	sim.world.emit("hit_resolved", {"attacker": p.id, "target": boss.id, "result": "strip", "move": "reach_in"})
	assert_eq(GameState.tokens, 1000, "strip while glowing spills them back")
	assert_eq(g.booth, 0)
	sim.world.emit("hit_resolved", {"attacker": boss.id, "target": p.id, "result": "hit", "move": "pay_up"})
	sim.run(6 * 60 + 2)
	assert_false(g.booth_glowing(), "glow fades after 6 s")
	sim.world.emit("hit_resolved", {"attacker": p.id, "target": boss.id, "result": "strip", "move": "reach_in"})
	assert_eq(g.booth, 100, "no spill once the glow is gone")
	sim.dispose()


func test_toll_gate_blocks_then_drops() -> void:
	var d: Dictionary = _duel("bk_toll", 1)
	var sim: CombatSim = d["sim"]
	var brain: BossBrain = d["brain"]
	var g: TollGimmick = brain.gimmick as TollGimmick
	brain.target = (d["p"] as Hooper).actor
	g.raise_gate(6.0)
	assert_eq(_live_gate_blocks(sim), 1, "gate up")
	sim.run(6 * 60 + 2)
	assert_eq(_live_gate_blocks(sim), 0, "gate down after 6 s")
	sim.dispose()


func _live_gate_blocks(sim: CombatSim) -> int:
	var n: int = 0
	for blk: Dictionary in sim.world.collision.blocks:
		if str(blk["tag"]) == "toll_gate" and float(blk["top"]) > 0.0:
			n += 1
	return n


func test_toll_rush_hour_glare_shrinks_shot_window() -> void:
	var d: Dictionary = _duel("bk_toll", 3)
	var sim: CombatSim = d["sim"]
	var brain: BossBrain = d["brain"]
	brain.set_phase(2)
	var g: TollGimmick = brain.gimmick as TollGimmick
	var p: SimActor = (d["p"] as Hooper).actor
	brain.target = p
	g.beam_timer_s = 0.01
	var glared: bool = false
	for _i: int in 240:
		sim.run(1)
		glared = glared or StatusEffects.has(p, "glare")
	assert_true(glared, "headlight beam swept over the player")
	sim.dispose()


func test_boss_sims_t1_and_t5() -> void:
	for id: String in BROOKLYN:
		var r1: Dictionary = BossSim.run(id, 1, {"god": true, "max_s": 600, "seed": 2})
		gut.p("SIM %s T1: %s in %.0fs makes=%d boss_hp=%.2f" % [id, r1["result"], r1["time_s"], int((r1["stats"] as Dictionary)["makes"]), r1["boss_hp_ratio"]])
		assert_eq(str(r1["result"]), "victory", "%s T1 bot wins: %s" % [id, r1])
		assert_eq((r1["phases_seen"] as Array).size(), 1, "%s T1 phase 1 only" % id)
		var r5: Dictionary = BossSim.run(id, 5, {"god": true, "max_s": 600, "seed": 2})
		gut.p("SIM %s T5: %s in %.0fs makes=%d boss_hp=%.2f" % [id, r5["result"], r5["time_s"], int((r5["stats"] as Dictionary)["makes"]), r5["boss_hp_ratio"]])
		assert_eq(str(r5["result"]), "victory", "%s T5 bot (god) wins: %s" % [id, r5])
		assert_true((r5["phases_seen"] as Array).has(2), "%s T5 reaches phase 2" % id)
		assert_gt(int((r5["events"] as Dictionary).get("t5_event", 0)), 0, "%s T5 event fires" % id)
