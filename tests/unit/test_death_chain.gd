extends GutTest
## Revisions 8 + 14: when you die, all your unspent Rep drops as
## your chain, under a light beam in the sky, and a marker leads you back.


func before_each() -> void:
	GameState.new_run("nobody", "brooklyn")
	GameState.set_flag("prologue_done")


func test_all_of_it_is_recoverable() -> void:
	assert_eq(ChainRules.recoverable(901), 901)
	assert_eq(ChainRules.recoverable(1), 1)
	assert_eq(ChainRules.recoverable(0), 0)


func test_waypoint_prefers_a_chain_in_this_district() -> void:
	assert_true(ChainRules.waypoint([], "bk_bedstuy").is_empty())
	var chains: Array = [{"district": "bk_coney", "pos": [1, 0, 1], "rep": 10, "lives": 0},
		{"district": "bk_bedstuy", "pos": [5, 0, 5], "rep": 20, "lives": 0}]
	var wp: Dictionary = ChainRules.waypoint(chains, "bk_bedstuy")
	assert_eq(str(wp["district"]), "bk_bedstuy")
	assert_eq(int(wp["rep"]), 20)
	assert_eq(str(ChainRules.waypoint(chains, "bk_dumbo")["district"]), "bk_coney", "else the first one anywhere")


func _district(id: String) -> District:
	SceneRouter.pending = {"district": id, "arrive": {}}
	var d: District = (load("res://world/district.tscn") as PackedScene).instantiate() as District
	add_child_autofree(d)
	return d


func test_dying_drops_it_all_under_a_beam_and_the_marker_leads_back() -> void:
	var d: District = _district("bk_bedstuy")
	await wait_physics_frames(3)
	GameState.rep = 901
	var died_at: Vector3 = d.player.pos
	d.lifecycle.on_player_killed()
	assert_eq(GameState.rep, 0, "you lose your unspent Rep")
	assert_eq(ChainRules.total_rep(GameState.chains), 901, "all of it is on the chain")
	d.lifecycle.refresh_chain_views()
	assert_eq(d.lifecycle.chain_views.size(), 1)
	var beam: Node3D = d.lifecycle.chain_views[0].get_node_or_null("Beam") as Node3D
	assert_not_null(beam, "a light beam over the chain")
	assert_gt((beam as MeshInstance3D).mesh.get_aabb().size.y, 50.0, "tall enough to see over the rooftops")
	d.update_objective()
	assert_true(d.objective_panel.has_chain, "a marker to follow")
	assert_true(d.objective_panel.chain_target.distance_to(died_at) < 0.01)
	assert_string_contains(d.objective_panel.chain_label, "901")
	d.lifecycle.dying = false
	d.player.pos = died_at
	d.lifecycle.physics_check()
	assert_eq(GameState.rep, 901, "ran it back")
	d.update_objective()
	assert_false(d.objective_panel.has_chain, "marker gone once you have it")


func test_marker_points_to_the_crossing_toward_a_chain_elsewhere() -> void:
	GameState.chains = [{"district": "bk_coney", "pos": [0, 0, 0], "rep": 30, "lives": 0}]
	var d: District = _district("bk_bedstuy")
	await wait_physics_frames(3)
	d.update_objective()
	assert_true(d.objective_panel.has_chain)
	assert_string_contains(d.objective_panel.chain_label, "Coney Island")
	var at_crossing: bool = false
	for x: Variant in JU.a(d.layout, "crossings"):
		at_crossing = at_crossing or ((x as Dictionary)["pos"] as Vector3).distance_to(d.objective_panel.chain_target) < 0.01
	assert_true(at_crossing, "points at the way out toward it")
