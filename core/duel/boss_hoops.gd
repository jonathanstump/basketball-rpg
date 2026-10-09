class_name BossHoops
extends RefCounted
## A boss's basketball profile (playtest R7): theme, 0-100 ratings and
## tendencies, from the boss's "hoops" block over the per-kind defaults in
## tuning/bosses hoops_defaults. Pure.

const RATINGS: PackedStringArray = ["inside", "mid", "three", "dunk", "handles", "strength", "defense", "steal", "block"]
const TENDENCIES: PackedStringArray = ["ball_hunger", "pressure", "gamble"]
const SHOT_KINDS: PackedStringArray = ["layup", "mid", "three", "dunk"]


static func profile(boss: Dictionary) -> Dictionary:
	var defs: Dictionary = JU.dict(DataDB.tuning("bosses"), "hoops_defaults")
	var kind: String = JU.s(boss, "kind", "mini")
	var base: Dictionary = JU.dict(defs, "mini" if kind == "mini" else "king")
	var own: Dictionary = JU.dict(boss, "hoops")
	var out: Dictionary = {"theme": JU.s(own, "theme", JU.s(base, "theme")), "ratings": {}, "tendencies": {}, "shot_mix": {}}
	var br: Dictionary = JU.dict(base, "ratings")
	var orr: Dictionary = JU.dict(own, "ratings")
	for k: String in RATINGS:
		(out["ratings"] as Dictionary)[k] = clampf(JU.f(orr, k, JU.f(br, k, 50.0)), 0.0, 100.0)
	var bt: Dictionary = JU.dict(base, "tendencies")
	var ot: Dictionary = JU.dict(own, "tendencies")
	for k2: String in TENDENCIES:
		(out["tendencies"] as Dictionary)[k2] = clampf(JU.f(ot, k2, JU.f(bt, k2, 0.5)), 0.0, 1.0)
	var mix: Dictionary = JU.dict(ot, "shot_mix")
	if mix.is_empty():
		mix = JU.dict(bt, "shot_mix")
	for k3: String in SHOT_KINDS:
		(out["shot_mix"] as Dictionary)[k3] = maxf(0.0, JU.f(mix, k3, 0.0))
	return out


static func rating(p: Dictionary, key: String) -> float:
	return JU.f(JU.dict(p, "ratings"), key, 50.0)


static func tendency(p: Dictionary, key: String) -> float:
	return JU.f(JU.dict(p, "tendencies"), key, 0.5)


static func shot_rating(p: Dictionary, kind: String) -> float:
	match kind:
		"layup":
			return rating(p, "inside")
		"dunk":
			return rating(p, "dunk")
		"three":
			return rating(p, "three")
	return rating(p, "mid")


static func headline(p: Dictionary, n: int = 3) -> Array[String]:
	## The boss's best ratings, for the Mic Check stat card: "THREE 85".
	var keys: Array = Array(RATINGS)
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return rating(p, str(a)) > rating(p, str(b)))
	var out: Array[String] = []
	for i: int in mini(n, keys.size()):
		out.append("%s %d" % [str(keys[i]).to_upper(), int(rating(p, str(keys[i])))])
	return out


static func validate(boss_id: String, boss: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	var own: Dictionary = JU.dict(boss, "hoops")
	if own.is_empty():
		return errs
	for k: Variant in JU.dict(own, "ratings").keys():
		if not RATINGS.has(str(k)):
			errs.append("boss %s hoops: unknown rating %s" % [boss_id, k])
		elif JU.f(JU.dict(own, "ratings"), str(k)) < 0.0 or JU.f(JU.dict(own, "ratings"), str(k)) > 100.0:
			errs.append("boss %s hoops: rating %s out of 0-100" % [boss_id, k])
	var t: Dictionary = JU.dict(own, "tendencies")
	for k2: Variant in t.keys():
		if k2 == "shot_mix":
			for sk: Variant in JU.dict(t, "shot_mix").keys():
				if not SHOT_KINDS.has(str(sk)):
					errs.append("boss %s hoops: unknown shot kind %s" % [boss_id, sk])
		elif not TENDENCIES.has(str(k2)):
			errs.append("boss %s hoops: unknown tendency %s" % [boss_id, k2])
		elif JU.f(t, str(k2)) < 0.0 or JU.f(t, str(k2)) > 1.0:
			errs.append("boss %s hoops: tendency %s out of 0-1" % [boss_id, k2])
	var style: String = JU.s(JU.dict(own, "offense"), "style")
	if style != "" and not SHOT_KINDS.has(style):
		errs.append("boss %s hoops: unknown offense style %s" % [boss_id, style])
	if JU.s(own, "theme") == "":
		errs.append("boss %s hoops: missing theme" % boss_id)
	return errs
