class_name SauceGimmick
extends RefCounted
## Extra Sauce (spec §9.3): SAUCE ZONES. White puddles slow (the zone's
## "slow" status), red puddles burn and drain Wind faster; standing in both
## at once = "the combo" burst. Puddles are zone moves lasting 12 s.

const DT: float = 1.0 / 60.0
const COMBO_PCT: float = 0.08
const COMBO_COOLDOWN_S: float = 2.0
const RED_WIND_DRAIN: float = 8.0

var brain: BossBrain
var world: SimWorld
var combo_ready_at: int = 0
var combos: int = 0


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world


func on_step(b: BossBrain) -> bool:
	var t: SimActor = b.target
	if t == null or not t.alive:
		return false
	if StatusEffects.has(t, "burn") and t.wind != null:
		t.wind.drain(RED_WIND_DRAIN * DT)
	if StatusEffects.has(t, "slow") and StatusEffects.has(t, "burn") and world.frame >= combo_ready_at:
		combo_ready_at = world.frame + int(COMBO_COOLDOWN_S * 60.0)
		combos += 1
		b.combat.damage.apply_raw(t, t.hp_max * COMBO_PCT)
		world.emit("sauce_combo", {"actor": t.id, "pos": t.pos})
		world.emit("popup", {"text": "THE COMBO!", "pos": t.pos, "style": "bad"})
	return false
