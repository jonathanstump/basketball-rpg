extends QAScript
## QA City run (spec §16 M11): five Crowns -> the Crown Pass opens the park
## gate into Midtown; sweep Downtown and Midtown; beat all five landmarks
## (god-mode bot, Tier 6); five Garden Ticket stubs.


func run() -> bool:
	await frames(3)
	GameState.new_run("two_way", "uptown", {"name": "QA"})
	GameState.set_flag("prologue_done")
	SceneRouter.goto_district("up_harlem", {}, false)
	await frames(10)
	var d: District = get_tree().current_scene as District
	var gate: Dictionary = {}
	for it: Dictionary in d.interact.items:
		if str(it["kind"]) == "crossing" and JU.s(it["data"] as Dictionary, "to") == "city_midtown":
			gate = it
	if not check(not gate.is_empty(), "no park gate crossing in Harlem"):
		return false
	DistrictActions.trigger(d, gate)
	await frames(6)
	if not check(get_tree().current_scene == d, "the gate opened without the Crown Pass"):
		return false
	for b: String in DataSchemas.BOROUGHS:
		GameState.award_crown(b)
	DistrictActions.trigger(d, gate)
	for _i: int in 600:
		await frames(1)
		var cur: Node = get_tree().current_scene
		if cur is District and (cur as District).district_id == "city_midtown":
			break
	var now: Node = get_tree().current_scene
	if not check(now is District and (now as District).district_id == "city_midtown", "the Crown Pass did not take us into Midtown"):
		return false
	var runner: QABoroughRun = QABoroughRun.new()
	add_child(runner)
	GameState.add_item("box_key", 20)
	for id: String in ["city_downtown", "city_midtown"]:
		if await runner.sweep_district(id) < 0:
			return fail(runner.failure)
	if not await runner.visit_interiors(["city_downtown", "city_midtown"]):
		return fail(runner.failure)
	for b: String in ["city_chainlink", "city_suspension", "city_gator", "city_primetime", "city_gargoyle"]:
		if not await runner.fight(b):
			return fail(runner.failure)
	if not check(GameState.garden_tickets.size() == 5, "Garden Ticket stubs: %d" % GameState.garden_tickets.size()):
		return false
	print("QA city: 5 landmarks down, %d Garden stubs" % GameState.garden_tickets.size())
	return true
