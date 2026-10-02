extends GutTest
## M4: ChallengerBrain drives a Hooper through ActorInput (spec §15.9).


func test_challenger_shoots_and_scores_when_open() -> void:
	var sim: CombatSim = CombatSim.new(5)
	var hoop: SimHoop = sim.balls.add_hoop(SimHoop.regulation("h", Vector3(0, 0, -10), Vector3(0, 0, 1)))
	var c: Hooper = sim.hooper(Vector3(0, 0, 0), {}, true, 1)
	var brain: ChallengerBrain = ChallengerBrain.for_tier(7)
	brain.hoop_id = hoop.id
	c.actor.input_source = brain
	var far: Hooper = sim.hooper(Vector3(40, 0, 40), {}, false, 0)
	far.actor.flags["cannot_die"] = true
	sim.run(60 * 20)
	assert_gt(sim.count("shot_released"), 0, "took shots")
	assert_gt(sim.count("shot_made"), 0, "high-skill challenger scores")
	sim.dispose()


func test_challenger_crosses_up_telegraphs() -> void:
	var sim: CombatSim = CombatSim.new(9)
	sim.combat.damage.hitstop_enabled = false
	var c: Hooper = sim.hooper(Vector3(0, 0, 1.6), {}, true, 0)
	c.actor.flags["cannot_die"] = true
	var brain: ChallengerBrain = ChallengerBrain.for_tier(7)
	brain.aggressive = false
	brain.passive_frames = 99999
	c.actor.input_source = brain
	var d: TrainingDummy = sim.dummy(Vector3.ZERO, "attack")
	d.trigger_range = 6.0
	sim.run(60 * 25)
	var ankles: int = 0
	for r: String in sim.results():
		if r == "ankle_breaker":
			ankles += 1
	assert_gt(ankles, 0, "reads windups and breaks ankles")
	sim.dispose()


func test_skill_scales_with_tier() -> void:
	assert_lt(ChallengerBrain.for_tier(1).skill, ChallengerBrain.for_tier(5).skill)
	assert_lte(ChallengerBrain.for_tier(7).skill, 0.98)
