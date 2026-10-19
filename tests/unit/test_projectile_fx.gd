extends GutTest
## Revision 11: thrown projectiles (the Stoop Queen's chancla) and wide gust
## arcs get a view that follows the live hitbox, then goes away with it.

var sim: CombatSim
var fx: ProjectileFx


func before_each() -> void:
	sim = CombatSim.new()
	fx = ProjectileFx.new()
	fx.combat = sim.combat
	fx.world = sim.world
	add_child_autofree(fx)


func after_each() -> void:
	sim.dispose()


func _chancla() -> Hitbox:
	var m: Dictionary = DataDB.move("bk_stoop", "chancla")
	var pd: Dictionary = JU.dict(m, "projectile")
	var hb: Hitbox = Hitbox.new()
	hb.owner_id = 999
	hb.team = 1
	hb.projectile = true
	hb.world_space = true
	hb.frames_left = 40
	hb.volume = HitVolume.from_dict({"shape": "sphere", "radius": 0.45, "height": 0.9, "y_offset": 0.6})
	hb.velocity = Vector3(0, 0, -JU.f(pd, "speed"))
	for k: String in ["look", "color", "visual_radius"]:
		hb.tags[k] = pd[k]
	return hb


func test_chancla_is_visible_and_follows_the_hitbox() -> void:
	var hb: Hitbox = _chancla()
	sim.combat.hitboxes.append(hb)
	fx._process(0.016)
	assert_eq(fx.views.size(), 1, "one view for the projectile")
	var v: Node3D = fx.views.values()[0]
	assert_true(v.visible)
	assert_almost_eq(v.position.z, 0.0, 0.01)
	hb.volume.origin = Vector3(0, 0, -5)
	fx._process(0.016)
	assert_almost_eq(v.position.z, -5.0, 0.01, "moves with the sim, same speed")
	sim.combat.hitboxes.erase(hb)
	fx._process(0.016)
	assert_eq(fx.views.size(), 0, "gone when the hitbox is")


func test_projectile_tags_reach_the_hitbox() -> void:
	assert_eq(str(JU.dict(DataDB.move("bk_stoop", "chancla"), "projectile").get("look", "")), "slipper")


func test_wide_gust_arcs_show_but_jabs_dont() -> void:
	var gust: Hitbox = Hitbox.new()
	gust.team = 1
	gust.frames_left = 10
	gust.volume = HitVolume.from_dict({"shape": "arc", "radius": 7.5, "angle": 50})
	var jab: Hitbox = Hitbox.new()
	jab.team = 1
	jab.frames_left = 10
	jab.volume = HitVolume.from_dict({"shape": "arc", "radius": 1.5, "angle": 90})
	assert_eq(ProjectileFx.wants(gust), "arc")
	assert_eq(ProjectileFx.wants(jab), "")
	gust.delay = 5
	assert_eq(ProjectileFx.wants(gust), "", "not before it's live")


func test_every_make_has_a_horn() -> void:
	assert_true(SfxSynth.has("bucket_horn"), "revision 11: an audio cue on every bucket")
	assert_eq(PostFX.flash_strength("bucket", true) < PostFX.flash_strength("bucket", false), true, "reduce-flashes dims it")


# ------------------------------------------------------------ revision 16

func _throw_at(target_pos: Vector3) -> Array:
	## A dummy at the origin starts the chancla at a hooper; returns [dummy, hooper].
	var dm: TrainingDummy = sim.dummy(Vector3.ZERO, "passive")
	var h: Hooper = sim.hooper(target_pos, {}, false)
	dm.runner.start(DataDB.move("bk_stoop", "chancla"), h.actor)
	return [dm, h]


func _hits_on(a: SimActor) -> int:
	var n: int = 0
	for e: Dictionary in sim.events:
		if str(e["type"]) == "hit_resolved" and int(e.get("target", 0)) == a.id:
			n += 1
	return n


func test_windup_shows_the_held_slipper_and_a_lane() -> void:
	var pair: Array = _throw_at(Vector3(0, 0, -12))
	var dm: TrainingDummy = pair[0]
	sim.run(12)
	var info: Dictionary = ProjectileFx.windup_of(dm.actor)
	assert_false(info.is_empty(), "winding up")
	assert_gt(float(info["progress"]), 0.2)
	assert_almost_eq((info["dir"] as Vector3).z, -1.0, 0.01, "aimed at the target")
	fx._process(0.016)
	assert_eq(fx.windups.size(), 1, "a wind-up view")
	assert_not_null(fx.windups[dm.actor.id].get_node("Lane"))
	sim.run(30)
	assert_true(ProjectileFx.windup_of(dm.actor).is_empty(), "thrown")
	fx._process(0.016)
	assert_eq(fx.windups.size(), 0, "the held slipper is gone once it's thrown")
	assert_eq(fx.views.size(), 1, "and the slipper is in the air")
	assert_eq(sim.count("projectile_thrown"), 1, "release cue (whoosh)")


func test_chancla_leaves_from_her_edge_not_her_belly() -> void:
	var pair: Array = _throw_at(Vector3(0, 0, -12))
	var dm: TrainingDummy = pair[0]
	sim.run(JU.i(DataDB.move("bk_stoop", "chancla"), "startup") + 1)
	var hb: Hitbox = null
	for x: Hitbox in sim.combat.hitboxes:
		if x.projectile:
			hb = x
	assert_not_null(hb)
	assert_gte(Vector2(hb.volume.origin.x, hb.volume.origin.z).length(), dm.actor.radius, "spawns outside the thrower")


func test_chancla_can_be_side_stepped() -> void:
	## Wind-up >= 0.5 s and flight >= 1.5 s at 12 m; running sideways at
	## run speed once it's thrown gets you out of the way.
	var m: Dictionary = DataDB.move("bk_stoop", "chancla")
	var pd: Dictionary = JU.dict(m, "projectile")
	assert_gte(JU.i(m, "startup"), 30, "a readable wind-up")
	assert_gte(JU.f(pd, "range") / JU.f(pd, "speed"), 1.5, "time to see it coming")
	var pair: Array = _throw_at(Vector3(0, 0, -12))
	var h: Hooper = pair[1]
	var run_speed: float = JU.f(DataDB.tuning("player"), "run_speed", 6.0)
	for f: int in 200:
		if sim.count("projectile_thrown") > 0:
			h.actor.pos.x += run_speed / 60.0
		sim.run(1)
	assert_eq(_hits_on(h.actor), 0, "a sidestep beats it")


func test_chancla_still_hits_if_you_stand_there() -> void:
	var pair: Array = _throw_at(Vector3(0, 0, -12))
	var h: Hooper = pair[1]
	sim.run(200)
	assert_eq(_hits_on(h.actor), 1, "standing still eats it")
