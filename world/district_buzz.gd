class_name DistrictBuzz
extends RefCounted
## Street rep in a live district (NEXT_SESSION step 3): earn Buzz from
## crews, tags, people, stashes and the side street; once the block knows
## your name, the court's lieutenant shows up and says so.


static func earn(d: District, source: String, once_id: String = "", at: Variant = null) -> int:
	var before: Array[String] = _waiting(d)
	var n: int = StreetRep.earn(d.district_id, source, once_id)
	if n <= 0:
		return 0
	var pos: Vector3 = at if at is Vector3 else (d.player.pos if d.player != null else Vector3.ZERO)
	var need: int = StreetRep.district_need(d.district_id)
	var have: int = StreetRep.points(d.district_id)
	if need > 0 and not before.is_empty():
		EventBus.popup_text.emit("+%d BUZZ  %d/%d" % [n, mini(have, need), need], pos + Vector3(0, 0.5, 0), "tokens")
	var now_known: Array[String] = []
	for boss_id: String in before:
		if StreetRep.known_for(boss_id):
			now_known.append(boss_id)
	if not now_known.is_empty():
		_word_gets_around(d, now_known)
	return n


static func on_kill(d: District, a: SimActor) -> void:
	if a.team == 0 or a.kind != "enemy" or a.flags.has("lieutenant") or a.flags.has("side_crew") or bool(a.flags.get("prop_target", false)):
		return
	earn(d, "captain_beaten" if bool(a.flags.get("captain", false)) else "crew_beaten", "", a.pos)


static func _waiting(d: District) -> Array[String]:
	## Courts here still waiting on Buzz before their lieutenant shows.
	var out: Array[String] = []
	for boss_id: String in StreetRep.gated_courts(d.district_id):
		if not GameState.defeated_bosses.has(boss_id) and not GameState.has_flag(CourtGate.lieutenant_flag(boss_id)) and not StreetRep.known_for(boss_id):
			out.append(boss_id)
	return out


static func _word_gets_around(d: District, bosses: Array[String]) -> void:
	d.spawn_lieutenants()
	var lines: PackedStringArray = PackedStringArray()
	for boss_id: String in bosses:
		var lt: Dictionary = LoreBook.lieutenant(boss_id)
		lines.append("(Word gets around %s. %s heard about you, and is waiting by %s's court.)" % [WorldIndex.district_name(d.district_id), JU.s(lt, "name"), CourtGate._title(JU.s(DataDB.boss(boss_id), "name"))])
	EventBus.popup_text.emit("THE BLOCK KNOWS YOUR NAME", d.player.pos if d.player != null else Vector3.ZERO, "style")
	EventBus.dialogue_requested.emit("", lines)
	d.update_objective()
	SaveSystem.request_autosave()
