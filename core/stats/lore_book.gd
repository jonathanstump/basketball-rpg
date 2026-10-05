class_name LoreBook
extends RefCounted
## Word on the street (playtest R6): who each boss was before the clocks
## stopped, their lieutenant, and the rumors NPCs tell. Lore you've heard is
## remembered as GameState flags ("lore_<boss>") for the journal.


static func entries() -> Array:
	return JU.a(DataDB.get_dict("dialogue/lore"), "entries")


static func entry(boss_id: String) -> Dictionary:
	for e: Variant in entries():
		if JU.s(e as Dictionary, "id") == boss_id:
			return e
	return {}


static func lieutenant(boss_id: String) -> Dictionary:
	return JU.dict(entry(boss_id), "lieutenant")


static func hear(boss_id: String) -> bool:
	## Returns true the first time.
	if boss_id == "" or entry(boss_id).is_empty() or heard(boss_id):
		return false
	GameState.set_flag("lore_" + boss_id)
	return true


static func heard(boss_id: String) -> bool:
	return GameState.has_flag("lore_" + boss_id)


static func known() -> Array[String]:
	var out: Array[String] = []
	for e: Variant in entries():
		var id: String = JU.s(e as Dictionary, "id")
		if heard(id):
			out.append(id)
	return out
