extends GutTest
## M1: puppet rig, character builder, pose library.


func test_pose_library_has_required_anims() -> void:
	var lib: PoseLibrary = PoseLibrary.get_set("hooper")
	for a: String in ["idle", "dribble_idle", "walk", "run", "sprint", "crossover", "slide", "jump", "land", "hit", "knockdown", "death"]:
		assert_true(lib.has_anim(a), a)
	assert_eq(lib.anim_for_state("defensive_slide"), "slide")
	assert_eq(lib.anim_for_state("stepback"), "crossover")


func test_pose_sampling_interpolates() -> void:
	var lib: PoseLibrary = PoseLibrary.get_set("hooper")
	var a: Dictionary = lib.sample("walk", 0.0)
	var mid: Dictionary = lib.sample("walk", 0.16)
	var b: Dictionary = lib.sample("walk", 0.32)
	var ta: Vector3 = a["thigh_l"]
	var tm: Vector3 = mid["thigh_l"]
	var tb: Vector3 = b["thigh_l"]
	assert_almost_eq(ta.x, 28.0, 0.01)
	assert_almost_eq(tb.x, -22.0, 0.01)
	assert_between(tm.x, -22.0, 28.0)
	var loop_wrap: Dictionary = lib.sample("walk", 0.64)
	assert_almost_eq((loop_wrap["thigh_l"] as Vector3).x, 28.0, 0.01, "loops")


func test_non_loop_holds_last_pose() -> void:
	var lib: PoseLibrary = PoseLibrary.get_set("hooper")
	var p: Dictionary = lib.sample("knockdown", 5.0)
	assert_almost_eq((p["_root_rot"] as Vector3).x, 82.0, 0.01)


func test_character_builder_builds_all_joints() -> void:
	var rig: PuppetRig = CharacterBuilder.build({})
	for j: String in PuppetRig.JOINTS:
		assert_not_null(rig.joint(j), j)
	assert_not_null(rig.ball_anchor)
	rig.apply_pose(PoseLibrary.get_set("hooper").pose("land"))
	assert_lt(rig.joint("hips").position.y, 0.54)
	rig.free()


func test_every_hair_style_builds() -> void:
	assert_eq(DataDB.catalog("hair_styles").size(), 16)
	for id: Variant in DataDB.catalog("hair_styles").keys():
		var rig: PuppetRig = CharacterBuilder.build({"hair_style": str(id)})
		assert_not_null(rig.joint("head"), str(id))
		rig.free()


func test_hooper_anim_states() -> void:
	var w: SimWorld = SimFixture.world()
	var h: Hooper = SimFixture.hooper(w)
	SimFixture.script_of(h).move_at(5, Vector2(1, 0)).press_at(30, "jump")
	w.step_n(2)
	assert_eq(h.actor.anim_state, "dribble_idle")
	w.step_n(20)
	assert_eq(h.actor.anim_state, "run")
	w.step_n(12)
	assert_eq(h.actor.anim_state, "jump")
	w.dispose()
