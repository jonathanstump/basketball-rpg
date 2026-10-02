class_name PauseMenu
extends RefCounted
## Pause anywhere (spec §14): Locker (gear), Ink (tattoo slots), Bag (moves),
## Stats, Items (consumables), Settings, Quit to title. Sticker-style lists.

const SLOT_LABELS: Dictionary = {"ball_1": "Ball 1", "ball_2": "Ball 2", "kicks": "Kicks", "fit": "Fit", "headband": "Headband",
	"sleeve": "Sleeve", "chain_1": "Chain 1", "chain_2": "Chain 2"}


static func open(w: GameWorld) -> void:
	var opts: Array[Dictionary] = [
		{"id": "resume", "label": "Resume"}, {"id": "locker", "label": "Locker", "detail": "Balls, kicks, fits, headbands, sleeves, chains."},
		{"id": "ink", "label": "Ink", "detail": "Your tattoos and open slots."}, {"id": "bag", "label": "Bag", "detail": "Bag Moves you know."},
		{"id": "stats", "label": "Stats"}, {"id": "items", "label": "Items", "detail": "Bodega snacks and keys."},
		{"id": "settings", "label": "Settings"}, {"id": "quit", "label": "Save & Quit to Title"},
	]
	MenuKit.show(w, "PAUSED", opts, func(id: String) -> void: _on_pause(w, id))


static func _on_pause(w: GameWorld, id: String) -> void:
	match id:
		"locker":
			locker(w)
		"ink":
			ink(w)
		"bag":
			bag(w)
		"stats":
			stats(w)
		"items":
			items(w)
		"settings":
			SettingsMenu.open(w, func() -> void: open(w))
		"quit":
			SaveSystem.save_slot(SaveSystem.active_slot)
			w.close_menu()
			SceneRouter.goto(ProjectSettings.get_setting("application/run/main_scene"))
		_:
			w.close_menu()


static func locker(w: GameWorld) -> void:
	var opts: Array[Dictionary] = []
	for slot: Variant in SLOT_LABELS.keys():
		var id: String = str(GameState.equipment.get(slot, ""))
		opts.append({"id": str(slot), "label": "%s:  %s" % [SLOT_LABELS[slot], JU.s(DataDB.find_any(id), "name", "-") if id != "" else "-"], "detail": MenuKit.item_detail(id) if id != "" else "Empty."})
	opts.append({"id": "_back", "label": "Back"})
	MenuKit.show(w, "LOCKER", opts, func(slot: String) -> void:
		if slot == "_back":
			open(w)
		else:
			_pick(w, slot))


static func _pick(w: GameWorld, slot: String) -> void:
	var cat: String = str(PlayerBuild.SLOT_CATALOG.get(slot, ""))
	var opts: Array[Dictionary] = [{"id": "_none", "label": "Unequip"}]
	var ids: Array = GameState.inventory.keys()
	ids.sort()
	for id: Variant in ids:
		if DataDB.catalog_of(str(id)) == cat:
			opts.append({"id": str(id), "label": JU.s(DataDB.find_any(str(id)), "name", str(id)), "detail": MenuKit.item_detail(str(id))})
	opts.append({"id": "_back", "label": "Back"})
	MenuKit.show(w, str(SLOT_LABELS[slot]).to_upper(), opts, func(id: String) -> void:
		if id != "_back":
			equip(w, slot, "" if id == "_none" else id)
		locker(w))


static func equip(w: GameWorld, slot: String, id: String) -> void:
	if slot == "ball_1" and id == "":
		return
	if id == "":
		GameState.equipment.erase(slot)
	else:
		GameState.equipment[slot] = id
	if slot == "ball_1" and w.player != null:
		BallProps.apply(w.player, id)
		var b: SimBall = w.balls.ball_of(w.player)
		if b != null:
			b.item_id = id
	if w.player != null:
		PlayerBuild.apply(w.player, w.player_hooper)
		w.player.flags["qw"] = GameState.quarter_waters


static func ink(w: GameWorld) -> void:
	var opts: Array[Dictionary] = []
	for i: int in 7:
		var label: String = "Locked (needs a Crown)"
		var detail: String = "Slots open: 2 + one per Crown."
		if i < TattooRules.slots():
			label = "Open slot"
			if i < GameState.tattoos.size():
				var t: Dictionary = DataDB.item("tattoos", GameState.tattoos[i])
				label = JU.s(t, "name")
				detail = JU.s(t, "description")
		opts.append({"id": "slot_%d" % i, "label": label, "detail": detail, "enabled": i < TattooRules.slots()})
	opts.append({"id": "_back", "label": "Back"})
	MenuKit.show(w, "INK  %d/%d" % [GameState.tattoos.size(), TattooRules.slots()], opts, func(id: String) -> void:
		if id == "_back":
			open(w))


static func bag(w: GameWorld) -> void:
	var opts: Array[Dictionary] = []
	for bm: String in GameState.known_bag_moves:
		var d: Dictionary = DataDB.item("bag_moves", bm)
		opts.append({"id": bm, "label": JU.s(d, "name") + (" (equipped)" if str(GameState.equipment.get("bag_move", "")) == bm else ""), "detail": "%s\nCost: %d Hype. Swap at any bodega." % [JU.s(d, "effect"), int(JU.f(d, "hype"))]})
	opts.append({"id": "_back", "label": "Back"})
	MenuKit.show(w, "BAG", opts, func(id: String) -> void:
		if id == "_back":
			open(w))


static func stats(w: GameWorld) -> void:
	var a: SimActor = w.player
	var opts: Array[Dictionary] = []
	for s: String in DataSchemas.STATS:
		opts.append({"id": s, "label": "%s  %d" % [s.to_upper(), a.stat(s) if a != null else GameState.stat(s)], "detail": str(TrainMenu.BLURB[s])})
	var detail: String = "Level %d   Rep %d / %d to next\nHeart %d   Wind %d   DR %d%%   Poise %d\nParry %d frames   Ankle window to frame %d\nNickname: %s" % [
		GameState.level, GameState.rep, Leveling.cost(GameState.level), int(a.hp_max) if a != null else 0, int(a.wind.max_value) if a != null else 0,
		int(DamageMath.actor_dr(a) * 100.0) if a != null else 0, int(a.poise) if a != null else 0,
		int(StatFormulas.parry_window_frames(GameState.stat("hands"), 10.0)), 12 + int(StatFormulas.ankle_bonus_frames(GameState.stat("handles"))),
		GameState.nickname if GameState.nickname != "" else "-"]
	opts.append({"id": "_back", "label": "Back", "detail": detail})
	MenuKit.show(w, "STATS", opts, func(id: String) -> void:
		if id == "_back":
			open(w), detail)


static func items(w: GameWorld) -> void:
	var opts: Array[Dictionary] = []
	var ids: Array = GameState.inventory.keys()
	ids.sort()
	for id: Variant in ids:
		var cat: String = DataDB.catalog_of(str(id))
		if cat in ["consumables", "materials", "key_items", "flash_sheets", "mixtapes"]:
			opts.append({"id": str(id), "label": "%s x%d" % [JU.s(DataDB.find_any(str(id)), "name", str(id)), GameState.item_count(str(id))], "detail": MenuKit.item_detail(str(id)), "enabled": cat == "consumables" or cat == "mixtapes"})
	opts.append({"id": "_back", "label": "Back"})
	MenuKit.show(w, "ITEMS", opts, func(id: String) -> void:
		if id == "_back":
			open(w)
			return
		if DataDB.has_item("mixtapes", id):
			var teaches: String = JU.s(DataDB.item("mixtapes", id), "teaches")
			if not GameState.known_bag_moves.has(teaches):
				GameState.known_bag_moves.append(teaches)
				EventBus.popup_text.emit("LEARNED " + JU.s(DataDB.item("bag_moves", teaches), "name").to_upper(), w.player.pos, "style")
			GameState.add_item(id, -1)
		elif w.player != null and PlayerBuffs.use(w.player, id, w.sim.frame):
			EventBus.popup_text.emit(JU.s(DataDB.find_any(id), "name").to_upper(), w.player.pos, "good")
		items(w))
