class_name LootRoller
extends RefCounted
## Shoebox loot (spec §10.3, §11.1): the box tier sets rarity odds; the
## borough tier shifts "loot_shift" points from Common upward; the brand
## picks the pool of items (by brand or by the brand's stats). Falls back to
## tokens + Grip Tape when no catalog item matches. Pools may list "extra"
## items that always drop (placed mixtapes, flash sheets, Punch Cards).

const RARITIES: PackedStringArray = ["common", "rare", "epic", "legendary"]


static func cfg() -> Dictionary:
	return DataDB.get_dict("loot_tables")


static func pool(id: String) -> Dictionary:
	return DataDB.item("pools", id)


static func odds(box_tier: String, tier: int) -> Dictionary:
	## Rarity weights after the tier shift (pts from Common upward).
	var base: Dictionary = JU.dict(JU.dict(cfg(), "box_tiers"), box_tier).duplicate()
	var shift: float = TierMath.loot_shift(DataDB.tiers(), tier)
	var split: Dictionary = JU.dict(cfg(), "shift_split")
	var from_key: String = "common" if JU.f(base, "common") > 0.0 else "rare"
	var taken: float = minf(shift, JU.f(base, from_key))
	base[from_key] = JU.f(base, from_key) - taken
	for r: String in ["rare", "epic", "legendary"]:
		if r == from_key:
			continue
		var share: float = JU.f(split, r)
		if from_key == "rare":
			share = {"epic": 0.75, "legendary": 0.25}.get(r, 0.0)
		base[r] = JU.f(base, r) + taken * share
	return base


static func roll_rarity(box_tier: String, tier: int, rng: RandomNumberGenerator) -> String:
	var o: Dictionary = odds(box_tier, tier)
	var total: float = 0.0
	for r: String in RARITIES:
		total += JU.f(o, r)
	var x: float = rng.randf() * total
	for r2: String in RARITIES:
		x -= JU.f(o, r2)
		if x <= 0.0:
			return r2
	return "common"


static func candidates(p: Dictionary, rarity: String) -> Array[String]:
	var brands: PackedStringArray = JU.strs(p, "brands")
	var slots: PackedStringArray = JU.strs(p, "slots")
	var out: Array[String] = []
	for cat: String in ["kicks", "fits", "headbands", "sleeves", "chains", "balls", "flash_sheets", "mixtapes"]:
		if not slots.is_empty() and not slots.has(cat):
			continue
		for id: Variant in DataDB.catalog(cat).keys():
			var it: Dictionary = DataDB.catalog(cat)[id]
			if JU.s(it, "rarity") != rarity or JU.b(it, "no_loot"):
				continue
			var brand: String = JU.s(it, "brand")
			if brand != "" and brands.has(brand):
				out.append(str(id))
			elif brand == "" and brands.has("GHOST") and (cat == "balls" or cat == "flash_sheets" or cat == "mixtapes"):
				out.append(str(id))
	out.sort()
	return out


static func roll(pool_id: String, tier: int, rng: RandomNumberGenerator) -> Dictionary:
	var p: Dictionary = pool(pool_id)
	if p.is_empty():
		p = pool("retail")
	var tok: Array = JU.a(p, "tokens")
	var tokens: int = rng.randi_range(int(tok[0]), int(tok[1])) if tok.size() >= 2 else 0
	tokens = int(round(float(tokens) * TierMath.multiplier(DataDB.tiers(), "tokens", tier, GameState.ng_cycle)))
	var items: PackedStringArray = PackedStringArray()
	if JU.s(p, "tier") == "grail":
		items.append(JU.s(p, "fixed"))
		return {"items": items, "tokens": tokens, "rarity": "grail"}
	var rolls: int = 1 + JU.i(p, "bonus_rolls")
	var best: String = "common"
	for _i: int in rolls:
		var rarity: String = roll_rarity(JU.s(p, "tier", "retail"), tier, rng)
		var c: Array[String] = candidates(p, rarity)
		if c.is_empty():
			items.append("grip_tape" if rarity == "common" else "pro_grip")
		else:
			items.append(c[rng.randi_range(0, c.size() - 1)])
		if RARITIES.find(rarity) > RARITIES.find(best):
			best = rarity
	for extra: String in JU.strs(p, "extra"):
		items.append(extra)
	return {"items": items, "tokens": tokens, "rarity": best}
