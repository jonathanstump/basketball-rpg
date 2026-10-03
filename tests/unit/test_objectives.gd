extends GutTest
## Story start and objectives: after the prologue you always know what to do
## next (spec §3.2 order), Pops names it, and the HUD points the way.


func before_each() -> void:
	GameState.new_run("nobody", "brooklyn")


func _done(ids: Array) -> void:
	for id: Variant in ids:
		if not GameState.defeated_bosses.has(str(id)):
			GameState.defeated_bosses.append(str(id))


func test_no_objective_before_the_prologue() -> void:
	assert_true(ObjectiveRules.current().is_empty())


func test_home_borough_crown_minis_then_king() -> void:
	GameState.set_flag("prologue_done")
	var cast: Dictionary = ObjectiveRules.borough_cast("brooklyn")
	assert_eq((cast["minis"] as Array).size(), 2, "Brooklyn's two minis")
	assert_false((cast["minis"] as Array).has("opt_ratking"), "optional bosses aren't on the main path")
	assert_eq(str(cast["king"]), "bk_toll")
	var o: Dictionary = ObjectiveRules.current("bk_bedstuy")
	assert_eq(str(o["title"]), "Take the Brooklyn Crown")
	assert_true((cast["minis"] as Array).has(str(o["boss"])), "a mini first")
	assert_eq(str(o["boss"]), "bk_stoop", "the nearest one from Bed-Stuy (its own court)")
	assert_eq(str(o["district"]), "bk_bedstuy")
	assert_string_contains(str(o["detail"]), "(0/3)")
	_done(cast["minis"])
	o = ObjectiveRules.current("bk_bedstuy")
	assert_eq(str(o["boss"]), "bk_toll", "then the King")
	assert_string_contains(str(o["detail"]), "Borough King")
	assert_string_contains(str(o["detail"]), "(2/3)")


func test_next_borough_city_garden_and_after() -> void:
	GameState.set_flag("prologue_done")
	GameState.award_crown("brooklyn")
	var b: String = ObjectiveRules.focus_borough()
	assert_ne(b, "brooklyn")
	assert_eq(TierManager.tier_of(b), 2, "next: the lowest-tier borough left")
	for x: String in ObjectiveRules.ACT_BOROUGHS:
		GameState.award_crown(x)
	var o: Dictionary = ObjectiveRules.current()
	assert_eq(str(o["title"]), "Into the City")
	assert_eq(JU.s(DataDB.boss(str(o["boss"])), "kind"), "landmark")
	for id: Variant in DataDB.catalog("bosses").keys():
		if JU.s(DataDB.boss(str(id)), "kind") == "landmark":
			_done([id])
	o = ObjectiveRules.current()
	assert_eq(str(o["boss"]), "fin_midnight")
	assert_ne(str(o["district"]), "", "the Garden court is on the map")
	GameState.set_flag("ending_daybreak")
	assert_eq(str(ObjectiveRules.current()["title"]), "Run it back")


func test_routes_follow_crossings_and_the_crown_pass() -> void:
	assert_eq(ObjectiveRules.route("bk_bedstuy", "bk_dumbo"), ["bk_dumbo"] as Array[String], "neighbors: one hop")
	assert_true(ObjectiveRules.route("bk_bedstuy", "bk_bedstuy").is_empty())
	var far: Array[String] = ObjectiveRules.route("bk_bedstuy", "si_heap")
	assert_gt(far.size(), 1, "multi-hop route across boroughs")
	assert_eq(far[-1], "si_heap")
	assert_true(ObjectiveRules.route("bk_bedstuy", "city_midtown").is_empty(), "the City needs the Crown Pass")
	for x: String in ObjectiveRules.ACT_BOROUGHS:
		GameState.award_crown(x)
	assert_false(ObjectiveRules.route("bk_bedstuy", "city_midtown").is_empty(), "open with five Crowns")


func test_every_boss_on_a_main_path_is_on_the_map() -> void:
	for b: String in ObjectiveRules.ACT_BOROUGHS:
		var cast: Dictionary = ObjectiveRules.borough_cast(b)
		for id: Variant in (cast["minis"] as Array) + [cast["king"]]:
			assert_ne(ObjectiveRules.boss_district(str(id)), "", "%s has a court" % id)


func test_pops_lines_name_the_real_fights() -> void:
	GameState.set_flag("prologue_done")
	var lines: Dictionary = JU.dict(DataDB.get_dict("dialogue/prologue"), "lines")
	var filled: PackedStringArray = ObjectiveRules.fill(JU.strs(lines, "wake_pops"), "brooklyn")
	var all: String = "\n".join(filled)
	assert_false(all.contains("{"), "every token filled: %s" % all)
	for id: String in ["bk_stoop", "bk_barker", "bk_toll"]:
		assert_string_contains(all, JU.s(DataDB.boss(id), "name"))
	assert_string_contains(all, "Brooklyn")
	assert_string_contains(all, "Midnight")
	var talk: String = "\n".join(ObjectiveRules.fill(JU.strs(lines, "pops_talk"), "brooklyn"))
	assert_string_contains(talk, "Take the Brooklyn Crown")


func test_dialogue_lines_carry_their_speaker() -> void:
	assert_eq(DialogueBox.line_parts("Pops: Easy, kid.", ""), PackedStringArray(["Pops", "Easy, kid."]))
	assert_eq(DialogueBox.line_parts("(A cat.)", "Pops"), PackedStringArray(["", "(A cat.)"]), "narration has no name tag")
	assert_eq(DialogueBox.line_parts("Fine. Show us something, kid.", "Crew"), PackedStringArray(["Crew", "Fine. Show us something, kid."]))


func test_wake_up_scene() -> void:
	GameState.set_flag("prologue_done")
	GameState.flags["wake_up_pending"] = true
	var bid: String = FrontEndFlow.first_bodega("bk_bedstuy")
	SceneRouter.pending = {"kind": "bodega", "id": bid, "return_to": {"district": "bk_bedstuy"}}
	var room: Interior = (load("res://world/interiors/interior.tscn") as PackedScene).instantiate() as Interior
	add_child_autofree(room)
	await wait_physics_frames(3)
	assert_true(room.dialogue.open, "the wake-up conversation plays")
	assert_eq(DialogueBox.line_parts(room.dialogue.lines[0], "")[0], "", "it opens on the cat (narration)")
	assert_string_contains("\n".join(room.dialogue.lines), JU.s(DataDB.boss("bk_toll"), "name"))
	var card: LocationCard = null
	for c: Node in room.get_children():
		if c is LocationCard:
			card = c
	assert_not_null(card, "location card")
	assert_eq(card.top, "BED-STUY, BROOKLYN")
	assert_true(room.pops_here(), "Pops is in the bodega")
	var ids: PackedStringArray = PackedStringArray()
	for e: Dictionary in room.interact.items:
		ids.append(str(e["kind"]))
	assert_true(ids.has("pops"), "you can talk to Pops")
	room.trigger("pops")
	assert_string_contains("\n".join(room.dialogue.lines), "Take the Brooklyn Crown", "Pops repeats the objective")


func test_reading_pops_lines_never_triggers_the_room() -> void:
	## Interact advances dialogue; it must not also fire the nearest
	## interaction (you used to walk out the door while reading Pops).
	GameState.set_flag("prologue_done")
	GameState.flags["wake_up_pending"] = true
	SceneRouter.pending = {"kind": "bodega", "id": FrontEndFlow.first_bodega("bk_bedstuy"), "return_to": {"district": "bk_bedstuy"}}
	var room: Interior = (load("res://world/interiors/interior.tscn") as PackedScene).instantiate() as Interior
	add_child_autofree(room)
	await wait_physics_frames(3)
	for it: Dictionary in room.interact.items:
		it["kind"] = "probe"   # nothing in the room actually runs (no scene change in tests)
	room.player.pos = Vector3(0, 0, 3.0)   # standing right at the door
	var fired: Array[String] = []
	room.interacted.connect(func(k: String) -> void: fired.append(k))
	var presses: int = 0
	while room.dialogue.open and presses < 80:
		Input.action_press("interact")
		await wait_physics_frames(2)
		Input.action_release("interact")
		await wait_physics_frames(3)
		presses += 1
	assert_false(room.dialogue.open, "pressed through every line (%d presses)" % presses)
	await wait_physics_frames(20)
	assert_eq(fired.size(), 0, "no interaction fired while reading: %s" % str(fired))
	Input.action_press("interact")
	await wait_physics_frames(2)
	Input.action_release("interact")
	await wait_physics_frames(3)
	assert_eq(fired.size(), 1, "after the conversation, Interact works again")
