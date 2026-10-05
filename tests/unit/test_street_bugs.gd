extends GutTest
## Playtest revisions R3/R4: street NPCs answer Interact, and gulls don't
## latch onto the player after a dive.


func before_each() -> void:
	GameState.new_run("nobody", "staten_island")
	GameState.set_flag("prologue_done")


func _district(id: String) -> District:
	SceneRouter.pending = {"district": id, "arrive": {}}
	var d: District = (load("res://world/district.tscn") as PackedScene).instantiate() as District
	add_child_autofree(d)
	return d


func _press_interact() -> void:
	Input.action_press("interact")
	await wait_physics_frames(2)
	Input.action_release("interact")
	await wait_physics_frames(3)


func test_old_deckhand_talks() -> void:
	var d: District = _district("si_st_george")
	await wait_physics_frames(3)
	var it: Dictionary = d.interact.find("npc_deckhand")
	assert_false(it.is_empty(), "the Deckhand is an interactable")
	d.player.pos = (it["pos"] as Vector3) + Vector3(0.6, 0, 0)
	d.player.vel = Vector3.ZERO
	await wait_physics_frames(2)
	assert_eq(str(d.interact.nearest(d.player.pos).get("id", "")), "npc_deckhand", "prompt is the Deckhand")
	await _press_interact()
	assert_true(d.dialogue.open, "talking opens the dialogue")
	assert_eq(d.dialogue.speaker, "Old Deckhand")


func test_every_street_npc_has_lines() -> void:
	## Built layouts store lines as PackedStringArray; JU.strs used to read
	## those as empty, so every street NPC (and challenger intro) was silent.
	for id: String in WorldIndex.all().keys():
		var m: MapData = MapParser.load_map(id)
		for n: Variant in JU.a(m.side, "npcs"):
			assert_false(JU.strs(n as Dictionary, "lines").is_empty(), "%s %s has lines" % [id, JU.s(n as Dictionary, "id")])


func test_strs_reads_packed_arrays() -> void:
	assert_eq(JU.strs({"l": PackedStringArray(["a", "b"])}, "l"), PackedStringArray(["a", "b"]))
	assert_eq(JU.strs({"l": ["a", 2]}, "l"), PackedStringArray(["a", "2"]))


func test_gull_dives_wheels_out_and_goes_home() -> void:
	## R3: a gull used to dive once, then hover on top of you forever.
	var sim: CombatSim = CombatSim.new()
	sim.combat.damage.hitstop_enabled = false
	var p: Hooper = sim.hooper(Vector3.ZERO, {}, true)
	var g: SimActor = sim.enemy("gull", Vector3(0, 0, -8), 1, {"facing": 0.0})
	var b: EnemyBrain = sim.brain(g)
	b.alert(p.actor)
	var close_run: int = 0
	var worst: int = 0
	var went_home: bool = false
	for f: int in 60 * 30:
		sim.run(1)
		p.actor.hp = p.actor.hp_max
		close_run = close_run + 1 if g.dist_to(p.actor) < 2.0 else 0
		worst = maxi(worst, close_run)
		if b.state == "leash":
			went_home = true
	assert_lt(worst, 90, "never sits within 2 m for 1.5 s (worst %d frames)" % worst)
	assert_true(went_home, "after a few dives it flies home")
	assert_true(b.state == "idle" or b.state == "leash", "and stays calm for a while (state %s)" % b.state)
	sim.dispose()
