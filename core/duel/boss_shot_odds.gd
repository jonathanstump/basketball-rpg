class_name BossShotOdds
extends RefCounted
## Boss shot outcomes (playtest R7). P(make) starts from the boss's rating
## for the shot and drops with the player's defense: how close they contest,
## their Body (strength), their Heart (a healthy defender is harder to score
## on) and a timed contest at the release (perfect = blocked outright).
## Pure: all inputs are numbers.

const BLOCKED: String = "blocked"
const ALTERED: String = "altered"


static func cfg() -> Dictionary:
	return JU.dict(JU.dict(JU.dict(DataDB.tuning("bosses"), "duel"), "r7"), "odds")


static func make_chance(kind: String, rating: float, contest_dist: float, body: int, hp_ratio: float, timing: String = "") -> float:
	## kind: layup|mid|three|dunk; rating 0-100; contest_dist = player to
	## shooter in meters (INF if nobody's near); timing "", "altered", "blocked".
	if timing == BLOCKED:
		return 0.0
	var c: Dictionary = cfg()
	var p: float = lerpf(JU.f(c, "base_lo", 0.22), JU.f(c, "base_hi", 0.78), clampf(rating / 100.0, 0.0, 1.0))
	var contest: float = clampf(1.0 - (contest_dist - 0.8) / JU.f(c, "contest_radius_m", 2.6), 0.0, 1.0)
	p *= 1.0 - JU.f(c, "contest_weight", 0.45) * contest
	## Strength matters most at the rim; only when you're actually there.
	var body_k: float = JU.f(c, "body_k_inside", 0.35) if kind == "layup" or kind == "dunk" else JU.f(c, "body_k", 0.22)
	p *= 1.0 - body_k * clampf(float(body - 10) / 50.0, 0.0, 1.0) * contest
	p *= 1.0 - JU.f(c, "heart_k", 0.25) * clampf(hp_ratio, 0.0, 1.0)
	if timing == ALTERED:
		p *= JU.f(c, "altered_mult", 0.45)
	return clampf(p, JU.f(c, "min", 0.04), JU.f(c, "max", 0.95))


static func timing_grade(frames_off: int, hands: int) -> String:
	## How close a contest press landed to the release frame. The perfect
	## window grows with Hands like the parry window.
	if frames_off < 0:
		return ""
	var ct: Dictionary = JU.dict(JU.dict(JU.dict(DataDB.tuning("bosses"), "duel"), "r7"), "contest")
	var perfect: float = minf(StatFormulas.parry_window_frames(hands, JU.f(ct, "perfect_base_f", 6.0)), JU.f(ct, "perfect_max_f", 12.0))
	if float(frames_off) <= perfect:
		return BLOCKED
	if float(frames_off) <= perfect + JU.f(ct, "good_extra_f", 8.0):
		return ALTERED
	return ""


static func score_damage(kind: String, player_hp_max: float, tier: int) -> float:
	## A boss bucket costs you Heart: % of max by shot kind, tier-scaled.
	var r7: Dictionary = JU.dict(JU.dict(DataDB.tuning("bosses"), "duel"), "r7")
	var pct: float = JU.f(JU.dict(r7, "score_pct"), kind, 0.08)
	return player_hp_max * pct * (1.0 + JU.f(r7, "score_tier_step", 0.05) * float(maxi(0, tier - 1)))
