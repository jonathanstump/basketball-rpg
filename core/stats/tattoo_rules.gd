class_name TattooRules
extends RefCounted
## Tattoos (spec §10.6): get a flash sheet, pay at any Ink & Needle, it's on
## you for good. Slots: 2 at start, +1 per Crown, 7 max. Laser removal costs
## 3,000 × tier price and destroys the flash sheet.


static func slots() -> int:
	return mini(7, 2 + GameState.crowns.size())


static func free_slots() -> int:
	return slots() - GameState.tattoos.size()


static func apply_cost(region: String) -> int:
	return TierManager.price(JU.f(JU.dict(DataDB.tuning("economy"), "prices"), "tattoo_apply", 1000.0), region)


static func laser_cost(region: String) -> int:
	return TierManager.price(JU.f(JU.dict(DataDB.tuning("economy"), "prices"), "tattoo_laser", 3000.0), region)


static func can_apply(tattoo_id: String, region: String) -> String:
	## "" if allowed, else the reason.
	var t: Dictionary = DataDB.item("tattoos", tattoo_id)
	if t.is_empty():
		return "unknown tattoo"
	if GameState.tattoos.has(tattoo_id):
		return "already inked"
	if GameState.item_count(JU.s(t, "flash")) <= 0:
		return "need the flash sheet"
	if free_slots() <= 0:
		return "no free slots"
	if GameState.tokens < apply_cost(region):
		return "not enough tokens"
	return ""


static func apply(tattoo_id: String, region: String) -> bool:
	if can_apply(tattoo_id, region) != "":
		return false
	GameState.add_tokens(-apply_cost(region))
	GameState.tattoos.append(tattoo_id)
	if GameState.tattoos.size() >= 7:
		EventBus.achievement_unlocked.emit("ACH_FULL_INK")
	return true


static func laser(tattoo_id: String, region: String) -> bool:
	if not GameState.tattoos.has(tattoo_id) or GameState.tokens < laser_cost(region):
		return false
	GameState.add_tokens(-laser_cost(region))
	GameState.tattoos.remove_at(GameState.tattoos.find(tattoo_id))
	var flash: String = JU.s(DataDB.item("tattoos", tattoo_id), "flash")
	if GameState.item_count(flash) > 0:
		GameState.add_item(flash, -GameState.item_count(flash))
	return true
