class_name ShopService
extends RefCounted
## Shopkeepers (spec §3.4, §10): The Plug (wearables up to Epic; buy/sell),
## Gripz at Pump & Grip (balls, Grip Tape, ball upgrades), Ink at Ink &
## Needle (apply / laser tattoos), and the bodega counter (consumables).


static func keeper(kind: String) -> String:
	return {"plug": "The Plug", "pump_grip": "Gripz", "ink_needle": "Ink"}.get(kind, "the owner")


static func region() -> String:
	var b: String = WorldIndex.district_borough(GameState.current_district)
	return b if b != "" else "brooklyn"


static func on_enter(it: Interior) -> void:
	var line: String = {"plug": "I got a guy everywhere. What size you wear?", "pump_grip": "Grip it right and the ball does half the work.", "ink_needle": "Pick a flash. It's on you for good."}.get(it.kind, "")
	EventBus.dialogue_requested.emit(keeper(it.kind), PackedStringArray([line]))


static func open(it: Interior) -> void:
	var opts: Array[Dictionary] = []
	match it.kind:
		"plug":
			opts = [{"id": "buy", "label": "Buy"}, {"id": "sell", "label": "Sell"}]
		"pump_grip":
			opts = [{"id": "buy", "label": "Buy"}, {"id": "upgrade", "label": "Upgrade a ball"}, {"id": "sell", "label": "Sell"}]
		"ink_needle":
			opts = [{"id": "apply", "label": "Get inked", "detail": "Slots: %d / %d" % [GameState.tattoos.size(), TattooRules.slots()]}, {"id": "laser", "label": "Laser removal"}]
	opts.append({"id": "_leave", "label": "Leave"})
	MenuKit.show(it, keeper(it.kind).to_upper(), opts, func(id: String) -> void: _on_main(it, id))


static func _on_main(it: Interior, id: String) -> void:
	match id:
		"buy":
			_buy(it, ShopLogic.plug_stock(region()) if it.kind == "plug" else ShopLogic.pump_stock())
		"sell":
			_sell(it)
		"upgrade":
			_upgrade(it)
		"apply":
			_ink(it)
		"laser":
			_laser(it)
		_:
			it.close_menu()


static func open_bodega(it: Interior) -> void:
	var stock: PackedStringArray = PackedStringArray()
	for id: Variant in DataDB.catalog("consumables").keys():
		stock.append(str(id))
	stock.sort()
	_buy(it, stock)


static func _buy(it: Interior, stock: PackedStringArray) -> void:
	var opts: Array[Dictionary] = []
	for id: String in stock:
		var p: int = ShopLogic.price(id, region())
		opts.append({"id": id, "label": "%s  -  %d" % [JU.s(DataDB.find_any(id), "name", id), p], "detail": MenuKit.item_detail(id) + "\nOwned: %d" % GameState.item_count(id), "enabled": GameState.tokens >= p})
	opts.append({"id": "_back", "label": "Back"})
	MenuKit.show(it, "BUY", opts, func(id: String) -> void:
		if id == "_back":
			_back(it)
			return
		var err: String = ShopLogic.buy(id, region())
		EventBus.popup_text.emit(err.to_upper() if err != "" else "BOUGHT", it.player.pos, "bad" if err != "" else "tokens")
		_buy(it, stock))


static func _sell(it: Interior) -> void:
	var opts: Array[Dictionary] = []
	var ids: Array = GameState.inventory.keys()
	ids.sort()
	for id: Variant in ids:
		var cat: String = DataDB.catalog_of(str(id))
		if cat in ["kicks", "fits", "headbands", "sleeves", "chains", "balls", "consumables"]:
			opts.append({"id": str(id), "label": "%s x%d  -  %d" % [JU.s(DataDB.find_any(str(id)), "name", str(id)), GameState.item_count(str(id)), ShopLogic.sell_price(str(id), region())], "detail": MenuKit.item_detail(str(id))})
	opts.append({"id": "_back", "label": "Back"})
	MenuKit.show(it, "SELL", opts, func(id: String) -> void:
		if id == "_back":
			_back(it)
			return
		var err: String = ShopLogic.sell(id, region())
		EventBus.popup_text.emit(err.to_upper() if err != "" else "SOLD", it.player.pos, "bad" if err != "" else "tokens")
		_sell(it))


static func _upgrade(it: Interior) -> void:
	var opts: Array[Dictionary] = []
	for id: Variant in GameState.inventory.keys():
		if DataDB.has_item("balls", str(id)):
			var lvl: int = int(GameState.ball_upgrades.get(str(id), 0))
			var nxt: int = lvl + 1
			opts.append({"id": str(id), "label": "%s +%d -> +%d  -  %d" % [JU.s(DataDB.ball(str(id)), "name"), lvl, nxt, ShopLogic.upgrade_cost(nxt, region())],
				"detail": "Needs 1 %s (you have %d).\n%s" % [JU.s(DataDB.find_any(ShopLogic.upgrade_material(nxt)), "name"), GameState.item_count(ShopLogic.upgrade_material(nxt)), MenuKit.item_detail(str(id))], "enabled": lvl < 10})
	opts.append({"id": "_back", "label": "Back"})
	MenuKit.show(it, "UPGRADE", opts, func(id: String) -> void:
		if id == "_back":
			_back(it)
			return
		var err: String = ShopLogic.upgrade(id, region())
		var msg: String = "UPGRADED" if err == "" else ("OLD FAITHFUL!" if err.begins_with("evolved") else err.to_upper())
		EventBus.popup_text.emit(msg, it.player.pos, "style" if err == "" or err.begins_with("evolved") else "bad")
		_upgrade(it))


static func _ink(it: Interior) -> void:
	var opts: Array[Dictionary] = []
	for id: Variant in DataDB.catalog("tattoos").keys():
		var t: Dictionary = DataDB.item("tattoos", str(id))
		if GameState.item_count(JU.s(t, "flash")) > 0 and not GameState.tattoos.has(str(id)):
			var why: String = TattooRules.can_apply(str(id), region())
			opts.append({"id": str(id), "label": "%s  -  %d" % [JU.s(t, "name"), TattooRules.apply_cost(region())], "detail": JU.s(t, "description") + ("" if why == "" else "\n(%s)" % why), "enabled": why == ""})
	if opts.is_empty():
		opts.append({"id": "_none", "label": "No flash sheets", "enabled": false, "detail": "Find flash sheets in shoeboxes and on bosses."})
	opts.append({"id": "_back", "label": "Back"})
	MenuKit.show(it, "INK", opts, func(id: String) -> void:
		if id == "_back" or id == "_none":
			_back(it)
			return
		if TattooRules.apply(id, region()):
			EventBus.popup_text.emit("FRESH INK", it.player.pos, "style")
			PlayerBuild.apply(it.player, it.player_hooper)
		_ink(it))


static func _laser(it: Interior) -> void:
	var opts: Array[Dictionary] = []
	for id: String in GameState.tattoos:
		var t: Dictionary = DataDB.item("tattoos", id)
		opts.append({"id": id, "label": "%s  -  %d" % [JU.s(t, "name"), TattooRules.laser_cost(region())], "detail": "Destroys the flash sheet. " + JU.s(t, "description")})
	opts.append({"id": "_back", "label": "Back"})
	MenuKit.show(it, "LASER", opts, func(id: String) -> void:
		if id == "_back":
			_back(it)
			return
		if TattooRules.laser(id, region()):
			EventBus.popup_text.emit("GONE", it.player.pos, "miss")
			PlayerBuild.apply(it.player, it.player_hooper)
		_laser(it))


static func _back(it: Interior) -> void:
	if it.kind == "bodega":
		it.counter_menu()
	else:
		open(it)
