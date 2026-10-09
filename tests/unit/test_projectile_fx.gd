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
