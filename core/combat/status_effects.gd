class_name StatusEffects
extends RefCounted
## Timed statuses on SimActor.flags["status"] (spec §15.5 pipeline "status"):
## burn (DoT), bleed (buildup -> burst), shock, slow, blind, trash_talked.

const BURN_DPS: float = 6.0
const BLEED_BURST_PCT: float = 0.12
const BLEED_THRESHOLD: float = 100.0


static func apply(a: SimActor, status: Dictionary, resist: float = 0.0) -> void:
	var st: Dictionary = a.flags.get("status", {})
	for k: Variant in status.keys():
		var v: float = float(status[k]) * (1.0 - resist)
		match str(k):
			"bleed":
				st["bleed"] = float(st.get("bleed", 0.0)) + v
			_:
				st[k] = maxf(float(st.get(k, 0.0)), v)
	a.flags["status"] = st


static func has(a: SimActor, k: String) -> bool:
	var st: Dictionary = a.flags.get("status", {})
	return float(st.get(k, 0.0)) > 0.0


static func tick(a: SimActor, dt: float) -> float:
	## Advances timers; returns damage dealt this tick (burn/bleed burst).
	var st: Dictionary = a.flags.get("status", {})
	if st.is_empty():
		return 0.0
	var dmg: float = 0.0
	for k: Variant in st.keys():
		if str(k) == "bleed":
			continue
		st[k] = maxf(0.0, float(st[k]) - dt)
		if str(k) == "burn" and float(st[k]) > 0.0:
			dmg += BURN_DPS * dt
	if float(st.get("bleed", 0.0)) >= BLEED_THRESHOLD:
		st["bleed"] = 0.0
		dmg += a.hp_max * BLEED_BURST_PCT
	else:
		st["bleed"] = maxf(0.0, float(st.get("bleed", 0.0)) - 10.0 * dt)
	return dmg


static func speed_mult(a: SimActor) -> float:
	return 0.6 if has(a, "slow") else 1.0
