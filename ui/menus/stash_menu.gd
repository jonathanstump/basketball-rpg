class_name StashMenu
extends RefCounted
## Bodega stash (spec §5.2): move unequipped gear between your bag and the
## stash (GameState.flags.stash), shared by every bodega.


static func stash() -> Dictionary:
	if not GameState.flags.has("stash"):
		GameState.flags["stash"] = {}
	return GameState.flags["stash"]


static func deposit(id: String) -> bool:
	for slot: Variant in GameState.equipment.keys():
		if str(GameState.equipment[slot]) == id and GameState.item_count(id) <= 1:
			return false
	if GameState.item_count(id) <= 0:
		return false
	GameState.add_item(id, -1)
	var s: Dictionary = stash()
	s[id] = int(s.get(id, 0)) + 1
	return true


static func withdraw(id: String) -> bool:
	var s: Dictionary = stash()
	if int(s.get(id, 0)) <= 0:
		return false
	s[id] = int(s[id]) - 1
	if int(s[id]) <= 0:
		s.erase(id)
	GameState.add_item(id, 1)
	return true


static func open(it: Interior) -> void:
	var opts: Array[Dictionary] = []
	for id: Variant in GameState.inventory.keys():
		if DataDB.catalog_of(str(id)) in ["kicks", "fits", "headbands", "sleeves", "chains", "balls"]:
			opts.append({"id": "d:" + str(id), "label": "Stash %s" % JU.s(DataDB.find_any(str(id)), "name", str(id)), "detail": MenuKit.item_detail(str(id))})
	for id2: Variant in stash().keys():
		opts.append({"id": "w:" + str(id2), "label": "Take %s x%d" % [JU.s(DataDB.find_any(str(id2)), "name", str(id2)), int(stash()[id2])], "detail": MenuKit.item_detail(str(id2))})
	opts.append({"id": "_back", "label": "Back"})
	MenuKit.show(it, "STASH", opts, func(id: String) -> void:
		if id == "_back":
			it.counter_menu()
			return
		if id.begins_with("d:"):
			deposit(id.substr(2))
		else:
			withdraw(id.substr(2))
		open(it))
