extends GutTest
## Revision 9: you can shoot on the run. Your feet keep moving through the
## gather, but the timing windows are tighter (sprinting tightest).

var w: SimWorld
var sys: BallSystem


func before_each() -> void:
	w = SimFixture.world()
	sys = SimFixture.with_balls(w)


func after_each() -> void:
	w.dispose()


func test_windows_shrink_on_the_move() -> void:
	var still: ShotContext = ShotContext.make(10, 5.0)
	var run: ShotContext = ShotContext.make(10, 5.0)
	run.on_run = "run"
	var sprint: ShotContext = ShotContext.make(10, 5.0)
	sprint.on_run = "sprint"
	var ws: ShotWindows = ShotResolver.compute_windows(still)
	var wr: ShotWindows = ShotResolver.compute_windows(run)
	var wsp: ShotWindows = ShotResolver.compute_windows(sprint)
	assert_lt(wr.perfect, ws.perfect, "harder to time on the run")
	assert_lt(wsp.perfect, wr.perfect, "hardest at a sprint")
	assert_gt(wsp.perfect, 0.0, "but still possible")


func test_shooting_while_running_keeps_you_moving() -> void:
	sys.add_hoop(SimHoop.regulation("h1", Vector3(0, 0, -11.0), Vector3(0, 0, 1)))
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	var si: ScriptedInput = SimFixture.script_of(h)
	si.move_at(0, Vector2(0, -1))
	si.hold(30, 70, "shoot")
	w.step_n(33)
	var mod: HooperBall = SimFixture.ball_module(h)
	assert_eq(h.action, "shot_gather", "the shot starts mid-run")
	assert_eq(mod.run_kind, "run")
	var z0: float = h.actor.pos.z
	w.step_n(8)
	assert_lt(h.actor.pos.z, z0 - 0.3, "still moving through the gather")
	var still: ShotContext = ShotContext.make(h.actor.stat("jumper"), sys.hoops[0].flat_distance(h.actor.pos))
	assert_lt(mod.windows.perfect, ShotResolver.compute_windows(still).perfect, "tighter window than a set shot")


func test_set_shot_is_unchanged() -> void:
	sys.add_hoop(SimHoop.regulation("h1", Vector3(0, 0, -5.0), Vector3(0, 0, 1)))
	var h: Hooper = SimFixture.ball_hooper(w, sys)
	SimFixture.script_of(h).hold(0, 20, "shoot")
	w.step_n(4)
	var mod: HooperBall = SimFixture.ball_module(h)
	assert_eq(h.action, "shot_gather")
	assert_eq(mod.run_kind, "", "standing still: a normal jumper")
	var p0: Vector3 = h.actor.pos
	w.step_n(6)
	assert_almost_eq(h.actor.pos.distance_to(p0), 0.0, 0.01, "planted feet")
