extends GutTest
## Revision 10: boroughs look distinct (building palettes, skyline profile,
## tower kinds), street hoops match the court hoops, and the map edge is a
## quay over harbor water with bridges you can't cross.

const BOROUGHS: PackedStringArray = ["bronx", "brooklyn", "queens", "staten_island", "uptown", "city"]


func after_each() -> void:
	KitBuildings.style = {}


func test_every_borough_has_a_look() -> void:
	for b: String in BOROUGHS:
		var prof: Dictionary = DistrictSkyline.profile(b)
		assert_false(prof.is_empty(), "%s skyline profile" % b)
		assert_gt(JU.a(prof, "bridges").size(), 0, "%s has a bridge" % b)
		for br: Variant in JU.a(prof, "bridges"):
			assert_true(JU.s(br as Dictionary, "style") in ["suspension", "arch", "truss"], "%s bridge style" % b)
		var style: Dictionary = JU.dict(JU.dict(DataDB.get_dict("palettes"), "buildings"), b)
		assert_eq(JU.strs(style, "brownstone").size(), 2, "%s brownstone range" % b)
		assert_eq(JU.strs(style, "highrise").size(), 4, "%s high-rise colors" % b)


func test_building_palettes_differ_by_borough() -> void:
	var seen: Dictionary = {}
	for b: String in BOROUGHS:
		KitBuildings.set_borough(b)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 7
		seen[KitBuildings.tone("brownstone", rng, "#000000", "#000000").to_html()] = b
	assert_eq(seen.size(), BOROUGHS.size(), "same seed, different borough -> different walls")
	KitBuildings.set_borough("staten_island")
	assert_eq(JU.s(KitBuildings.style, "roof"), "pitched", "Staten Island gets pitched roofs")


func test_skyline_has_several_tower_kinds_and_water_width_per_borough() -> void:
	var m: MapData = MapParser.load_map("city_midtown")
	var meshes: Dictionary = {}
	var styles: Dictionary = {}
	for t: Dictionary in DistrictSkyline.towers(m, "city"):
		meshes[JU.s(t, "mesh")] = true
		styles[int(t.get("style", 0))] = true
	for k: String in ["box", "cyl", "prism", "needle"]:
		assert_true(meshes.has(k), "the City skyline has %s parts" % k)
	assert_true(styles.has(1) and styles.has(2) and styles.has(3), "glass, lit crowns and beacons")
	var si: MapData = MapParser.load_map("si_st_george")
	var bk: MapData = MapParser.load_map("bk_bedstuy")
	assert_gt(DistrictSkyline.ring_inner(si, "staten_island") - DistrictSkyline.ring_inner(bk, "brooklyn"), 50.0, "the harbor is wider than the East River")


func test_border_builds_water_shore_quay_and_bridges() -> void:
	var m: MapData = MapParser.load_map("bk_bedstuy")
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var border: Node3D = DistrictBorder.build(m, "brooklyn", root)
	assert_not_null(border.get_node_or_null("Water"), "harbor water past the edge")
	assert_not_null(border.get_node_or_null("FarShore"), "a far shore under the skyline")
	var instances: int = 0
	for c: Node in border.get_children():
		if c is MultiMeshInstance3D:
			instances += (c as MultiMeshInstance3D).multimesh.instance_count
			assert_eq((c as MultiMeshInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "no shadow cost")
	assert_gt(instances, 300, "quay rails, lamps and two lit bridges")
	assert_eq(border.find_children("*", "Light3D", true, false).size(), 0, "no real lights (light budget)")


func test_bridges_are_out_of_reach() -> void:
	## They start at the quay, outside the walkable map ('#' ring blocks you).
	var m: MapData = MapParser.load_map("bk_bedstuy")
	var half: float = float(m.width) * MapData.TILE * 0.5
	var w: SimWorld = SimWorld.new(1)
	var root: Node3D = Node3D.new()
	BoroughBuilder.build(m, w, BallSystem.new(w), root)
	var e: float = half - MapData.TILE
	for br: Variant in JU.a(DistrictSkyline.profile("brooklyn"), "bridges"):
		var ang: float = deg_to_rad(JU.f(br as Dictionary, "deg", 0.0))
		var dir: Vector3 = Vector3(sin(ang), 0, -cos(ang))
		var start: Vector3 = dir * (e / maxf(absf(dir.x), absf(dir.z))) + dir * 1.0
		assert_eq(m.at(m.cell_of(start)), "#", "bridge at %d deg starts on the edge ring" % int(JU.f(br as Dictionary, "deg")))
		assert_true(w.collision.blocked(start + Vector3(0, 1.0, 0), 0.4), "and the edge wall stops you there")
	w.dispose()
	root.free()


func test_street_hoop_looks_like_a_court_hoop() -> void:
	var h: SimHoop = SimHoop.crate("t", Vector3.ZERO, Vector3(0, 0, 1))
	var v: HoopView = HoopView.create(h)
	add_child_autofree(v)
	assert_not_null(v.net, "chain net")
	assert_gte(v.get_child_count(), 6, "pole, board, frame, square, rim, net")
	assert_not_null(v.crate_mat, "still glows when its Bucket Blast is ready")
