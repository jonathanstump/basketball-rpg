class_name FrontEndFlow
extends RefCounted
## Scene flow from the title (spec §3.3): New Game -> creator -> prologue
## "I Got Next" -> wake up in the nearest bodega; Continue -> last bodega.

const TITLE: String = "res://ui/title/title_screen.tscn"
const CREATOR: String = "res://ui/creator/creator.tscn"
const PROLOGUE: String = "res://world/prologue/prologue.tscn"


static func latest_slot() -> int:
	## The slot with the newest save, or -1.
	var best: int = -1
	var best_at: String = ""
	for s: int in SaveSystem.SLOTS:
		var sum: Dictionary = SaveSystem.slot_summary(s)
		if not sum.is_empty() and JU.s(sum, "saved_at") >= best_at:
			best = s
			best_at = JU.s(sum, "saved_at")
	return best


static func free_slot() -> int:
	for s: int in SaveSystem.SLOTS:
		if not SaveSystem.has_slot(s):
			return s
	return 0


static func start_new_game(arch: String, borough: String, profile: Dictionary, slot: int) -> void:
	GameState.new_run(arch, borough, profile)
	SaveSystem.active_slot = slot
	GameState.current_district = start_district(borough)
	SaveSystem.save_slot(slot)
	SceneRouter.goto(PROLOGUE, {"borough": borough})


static func start_district(borough: String) -> String:
	var d: String = JU.s(DataDB.item("boroughs", borough), "start_district", "bk_bedstuy")
	return d if WorldIndex.has_district(d) else "bk_bedstuy"


static func first_bodega(district: String) -> String:
	var side: Dictionary = WorldIndex.districts.get(district, {}) if WorldIndex.has_district(district) else {}
	var b: Array = JU.a(side, "bodegas")
	return JU.s(b[0] as Dictionary, "id") if not b.is_empty() else ""


static func continue_game(slot: int) -> bool:
	if not SaveSystem.load_slot(slot):
		return false
	if not GameState.has_flag("prologue_done"):
		SceneRouter.goto(PROLOGUE, {"borough": GameState.start_borough})
		return true
	var d: String = GameState.current_district if WorldIndex.has_district(GameState.current_district) else start_district(GameState.start_borough)
	var arrive: Dictionary = {}
	if GameState.respawn_bodega != "" and JU.s(WorldIndex.bodega(GameState.respawn_bodega), "district") == d:
		arrive = {"kind": "bodega", "id": GameState.respawn_bodega}
	SceneRouter.goto_district(d, arrive, false)
	return true


static func wake_up() -> void:
	## After the Midnight cameo: the nearest bodega, cat on your chest, Pops.
	GameState.set_flag("prologue_done")
	var d: String = start_district(GameState.start_borough)
	var bid: String = first_bodega(d)
	GameState.respawn_bodega = bid
	GameState.flags["wake_up_pending"] = true
	SaveSystem.request_autosave()
	if bid != "":
		SceneRouter.goto_interior("bodega", bid, {"district": d, "arrive": {"kind": "bodega", "id": bid}})
	else:
		SceneRouter.goto_district(d, {}, false)
