class_name AttackTokenManager
extends RefCounted
## Group AI throttle (spec §7.9, §8.5): at most N enemies actively attack a
## target at once (2; 3 at Tier 5+). Others circle at 4-6 m and taunt.

var max_attackers: int = 2
var holders: Dictionary = {}   # target id -> Array[int] of attacker ids


func limit_for_tier(tier: int) -> int:
	var ai: Dictionary = DataDB.tuning("ai")
	return JU.i(ai, "max_attackers_t5", 3) if tier >= 5 else JU.i(ai, "max_attackers", 2)


func request(attacker: SimActor, target_id: int) -> bool:
	var list: Array = holders.get(target_id, [])
	if list.has(attacker.id):
		return true
	if list.size() >= limit_for_tier(attacker.tier):
		return false
	list.append(attacker.id)
	holders[target_id] = list
	return true


func release(attacker_id: int) -> void:
	for k: Variant in holders.keys():
		var list: Array = holders[k]
		list.erase(attacker_id)


func has_token(attacker_id: int, target_id: int) -> bool:
	return (holders.get(target_id, []) as Array).has(attacker_id)


func count(target_id: int) -> int:
	return (holders.get(target_id, []) as Array).size()


func prune(w: SimWorld) -> void:
	## Drops tokens held by dead or removed attackers.
	for k: Variant in holders.keys():
		var list: Array = holders[k]
		for id: Variant in list.duplicate():
			var a: SimActor = w.actor_by_id(int(id))
			if a == null or not a.alive:
				list.erase(id)
