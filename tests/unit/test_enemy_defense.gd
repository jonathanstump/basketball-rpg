extends GutTest
## Revision 12: punch spam isn't free. Street enemies parry, dodge or counter
## once a string of hits builds up; critters and bosses don't.

var sim: CombatSim
var p: Hooper


func before_each() -> void:
	sim = CombatSim.new()
	sim.combat.damage.hitstop_enabled = false
	GameState.new_run("two_way", "brooklyn")
	p = sim.hooper(Vector3.ZERO, {}, false)


func after_each() -> void:
	sim.dispose()


func _punch(t: SimActor) -> Dictionary:
	var hb: Hitbox = Hitbox.new()
	hb.owner_id = p.actor.id
	hb.team = 0
	hb.move_id = "jab"
	hb.damage = 30.0
	hb.weight = "light"
	return sim.combat.damage.resolve(hb, t)


func _enemy(only: String = "", base: float = 1.0) -> SimActor:
	var a: SimActor = sim.enemy("ball_hog", Vector3(0, 0, -1.2), 1)
	a.hp = 9999.0
	a.hp_max = 9999.0
	var d: EnemyDefense = sim.brain(a).defense
	d.cfg = d.cfg.duplicate(true)
	d.cfg["base"] = base
	if only != "":
		d.cfg["weights"] = {"parry": 1.0 if only == "parry" else 0.0, "dodge": 1.0 if only == "dodge" else 0.0, "counter": 1.0 if only == "counter" else 0.0}
	return a


func test_chance_grows_with_the_streak_and_tier() -> void:
	var c: Dictionary = JU.dict(DataDB.tuning("ai"), "defense")
	var need: int = JU.i(c, "min_hits", 3)
	assert_eq(EnemyDefense.chance(c, need - 1, 1, 1.0), 0.0, "a couple of hits are free")
	assert_gt(EnemyDefense.chance(c, need, 1, 1.0), 0.0, "street tier defends too")
	assert_gt(EnemyDefense.chance(c, need + 2, 1, 1.0), EnemyDefense.chance(c, need, 1, 1.0))
	assert_gt(EnemyDefense.chance(c, need, 5, 1.0), EnemyDefense.chance(c, need, 1, 1.0))
	assert_lte(EnemyDefense.chance(c, 50, 7, 3.0), JU.f(c, "max", 0.85))


func test_no_reaction_before_the_streak() -> void:
	var a: SimActor = _enemy()
	var need: int = JU.i(sim.brain(a).defense.cfg, "min_hits", 3)
	for i: int in need - 1:
		assert_eq(str(_punch(a)["result"]), "hit")
	assert_eq(sim.brain(a).defense.reaction, "")
	assert_gt(sim.brain(a).stun_frames, 0, "still flinching")


func test_parry_deflects_the_next_punch_then_counters() -> void:
	var a: SimActor = _enemy("parry")
	var b: EnemyBrain = sim.brain(a)
	for i: int in JU.i(b.defense.cfg, "min_hits", 3):
		_punch(a)
	assert_eq(b.defense.reaction, "parry")
	assert_eq(b.stun_frames, 0, "the parry cancels the hitstun")
	assert_true(bool(a.flags.get("parry_window", false)))
	assert_eq(str(_punch(a)["result"]), "deflect", "your next punch bounces off")
	assert_eq(b.defense.reaction, "counter")
	assert_true(b.runner.running, "it swings right back")
	assert_true(a.hyper_armor)


func test_dodge_slides_out_of_the_string() -> void:
	var a: SimActor = _enemy("dodge")
	var b: EnemyBrain = sim.brain(a)
	for i: int in JU.i(b.defense.cfg, "min_hits", 3):
		_punch(a)
	assert_eq(b.defense.reaction, "dodge")
	assert_eq(str(_punch(a)["result"]), "dodged")
	var p0: Vector3 = a.pos
	sim.run(10)
	assert_gt(a.pos.distance_to(p0), 0.8, "slid away")
	sim.run(20)
	assert_false(a.invulnerable, "i-frames end")
	assert_eq(b.defense.reaction, "")


func test_counter_attacks_through_it() -> void:
	var a: SimActor = _enemy("counter")
	var b: EnemyBrain = sim.brain(a)
	for i: int in JU.i(b.defense.cfg, "min_hits", 3):
		_punch(a)
	assert_eq(b.defense.reaction, "counter")
	assert_true(b.runner.running)
	assert_eq(str(_punch(a)["result"]), "hit")
	assert_true(b.runner.running, "hyper armor: your punch doesn't stop it")


func test_cooldown_between_reactions() -> void:
	var a: SimActor = _enemy("counter")
	var b: EnemyBrain = sim.brain(a)
	for i: int in JU.i(b.defense.cfg, "min_hits", 3):
		_punch(a)
	b.runner.interrupt()
	b.defense.reaction = ""
	for i2: int in 6:
		_punch(a)
	assert_eq(b.defense.reaction, "", "not again so soon")


func test_critters_dont_defend() -> void:
	for id: Variant in DataDB.catalog("enemies").keys():
		var d: Dictionary = DataDB.enemy(str(id))
		if JU.s(d, "kind") == "critter":
			assert_false(EnemyDefense.new(DataDB.tuning("ai"), d).enabled, str(id))
