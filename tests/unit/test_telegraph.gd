extends GutTest
## Attack wind-up cue: Telegraph reads an enemy's startup, the aura swells
## through it and pulses in the last frames, and never shows on your side.


func _engaged_sim() -> Array:
	var sim: CombatSim = CombatSim.new(5)
	sim.combat.damage.hitstop_enabled = false
	var p: Hooper = sim.hooper(Vector3(0, 0, 0))
	p.actor.flags["cannot_die"] = true
	var e: SimActor = EnemyFactory.spawn(sim.world, sim.combat, sim.balls, "ball_hog", Vector3(0, 0, 1.6), 1)
	return [sim, p, e]


func test_reads_an_enemy_windup_frame_by_frame() -> void:
	var parts: Array = _engaged_sim()
	var sim: CombatSim = parts[0]
	var e: SimActor = parts[2]
	var seen: Array[Dictionary] = []
	for _f: int in 600:
		sim.run(1)
		var info: Dictionary = Telegraph.read(e)
		if not info.is_empty():
			seen.append(info)
		elif not seen.is_empty():
			break
	assert_gt(seen.size(), 5, "the ball hog winds up an attack within 10 s")
	if seen.size() > 1:
		assert_lt(float(seen[0]["progress"]), float(seen[-1]["progress"]), "progress grows")
		assert_false(bool(seen[0]["now"]), "the cue isn't 'now' at the start")
		assert_true(bool(seen[-1]["now"]), "the last frames are the 'now' pulse")
		assert_lte(int(seen[-1]["frames_left"]), Telegraph.CUE_FRAMES)
	sim.dispose()


func test_no_cue_for_your_side_or_idle() -> void:
	var parts: Array = _engaged_sim()
	var sim: CombatSim = parts[0]
	var p: Hooper = parts[1]
	assert_true(Telegraph.read(p.actor).is_empty(), "never on the player")
	assert_true(Telegraph.read(null).is_empty())
	sim.dispose()


func test_aura_strength_curve() -> void:
	assert_eq(TelegraphAura.strength({}, 0.0, false), 0.0, "hidden when nothing winds up")
	var early: float = TelegraphAura.strength({"progress": 0.1, "now": false, "unblockable": false}, 0.0, false)
	var late: float = TelegraphAura.strength({"progress": 0.8, "now": false, "unblockable": false}, 0.0, false)
	var now: float = TelegraphAura.strength({"progress": 0.95, "now": true, "unblockable": false}, 0.0, false)
	assert_lt(early, late, "swells through the wind-up")
	assert_lt(late, now, "brightest in the cue frames")
	# Unblockables flicker, but not with Reduce flashes on.
	var a: float = TelegraphAura.strength({"progress": 1.0, "now": true, "unblockable": true}, 0.0, true)
	var b: float = TelegraphAura.strength({"progress": 1.0, "now": true, "unblockable": true}, 0.37, true)
	assert_eq(a, b, "steady when reducing flashes")


func test_views_carry_an_aura() -> void:
	var parts: Array = _engaged_sim()
	var sim: CombatSim = parts[0]
	var e: SimActor = parts[2]
	var v: ActorView = ActorView.create(e)
	add_child_autofree(v)
	assert_not_null(v.aura, "enemy view has the telegraph aura")
	assert_false(v.aura.visible, "hidden while idle")
	var shown: bool = false
	for _f: int in 600:
		sim.run(1)
		v.aura.update_aura(1.0 / 60.0, e.height)
		shown = shown or v.aura.visible
		if shown:
			break
	assert_true(shown, "glows during the wind-up")
	assert_gt(v.aura.position.y, e.height, "above the head")
	sim.dispose()
