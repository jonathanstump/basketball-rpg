class_name HeapGimmick
extends RefCounted
## King of the Heap (spec §9.3): ARMOR + SHOT CLOCK. He absorbs trash into
## an armor bar over his Heart (Absorb rebuilds it; a bucket or heavy hit
## interrupts). Gulls are the shot clock: hold the ball 6 s without shooting
## or passing and they dive and snatch it. Phase 2: a garbage truck sweeps a
## lane every 25 s.

const DT: float = 1.0 / 60.0
const SHOT_CLOCK_S: float = 6.0
const TRUCK_EVERY_S: float = 25.0
const ARMOR_PCT: float = 0.10
const ABSORB_PER_S_PCT: float = 0.015

var brain: BossBrain
var world: SimWorld
var hold_s: float = 0.0
var truck_s: float = TRUCK_EVERY_S
var snatches: int = 0
var armor_max: float = 0.0


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	armor_max = b.actor.hp_max * ARMOR_PCT
	b.actor.flags["armor"] = armor_max
	b.actor.flags["armor_max"] = armor_max
	world.sim_event.connect(_on_event)


func on_step(b: BossBrain) -> bool:
	var t: SimActor = b.target
	var st: String = b.duel_state()
	if b.runner.running and JU.s(b.runner.move, "id") == "absorb" and b.runner.in_active():
		b.actor.flags["armor"] = minf(armor_max, float(b.actor.flags.get("armor", 0.0)) + b.actor.hp_max * ABSORB_PER_S_PCT * DT)
	if t != null and st == PossessionDuel.PLAYER_OFFENSE and t.has_ball and t.controller is Hooper and (t.controller as Hooper).action != "shot_gather":
		hold_s += DT
		if int(hold_s * 60.0) % 60 == 0:
			world.emit("shot_clock", {"actor": t.id, "left_s": maxf(0.0, SHOT_CLOCK_S - hold_s)})
		if hold_s >= SHOT_CLOCK_S:
			_snatch(t)
	else:
		hold_s = 0.0
	if b.phase >= 2 and st in [PossessionDuel.PLAYER_OFFENSE, PossessionDuel.BOSS_OFFENSE, PossessionDuel.LOOSE_BALL]:
		truck_s -= DT
		if truck_s <= 0.0 and not b.runner.running:
			truck_s = TRUCK_EVERY_S
			b.run_event_move("garbage_truck")
			return true
	return false


func _snatch(t: SimActor) -> void:
	## The gulls dive: the ball is knocked loose toward the King.
	hold_s = 0.0
	snatches += 1
	var ball: SimBall = brain.balls.take_from(t)
	if ball != null:
		ball.vel = (brain.actor.pos - t.pos).normalized() * 5.0 + Vector3(0, 5, 0)
	world.emit("gull_snatch", {"actor": t.id, "pos": t.pos})
	world.emit("popup", {"text": "SHOT CLOCK! GULLS!", "pos": t.pos, "style": "bad"})
	world.emit("ball_knocked_loose", {"actor": t.id, "by": brain.actor.id})


func _on_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"shot_released", "pass_released", "lob_released":
			if brain.target != null and int(ev.get("actor", 0)) == brain.target.id:
				hold_s = 0.0
		"bucket_damage":
			_interrupt_absorb()
		"hit_resolved":
			if int(ev["target"]) == brain.actor.id and str(ev.get("weight", "")) == "heavy":
				_interrupt_absorb()
		"duel_check":
			hold_s = 0.0


func _interrupt_absorb() -> void:
	if brain.runner.running and JU.s(brain.runner.move, "id") == "absorb":
		brain.runner.interrupt()
		world.emit("absorb_interrupted", {"actor": brain.actor.id})
