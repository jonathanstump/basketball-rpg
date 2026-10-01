class_name TierMath
extends RefCounted
## Pure tier rules (spec §4.3, §11.1). TierManager wraps these with run state.

const CITY: String = "city"
const GARDEN: String = "garden"


static func base_tier(tiers: Dictionary, start: String, region: String) -> int:
	var fixed: Dictionary = JU.dict(tiers, "fixed")
	if fixed.has(region):
		return JU.i(fixed, region, 1)
	var row: Dictionary = JU.dict(JU.dict(tiers, "start_tiers"), start)
	return JU.i(row, region, 1)


static func tier_for(tiers: Dictionary, start: String, region: String, ng_cycle: int = 0) -> int:
	var t: int = base_tier(tiers, start, region)
	if ng_cycle <= 0:
		return t
	var ng: Dictionary = JU.dict(tiers, "ng_plus")
	return mini(JU.i(ng, "tier_cap", 7), t + JU.i(ng, "tier_add", 2) * ng_cycle)


static func multiplier(tiers: Dictionary, kind: String, tier: int, ng_cycle: int = 0) -> float:
	var arr: Array = JU.a(JU.dict(tiers, "multipliers"), kind)
	if arr.is_empty():
		return 1.0
	var idx: int = clampi(tier, 1, arr.size()) - 1
	var m: float = float(arr[idx])
	if ng_cycle > 0:
		var ng: Dictionary = JU.dict(tiers, "ng_plus")
		if JU.strs(ng, "scaled_kinds").has(kind):
			m *= pow(JU.f(ng, "mult_per_cycle", 1.3), ng_cycle)
	return m


static func loot_shift(tiers: Dictionary, tier: int) -> float:
	return multiplier(tiers, "loot_shift", tier, 0)
