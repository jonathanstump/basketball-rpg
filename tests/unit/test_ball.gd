extends GutTest
## M2: ball state transitions, shooting through the meter, passes and ricochet
## rules, lobs, loose physics + pickup, lost-ball safety, Wire Kicks.

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


func _types() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for e: Dictionary in events:
		out.append(str(e["type"]))
	return out


func _ev(type: String) -> Dictionary:
	for e: Dictionary in events:
		if str(e["type"]) == type:
			return e
	return {}


func _hoop_ahead(dist: float) -> SimHoop:
	return sys.add_hoop(SimHoop.regulation("h1", Vector3(0, 0, -dist), Vector3(0, 0, 1)))


func _release_frame_for(meter_value: float, gather_s: float = 0.55) -> int:
	## Last held frame so the release lands on `meter_value`.
	return int(round(meter_value * gather_s * 60.0)) - 2


func test_held_ball_follows_holder() -> void:
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	SimFixture.script_of(h).move_at(0, Vector2(1, 0))
	w.step_n(30)
	var b: SimBall = sys.ball_of(h.actor)
	assert_eq(b.state, SimBall.State.HELD)
	assert_lt(b.pos.distance_to(h.actor.pos), 1.2)
	assert_true(h.actor.has_ball)


func test_perfect_shot_goes_in_and_returns() -> void:
	_hoop_ahead(5.0)
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	SimFixture.script_of(h).hold(0, _release_frame_for(0.82), "shoot")
	w.step_n(30)
	var mod: HooperBall = SimFixture.ball_module(h)
	assert_eq(mod.last_grade, "PERFECT", "release %.3f" % mod.last_release)
	assert_false(h.actor.has_ball, "ball in flight")
	w.step_n(90)
	assert_true(_types().has("shot_made"))
	assert_eq(str(_ev("shot_made")["zone"]), "mid")
	assert_true(h.actor.has_ball, "make returns the ball in the street")


func test_early_release_bricks_and_goes_loose() -> void:
	_hoop_ahead(5.0)
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	SimFixture.script_of(h).hold(0, 3, "shoot")
	w.step_n(10)
	assert_eq(SimFixture.ball_module(h).last_grade, "BRICK")
	w.step_n(80)
	assert_true(_types().has("shot_missed"))
	assert_false(_types().has("shot_made"))


func test_holding_past_full_auto_bricks() -> void:
	_hoop_ahead(5.0)
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	SimFixture.script_of(h).hold(0, 200, "shoot")
	w.step_n(40)
	assert_eq(SimFixture.ball_module(h).last_grade, "BRICK")
	assert_gte(SimFixture.ball_module(h).last_release, 1.0)


func test_near_miss_rims_out_with_rebound_event() -> void:
	_hoop_ahead(5.0)
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	SimFixture.script_of(h).hold(0, _release_frame_for(0.82 - 0.09), "shoot")
	w.step_n(100)
	assert_eq(SimFixture.ball_module(h).last_grade, "NEAR_MISS")
	var ev: Dictionary = _ev("shot_missed")
	assert_false(ev.is_empty())
	assert_true(ev.has("rebound_pos"))


func test_smothered_bad_shot_is_rejected_and_blocker_takes_ball() -> void:
	_hoop_ahead(5.0)
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	var d: SimActor = SimFixture.dummy(w, Vector3(0, 0, -0.6))
	d.facing = PI   # facing +Z toward the shooter
	d.contest_radius = 3.0
	SimFixture.script_of(h).hold(0, 3, "shoot")
	w.step_n(40)
	assert_eq(SimFixture.ball_module(h).last_grade, "REJECTED")
	assert_true(_types().has("shot_rejected"))
	assert_true(d.has_ball, "blocker took it")


func test_no_hoop_in_range_lobs() -> void:
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	var d: SimActor = SimFixture.dummy(w, Vector3(0, 0, -8))
	h.lock_target = d
	SimFixture.script_of(h).press_at(0, "shoot")
	w.step_n(90)
	assert_true(_types().has("lob_released"))
	var landed: Dictionary = _ev("lob_landed")
	assert_false(landed.is_empty())
	assert_true((landed["targets"] as Array).has(d.id), "lob splashed the target")


func test_chest_pass_hit_ricochets_back() -> void:
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	var d: SimActor = SimFixture.dummy(w, Vector3(0, 0, -6))
	SimFixture.script_of(h).press_at(0, "heavy")
	w.step_n(12)
	assert_true(_types().has("pass_released"))
	w.step_n(40)
	assert_eq(int(_ev("pass_hit")["target"]), d.id)
	assert_true(_types().has("pass_returned"))
	assert_true(h.actor.has_ball, "ricochet back to passer")


func test_chest_pass_miss_goes_loose() -> void:
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	SimFixture.script_of(h).press_at(0, "heavy")
	w.step_n(60)
	assert_true(_types().has("pass_missed"))
	assert_false(h.actor.has_ball)
	var b: SimBall = sys.balls[0]
	assert_true(b.state == SimBall.State.LOOSE or b.state == SimBall.State.HELD)


func test_pinkie_ricochets_to_second_target() -> void:
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	h.actor.flags["pass_ricochets"] = 2
	var d1: SimActor = SimFixture.dummy(w, Vector3(0, 0, -6))
	var d2: SimActor = SimFixture.dummy(w, Vector3(3, 0, -9))
	SimFixture.script_of(h).press_at(0, "heavy")
	w.step_n(90)
	var hits: Array[int] = []
	for e: Dictionary in events:
		if str(e["type"]) == "pass_hit":
			hits.append(int(e["target"]))
	assert_eq(hits, [d1.id, d2.id] as Array[int])


func test_baseball_pass_pierces_two_commons_then_loose() -> void:
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	for z: float in [-5.0, -9.0, -13.0, -17.0]:
		SimFixture.dummy(w, Vector3(0, 0, z))
	SimFixture.script_of(h).hold(0, 45, "heavy")
	w.step_n(130)
	var hits: int = 0
	for e: Dictionary in events:
		if str(e["type"]) == "pass_hit":
			assert_eq(str(e["kind"]), "baseball_pass")
			hits += 1
	assert_eq(hits, 3, "hits first, pierces 2 more, stops on the 3rd pierce check")
	assert_false(h.actor.has_ball, "always ends loose")


func test_baseball_pass_stops_on_boss() -> void:
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	SimFixture.dummy(w, Vector3(0, 0, -5), "boss")
	SimFixture.dummy(w, Vector3(0, 0, -9))
	SimFixture.script_of(h).hold(0, 45, "heavy")
	w.step_n(130)
	var hits: int = 0
	for e: Dictionary in events:
		if str(e["type"]) == "pass_hit":
			hits += 1
	assert_eq(hits, 1)


func test_loose_ball_bounces_and_settles() -> void:
	var b: SimBall = sys.spawn_ball("ball_rec", Vector3(0, 3, 0))
	b.vel = Vector3(1, 0, 0)
	var peak_after_first: float = 0.0
	var bounced: bool = false
	for _i: int in 600:
		w.step()
		if b.bounces >= 1:
			bounced = true
			peak_after_first = maxf(peak_after_first, b.pos.y)
	assert_true(bounced)
	assert_lt(peak_after_first, 3.0 * 0.78 + 0.2, "bounce 0.78 loses height")
	assert_almost_eq(b.pos.y, 0.12, 0.02, "rests on the ground")


func test_pickup_loose_ball() -> void:
	var h: Hooper = SimFixture.hooper(w)
	h.actor.has_ball = false
	var b: SimBall = sys.spawn_ball("ball_rec", Vector3(2, 0.12, 0))
	SimFixture.script_of(h).move_at(0, Vector2(1, 0))
	w.step_n(40)
	assert_eq(b.state, SimBall.State.HELD)
	assert_eq(b.holder_id, h.actor.id)
	assert_true(_types().has("ball_picked"))


func test_lost_ball_in_water_gives_spare() -> void:
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	w.collision.water.append({"min": Vector2(-3, -40), "max": Vector2(3, -15)})
	SimFixture.script_of(h).press_at(0, "heavy")
	w.step_n(150)
	assert_true(_types().has("ball_lost"))
	assert_eq(str(_ev("ball_lost")["reason"]), "water")
	assert_true(_types().has("spare_ball"))
	assert_true(h.actor.has_ball)


func test_unreachable_ball_respawns_after_10s() -> void:
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	var b: SimBall = sys.take_from(h.actor)
	b.pos = Vector3(30, 0.12, 30)
	b.vel = Vector3.ZERO
	w.step_n(60 * 9)
	assert_false(_types().has("ball_lost"))
	w.step_n(80)
	assert_eq(str(_ev("ball_lost")["reason"]), "unreachable")
	assert_true(h.actor.has_ball)


func test_wire_kicks_knocked_down_by_pass() -> void:
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	sys.add_wire_kicks("wk1", Vector3(0, 6.0, -7))
	SimFixture.script_of(h).press_at(0, "heavy")
	w.step_n(40)
	assert_true(_types().has("wire_kicks_down"))
	assert_true(bool(sys.wire_kicks[0]["down"]))


func test_ball_states_cover_lifecycle() -> void:
	_hoop_ahead(4.0)
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	var b: SimBall = sys.ball_of(h.actor)
	var seen: Dictionary = {}
	SimFixture.script_of(h).hold(0, _release_frame_for(0.82), "shoot")
	for _i: int in 120:
		w.step()
		seen[b.state_name()] = true
	for s: String in ["HELD", "SHOT", "IN_NET"]:
		assert_true(seen.has(s), s)
