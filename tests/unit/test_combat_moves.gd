extends GutTest
## M3: every §7.4-7.5 move, Hype/Takeover/Taunt/Quarter Water, Bag Moves.

var sim: CombatSim


func before_each() -> void:
	sim = CombatSim.new()
	sim.combat.damage.hitstop_enabled = false


func after_each() -> void:
	sim.dispose()


func _si(h: Hooper) -> ScriptedInput:
	return h.actor.input_source as ScriptedInput


func _hits_by(move: String) -> int:
	var n: int = 0
	for e: Dictionary in sim.events:
		if str(e["type"]) == "hit_resolved" and str(e["move"]) == move and str(e["result"]) == "hit":
			n += 1
	return n


func test_dribble_chain_four_hits() -> void:
	var h: Hooper = sim.hooper()
	sim.dummy(Vector3(0, 0, -1.4))
	_si(h).press_at(0, "light").press_at(18, "light").press_at(36, "light").press_at(58, "light")
	var seen: Array[String] = []
	for _i: int in 130:
		sim.run(1)
		if h.action != "" and not seen.has(h.action):
			seen.append(h.action)
	assert_eq(seen, ["pound", "cross_whip", "btl_snap", "btb_slam"] as Array[String])
	for m: String in ["pound", "cross_whip", "btl_snap", "btb_slam"]:
		assert_eq(_hits_by(m), 1, m)


func test_chain_drops_without_input() -> void:
	var h: Hooper = sim.hooper()
	_si(h).press_at(0, "light").press_at(60, "light")
	sim.run(30)
	assert_eq(h.action, "")
	sim.run(2)
	sim.run(30)
	assert_eq(_hits_by("cross_whip"), 0)


func test_pound_frame_data() -> void:
	var h: Hooper = sim.hooper()
	_si(h).press_at(0, "light")
	sim.run(1)
	assert_eq(h.action, "pound")
	assert_eq(h.action_total, 27, "9/4/14")
	sim.run(27)
	assert_eq(h.action, "")


func test_euro_step_two_hits_and_gap_close() -> void:
	var h: Hooper = sim.hooper()
	var d: TrainingDummy = sim.dummy(Vector3(0, 0, -3.5))
	d.actor.hp_max = 5000.0
	d.actor.hp = 5000.0
	_si(h).move_at(0, Vector2(0, -0.2)).hold(0, 40, "dodge").press_at(25, "light")
	sim.run(60)
	assert_eq(_hits_by("euro_step"), 2)


func test_tomahawk_aoe() -> void:
	var h: Hooper = sim.hooper()
	sim.dummy(Vector3(1.5, 0, 0))
	sim.dummy(Vector3(-1.5, 0, 0.5))
	_si(h).press_at(0, "jump").press_at(18, "light")
	sim.run(60)
	assert_eq(_hits_by("tomahawk"), 2, "AoE hits both")


func test_shove_without_ball() -> void:
	var h: Hooper = sim.hooper(Vector3.ZERO, {}, false)
	var d: TrainingDummy = sim.dummy(Vector3(0, 0, -1.2))
	_si(h).press_at(0, "light")
	sim.run(30)
	assert_eq(_hits_by("shove"), 1)
	assert_almost_eq(d.actor.composure.value, 10.0, 0.01)


func test_reach_in_steals_and_miss_off_balance() -> void:
	var h: Hooper = sim.hooper(Vector3.ZERO, {}, false)
	var d: TrainingDummy = sim.dummy(Vector3(0, 0, -1.3))
	sim.balls.give(sim.balls.spawn_ball("ball_rec", d.actor.pos, d.actor), d.actor)
	d.actor.flags["ball_security"] = -1.0
	_si(h).press_at(0, "heavy")
	sim.run(20)
	assert_true(h.actor.has_ball, "stole it")
	assert_eq(sim.count("steal"), 1)
	var h2: Hooper = sim.hooper(Vector3(20, 0, 0), {}, false)
	_si(h2).press_at(0, "heavy")
	sim.run(40)
	assert_eq(h2.action, "off_balance", "whiff = off balance 20f")


func test_hustle_dive_grabs_loose_ball() -> void:
	var h: Hooper = sim.hooper(Vector3.ZERO, {}, false)
	sim.balls.spawn_ball("ball_rec", Vector3(2.4, 0.12, 0))
	_si(h).press_at(0, "dodge")
	sim.run(1)
	assert_eq(h.action, "hustle_dive")
	sim.run(24)
	assert_true(h.actor.has_ball)


func test_rejection_swats_lob() -> void:
	var h: Hooper = sim.hooper(Vector3.ZERO, {}, false)
	var d: TrainingDummy = sim.dummy(Vector3(0, 0, -6))
	_si(h).press_at(0, "jump").press_at(0, "hands_up")
	sim.run(8)
	assert_eq(h.action, "rejection")
	var hb: Hitbox = Hitbox.new()
	hb.owner_id = d.actor.id
	hb.team = 1
	hb.damage = 30.0
	hb.lob = true
	hb.world_space = true
	hb.volume = HitVolume.from_dict({"shape": "circle", "radius": 2.0, "height": 3.0})
	hb.volume.origin = Vector3.ZERO
	sim.combat.add(hb)
	sim.run(1)
	assert_eq(sim.results()[0], "rejection")


func test_quarter_water() -> void:
	var h: Hooper = sim.hooper()
	h.actor.hp = 100.0
	_si(h).press_at(0, "quarter_water")
	sim.run(35)
	assert_eq(h.actor.hp, 100.0, "heals at frame 36")
	sim.run(1)
	assert_almost_eq(h.actor.hp, 100.0 + h.actor.hp_max * 0.35, 0.01)
	assert_eq(int(h.actor.flags["qw"]), 2)
	sim.run(20)
	assert_eq(h.action, "", "54 frames total")


func test_taunt_completes_for_hype() -> void:
	var h: Hooper = sim.hooper()
	_si(h).press_at(0, "taunt")
	sim.run(71)
	assert_eq(h.actor.hype.value, 0.0)
	sim.run(2)
	assert_almost_eq(h.actor.hype.value, 15.0, 0.01)
	assert_eq(sim.count("taunt_completed"), 1)


func test_taunt_interrupted_gives_nothing() -> void:
	var h: Hooper = sim.hooper()
	var d: TrainingDummy = sim.dummy(Vector3(0, 0, -1.5))
	_si(h).press_at(0, "taunt")
	sim.run(30)
	var hb: Hitbox = Hitbox.new()
	hb.owner_id = d.actor.id
	hb.team = 1
	hb.damage = 30.0
	hb.world_space = true
	hb.volume = HitVolume.from_dict({"shape": "sphere", "radius": 3.0})
	sim.combat.add(hb)
	sim.run(60)
	assert_eq(h.actor.hype.value, 0.0)


func test_takeover_activation_and_duration() -> void:
	var h: Hooper = sim.hooper()
	h.actor.hype.value = 100.0
	_si(h).press_at(0, "bag_move").press_at(0, "interact")
	sim.run(10)
	assert_eq(h.action, "takeover")
	assert_true(h.actor.invulnerable, "i-frames during activation")
	sim.run(25)
	assert_true(bool(h.actor.flags.get("takeover", false)))
	assert_eq(h.actor.hype.value, 0.0)
	assert_almost_eq(HooperCombat.damage_buffs(h.actor), 1.25, 0.001)
	sim.run(60 * 12)
	assert_false(bool(h.actor.flags.get("takeover", false)), "12 s")


func test_takeover_needs_full_hype() -> void:
	var h: Hooper = sim.hooper()
	h.actor.hype.value = 99.0
	_si(h).press_at(0, "bag_move").press_at(0, "interact")
	sim.run(5)
	assert_ne(h.action, "takeover")


func test_bag_spin_cycle_multi_hit() -> void:
	var h: Hooper = sim.hooper()
	h.actor.flags["bag_move"] = "spin_cycle"
	h.actor.hype.add(40.0)
	var d: TrainingDummy = sim.dummy(Vector3(1.2, 0, 0))
	d.actor.hp_max = 5000.0
	d.actor.hp = 5000.0
	_si(h).press_at(0, "bag_move")
	sim.run(50)
	assert_eq(_hits_by("bag_spin_cycle"), 3)
	assert_almost_eq(h.actor.hype.value, 10.0, 0.01, "costs 30")


func test_bag_hesi_doubles_next_composure() -> void:
	var h: Hooper = sim.hooper()
	h.actor.flags["bag_move"] = "hesi"
	h.actor.hype.value = 20.0
	var d: TrainingDummy = sim.dummy(Vector3(0, 0, -1.4))
	_si(h).press_at(0, "bag_move").press_at(17, "light")
	sim.run(50)
	assert_almost_eq(d.actor.composure.value, 16.0, 0.01, "pound 8 composure x2")


func test_bag_snatchback_slides_back() -> void:
	var h: Hooper = sim.hooper()
	h.actor.flags["bag_move"] = "snatchback"
	h.actor.hype.value = 25.0
	h.actor.facing = 0.0
	_si(h).press_at(0, "bag_move")
	sim.run(30)
	assert_almost_eq(h.actor.pos.z, 4.0, 0.3, "4 m back")
	assert_eq(int(h.actor.flags.get("deflect_projectiles", 0)), 1)


func test_not_enough_hype() -> void:
	var h: Hooper = sim.hooper()
	h.actor.flags["bag_move"] = "spin_cycle"
	h.actor.hype.value = 10.0
	_si(h).press_at(0, "bag_move")
	sim.run(3)
	assert_eq(sim.count("hype_short"), 1)


func test_dunk_scores() -> void:
	var hoop: SimHoop = sim.balls.add_hoop(SimHoop.regulation("h", Vector3(0, 0, -8), Vector3(0, 0, 1)))
	var h: Hooper = sim.hooper(Vector3.ZERO, SimFixture.stats_with({"bounce": 14}))
	_si(h).move_at(0, Vector2(0, -1)).hold(0, 90, "dodge").press_at(46, "jump")
	sim.run(90)
	var made: Dictionary = sim.last("shot_made")
	assert_false(made.is_empty(), "dunk made")
	assert_eq(str(made["grade"]), "DUNK")
	assert_eq(str(made["hoop"]), hoop.id)


func test_dunk_finisher_crits_downed_common() -> void:
	var h: Hooper = sim.hooper()
	var d: TrainingDummy = sim.dummy(Vector3(0, 0, -1.5))
	d.actor.hp_max = 5000.0
	d.actor.hp = 5000.0
	d.actor.flags["downed"] = true
	d.stun_frames = 200
	d.actor.flags["knocked"] = true
	_si(h).press_at(0, "interact")
	sim.run(20)
	var res: Dictionary = sim.last("hit_resolved")
	assert_eq(str(res["move"]), "dunk_finisher")
	assert_true(bool(res.get("crit", false)))
	var base: float = DamageMath.hooper_damage(DataDB.move("hooper", "dunk_finisher"), h.actor)
	assert_almost_eq(float(res["damage"]), base * 3.0, 0.01)


func test_player_death() -> void:
	var h: Hooper = sim.hooper()
	var d: TrainingDummy = sim.dummy(Vector3(0, 0, -1.5))
	var hb: Hitbox = Hitbox.new()
	hb.owner_id = d.actor.id
	hb.team = 1
	hb.damage = 9999.0
	hb.world_space = true
	hb.volume = HitVolume.from_dict({"shape": "sphere", "radius": 3.0})
	sim.combat.add(hb)
	sim.run(2)
	assert_false(h.actor.alive)
	assert_eq(h.action, "death")
	assert_eq(sim.count("actor_killed"), 1)
