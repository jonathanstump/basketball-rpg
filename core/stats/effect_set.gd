class_name EffectSet
extends RefCounted
## Stacks gear/tattoo/crown effects (spec §10). Stacking rules:
##   *_mult  multiplicative: factor = Π(1 + v)        ("+10%" = 0.10)
##   *_add   additive sum
##   other   flags: max value wins (rose, hustle, nine_lives...)
## "all_mult" (Golden Hour) feeds every headline multiplier.

const ALL_MULT_KEYS: PackedStringArray = ["damage_mult", "speed_mult", "hype_gain_mult", "rep_mult", "tokens_mult", "jump_mult"]

var mults: Dictionary = {}   # key -> factor
var adds: Dictionary = {}    # key -> sum
var flags: Dictionary = {}   # key -> value
var sources: PackedStringArray = PackedStringArray()


func add_effects(effects: Dictionary, source: String = "") -> void:
	if source != "":
		sources.append(source)
	for k: Variant in effects.keys():
		var key: String = str(k)
		var v: Variant = effects[k]
		if key == "all_mult":
			for ak: String in ALL_MULT_KEYS:
				mults[ak] = mult(ak) * (1.0 + float(v))
		elif key.ends_with("_mult"):
			mults[key] = mult(key) * (1.0 + float(v))
		elif key.ends_with("_add"):
			adds[key] = add(key) + float(v)
		else:
			flags[key] = maxf(float(flags.get(key, 0.0)), float(v))


func mult(key: String) -> float:
	return float(mults.get(key, 1.0))


func add(key: String) -> float:
	return float(adds.get(key, 0.0))


func flag(key: String) -> bool:
	return float(flags.get(key, 0.0)) > 0.0
