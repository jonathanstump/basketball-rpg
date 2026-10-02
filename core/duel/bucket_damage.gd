class_name BucketDamage
extends RefCounted
## Buckets vs bosses (spec §11.5): % of the current phase's max Heart by
## zone, plus a stat bonus ball_attack × scaling(JMP or BNC) × 0.5;
## multipliers Perfect ×1.4, Wide Open ×1.5, Takeover ×1.25; cap 22%.
## This is what lets skill beat grind: it ignores the player's level.


static func compute(kind: String, phase_max_hp: float, ball_attack: float, stat_points: int, grade: String,
		perfect: bool, wide_open: bool, takeover: bool) -> Dictionary:
	var b: Dictionary = JU.dict(DataDB.tuning("economy"), "buckets")
	var row: Dictionary = JU.dict(b, kind)
	var pct: float = JU.f(row, "pct", 0.05)
	var dmg: float = pct * phase_max_hp + ball_attack * StatFormulas.scaling(stat_points, grade) * JU.f(b, "stat_bonus_factor", 0.5)
	if perfect:
		dmg *= JU.f(b, "perfect_mult", 1.4)
	if wide_open:
		dmg *= JU.f(b, "wide_open_mult", 1.5)
	if takeover:
		dmg *= JU.f(b, "takeover_mult", 1.25)
	dmg = minf(dmg, JU.f(b, "cap_pct", 0.22) * phase_max_hp)
	return {"damage": dmg, "composure": JU.f(row, "composure", 15.0)}


static func kind_for(zone: String, grade: String, poster: bool) -> String:
	if poster:
		return "poster"
	if grade == "DUNK" or zone == "dunk":
		return "dunk"
	return zone if ["close", "mid", "three", "deep"].has(zone) else "mid"


static func for_shooter(kind: String, phase_max_hp: float, shooter: SimActor, grade: String, wide_open: bool) -> Dictionary:
	var item: String = str(shooter.flags.get("ball_item", "ball_rec"))
	var stat: String = "bounce" if kind == "dunk" or kind == "poster" else "jumper"
	var res: Dictionary = compute(kind, phase_max_hp, JU.f(DataDB.ball(item), "attack", 20.0), shooter.stat(stat),
		DamageMath.ball_grade(item, stat), grade == "PERFECT", wide_open, bool(shooter.flags.get("takeover", false)))
	var comp_mult: float = float(shooter.flags.get("poster_composure_mult", 1.0)) if kind == "dunk" or kind == "poster" else 1.0
	res["composure"] = float(res["composure"]) * comp_mult
	if bool(shooter.flags.get("perfect_crit", false)) and grade == "PERFECT":
		res["damage"] = float(res["damage"]) * 1.5
	if float(shooter.flags.get("double_bucket_chance", 0.0)) > 0.0:
		res["double_chance"] = float(shooter.flags["double_bucket_chance"])
	return res
