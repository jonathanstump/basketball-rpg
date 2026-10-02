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
