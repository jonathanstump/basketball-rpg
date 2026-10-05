extends GutTest
## M1: camera framing (spec D2).

var cfg: Dictionary


func before_each() -> void:
	cfg = DataDB.tuning("camera")


func test_explore_orbit_geometry() -> void:
	var focus: Vector3 = Vector3(5, 0.9, -3)
	var xf: Transform3D = CameraMath.orbit_transform(focus, 0.0, 50.0, 12.0)
	assert_almost_eq(xf.origin.distance_to(focus), 12.0, 0.001)
	var down: float = rad_to_deg(asin((xf.origin.y - focus.y) / 12.0))
	assert_almost_eq(down, 50.0, 0.01, "pitch 50")
	assert_gt(xf.origin.z, focus.z, "yaw 0 camera sits behind (+Z)")
	assert_true(CameraMath.in_view(xf, 45.0, 16.0 / 9.0, focus, 0.1), "focus centered")


func test_lockon_frames_player_and_target() -> void:
	var player: Vector3 = Vector3(0, 0, 0)
	for target: Vector3 in [Vector3(0, 0, -6), Vector3(8, 0, -8), Vector3(-15, 0, 3), Vector3(2, 0, 18)]:
		var fr: Dictionary = CameraMath.lockon_framing(player, target, Vector3.INF, false, cfg)
		var d: float = fr["distance"]
		assert_between(d, 9.0, 14.0, "distance clamp")
		var xf: Transform3D = CameraMath.orbit_transform(fr["focus"], fr["yaw"], fr["pitch"], d)
		assert_false(fr.is_empty())
		assert_true(CameraMath.in_view(xf, 45.0, 16.0 / 9.0, player + Vector3.UP * 0.7), "player in view for %s" % target)
		assert_true(CameraMath.in_view(xf, 45.0, 16.0 / 9.0, target + Vector3.UP * 1.0), "target in view for %s" % target)


func test_lockon_includes_hoop() -> void:
	var player: Vector3 = Vector3(0, 0, 4)
	var boss: Vector3 = Vector3(0, 0, -2)
	var hoop: Vector3 = Vector3(0, 3.05, -6)
	var fr: Dictionary = CameraMath.lockon_framing(player, boss, hoop, true, cfg)
	var xf: Transform3D = CameraMath.orbit_transform(fr["focus"], fr["yaw"], fr["pitch"], fr["distance"])
	assert_almost_eq(float(fr["pitch"]), 38.0, 0.001)
	for p: Vector3 in [player, boss + Vector3.UP * 2.0, hoop]:
		assert_true(CameraMath.in_view(xf, 45.0, 16.0 / 9.0, p), "in view: %s" % p)


func test_distance_grows_with_separation() -> void:
	var near: Dictionary = CameraMath.lockon_framing(Vector3.ZERO, Vector3(0, 0, -2), Vector3.INF, false, cfg)
	var far: Dictionary = CameraMath.lockon_framing(Vector3.ZERO, Vector3(0, 0, -20), Vector3.INF, false, cfg)
	assert_lt(float(near["distance"]), float(far["distance"]))
	assert_almost_eq(float(far["distance"]), 14.0, 0.001)


func test_segment_blocked_for_cutaway_logic() -> void:
	var col: WorldCollision = WorldCollision.new()
	col.add_box(Vector3(0, 10, 0), Vector3(4, 20, 4))
	assert_true(col.segment_blocked(Vector3(-10, 1, 0), Vector3(10, 1, 0)))
	assert_false(col.segment_blocked(Vector3(-10, 1, 5), Vector3(10, 1, 5)))


func test_free_pitch_reaches_up_past_the_horizon() -> void:
	## R2: look up at the skyline.
	assert_almost_eq(CameraMath.clamp_pitch(-90.0, cfg), JU.f(JU.dict(cfg, "explore"), "pitch_min_deg"), 0.001)
	assert_lt(CameraMath.clamp_pitch(-90.0, cfg), 0.0, "camera can sit below the look point (looking up)")
	assert_almost_eq(CameraMath.clamp_pitch(90.0, cfg), JU.f(JU.dict(cfg, "explore"), "pitch_max_deg"), 0.001)
	var low: Dictionary = CameraMath.explore_shape(CameraMath.clamp_pitch(-90.0, cfg), cfg)
	var high: Dictionary = CameraMath.explore_shape(CameraMath.clamp_pitch(90.0, cfg), cfg)
	assert_lt(float(low["distance"]), float(high["distance"]), "the orbit shortens as it drops")
	assert_gt(float(low["lift"]), float(high["lift"]), "and the look point rises")
	var focus: Vector3 = Vector3(0, float(low["lift"]), 0)
	var xf: Transform3D = CameraMath.orbit_transform(focus, 0.0, CameraMath.clamp_pitch(-90.0, cfg), float(low["distance"]))
	assert_gt(xf.origin.y, 0.3, "never under the street")
	assert_gt((-xf.basis.z).y, 0.0, "looking upward")
	assert_true(CameraMath.in_view(xf, 45.0, 16.0 / 9.0, Vector3(0, 60, -200)), "a tower top 200 m ahead is on screen")


func test_mouse_pitch_matches_yaw_rate() -> void:
	var rig: CameraRig = CameraRig.new()
	add_child_autofree(rig)
	var p0: float = rig.explore_pitch
	rig._add_pitch(rad_to_deg(-100.0 * JU.f(cfg, "mouse_sensitivity", 0.005)))
	assert_almost_eq(p0 - rig.explore_pitch, rad_to_deg(100.0 * JU.f(cfg, "mouse_sensitivity", 0.005)) * Settings.get_float("camera_sensitivity"), 0.01)


func test_camera_pulls_in_before_a_wall() -> void:
	var col: WorldCollision = WorldCollision.new()
	col.set_bounds(Vector2(-100, -100), Vector2(100, 100))
	col.add_box(Vector3(0, 10, 6), Vector3(20, 20, 2))   # wall 6 m behind the player (+Z)
	var focus: Vector3 = Vector3(0, 1.5, 0)
	var d: float = CameraMath.pull_in(focus, 0.0, 10.0, 10.0, col)
	assert_lt(d, 5.5, "pulled in front of the wall (got %.1f)" % d)
	assert_false(col.segment_blocked(focus, CameraMath.orbit_transform(focus, 0.0, 10.0, d).origin))
	assert_almost_eq(CameraMath.pull_in(focus, PI, 10.0, 10.0, col), 10.0, 0.001, "open side: full distance")


func test_duel_framing_keeps_the_hoop_ahead() -> void:
	## R5: the rim is in front of the camera, not behind the boss's shoulder.
	var hoop: Vector3 = Vector3(0, 3.05, -6)
	for player: Vector3 in [Vector3(0, 0, 4), Vector3(5, 0, 2), Vector3(-6, 0, 0)]:
		var boss: Vector3 = player.lerp(Vector3(hoop.x, 0, hoop.z), 0.5) + Vector3(1.5, 0, 0)
		var fr: Dictionary = CameraMath.duel_framing(player, boss, hoop, cfg, 0.0)
		var xf: Transform3D = CameraMath.orbit_transform(fr["focus"], fr["yaw"], fr["pitch"], fr["distance"])
		var fwd: Vector3 = -xf.basis.z
		var to_h: Vector3 = (hoop - xf.origin)
		assert_gt(Vector2(fwd.x, fwd.z).normalized().dot(Vector2(to_h.x, to_h.z).normalized()), 0.95, "looking at the rim from %s" % player)
		for p: Vector3 in [player + Vector3.UP, hoop, boss + Vector3.UP * 1.5]:
			assert_true(CameraMath.in_view(xf, 45.0, 16.0 / 9.0, p), "in view: %s (player %s)" % [p, player])


func test_skyline_rings_the_district_and_rises_toward_the_city() -> void:
	var m: MapData = MapParser.load_map("bk_bedstuy")
	var list: Array[Dictionary] = DistrictSkyline.towers(m, "brooklyn")
	assert_gt(list.size(), 100)
	var half: float = float(m.width) * MapData.TILE * 0.5
	var city_h: float = 0.0
	var far_h: float = 0.0
	for t: Dictionary in list:
		var p: Vector3 = t["pos"]
		assert_gt(Vector2(p.x, p.z).length(), half + 10.0, "outside the map")
		var a: float = atan2(p.x, -p.z)
		if absf(angle_difference(a, deg_to_rad(315.0))) < 0.3:
			city_h = maxf(city_h, (t["size"] as Vector3).y)
		elif absf(angle_difference(a, deg_to_rad(135.0))) < 0.3:
			far_h = maxf(far_h, (t["size"] as Vector3).y)
	assert_gt(city_h, far_h, "Manhattan side is taller")
	assert_eq(DistrictSkyline.towers(m, "brooklyn").size(), list.size(), "deterministic")


func test_duel_framing_looks_past_a_boss_behind_you() -> void:
	var hoop: Vector3 = Vector3(0, 3.05, -6)
	var player: Vector3 = Vector3(0, 0, 2)
	var boss: Vector3 = Vector3(0, 0, 5)   # right behind the player, where the camera wants to be
	var fr: Dictionary = CameraMath.duel_framing(player, boss, hoop, cfg, 0.0, 16.0 / 9.0, 4.0, 1.3)
	var xf: Transform3D = CameraMath.orbit_transform(fr["focus"], fr["yaw"], fr["pitch"], fr["distance"])
	assert_false(CameraMath.boss_hides(xf.origin, player + Vector3.UP * 1.2, boss, 1.3, 4.0), "the player is visible")
	assert_true(CameraMath.in_view(xf, 45.0, 16.0 / 9.0, player + Vector3.UP * 1.2))


func test_duel_framing_when_pinned_against_the_fence() -> void:
	## Seen in a render: the boss pushed the player into the back fence, the
	## camera got pulled in over the player's head and the boss filled the screen.
	var col: WorldCollision = WorldCollision.new()
	col.set_bounds(Vector2(-100, -100), Vector2(100, 100))
	col.add_box(Vector3(0, 1.6, 11.5), Vector3(30, 3.2, 0.3))   # back fence
	var hoop: Vector3 = Vector3(0, 3.05, -6.8)
	var player: Vector3 = Vector3(0, 0, 10.15)
	var boss: Vector3 = Vector3(0, 0, 9.1)
	var fr: Dictionary = CameraMath.duel_framing(player, boss, hoop, cfg, 0.0, 16.0 / 9.0, 4.0, 1.4, col)
	var xf: Transform3D = CameraMath.orbit_transform(fr["focus"], fr["yaw"], fr["pitch"], fr["distance"])
	assert_true(CameraMath.in_view(xf, 45.0, 16.0 / 9.0, player + Vector3.UP * 1.2), "player on screen")
	assert_false(CameraMath.boss_hides(xf.origin, player + Vector3.UP * 1.2, boss, 1.4, 4.0), "not behind the boss")
