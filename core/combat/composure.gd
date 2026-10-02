class_name Composure
extends RefCounted
## Posture bar (spec §7.11): fills with composure damage; at max it breaks
## into SHOOK (offense) or STAGGER (defense). Regen 6%/s after 2 s without
## composure damage (×2 while holding the ball). Durations shrink at Tier 4+.

var max_value: float = 100.0
var value: float = 0.0
var since_hit_s: float = 99.0
var broken: String = ""          # "" | "shook" | "stagger"
var broken_left_s: float = 0.0
var tier: int = 1
var cfg: Dictionary = {}


func _init(max_v: float = 100.0, tier_v: int = 1) -> void:
	max_value = max_v
	tier = tier_v
	cfg = DataDB.tuning("composure")


func duration(kind: String) -> float:
	var base: float = JU.f(cfg, "shook_s", 3.0) if kind == "shook" else JU.f(cfg, "stagger_s", 2.0)
	var floor_s: float = JU.f(cfg, "shook_floor_s", 2.0) if kind == "shook" else JU.f(cfg, "stagger_floor_s", 1.4)
	var from: int = JU.i(cfg, "tier_shrink_from", 4)
	if tier >= from:
		base -= float(tier - from + 1) * JU.f(cfg, "tier_shrink_per_tier_s", 0.2)
	return maxf(floor_s, base)


func add(amount: float, kind: String) -> String:
	## Returns the break kind if this hit broke composure, else "".
	if broken != "" or amount <= 0.0:
		return ""
	value += amount
	since_hit_s = 0.0
	if value >= max_value:
		value = max_value
		broken = kind
		broken_left_s = duration(kind)
		return kind
	return ""


func force_break(kind: String, seconds: float = -1.0) -> void:
	value = max_value
	broken = kind
	broken_left_s = duration(kind) if seconds < 0.0 else seconds


func tick(dt: float, holding_ball: bool) -> String:
	## Returns "recovered" on the frame a break ends.
	if broken != "":
		broken_left_s -= dt
		if broken_left_s <= 0.0:
			broken = ""
			value = 0.0
			return "recovered"
		return ""
	since_hit_s += dt
	if since_hit_s >= JU.f(cfg, "regen_delay_s", 2.0) and value > 0.0:
		var rate: float = JU.f(cfg, "regen_pct_per_s", 0.06) * max_value
		if holding_ball:
			rate *= JU.f(cfg, "regen_with_ball_mult", 2.0)
		value = maxf(0.0, value - rate * dt)
	return ""


func ratio() -> float:
	return value / max_value if max_value > 0.0 else 0.0
