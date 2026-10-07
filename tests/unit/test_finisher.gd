extends GutTest
## Playtest: "I took ankles and pressed R near the enemy and nothing
## happened." The crossover carries you 3.2 m, so the downed enemy was out of
## the old 2.2 m reach by the time you could act. The Dunk Finisher now
## leaps to an open enemy within seek range and cancels a dodge's tail.

var d: District


func before_each() -> void:
	GameState.new_run("nobody", "brooklyn")
	GameState.set_flag("prologue_done")
	SceneRouter.pending = {"district": "bk_bedstuy", "arrive": {}}
	d = (load("res://world/district.tscn") as PackedScene).instantiate() as District
	add_child_autofree(d)


func _crew() -> SimActor:
	for a: SimActor in d.sim.actors:
		if a.kind == "enemy" and a.team != 0 and not a.flags.has("prop_target"):
			return a
	return null


func _down_at(e: SimActor, dist: float) -> void:
	e.pos = d.player.pos + d.player.forward() * dist
	(e.controller as EnemyBrain).stun(90, true)


func test_finisher_leaps_to_a_downed_enemy_out_of_arm_reach() -> void:
	await wait_physics_frames(3)
	var e: SimActor = _crew()
	_down_at(e, 4.0)
	await wait_physics_frames(2)
	assert_true(d.player.has_ball)
	var hp0: float = e.hp
	d.player.input.press("interact")
	await wait_physics_frames(1)
	assert_eq(d.player_hooper.action, "dunk_finisher", "R starts the finisher from 4 m")
	await wait_physics_frames(30)
	assert_lt(e.hp, hp0, "and the slam lands")
	assert_lt(e.dist_to(d.player), 2.5, "you leapt to them")


func test_finisher_cancels_the_crossover_tail() -> void:
	await wait_physics_frames(3)
	var e: SimActor = _crew()
	var h: Hooper = d.player_hooper
	h.begin("crossover", d.player.forward().cross(Vector3.UP))
	await wait_physics_frames(15)   # past the i-frames, still in the crossover
	assert_eq(h.action, "crossover")
	_down_at(e, 3.6)
	await wait_physics_frames(1)
	d.player.input.press("interact")
	await wait_physics_frames(1)
	assert_eq(h.action, "dunk_finisher", "the ankle turns straight into the slam")


func test_no_finisher_on_a_standing_or_far_enemy() -> void:
	await wait_physics_frames(3)
	var e: SimActor = _crew()
	e.pos = d.player.pos + d.player.forward() * 1.5
	(e.controller as EnemyBrain).stun(90, false)   # hit-stun, not knocked down
	await wait_physics_frames(1)
	d.player.input.press("interact")
	await wait_physics_frames(1)
	assert_ne(d.player_hooper.action, "dunk_finisher", "only DOWN / SHOOK enemies")
	_down_at(e, 7.5)
	await wait_physics_frames(10)
	d.player.input.press("interact")
	await wait_physics_frames(1)
	assert_ne(d.player_hooper.action, "dunk_finisher", "out of seek range")


func test_real_ankle_breaker_then_finisher() -> void:
	## A crew member swings, you cross them over on the red cue (like the
	## tutorial bot), then mash R.
	await wait_physics_frames(3)
	var e: SimActor = _crew()
	var br: EnemyBrain = e.controller as EnemyBrain
	e.pos = d.player.pos + d.player.forward() * 2.0
	br.alert(d.player)
	var broke: Array[bool] = [false]
	d.sim.sim_event.connect(func(ev: Dictionary) -> void:
		if str(ev.get("type", "")) == "hit_resolved" and str(ev.get("result", "")) == "ankle_breaker":
			broke[0] = true)
	var cool: int = 0
	for f: int in 900:
		cool = maxi(0, cool - 1)
		if broke[0]:
			break
		var cue: bool = false
		for o: SimActor in d.sim.hostiles_of(d.player):
			cue = cue or (o.alive and o.dist_to(d.player) < 7.0 and bool(Telegraph.read(o).get("now", false)))
		if cool == 0 and d.player_hooper.action == "" and cue:
			d.player.input.press("dodge")
			cool = 30
		d.player.wind.value = d.player.wind.max_value
		d.player.hp = d.player.hp_max
		await wait_physics_frames(1)
	assert_true(broke[0], "took their ankles")
	var started: bool = false
	for i: int in 40:
		d.player.input.press("interact")
		await wait_physics_frames(1)
		if d.player_hooper.action == "dunk_finisher":
			started = true
			break
	assert_true(started, "mashing R after the ankles slams them")
