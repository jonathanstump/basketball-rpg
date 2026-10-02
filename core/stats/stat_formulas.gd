class_name StatFormulas
extends RefCounted
## Stat -> derived value formulas (spec §6.4). Config comes from
## data/tuning/stats.json so numbers stay tunable.


static func banded(points: int, cfg: Dictionary) -> float:
	## base at `at`, then per-point slopes per band ([[upto, per_pt], ...]).
	## Below `at`, the first band's slope applies in reverse.
	var base: float = JU.f(cfg, "base")
	var at: int = JU.i(cfg, "at", 10)
	var bands: Array = JU.a(cfg, "bands")
	if bands.is_empty():
		return base
	if points <= at:
		return base - float(at - points) * float((bands[0] as Array)[1])
	var v: float = base
	var prev: int = at
	for b: Variant in bands:
		var band: Array = b
		var upto: int = int(band[0])
		var per: float = float(band[1])
		if points <= prev:
			break
		var n: int = mini(points, upto) - prev
		if n > 0:
			v += float(n) * per
		prev = upto
	return v


static func cfg(name: String) -> Dictionary:
	return JU.dict(DataDB.tuning("stats"), name)


static func heart_max(heart: int) -> float:
	return banded(heart, cfg("heart"))


static func wind_max(wind: int) -> float:
	return banded(wind, cfg("wind"))


static func body_dr(body: int) -> float:
	var c: Dictionary = cfg("body")
	return clampf(float(body - 10) * JU.f(c, "dr_per_pt", 0.004), 0.0, JU.f(c, "dr_cap", 0.2))


static func poise(body: int) -> float:
	var c: Dictionary = cfg("body")
	return JU.f(c, "base_poise", 20.0) + float(maxi(0, body - 10)) * JU.f(c, "poise_per_pt", 2.0)


static func ankle_bonus_frames(handles: int) -> float:
	var c: Dictionary = cfg("handles")
	return clampf(float(handles - 10) * JU.f(c, "ankle_frames_per_pt", 0.2), 0.0, JU.f(c, "ankle_frames_max_bonus", 6.0))


static func parry_window_frames(hands: int, base_frames: float) -> float:
	var c: Dictionary = cfg("hands")
	var bonus: float = maxf(0.0, float(hands - 10) * JU.f(c, "parry_frames_per_pt", 0.2))
	return minf(base_frames + bonus, JU.f(c, "parry_frames_max_total", 16.0))


static func jump_height(bounce: int, base_m: float) -> float:
	return base_m + float(bounce - 10) * JU.f(cfg("bounce"), "jump_per_pt", 0.02)


static func dunk_range(bounce: int, base_m: float) -> float:
	return base_m + float(bounce - 10) * JU.f(cfg("bounce"), "dunk_range_per_pt", 0.03)


static func stat_factor(points: int) -> float:
	## Diminishing contribution with soft caps (see DECISIONS: stat scaling).
	var bands: Array = JU.a(DataDB.tuning("stats"), "stat_factor_bands")
	var v: float = 0.0
	var prev: int = 0
	for b: Variant in bands:
		var band: Array = b
		var upto: int = int(band[0])
		var n: int = mini(points, upto) - prev
		if n <= 0:
			break
		v += float(n) * float(band[1])
		prev = upto
	return v


static func grade_mult(grade: String) -> float:
	return JU.f(JU.dict(DataDB.tuning("stats"), "grades"), grade, 0.0)


static func scaling(points: int, grade: String) -> float:
	if grade == "":
		return 0.0
	return grade_mult(grade) * stat_factor(points)
