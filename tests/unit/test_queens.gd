extends BoroughTest
## M9b: Queens — The Express (lanes, Decouple), Extra Sauce (sauce zones),
## Atlas (orbit rings, rolling globe), three districts per spec §4.4/§4.5.

const BOSSES: PackedStringArray = ["qn_express", "qn_sauce", "qn_atlas"]


func before_each() -> void:
	GameState.new_run("two_way", "queens")


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
	check_boss_data(BOSSES, "qn_atlas", "queens")


func test_boss_sims_t1_t3_t5() -> void:
	sim_tiers(BOSSES)


func test_districts() -> void:
	check_districts(["qn_roosevelt", "qn_astoria", "qn_flushing"], ["Momo", "Mango", "Saffron", "Taco"])


func test_express_charges_run_on_lanes() -> void:
	var d: Dictionary = _duel("qn_express", 1)
	var brain: BossBrain = d["brain"]
	var p: SimActor = (d["p"] as Hooper).actor
	p.pos = brain.actor.pos + Vector3(3.0, 0, 5.0)
	brain.target = p
	brain.run_event_move("express_charge")
	_run(d, 40)
	var dir: Vector3 = brain.runner.dir
	assert_true(is_zero_approx(dir.x) or is_zero_approx(dir.z), "charge snapped to a lane axis: %s" % dir)
	(d["sim"] as CombatSim).dispose()


func test_express_decouple_shares_hp() -> void:
	var d: Dictionary = _duel("qn_express", 3)
	var sim: CombatSim = d["sim"]
	var brain: BossBrain = d["brain"]
	var g: ExpressGimmick = brain.gimmick as ExpressGimmick
	sim.world.emit("duel_phase_changed", {"phase": 2})
	assert_eq(g.cars.size(), 2, "two cars break off")
	var hp0: float = brain.actor.hp
	sim.world.emit("hit_resolved", {"attacker": (d["p"] as Hooper).actor.id, "target": g.cars[0].id, "result": "hit", "damage": 50.0, "move": "pound"})
	assert_almost_eq(hp0 - brain.actor.hp, 50.0, 0.01, "damage to a car comes off the Express")
	sim.world.emit("arena_event", {"actor": brain.actor.id, "event": "rush_hour_crowd", "move": {}})
	var crowd: int = 0
	for blk: Dictionary in sim.world.collision.blocks:
		if str(blk["tag"]) == "crowd" and float(blk["top"]) > 0.0:
			crowd += 1
	assert_gt(crowd, 0, "commuters block lanes")
	sim.dispose()


func test_sauce_combo_needs_both_puddles() -> void:
	var d: Dictionary = _duel("qn_sauce", 1)
	var brain: BossBrain = d["brain"]
	var g: SauceGimmick = brain.gimmick as SauceGimmick
	var p: SimActor = (d["p"] as Hooper).actor
	brain.target = p
	StatusEffects.apply(p, {"slow": 2.0})
	_run(d, 5)
	assert_eq(g.combos, 0, "white alone: just slow")
	var w0: float = p.wind.value
	StatusEffects.apply(p, {"burn": 2.0})
	_run(d, 5)
	assert_eq(g.combos, 1, "both = the combo")
	assert_lt(p.wind.value, w0, "red sauce drains Wind")
	(d["sim"] as CombatSim).dispose()


func test_atlas_rings_jump_low_and_vanish_when_shook() -> void:
	var d: Dictionary = _duel("qn_atlas", 1)
	var brain: BossBrain = d["brain"]
	var g: AtlasGimmick = brain.gimmick as AtlasGimmick
	_run(d, 120)
	assert_eq(g.rings.size(), 3, "three orbit rings while live")
	var low: Hitbox = g.rings[0]
	var p: SimActor = (d["p"] as Hooper).actor
	p.pos = low.volume.origin + low.volume.fwd() * 3.0
	assert_true(low.volume.hits(p), "standing in the low ring's path gets hit")
	p.pos.y = 0.9
	assert_false(low.volume.hits(p), "jumping clears the low ring")
	brain.actor.composure.force_break("shook", 3.0)
	_run(d, 2)
	assert_eq(g.rings.size(), 0, "rings vanish while SHOOK")
	g.drop_globe()
	var g0: Vector3 = g.globe.volume.origin
	_run(d, 30)
	assert_gt(g.globe.volume.origin.distance_to(g0), 1.0, "the globe rolls")
	(d["sim"] as CombatSim).dispose()
