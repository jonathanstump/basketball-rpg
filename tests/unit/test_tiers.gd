extends GutTest
## M0: tier rows are permutations of 1-5, start = 1, and match spec §4.3 exactly.

const SPEC_TABLE: Dictionary = {
	# start -> [bronx, brooklyn, queens, staten_island, uptown]
	"bronx": [1, 4, 3, 5, 2],
	"brooklyn": [4, 1, 2, 5, 3],
	"queens": [3, 2, 1, 5, 4],
	"staten_island": [5, 2, 4, 1, 3],
	"uptown": [2, 3, 4, 5, 1],
}
const COLS: PackedStringArray = ["bronx", "brooklyn", "queens", "staten_island", "uptown"]


func test_rows_are_permutations_with_start_one() -> void:
	var tiers: Dictionary = DataDB.tiers()
	for start: String in COLS:
		var seen: Array[int] = []
		for region: String in COLS:
			seen.append(TierMath.tier_for(tiers, start, region))
		seen.sort()
		assert_eq(seen, [1, 2, 3, 4, 5] as Array[int], "row %s" % start)
		assert_eq(TierMath.tier_for(tiers, start, start), 1, "start %s is tier 1" % start)


func test_matches_spec_table_exactly() -> void:
	var tiers: Dictionary = DataDB.tiers()
	for start: Variant in SPEC_TABLE.keys():
		var row: Array = SPEC_TABLE[start]
		for idx: int in COLS.size():
			assert_eq(TierMath.tier_for(tiers, str(start), COLS[idx]), int(row[idx]), "%s -> %s" % [start, COLS[idx]])


func test_fixed_tiers() -> void:
	var tiers: Dictionary = DataDB.tiers()
	for start: String in COLS:
		assert_eq(TierMath.tier_for(tiers, start, "city"), 6)
		assert_eq(TierMath.tier_for(tiers, start, "garden"), 7)


func test_multipliers_spec_values() -> void:
	var tiers: Dictionary = DataDB.tiers()
	assert_almost_eq(TierMath.multiplier(tiers, "hp", 1), 1.0, 0.0001)
	assert_almost_eq(TierMath.multiplier(tiers, "hp", 5), 5.0, 0.0001)
	assert_almost_eq(TierMath.multiplier(tiers, "damage", 7), 4.5, 0.0001)
	assert_almost_eq(TierMath.multiplier(tiers, "composure", 3), 1.55, 0.0001)
	assert_almost_eq(TierMath.multiplier(tiers, "rep", 6), 13.0, 0.0001)
	assert_almost_eq(TierMath.multiplier(tiers, "price", 4), 3.4, 0.0001)
	assert_almost_eq(TierMath.multiplier(tiers, "loot_shift", 7), 30.0, 0.0001)


func test_ng_plus_shift_and_cap() -> void:
	var tiers: Dictionary = DataDB.tiers()
	assert_eq(TierMath.tier_for(tiers, "bronx", "bronx", 1), 3)
	assert_eq(TierMath.tier_for(tiers, "bronx", "staten_island", 1), 7)
	assert_eq(TierMath.tier_for(tiers, "bronx", "garden", 1), 7)
	assert_eq(TierMath.tier_for(tiers, "bronx", "bronx", 3), 7)
	assert_almost_eq(TierMath.multiplier(tiers, "hp", 3, 1), 2.6 * 1.3, 0.0001)
	assert_almost_eq(TierMath.multiplier(tiers, "price", 3, 1), 2.4, 0.0001, "prices not NG-scaled")


func test_tier_manager_uses_run_state() -> void:
	GameState.new_run("two_way", "queens")
	assert_eq(TierManager.tier_of("uptown"), 4)
	assert_eq(int(TierManager.all_tiers()["queens"]), 1)
