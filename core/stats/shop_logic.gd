class_name ShopLogic
extends RefCounted
## Shop rules (spec §10.8, §10.9, §11.4). Prices scale by the borough's tier
## price multiplier; stock tops out at Epic (Legendary/Grail come from boxes,
## bosses, quests). Ball upgrades: +1..+5 use Grip Tape, +6..+10 Pro Grip,
## cost 200 × level × tier price; the Taped-Up Ball becomes Old Faithful at +10.

const WEARABLE_CATS: PackedStringArray = ["kicks", "fits", "headbands", "sleeves", "chains"]
const BALL_PRICES: Dictionary = {"common": 600, "rare": 2000, "epic": 4500}


static func plug_stock(borough: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for cat: String in WEARABLE_CATS:
		var ids: Array = DataDB.catalog(cat).keys()
		ids.sort()
		for id: Variant in ids:
			var it: Dictionary = DataDB.catalog(cat)[id]
			if JU.s(it, "borough") == borough and not JU.b(it, "no_shop") and ["common", "rare", "epic"].has(JU.s(it, "rarity")):
				out.append(str(id))
	return out


static func pump_stock() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id: Variant in DataDB.catalog("balls").keys():
		var b: Dictionary = DataDB.ball(str(id))
		if JU.s(b, "source").begins_with("Start") and str(id) != "ball_old_faithful":
			out.append(str(id))
	out.sort()
	out.append("grip_tape")
	return out


static func base_price(id: String) -> int:
	var it: Dictionary = DataDB.find_any(id)
	if DataDB.has_item("balls", id):
		return int(BALL_PRICES.get(JU.s(it, "rarity"), 2000))
	return JU.i(it, "price", 100)


static func price(id: String, borough: String) -> int:
	return TierManager.price(float(base_price(id)), borough)


static func sell_price(id: String, borough: String) -> int:
	return int(round(float(price(id, borough)) * JU.f(JU.dict(DataDB.tuning("economy"), "prices"), "sell_ratio", 0.25)))


static func buy(id: String, borough: String) -> String:
	var p: int = price(id, borough)
	if GameState.tokens < p:
		return "not enough tokens"
	if DataDB.has_item("consumables", id) and GameState.item_count(id) >= JU.i(DataDB.item("consumables", id), "max_carry", 5):
		return "can't carry more"
	GameState.add_tokens(-p)
	GameState.add_item(id, 1)
	return ""


static func sell(id: String, borough: String) -> String:
	if GameState.item_count(id) <= 0:
		return "you don't have it"
	for slot: Variant in GameState.equipment.keys():
		if str(GameState.equipment[slot]) == id and GameState.item_count(id) <= 1:
			return "it's equipped"
	GameState.add_item(id, -1)
	GameState.add_tokens(sell_price(id, borough))
	return ""


static func upgrade_material(next_level: int) -> String:
	return "grip_tape" if next_level <= 5 else "pro_grip"


static func upgrade_cost(next_level: int, borough: String) -> int:
	return TierManager.price(JU.f(JU.dict(DataDB.tuning("economy"), "prices"), "ball_upgrade_per_level", 200.0) * float(next_level), borough)


static func upgrade(ball_id: String, borough: String) -> String:
	var lvl: int = int(GameState.ball_upgrades.get(ball_id, 0))
	if lvl >= 10:
		return "maxed"
	if GameState.item_count(ball_id) <= 0:
		return "you don't own it"
	var nxt: int = lvl + 1
	var mat: String = upgrade_material(nxt)
	if GameState.item_count(mat) <= 0:
		return "need " + JU.s(DataDB.find_any(mat), "name", mat)
	var cost: int = upgrade_cost(nxt, borough)
	if GameState.tokens < cost:
		return "not enough tokens"
	GameState.add_tokens(-cost)
	GameState.add_item(mat, -1)
	GameState.ball_upgrades[ball_id] = nxt
	var props: Dictionary = JU.dict(DataDB.ball(ball_id), "props")
	if props.has("evolves_at") and nxt >= JU.i(props, "evolves_at", 10):
		var to: String = JU.s(props, "evolves_to")
		GameState.add_item(ball_id, -1)
		GameState.add_item(to, 1)
		GameState.ball_upgrades.erase(ball_id)
		GameState.ball_upgrades[to] = 0
		for slot: Variant in GameState.equipment.keys():
			if str(GameState.equipment[slot]) == ball_id:
				GameState.equipment[slot] = to
		return "evolved:" + to
	return ""
