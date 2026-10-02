extends BoroughTest
## M9d: Uptown — The Hook (applause meter, spotlight hunt), The Coop King
## (swarm disperse, exposed core), High Rise (reach, stepbacks, storm), three
## districts per spec §4.4/§4.5.

const BOSSES: PackedStringArray = ["up_hook", "up_coop", "up_highrise"]


func before_each() -> void:
	GameState.new_run("two_way", "uptown")


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
	check_boss_data(BOSSES, "up_highrise", "uptown")


func test_boss_sims_t1_t3_t5() -> void:
	sim_tiers(BOSSES)


func test_districts() -> void:
	check_districts(["up_harlem", "up_heights", "up_mecca"], ["Duke", "Sugar", "Smokey", "Lady"])


func test_hook_applause_and_boos() -> void:
	var d: Dictionary = _duel("up_hook", 1)
	var sim: CombatSim = d["sim"]
	var brain: BossBrain = d["brain"]
	var g: HookGimmick = brain.gimmick as HookGimmick
	var p: SimActor = (d["p"] as Hooper).actor
	brain.target = p
	for _i: int in 7:
		sim.world.emit("shot_missed", {"actor": p.id, "grade": "BRICK", "rebound_pos": Vector3.ZERO, "rebound_t": 0.5})
	assert_lt(g.meter, -90.0 + 100.0, "boos pile up")
	for _j: int in 8:
		sim.world.emit("hit_resolved", {"attacker": 9, "target": p.id, "result": "hit", "move": "x"})
	assert_eq(JU.s(brain.runner.move, "id"), "get_off_the_stage", "full boos: the hook comes out")
	g.meter = 90.0
	g.add(15.0)
	assert_true(brain.actor.is_shook(), "full applause: free SHOOK")
	sim.dispose()


func test_hook_spotlight_hunt() -> void:
	var d: Dictionary = _duel("up_hook", 3)
	var brain: BossBrain = d["brain"]
	var g: HookGimmick = brain.gimmick as HookGimmick
	brain.set_phase(2)
	g.spot = brain.actor.pos
	g.on_step(brain)
	assert_almost_eq(float(brain.actor.flags["damage_taken_mult"]), 1.0, 0.001, "lit: full damage")
	g.spot = brain.actor.pos + Vector3(8, 0, 0)
	g.on_step(brain)
	assert_almost_eq(float(brain.actor.flags["damage_taken_mult"]), HookGimmick.DARK_DAMAGE_MULT, 0.001, "in the dark: reduced")
	(d["sim"] as CombatSim).dispose()


func test_coop_disperse_and_core() -> void:
	var d: Dictionary = _duel("up_coop", 1)
	var sim: CombatSim = d["sim"]
	var brain: BossBrain = d["brain"]
	var g: CoopGimmick = brain.gimmick as CoopGimmick
	var p: SimActor = (d["p"] as Hooper).actor
	sim.world.emit("hit_resolved", {"attacker": p.id, "target": brain.actor.id, "result": "hit", "weight": "heavy", "move": "pound"})
	g.on_step(brain)
	assert_true(bool(brain.actor.flags["ghost"]), "a heavy hit disperses him (walk through)")
	assert_true(brain.actor.invulnerable)
	_run(d, 130)
	assert_false(bool(brain.actor.flags["ghost"]), "reforms in 2 s")
	sim.world.emit("ball_thrown", {"actor": brain.actor.id})
	assert_true(g.core_exposed())
	g.on_step(brain)
	assert_almost_eq(float(brain.actor.flags["damage_taken_mult"]), 3.0, 0.001, "core hits triple")
	sim.world.emit("hit_resolved", {"attacker": p.id, "target": brain.actor.id, "result": "hit", "weight": "light", "move": "pound"})
	assert_true(brain.actor.is_shook(), "core hit: full composure")
	sim.dispose()


func test_highrise_reach_and_stepback() -> void:
	var d: Dictionary = _duel("up_highrise", 1)
	var sim: CombatSim = d["sim"]
	var brain: BossBrain = d["brain"]
	var g: HighRiseGimmick = brain.gimmick as HighRiseGimmick
	var p: SimActor = (d["p"] as Hooper).actor
	brain.target = p
	g.on_step(brain)
	assert_almost_eq(brain.actor.contest_radius, HighRiseGimmick.REACH_RADIUS, 0.001, "reach covers the court")
	sim.world.emit("action_started", {"actor": p.id, "move": "stepback"})
	g.on_step(brain)
	assert_lt(brain.actor.contest_radius, HighRiseGimmick.REACH_RADIUS, "a stepback beats the reach")
	sim.dispose()


func test_zones_chip_without_flinching() -> void:
	var sim: CombatSim = CombatSim.new()
	var h: Hooper = sim.hooper()
	h.on_hit({"result": "hit", "no_flinch": true, "damage": 5.0, "weight": "light"})
	assert_eq(h.action, "", "puddles and rain don't stunlock")
	sim.dispose()
