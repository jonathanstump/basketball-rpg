extends Node
## Tier lookup (spec §4.3) and multipliers (§11.1) for the current run.


func tier_of(region: String) -> int:
	return TierMath.tier_for(DataDB.tiers(), GameState.start_borough, region, GameState.ng_cycle)


func mult(kind: String, tier: int) -> float:
	return TierMath.multiplier(DataDB.tiers(), kind, tier, GameState.ng_cycle)


func mult_for_region(kind: String, region: String) -> float:
	return mult(kind, tier_of(region))


func price(base: float, region: String) -> int:
	return int(round(base * mult("price", tier_of(region))))


func all_tiers() -> Dictionary:
	var out: Dictionary = {}
	for b: String in DataSchemas.BOROUGHS:
		out[b] = tier_of(b)
	out[TierMath.CITY] = tier_of(TierMath.CITY)
	out[TierMath.GARDEN] = tier_of(TierMath.GARDEN)
	return out
