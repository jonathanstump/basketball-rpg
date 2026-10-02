extends GutTest
## M1: Wind math, i-frame windows, input buffer, coyote time, jump, sprint.

var w: SimWorld


func before_each() -> void:
	w = SimFixture.world()


func after_each() -> void:
	w.dispose()


func test_wind_pool_regen_delay_and_rates() -> void:
	var p: WindPool = WindPool.new()
	p.configure(100.0, DataDB.tuning("player"))
	assert_true(p.spend(30.0))
	assert_almost_eq(p.value, 70.0, 0.001)
	p.tick(0.5)
	assert_almost_eq(p.value, 70.0, 0.001, "no regen before 0.6 s")
	p.tick(0.2)   # 0.7 s since spend -> regen applies this tick
	assert_almost_eq(p.value, 70.0 + 45.0 * 0.2, 0.001)
	p.spend(50.0)
	p.tick(0.6)
	var before: float = p.value
	p.tick(1.0, true)
	assert_almost_eq(p.value, before + 15.0, 0.001, "guarding regen 15/s")


func test_wind_floor_and_can_act() -> void:
	var p: WindPool = WindPool.new()
	p.configure(100.0, DataDB.tuning("player"))
	assert_true(p.spend(150.0), "souls rule: can act while > 0")
	assert_eq(p.value, 0.0)
	assert_false(p.can_act())
	assert_false(p.spend(10.0))


func test_wind_and_heart_max_formulas() -> void:
	assert_almost_eq(StatFormulas.wind_max(10), 100.0, 0.001)
	assert_almost_eq(StatFormulas.wind_max(40), 190.0, 0.001)
	assert_almost_eq(StatFormulas.wind_max(50), 200.0, 0.001)
	assert_almost_eq(StatFormulas.heart_max(10), 300.0, 0.001)
	assert_almost_eq(StatFormulas.heart_max(40), 1050.0, 0.001)
	assert_almost_eq(StatFormulas.heart_max(60), 1250.0, 0.001)
	assert_almost_eq(StatFormulas.heart_max(70), 1280.0, 0.001)
	assert_almost_eq(StatFormulas.heart_max(9), 275.0, 0.001)


func test_crossover_iframes_exact() -> void:
	var h: Hooper = SimFixture.hooper(w)
	SimFixture.script_of(h).move_at(0, Vector2(1, 0)).press_at(0, "dodge")
	var inv: Array[bool] = []
	for _i: int in 24:
		w.step()
		inv.append(h.actor.invulnerable)
	assert_eq(h.action, "", "action finished")
	for f: int in range(1, 23):
		var expected: bool = f >= 3 and f <= 14
		assert_eq(inv[f - 1], expected, "frame %d iframes" % f)
	assert_false(inv[22], "frame 23 back to free")


func test_crossover_distance_and_wind() -> void:
	var h: Hooper = SimFixture.hooper(w)
	var wind0: float = h.actor.wind.value
	SimFixture.script_of(h).move_at(0, Vector2(1, 0)).press_at(0, "dodge").move_at(1, Vector2.ZERO)
	w.step_n(30)
	assert_almost_eq(h.actor.pos.x, 3.2, 0.2, "3.2 m dash")
	assert_almost_eq(wind0 - h.actor.wind.value, 18.0, 0.5, "18 Wind")


func test_slide_without_ball() -> void:
	var h: Hooper = SimFixture.hooper(w)
	h.actor.has_ball = false
	SimFixture.script_of(h).move_at(0, Vector2(0, 1)).press_at(0, "dodge")
	var inv: Array[bool] = []
	for _i: int in 21:
		w.step()
		inv.append(h.actor.invulnerable)
	for f: int in range(1, 21):
		assert_eq(inv[f - 1], f >= 3 and f <= 12, "slide frame %d" % f)


func test_stepback_when_pulling_back() -> void:
	var h: Hooper = SimFixture.hooper(w)
	h.actor.facing = 0.0   # forward = -Z
	SimFixture.script_of(h).move_at(0, Vector2(0, 1)).press_at(0, "dodge")
	w.step()
	assert_eq(h.action, "stepback")
	w.step_n(5)
	assert_gt(h.stepback_timer_s, 0.0, "stepback shot window open")


func test_input_buffer_dodge_after_dodge() -> void:
	var h: Hooper = SimFixture.hooper(w)
	# Second press 6 frames before the first dodge ends (frame 22): buffered.
	SimFixture.script_of(h).move_at(0, Vector2(1, 0)).press_at(0, "dodge").press_at(16, "dodge")
	w.step_n(23)
	assert_eq(h.action, "crossover", "buffered dodge started right after")
	assert_lt(h.action_frame, 3)


func test_input_buffer_expires() -> void:
	var h: Hooper = SimFixture.hooper(w)
	# Press at frame 5 is > 8 frames before the dodge ends at 22: dropped.
	SimFixture.script_of(h).move_at(0, Vector2(1, 0)).press_at(0, "dodge").press_at(5, "dodge")
	w.step_n(23)
	assert_eq(h.action, "")


func test_jump_height() -> void:
	var h: Hooper = SimFixture.hooper(w)
	SimFixture.script_of(h).press_at(0, "jump")
	var peak: float = 0.0
	for _i: int in 80:
		w.step()
		peak = maxf(peak, h.actor.pos.y)
	assert_almost_eq(peak, 1.2, 0.08, "1.2 m jump at Bounce 10")
	assert_true(h.actor.on_ground)


func test_bounce_raises_jump() -> void:
	var h: Hooper = SimFixture.hooper(w, Vector3.ZERO, SimFixture.stats_with({"bounce": 20}))
	assert_almost_eq(h.jump_height_m, 1.4, 0.001)


func _platform_world() -> Hooper:
	w.collision.add_box(Vector3(0, 0.5, 0), Vector3(4, 1.0, 4), "platform")
	var h: Hooper = SimFixture.hooper(w, Vector3(0, 1.0, 0))
	h.actor.on_ground = true
	return h


func test_coyote_time_allows_late_jump() -> void:
	var h: Hooper = _platform_world()
	var si: ScriptedInput = SimFixture.script_of(h)
	si.move_at(0, Vector2(1, 0))
	var left_at: int = -1
	for i: int in 120:
		w.step()
		if not h.actor.on_ground:
			left_at = i
			break
	assert_gt(left_at, 0, "walked off the platform")
	si.press_at(si.local_frame + 4, "jump")
	w.step_n(5)
	assert_gt(h.actor.vel.y, 0.0, "jumped within 5 coyote frames")


func test_coyote_time_expires() -> void:
	var h: Hooper = _platform_world()
	var si: ScriptedInput = SimFixture.script_of(h)
	si.move_at(0, Vector2(1, 0))
	for _i: int in 120:
		w.step()
		if not h.actor.on_ground:
			break
	si.press_at(si.local_frame + 7, "jump")
	w.step_n(8)
	assert_lte(h.actor.vel.y, 0.0, "too late: no jump")


func test_sprint_speed_and_drain() -> void:
	var h: Hooper = SimFixture.hooper(w)
	SimFixture.script_of(h).move_at(0, Vector2(1, 0)).hold(0, 200, "dodge")
	w.step_n(60)
	assert_true(h.sprinting, "holding dodge after the crossover sprints")
	var x0: float = h.actor.pos.x
	var wind0: float = h.actor.wind.value
	w.step_n(60)
	assert_almost_eq(h.actor.pos.x - x0, 8.5, 0.2, "8.5 m/s sprint")
	assert_almost_eq(wind0 - h.actor.wind.value, 12.0, 0.5, "12 Wind/s")


func test_walk_and_run_speeds() -> void:
	var h: Hooper = SimFixture.hooper(w)
	SimFixture.script_of(h).move_at(0, Vector2(0.4, 0))
	w.step_n(60)
	assert_almost_eq(h.actor.pos.x, 3.5, 0.15, "walk 3.5 m/s")
	var h2: Hooper = SimFixture.hooper(w, Vector3(0, 0, 10))
	SimFixture.script_of(h2).move_at(0, Vector2(1, 0))
	w.step_n(60)
	assert_almost_eq(h2.actor.pos.x, 6.0, 0.25, "run 6 m/s")


func test_walls_block_movement() -> void:
	w.collision.add_box(Vector3(3, 5, 0), Vector3(2, 10, 10), "wall")
	var h: Hooper = SimFixture.hooper(w)
	SimFixture.script_of(h).move_at(0, Vector2(1, 0))
	w.step_n(120)
	assert_almost_eq(h.actor.pos.x, 2.0 - h.actor.radius, 0.02, "stopped at wall face")


func test_curb_is_walkable() -> void:
	w.collision.add_box(Vector3(5, 0.075, 0), Vector3(4, 0.15, 10), "curb")
	var h: Hooper = SimFixture.hooper(w)
	SimFixture.script_of(h).move_at(0, Vector2(1, 0))
	w.step_n(60)
	assert_gt(h.actor.pos.x, 4.0, "stepped up the curb")
	assert_almost_eq(h.actor.pos.y, 0.15, 0.01)
