extends QAScript
## QA: the entry scene boots, data is valid, a run can start from every borough.


func run() -> bool:
	await frames(5)
	if not check(get_tree().current_scene != null, "no current scene"):
		return false
	if not check(DataDB.validate().is_empty(), "data problems"):
		return false
	for b: String in DataSchemas.BOROUGHS:
		GameState.new_run("two_way", b)
		if not check(TierManager.tier_of(b) == 1, "start borough %s not tier 1" % b):
			return false
	return true
