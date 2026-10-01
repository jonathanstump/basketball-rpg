class_name SaveMigrations
extends RefCounted
## Per-version save migrations (spec §15.14). Version 0 = pre-schema saves
## (no schema_version key) whose game state sat at the top level.


static func migrate(data: Dictionary, target: int) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	var v: int = JU.i(d, "schema_version", 0)
	while v < target:
		match v:
			0:
				d = _v0_to_v1(d)
			_:
				push_error("No save migration from version %d" % v)
				return {}
		v = JU.i(d, "schema_version", v + 1)
	return d


static func _v0_to_v1(d: Dictionary) -> Dictionary:
	var game: Dictionary = d.duplicate(true)
	if game.has("money"):
		game["tokens"] = game["money"]
		game.erase("money")
	if game.has("xp"):
		game["rep"] = game["xp"]
		game.erase("xp")
	return {"schema_version": 1, "saved_at": "", "game": game}
