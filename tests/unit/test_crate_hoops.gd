extends GutTest
## M2: crate hoops — Bucket Blast radius and 20 s cooldown, first-make tokens.

var w: SimWorld
var sys: BallSystem
var events: Array[Dictionary] = []


func before_each() -> void:
	w = SimFixture.world()
	sys = SimFixture.with_balls(w)
	events.clear()
	w.sim_event.connect(func(ev: Dictionary) -> void: events.append(ev))


func after_each() -> void:
	w.dispose()


func _count(type: String) -> int:
	var n: int = 0
	for e: Dictionary in events:
		if str(e["type"]) == type:
			n += 1
	return n


func test_blast_radius_selects_targets() -> void:
	var near: SimActor = SimFixture.dummy(w, Vector3(5.9, 0, 0))
	var far: SimActor = SimFixture.dummy(w, Vector3(6.2, 0, 0))
	var ally: SimActor = SimFixture.dummy(w, Vector3(1, 0, 0))
	ally.team = 0
	var t: Array[int] = BucketBlast.targets(w, Vector3.ZERO, 6.0, 0)
	assert_true(t.has(near.id))
	assert_false(t.has(far.id))
	assert_false(t.has(ally.id))


func test_make_in_combat_fires_blast_then_cooldown() -> void:
	var hoop: SimHoop = sys.add_hoop(SimHoop.crate("c1", Vector3(0, 0, -5), Vector3(0, 0, 1)))
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	SimFixture.dummy(w, Vector3(2, 0, -3))
	assert_true(sys.in_combat(h.actor))
	sys.fire_bucket_blast(hoop, h.actor)
	assert_eq(_count("bucket_blast"), 1)
	assert_false(hoop.is_ready())
	assert_almost_eq(hoop.cooldown_s, 20.0, 0.001)
	w.step_n(60 * 19)
	assert_false(hoop.is_ready(), "still cooling at 19 s")
	w.step_n(61)
	assert_true(hoop.is_ready(), "ready after 20 s")


func test_shot_make_triggers_blast_only_when_ready() -> void:
	var hoop: SimHoop = sys.add_hoop(SimHoop.crate("c1", Vector3(0, 0, -4), Vector3(0, 0, 1)))
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	SimFixture.dummy(w, Vector3(3, 0, -3))
	sys.shoot(h.actor, hoop, "PERFECT", "mid")
	w.step_n(120)
	assert_eq(_count("bucket_blast"), 1)
	sys.shoot(h.actor, hoop, "PERFECT", "mid")
	w.step_n(120)
	assert_eq(_count("shot_made"), 2)
	assert_eq(_count("bucket_blast"), 1, "second make during cooldown: no blast")


func test_first_make_out_of_combat_pays_tokens_once() -> void:
	var hoop: SimHoop = sys.add_hoop(SimHoop.crate("c1", Vector3(0, 0, -4), Vector3(0, 0, 1)))
	hoop.tier = 3
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	sys.shoot(h.actor, hoop, "GOOD", "mid")
	w.step_n(120)
	sys.shoot(h.actor, hoop, "GOOD", "mid")
	w.step_n(120)
	assert_eq(_count("crate_first_make"), 1)
	for e: Dictionary in events:
		if str(e["type"]) == "crate_first_make":
			assert_eq(int(e["tokens"]), 75, "25 x tier 3")
	assert_eq(_count("bucket_blast"), 0)


func test_beach_ball_doubles_blast_radius() -> void:
	var hoop: SimHoop = sys.add_hoop(SimHoop.crate("c1", Vector3(0, 0, 0), Vector3(0, 0, 1)))
	var h: Hooper = SimFixture.ball_hooper(w, sys, Vector3(0, 0, 3))
	h.actor.flags["bucket_blast_radius_mult"] = 2.0
	var d: SimActor = SimFixture.dummy(w, Vector3(10, 0, 0))
	var t: Array[int] = sys.fire_bucket_blast(hoop, h.actor)
	assert_true(t.has(d.id))
