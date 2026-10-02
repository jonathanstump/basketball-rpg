class_name GatorGimmick
extends RefCounted
## The Gator (spec §9.3, The Underground): FLOOD. Water rises and falls on a
## 30 s cycle (Phase 2 "Deep End": it stays high). In high water you wade
## (slow) and he submerges and ambushes (ripples cue); when the third rail
## sparks, get out of the water (platform edges are dry).

const DT: float = 1.0 / 60.0
const CYCLE_S: float = 30.0
const HIGH_S: float = 12.0
const SPARK_EVERY_S: float = 8.0
const DRY_EDGE: float = 2.0

var brain: BossBrain
var world: SimWorld
var t_s: float = 0.0
var high: bool = false
var spark_s: float = SPARK_EVERY_S
var half: Vector2 = Vector2(11, 9)
var ambushes: int = 0


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	var size: Array = JU.a(JU.dict(b.boss, "arena"), "size_m")
	if size.size() >= 2:
		half = Vector2(float(size[0]), float(size[1])) * 0.5


func in_water(p: Vector3) -> bool:
	return high and absf(p.x) < half.x - DRY_EDGE


func on_step(b: BossBrain) -> bool:
	var live: bool = b.duel_state() in [PossessionDuel.PLAYER_OFFENSE, PossessionDuel.BOSS_OFFENSE, PossessionDuel.LOOSE_BALL]
	if not live:
		return false
	t_s += DT
	var was: bool = high
	high = b.phase >= 2 or fmod(t_s, CYCLE_S) >= CYCLE_S - HIGH_S
	if high != was:
		world.emit("flood", {"actor": b.actor.id, "high": high})
	var t: SimActor = b.target
	if t != null and in_water(t.pos):
		StatusEffects.apply(t, {"slow": 0.2})
	if high:
		spark_s -= DT
		if spark_s <= 0.0 and not b.runner.running:
			spark_s = SPARK_EVERY_S
			world.emit("rail_spark", {"actor": b.actor.id})
			if t != null and in_water(t.pos):
				b.combat.damage.apply_raw(t, t.hp_max * 0.08)
				StatusEffects.apply(t, {"shock": 0.6})
				world.emit("popup", {"text": "THIRD RAIL!", "pos": t.pos, "style": "bad"})
			b.run_event_move("submerge_ambush")
			ambushes += 1
			return true
	return false
