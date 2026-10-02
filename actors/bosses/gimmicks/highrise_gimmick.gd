class_name HighRiseGimmick
extends RefCounted
## High Rise (spec §9.3): REACH. His contest covers half the court, so
## normal shots get swatted; while he's SHOOK or STAGGERED (ankle-breakers,
## posters) or right after your stepback, the reach goes away. Phase 2 "Elevation": he grows and
## his cloud becomes a thunderstorm — telegraphed lightning every 7 s.

const DT: float = 1.0 / 60.0
const STORM_EVERY_S: float = 7.0
const REACH_RADIUS: float = 6.0

var brain: BossBrain
var world: SimWorld
var storm_s: float = STORM_EVERY_S
var base_contest: float = 3.6
var spaced_until: int = -1
const SPACE_S: float = 1.4


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	base_contest = b.actor.contest_radius
	world.sim_event.connect(_on_event)


func on_step(b: BossBrain) -> bool:
	var a: SimActor = b.actor
	## A stepback buys the space his reach takes away.
	var spaced: bool = world.frame < spaced_until
	a.contest_radius = base_contest if a.is_broken() or spaced else REACH_RADIUS
	if b.phase >= 2 and b.duel_state() in [PossessionDuel.PLAYER_OFFENSE, PossessionDuel.BOSS_OFFENSE, PossessionDuel.LOOSE_BALL]:
		storm_s -= DT
		if storm_s <= 0.0 and not b.runner.running:
			storm_s = STORM_EVERY_S
			b.run_event_move("lightning")
			return true
	return false


func _on_event(ev: Dictionary) -> void:
	if str(ev.get("type", "")) == "action_started" and brain.target != null and int(ev["actor"]) == brain.target.id and str(ev["move"]) == "stepback":
		spaced_until = world.frame + int(SPACE_S * 60.0)
	if str(ev.get("type", "")) == "shot_rejected" and int(ev.get("blocker", 0)) == brain.actor.id:
		world.emit("popup", {"text": "NOT IN MY HOUSE!", "pos": brain.actor.pos, "style": "bad"})
