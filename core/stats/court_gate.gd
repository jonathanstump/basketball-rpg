class_name CourtGate
extends RefCounted
## Who may play which court (playtest R6). Before you can challenge a boss,
## the street has to know your name:
## - mini-bosses and landmarks: get known in the district (StreetRep "Buzz"),
##   then beat their lieutenant (a named crew captain who only shows up once
##   word gets around);
## - Borough Kings: the borough's minis first, then Buzz, then the King's
##   lieutenant.
## Beaten bosses' courts stay open; the Garden keeps its ticket-stub gate;
## optional bosses are open. Pure: reads GameState and data.


static func lieutenant_flag(boss_id: String) -> String:
	return "lt_beaten_" + boss_id


static func status(boss_id: String) -> Dictionary:
	## {open: bool, need: "" | "minis" | "rep" | "lieutenant", text: in-world line}
	var b: Dictionary = DataDB.boss(boss_id)
	var kind: String = JU.s(b, "kind")
	if GameState.defeated_bosses.has(boss_id) or kind in ["final", "superboss", "rival"] or boss_id.begins_with("opt_") or JU.b(b, "optional"):
		return {"open": true, "need": "", "text": ""}
	var name: String = JU.s(b, "name", boss_id)
	if kind == "king":
		var cast: Dictionary = ObjectiveRules.borough_cast(JU.s(b, "borough"))
		for m: Variant in cast["minis"]:
			if not GameState.defeated_bosses.has(str(m)):
				return {"open": false, "need": "minis", "text": "%s doesn't take challengers with no name. Beat the borough's best first." % _title(name)}
	var lt: Dictionary = LoreBook.lieutenant(boss_id)
	if not lt.is_empty() and not GameState.has_flag(lieutenant_flag(boss_id)) and not StreetRep.known_for(boss_id):
		var where: String = WorldIndex.district_name(ObjectiveRules.boss_district(boss_id))
		return {"open": false, "need": "rep", "text": "Nobody in %s knows your name yet. Run with the crews, read the walls, talk to people." % where}
	if not lt.is_empty() and not GameState.has_flag(lieutenant_flag(boss_id)):
		return {"open": false, "need": "lieutenant", "text": "%s's court. %s decides who plays here." % [_title(name), JU.s(lt, "name")]}
	return {"open": true, "need": "", "text": ""}


static func is_open(boss_id: String) -> bool:
	return bool(status(boss_id)["open"])


static func mark_lieutenant_beaten(boss_id: String) -> void:
	GameState.set_flag(lieutenant_flag(boss_id))


static func _title(n: String) -> String:
	## "THE STOOP QUEEN" -> "The Stoop Queen" for sentences.
	var words: PackedStringArray = n.to_lower().split(" ")
	for i: int in words.size():
		words[i] = words[i].capitalize()
	return " ".join(words)
