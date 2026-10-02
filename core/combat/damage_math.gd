class_name DamageMath
extends RefCounted
## §7.12: damage = (move_base + ball_attack × scaling(stat, grade))
##                 × ball_upgrade_mult × crit × buffs × (1 − target_DR)
## ball_upgrade_mult = 1 + 0.08 × upgrade_level. Tier multipliers apply to
## enemy HP and damage, never to the player's damage.


static func ball_grade(ball_item: String, stat: String) -> String:
	return JU.s(JU.dict(DataDB.ball(ball_item), "scaling"), stat, "")


static func upgrade_mult(level: int) -> float:
	return 1.0 + JU.f(DataDB.tuning("combat"), "ball_upgrade_per_level", 0.08) * float(level)


static func raw(move_base: float, ball_attack: float, stat_points: int, grade: String, upgrade_level: int, crit: float, buffs: float, target_dr: float) -> float:
	var scaled: float = move_base + ball_attack * StatFormulas.scaling(stat_points, grade)
	return scaled * upgrade_mult(upgrade_level) * crit * buffs * (1.0 - clampf(target_dr, 0.0, 0.9))


static func hooper_damage(move: Dictionary, a: SimActor, buffs: float = 1.0) -> float:
	## Pre-defense damage for a hooper move (crit and DR applied on hit).
	var base: float = JU.f(move, "damage")
	if base <= 0.0:
		return 0.0
	var item: String = str(a.flags.get("ball_item", "ball_rec"))
	var stat: String = JU.s(move, "stat", "handles")
	var grade: String = ball_grade(item, stat)
	var attack: float = JU.f(DataDB.ball(item), "attack", 20.0)
	var upg: int = int(a.flags.get("ball_upgrade", 0))
	var phys: float = float(a.flags.get("physical_mult", 1.0))
	return raw(base, attack, a.stat(stat), grade, upg, 1.0, buffs * phys, 0.0)


static func enemy_damage(base: float, tier: int, ng_cycle: int = 0, buffs: float = 1.0) -> float:
	return base * TierMath.multiplier(DataDB.tiers(), "damage", tier, ng_cycle) * buffs


static func actor_dr(a: SimActor) -> float:
	var dr: float = float(a.flags.get("dr", 0.0))
	if a.kind == "hooper":
		dr += StatFormulas.body_dr(a.stat("body"))
	return clampf(dr, 0.0, 0.75)


static func stat_scale(points: int, per_pt: float = 0.02, cap: float = 2.0) -> float:
	## Linear stat scaling for parry/ankle composure bonuses (1.0 at 10).
	return clampf(1.0 + float(points - 10) * per_pt, 0.5, cap)
