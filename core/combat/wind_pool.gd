class_name WindPool
extends RefCounted
## Stamina (spec §7.3): regen 45/s after a 0.6 s delay since the last spend,
## 15/s while guarding. Actions may start while Wind > 0 (souls rule) and
## can drive it to 0, never below.

var max_value: float = 100.0
var value: float = 100.0
var regen_per_s: float = 45.0
var regen_guarding_per_s: float = 15.0
var regen_delay_s: float = 0.6
var _since_spend_s: float = 999.0


func configure(max_v: float, tuning: Dictionary) -> void:
	max_value = max_v
	value = max_v
	regen_per_s = JU.f(tuning, "wind_regen_per_s", 45.0)
	regen_guarding_per_s = JU.f(tuning, "wind_regen_guarding_per_s", 15.0)
	regen_delay_s = JU.f(tuning, "wind_regen_delay_s", 0.6)


func can_act() -> bool:
	return value > 0.0


func spend(cost: float) -> bool:
	if value <= 0.0 and cost > 0.0:
		return false
	value = maxf(0.0, value - cost)
	_since_spend_s = 0.0
	return true


func drain(amount: float) -> void:
	## Continuous drain (sprint); also resets the regen delay.
	value = maxf(0.0, value - amount)
	_since_spend_s = 0.0


func tick(dt: float, guarding: bool = false, regen_mult: float = 1.0) -> void:
	_since_spend_s += dt
	if _since_spend_s < regen_delay_s:
		return
	var rate: float = regen_guarding_per_s if guarding else regen_per_s
	value = minf(max_value, value + rate * regen_mult * dt)


func ratio() -> float:
	return value / max_value if max_value > 0.0 else 0.0
