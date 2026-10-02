extends QAScript
## QA: The Stoop Queen boss sim at Tier 1 and Tier 5 with the QA bot.


func run() -> bool:
	await frames(2)
	for tier: int in [1, 5]:
		var r: Dictionary = BossSim.run("bk_stoop", tier, {"god": true, "max_s": 300, "seed": 21 + tier})
		print("QA boss bk_stoop T%d: %s in %.1fs, boss hp %.0f%%, makes %d, phases %s" % [tier, r["result"], float(r["time_s"]), float(r["boss_hp_ratio"]) * 100.0, int((r["stats"] as Dictionary)["makes"]), r["phases_seen"]])
		if not check(int((r["stats"] as Dictionary)["makes"]) > 0, "bot never scored at T%d" % tier):
			return false
		if tier == 5 and not check(float(r["boss_hp_ratio"]) < 1.0, "no damage at T5"):
			return false
	return true
