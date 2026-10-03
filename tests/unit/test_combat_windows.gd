extends GutTest
## M3: frame-exact Ankle Breaker / parry / Read windows with stat scaling.


func _hb(sim: CombatSim, attacker: SimActor, target: SimActor, kind: String, unblockable: bool = false) -> Hitbox:
	var hb: Hitbox = Hitbox.new()
	hb.owner_id = attacker.id
	hb.team = attacker.team
	hb.move_id = "test_attack"
	hb.volume = HitVolume.from_dict({"shape": "sphere", "radius": 3.0})
	hb.volume.origin = target.pos
	hb.world_space = true
	hb.frames_left = 1
	hb.damage = 30.0
	hb.composure = 0.0
	hb.kind = kind
	hb.unblockable = unblockable
	return sim.combat.add(hb)


func _result_at(action: String, frame: int, stats: Dictionary = {}, kind: String = "ball", with_ball: bool = true) -> String:
	## Starts `action` on frame 1 and lands a one-frame hit on action frame `frame`.
	var sim: CombatSim = CombatSim.new()
	var h: Hooper = sim.hooper(Vector3.ZERO, SimFixture.stats_with(stats) if not stats.is_empty() else {}, with_ball)
	var d: TrainingDummy = sim.dummy(Vector3(0, 0, -1.5), "passive")
	sim.combat.damage.hitstop_enabled = false
	var si: ScriptedInput = h.actor.input_source as ScriptedInput
	match action:
		"crossover":
			si.move_at(0, Vector2(1, 0)).press_at(0, "dodge")
		"slide":
			si.move_at(0, Vector2(1, 0)).press_at(0, "dodge")
		"hands_up":
			si.press_at(0, "hands_up")
	sim.run(frame - 1)
	_hb(sim, d.actor, h.actor, kind)
	sim.run(1)
	var rs: PackedStringArray = sim.results()
	sim.dispose()
	return rs[0] if rs.size() > 0 else "none"


func _ankle_end() -> int:
	## Base window end from tuning (12 in the spec; widened to 14 by request).
	return JU.i(JU.dict(DataDB.tuning("combat"), "ankle_breaker"), "window_end", 12)


func test_ankle_window_base_handles_10() -> void:
	var w: int = _ankle_end()
	for f: int in range(1, 20):
		var r: String = _result_at("crossover", f, {"handles": 10})
		if f >= 3 and f <= w:
			assert_eq(r, "ankle_breaker", "frame %d" % f)
		elif f > w and f <= 14:
			assert_eq(r, "dodged", "i-frames only at %d" % f)
		else:
			assert_eq(r, "hit", "vulnerable at %d" % f)


func test_ankle_window_grows_with_handles() -> void:
	var w: int = _ankle_end()
	# +0.2 f/pt above 10: Handles 20 -> +2 frames (3..w+2).
	assert_eq(_result_at("crossover", w + 2, {"handles": 20}), "ankle_breaker")
	assert_eq(_result_at("crossover", w + 3, {"handles": 20}), "hit")
	# Cap +6 frames: Handles 60 -> 3..w+6 (beyond the 14f i-frames).
	assert_eq(_result_at("crossover", w + 6, {"handles": 60}), "ankle_breaker")
	assert_eq(_result_at("crossover", w + 7, {"handles": 60}), "hit")


func test_ankle_breaker_beats_unblockables_but_needs_ball() -> void:
	assert_eq(_result_at("slide", 5, {}, "body", false), "read", "no ball: slide reads instead")


func test_parry_window_base_hands_10() -> void:
	for f: int in range(1, 14):
		var r: String = _result_at("hands_up", f, {"hands": 10}, "ball", false)
		if f <= 10:
			assert_eq(r, "strip", "frame %d strips" % f)
		else:
			assert_eq(r, "hit", "frame %d whiffed" % f)


func test_parry_window_scales_with_hands() -> void:
	assert_eq(_result_at("hands_up", 12, {"hands": 20}, "ball", false), "strip", "Hands 20 -> 12f")
	assert_eq(_result_at("hands_up", 13, {"hands": 20}, "ball", false), "hit")
	assert_eq(_result_at("hands_up", 16, {"hands": 60}, "ball", false), "strip", "max 16f")
	assert_eq(_result_at("hands_up", 17, {"hands": 60}, "ball", false), "hit")


func test_body_attack_parry_is_deflect() -> void:
	assert_eq(_result_at("hands_up", 4, {}, "body", false), "deflect")


func test_unblockable_ignores_parry() -> void:
	var sim: CombatSim = CombatSim.new()
	var h: Hooper = sim.hooper(Vector3.ZERO, {}, false)
	var d: TrainingDummy = sim.dummy(Vector3(0, 0, -1.5))
	(h.actor.input_source as ScriptedInput).press_at(0, "hands_up")
	sim.run(3)
	_hb(sim, d.actor, h.actor, "ball", true)
	sim.run(1)
	assert_eq(sim.results()[0], "hit")
	sim.dispose()


func test_strip_knocks_common_ball_loose_and_disarms() -> void:
	var sim: CombatSim = CombatSim.new()
	var h: Hooper = sim.hooper(Vector3.ZERO, SimFixture.stats_with({"hands": 10}), false)
	var d: TrainingDummy = sim.dummy(Vector3(0, 0, -1.5))
	sim.balls.give(sim.balls.spawn_ball("ball_rec", d.actor.pos, d.actor), d.actor)
	(h.actor.input_source as ScriptedInput).press_at(0, "hands_up")
	sim.run(2)
	_hb(sim, d.actor, h.actor, "ball")
	sim.run(1)
	assert_eq(sim.results()[0], "strip")
	assert_false(d.actor.has_ball)
	assert_true(bool(d.actor.flags.get("disarmed", false)))
	assert_almost_eq(h.actor.hype.value, 10.0, 0.01, "+10 Hype")
	assert_almost_eq(d.actor.composure.value, 30.0, 0.01, "30 composure")
	sim.dispose()


func test_ankle_breaker_effects() -> void:
	var sim: CombatSim = CombatSim.new()
	var h: Hooper = sim.hooper(Vector3.ZERO)
	var d: TrainingDummy = sim.dummy(Vector3(0, 0, -1.5))
	(h.actor.input_source as ScriptedInput).move_at(0, Vector2(1, 0)).press_at(0, "dodge")
	sim.run(4)
	_hb(sim, d.actor, h.actor, "body")
	sim.run(1)
	assert_eq(sim.results()[0], "ankle_breaker")
	assert_almost_eq(h.actor.hype.value, 12.0, 0.01, "+12 Hype")
	assert_almost_eq(d.actor.composure.value, 35.0, 0.01, "35 composure at Handles 10")
	assert_gt(d.stun_frames, 60, "commons fall for 1.5 s")
	assert_eq(h.actor.hp, h.actor.hp_max, "no damage")
	sim.dispose()
