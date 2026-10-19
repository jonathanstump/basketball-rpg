extends GutTest
## Revision 17: manual lock-on. Switch targets left/right, keep facing your
## target while you back up (so a stepback can take their ankles), and the
## lock breaks once you've backed far enough away.

const FWD: Vector3 = Vector3(0, 0, -1)   # camera forward at yaw 0; right is +X

var sim: CombatSim
var player: SimActor


func before_each() -> void:
	sim = CombatSim.new()
	player = sim.hooper(Vector3.ZERO).actor


func after_each() -> void:
	sim.dispose()


func _foe(p: Vector3) -> SimActor:
	var a: SimActor = SimActor.new()
	a.kind = "enemy"
	a.team = 1
	a.pos = p
	sim.world.add_actor(a)
	return a


func test_best_is_the_one_in_front() -> void:
	var left: SimActor = _foe(Vector3(-4, 0, -5))
	var mid: SimActor = _foe(Vector3(0, 0, -6))
	_foe(Vector3(0, 0, -30))
	assert_eq(LockOn.best(sim.world, player, FWD, 16.0), mid)
	assert_eq(LockOn.candidates(sim.world, player, 16.0).size(), 2, "out of range doesn't count")
	assert_ne(LockOn.best(sim.world, player, FWD, 16.0), left)


func test_cycle_goes_right_and_left_and_wraps() -> void:
	var left: SimActor = _foe(Vector3(-4, 0, -5))
	var mid: SimActor = _foe(Vector3(0, 0, -6))
	var right: SimActor = _foe(Vector3(4, 0, -5))
	assert_eq(LockOn.cycle(sim.world, player, mid, FWD, 1, 16.0), right, "next = to the right")
	assert_eq(LockOn.cycle(sim.world, player, mid, FWD, -1, 16.0), left, "prev = to the left")
	assert_eq(LockOn.cycle(sim.world, player, right, FWD, 1, 16.0), left, "wraps around")
	assert_eq(LockOn.cycle(sim.world, player, null, FWD, 1, 16.0), mid, "no lock yet: the best one")


func test_lock_breaks_when_you_back_off_or_they_go_down() -> void:
	var cfg: Dictionary = JU.dict(DataDB.tuning("camera"), "lockon")
	var brk: float = JU.f(cfg, "break_range_m")
	assert_gt(brk, JU.f(cfg, "lock_range_m"), "a fresh lock never breaks on its own")
	var e: SimActor = _foe(Vector3(0, 0, -6))
	assert_false(LockOn.breaks(player, e, brk))
	e.pos = Vector3(0, 0, -(brk + 1.0))
	assert_true(LockOn.breaks(player, e, brk), "backed far enough away")
	e.pos = Vector3(0, 0, -6)
	e.alive = false
	assert_true(LockOn.breaks(player, e, brk), "down for good")


func test_tutorial_step_needs_you_to_back_up_while_locked() -> void:
	var t: TutorialTracker = TutorialTracker.new(player.id)
	var to: Vector3 = Vector3(0, 0, -5)
	for i: int in 60:
		t.feed_lock(false, to, Vector3(0, 0, 4))
		t.feed_lock(true, to, Vector3(0, 0, -4))
	assert_false(t.is_done("lock_on"), "unlocked or walking at them doesn't count")
	for i: int in TutorialTracker.BACKPEDAL_FRAMES:
		t.feed_lock(true, to, Vector3(0, 0, 4))
	assert_true(t.is_done("lock_on"), "locked and backing up")


# ------------------------------------------------------------ in the street

class BackAway:
	extends InputSource
	var game: GameWorld
	var lock_at: int = 2
	var n: int = 0

	func fill(input: ActorInput, a: SimActor, _w: SimWorld) -> void:
		n += 1
		input.move = Vector2.ZERO
		if n == lock_at:
			input.press("lock_on")
		var lt: SimActor = game.player_hooper.lock_target
		if lt != null and n > lock_at + 5:
			var away: Vector3 = a.pos - lt.pos
			input.move = Vector2(away.x, away.z).normalized() * 0.7   # a run, not a sprint


func test_backing_up_while_locked_keeps_you_facing_them() -> void:
	sim.dispose()
	sim = CombatSim.new()
	GameState.new_run("nobody", "brooklyn")
	GameState.set_flag("prologue_done")
	SceneRouter.pending = {"district": "bk_bedstuy", "arrive": {}}
	var d: District = (load("res://world/district.tscn") as PackedScene).instantiate() as District
	add_child_autofree(d)
	await wait_physics_frames(3)
	var e: SimActor = null
	for a: SimActor in d.sim.actors:
		if a.kind == "enemy" and a.team != 0 and not a.flags.has("prop_target"):
			e = a
	e.pos = d.player.pos + d.camera_rig.forward_flat() * 4.0
	var bot: BackAway = BackAway.new()
	bot.game = d
	d.use_scripted_input(bot)
	await wait_physics_frames(4)
	var lt: SimActor = d.player_hooper.lock_target
	assert_not_null(lt, "locked on")
	assert_eq(d.camera_rig.lock_target, lt, "the camera frames them")
	var start: Vector3 = d.player.pos
	await wait_physics_frames(45)
	assert_not_null(d.player_hooper.lock_target, "still locked")
	lt = d.player_hooper.lock_target
	var to: Vector3 = lt.pos - d.player.pos
	to.y = 0.0
	assert_gt(d.player.pos.distance_to(start), 1.5, "backed up")
	assert_gt(d.player.forward().dot(to.normalized()), 0.8, "still facing them, not turned away")
	lt.pos = d.player.pos + (lt.pos - d.player.pos).normalized() * (JU.f(JU.dict(DataDB.tuning("camera"), "lockon"), "break_range_m") + 2.0)
	await wait_physics_frames(2)
	assert_null(d.player_hooper.lock_target, "far enough back breaks the lock")
	assert_null(d.camera_rig.lock_target)
