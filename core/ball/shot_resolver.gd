class_name ShotResolver
extends RefCounted
## Pure shot math (spec §7.6, §15.7). The outcome is decided at release; the
## flight only plays it out.

const PERFECT: String = "PERFECT"
const GOOD: String = "GOOD"
const NEAR_MISS: String = "NEAR_MISS"
const BRICK: String = "BRICK"
const REJECTED: String = "REJECTED"


static func cfg() -> Dictionary:
	return DataDB.tuning("shooting")


static func zone_for(distance: float, c: Dictionary = {}) -> String:
	var z: Dictionary = JU.dict(c if not c.is_empty() else cfg(), "zones")
	var arc: float = JU.f(z, "arc_m", 6.75)
	if distance < JU.f(z, "close_m", 3.0):
		return "close"
	if distance < arc:
		return "mid"
	if distance < arc + JU.f(z, "deep_extra_m", 2.0):
		return "three"
	return "deep"


static func jumper_perfect(jumper: int, c: Dictionary) -> float:
	var base: float = JU.f(JU.dict(c, "base_widths"), "perfect", 0.05)
	var j: Dictionary = JU.dict(c, "jumper")
	var base_stat: int = JU.i(j, "base_stat", 10)
	var per40: float = JU.f(j, "per_pt_to_40", 0.0015)
	var per60: float = JU.f(j, "per_pt_to_60", 0.0005)
	if jumper <= base_stat:
		return maxf(0.005, base - float(base_stat - jumper) * per40)
	var w: float = base + float(mini(jumper, 40) - base_stat) * per40
	if jumper > 40:
		w += float(mini(jumper, 60) - 40) * per60
	return w


static func compute_windows(ctx: ShotContext) -> ShotWindows:
	var c: Dictionary = cfg()
	var widths: Dictionary = JU.dict(c, "base_widths")
	var mods: Dictionary = JU.dict(c, "modifiers")
	var zones: Dictionary = JU.dict(c, "zones")
	var out: ShotWindows = ShotWindows.new()
	out.zone = ctx.zone if ctx.zone != "" else zone_for(ctx.distance, c)
	out.center = clampf(JU.f(c, "center", 0.82) + ctx.wind_drift, 0.05, 0.95)
	var perfect: float = jumper_perfect(ctx.jumper, c)
	var k: float = perfect / JU.f(widths, "perfect", 0.05)
	var good: float = JU.f(widths, "good", 0.12) * k
	var near: float = JU.f(widths, "near", 0.22) * k
	var m: float = JU.f(zones, out.zone, 1.0)
	m *= 1.0 - JU.f(c, "contest_factor", 0.6) * clampf(ctx.contest, 0.0, 1.0)
	if ctx.stepback:
		m *= JU.f(mods, "stepback", 1.4)
	if ctx.on_run == "run":
		m *= JU.f(mods, "on_the_run", 0.65)
	elif ctx.on_run == "sprint":
		m *= JU.f(mods, "sprinting", 0.5)
	if ctx.wide_open:
		m *= JU.f(mods, "wide_open", 2.0)
	if ctx.takeover:
		m *= JU.f(mods, "takeover", 1.6)
	if ctx.wind_ratio < JU.f(DataDB.tuning("player"), "low_wind_ratio", 0.25):
		m *= JU.f(mods, "low_wind", 0.8)
	if ctx.rookie:
		m *= JU.f(JU.dict(DataDB.tuning("player"), "rookie"), "window_mult", 1.25)
	m *= ctx.window_mult
	out.perfect = minf(perfect * m + ctx.perfect_bonus, JU.f(c, "perfect_cap", 0.25))
	out.good = maxf(good * m + ctx.perfect_bonus, out.perfect)
	out.near = maxf(near * m + ctx.perfect_bonus, out.good)
	return out


static func grade(release: float, windows: ShotWindows, contest: float) -> String:
	var g: String = BRICK
	if release < 1.0:
		var d: float = absf(release - windows.center)
		if d <= windows.half("perfect"):
			g = PERFECT
		elif d <= windows.half("good"):
			g = GOOD
		elif d <= windows.half("near"):
			g = NEAR_MISS
	if contest >= JU.f(cfg(), "smothered", 0.85) and (g == NEAR_MISS or g == BRICK):
		return REJECTED
	return g


static func is_make(g: String) -> bool:
	return g == PERFECT or g == GOOD


static func contest_of(shooter_pos: Vector3, defender_pos: Vector3, defender_forward: Vector3, contest_radius: float) -> float:
	## Contest from distance vs the defender's contest radius and facing.
	var to_shooter: Vector3 = shooter_pos - defender_pos
	to_shooter.y = 0.0
	var d: float = to_shooter.length()
	if d >= contest_radius or contest_radius <= 0.0:
		return 0.0
	var dist_term: float = 1.0 - d / contest_radius
	var facing: float = defender_forward.dot(to_shooter.normalized()) if d > 0.001 else 1.0
	var facing_term: float = clampf((facing + 0.3) / 1.0, 0.0, 1.0)
	return clampf(dist_term * 1.25 * facing_term, 0.0, 1.0)
