class_name JournalMenu
extends RefCounted
## Pause -> Word on the Street (playtest R6): what you've heard about the
## people who hold the courts. Entries unlock as NPCs, lieutenants and Mic
## Check tell you about them (LoreBook flags).


static func options() -> Array[Dictionary]:
	var opts: Array[Dictionary] = []
	for id: String in LoreBook.known():
		var e: Dictionary = LoreBook.entry(id)
		var b: Dictionary = DataDB.boss(id)
		var beaten: bool = GameState.defeated_bosses.has(id)
		var lines: PackedStringArray = JU.strs(e, "who")
		var prof: Dictionary = BossHoops.profile(b)
		var detail: String = "\n\n".join(lines)
		detail += "\n\nOn the court: " + JU.s(prof, "theme")
		var lt: Dictionary = JU.dict(e, "lieutenant")
		if not lt.is_empty() and not beaten:
			detail += "\n\n" + ("You got past %s." if GameState.has_flag(CourtGate.lieutenant_flag(id)) else "%s guards the way to the court.") % JU.s(lt, "name")
		var where: String = WorldIndex.district_name(JU.s(b, "district"))
		opts.append({"id": id, "label": "%s%s" % [JU.s(b, "name", id), "  (beaten)" if beaten else ""],
			"detail": ("%s\n\n" % where if where != "" else "") + detail})
	if opts.is_empty():
		opts.append({"id": "_none", "label": "Nothing yet", "detail": "Nobody's told you anything. Talk to people on the street."})
	opts.append({"id": "_back", "label": "Back"})
	return opts


static func open(w: GameWorld, back: Callable) -> void:
	MenuKit.show(w, "WORD ON THE STREET", options(), func(id: String) -> void:
		if id == "_back":
			back.call()
		else:
			open(w, back))
