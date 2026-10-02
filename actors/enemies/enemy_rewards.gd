class_name EnemyRewards
extends RefCounted
## Rewards for a defeated enemy (spec §8.1, §8.4, §11.4): Rep and tokens are
## already tier-scaled at spawn; Crew Captains roll a 25% Box Key; Bootlegs
## drop a real shoebox's loot; Gulls return snatched tokens.


static func compute(a: SimActor, rng: RandomNumberGenerator) -> Dictionary:
	var drops: PackedStringArray = PackedStringArray()
	if bool(a.flags.get("captain", false)):
		if rng.randf() < JU.f(JU.dict(DataDB.tuning("ai"), "captain"), "key_chance", 0.25):
			drops.append("box_key")
	if a.archetype == "bootleg":
		drops.append("loot:bootleg")
	return {"actor": a.id, "enemy": a.archetype, "tier": a.tier, "captain": bool(a.flags.get("captain", false)),
		"rep": int(a.flags.get("reward_rep", 0)), "tokens": int(a.flags.get("reward_tokens", 0)) + int(a.flags.get("snatched_tokens", 0)),
		"drops": drops, "pos": a.pos}
