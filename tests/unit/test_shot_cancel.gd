extends GutTest
## Revision 13: knocked out of the shot mid-gather, the meter goes away
## instead of showing a full meter for a shot that never left your hands.

var w: SimWorld
var sys: BallSystem


func before_each() -> void:
	w = SimFixture.world()
	sys = SimFixture.with_balls(w)
	sys.add_hoop(SimHoop.regulation("h1", Vector3(0, 0, -5.0), Vector3(0, 0, 1)))


func after_each() -> void:
	w.dispose()


func test_hit_mid_gather_cancels_the_meter() -> void:
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	SimFixture.script_of(h).hold(0, 40, "shoot")
	w.step_n(8)
	var mod: HooperBall = SimFixture.ball_module(h)
	assert_eq(h.action, "shot_gather")
	assert_false(mod.cancelled)
	h.on_hit({"result": "hit", "damage": 999.0, "weight": "heavy"})
	assert_ne(h.action, "shot_gather", "the hit knocks you out of the shot")
	assert_true(mod.cancelled, "no shot left your hands")
	assert_lt(mod.meter, 0.0)


func test_a_released_shot_is_not_cancelled() -> void:
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	SimFixture.script_of(h).hold(0, 12, "shoot")
	w.step_n(20)
	var mod: HooperBall = SimFixture.ball_module(h)
	assert_false(mod.cancelled, "a real release flashes the meter as before")
