class_name MidnightGimmick
extends RefCounted
## Midnight (spec §9.3, The Garden). Phase 1 "Warm-Up": he plays your game —
## dodge carelessly into his crossover and YOU go SHOOK (player-side stagger,
## 1.2 s). Phase 2 "Prime": borrowed signature moves (data). Phase 3
## "Overtime": the scoreboard counts down 60 s; at zero he unleashes
## MIDNIGHT (full-arena unblockable). A perfect crossover through it breaks
## his ankles -> SHOOK -> GAME POINT for the final poster. Miss and you take
## 90% max Heart and the clock resets to 30 s.

const DT: float = 1.0 / 60.0
const COUNTDOWN_S: float = 60.0
const RETRY_S: float = 30.0
const MISS_PCT: float = 0.9
const SHOOK_RANGE: float = 3.5

var brain: BossBrain
var world: SimWorld
var clock_s: float = COUNTDOWN_S
var midnight_live: bool = false
var player_shooks: int = 0
var midnight_attempts: int = 0
var broken: bool = false


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	world.sim_event.connect(_on_event)


func on_step(b: BossBrain) -> bool:
	if b.phase < 3 or broken:
		return false
	var st: String = b.duel_state()
	if not st in [PossessionDuel.PLAYER_OFFENSE, PossessionDuel.BOSS_OFFENSE, PossessionDuel.LOOSE_BALL]:
		return false
	var before: int = int(ceil(clock_s))
	clock_s -= DT
	if int(ceil(clock_s)) != before:
		world.emit("midnight_clock", {"actor": b.actor.id, "seconds": maxi(0, int(ceil(clock_s)))})
	if clock_s <= 0.0 and not midnight_live:
		midnight_live = true
		midnight_attempts += 1
		b.run_event_move("midnight")
		world.emit("midnight_unleashed", {"actor": b.actor.id})
		return true
	return false


func _on_event(ev: Dictionary) -> void:
	var t: String = str(ev.get("type", ""))
	match t:
		"action_started":
			## Warm-Up: dodging into his crossover's window shakes YOU.
			var a: SimActor = world.actor_by_id(int(ev["actor"]))
			if brain.phase != 1 or a == null or brain.target == null or a != brain.target:
				return
			if not str(ev["move"]) in ["crossover", "stepback", "defensive_slide"]:
				return
			var r: MoveRunner = brain.runner
			if r.running and JU.s(r.move, "id") == "warmup_crossover" and r.frame <= r.startup() + r.active() and a.dist_to(brain.actor) <= SHOOK_RANGE:
				player_shooks += 1
				if a.controller is Hooper:
					(a.controller as Hooper).call("_react", "player_shook")
				world.emit("player_shook", {"actor": a.id})
				world.emit("popup", {"text": "SHOOK!", "pos": a.pos, "style": "bad"})
		"hit_resolved":
			if str(ev["move"]) != "midnight" or int(ev["attacker"]) != brain.actor.id:
				return
			var tgt: SimActor = world.actor_by_id(int(ev["target"]))
			if tgt == null:
				return
			midnight_live = false
			if str(ev["result"]) in ["ankle_breaker", "dodged", "read"]:
				## The perfect crossover: his ankles go, the clock stops.
				broken = true
				brain.combat.damage.apply_raw(brain.actor, brain.actor.hp)
				if brain.actor.composure != null:
					brain.actor.composure.force_break("shook", 9999.0)
				world.emit("midnight_broken", {"actor": brain.actor.id})
				world.emit("popup", {"text": "ANKLES! FINISH IT!", "pos": tgt.pos, "style": "big"})
			else:
				brain.combat.damage.apply_raw(tgt, tgt.hp_max * MISS_PCT)
				clock_s = RETRY_S
				world.emit("midnight_missed", {"actor": tgt.id})
		"duel_phase_changed":
			if int(ev.get("phase", 1)) >= 3:
				clock_s = COUNTDOWN_S
				world.emit("midnight_clock", {"actor": brain.actor.id, "seconds": int(COUNTDOWN_S)})
