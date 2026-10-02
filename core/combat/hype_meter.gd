class_name HypeMeter
extends RefCounted
## Hype 0-100 (spec §7.3): built by style, decays 2/s after 8 s without gain,
## spent on Bag Moves and Takeover.

var value: float = 0.0
var max_value: float = 100.0
var gain_mult: float = 1.0
var decay_mult: float = 1.0
var since_gain_s: float = 99.0
var cfg: Dictionary = {}


func _init() -> void:
	cfg = JU.dict(DataDB.tuning("combat"), "hype")
	max_value = JU.f(cfg, "max", 100.0)


func gain(source: String, mult: float = 1.0) -> float:
	## Adds the configured amount for a style source ("ankle_breaker", ...).
	return add(JU.f(cfg, source, 0.0) * mult)


func add(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var before: float = value
	value = minf(max_value, value + amount * gain_mult)
	since_gain_s = 0.0
	return value - before


func spend(amount: float) -> bool:
	if value + 0.0001 < amount:
		return false
	value = maxf(0.0, value - amount)
	return true


func tick(dt: float) -> void:
	since_gain_s += dt
	if since_gain_s >= JU.f(cfg, "decay_delay_s", 8.0):
		value = maxf(0.0, value - JU.f(cfg, "decay_per_s", 2.0) * decay_mult * dt)


func full() -> bool:
	return value >= max_value - 0.001
