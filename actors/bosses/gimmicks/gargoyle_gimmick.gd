class_name GargoyleGimmick
extends RefCounted
## The Gargoyle (spec §9.3, The Summit): WIND. Gusts push you and curve your
## shots (the shot drift the meter shows; correct during the gather). Every
## 10 s a gust blows for 3 s (6 s cycle in Phase 2 "Storm Front", which also
## brings lightning).

const DT: float = 1.0 / 60.0
const GUST_S: float = 3.0
const PUSH_MPS: float = 2.2
const DRIFT: float = 0.12

var brain: BossBrain
var world: SimWorld
var every_s: float = 10.0
var gust_in: float = 10.0
var gust_left: float = 0.0
var gust_dir: Vector3 = Vector3.RIGHT
var storm_s: float = 6.0


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world


func on_step(b: BossBrain) -> bool:
	var t: SimActor = b.target
	if t == null:
		return false
	if b.duel_state() in [PossessionDuel.GAME_POINT, PossessionDuel.VICTORY, PossessionDuel.CHECK]:
		## The wind dies down with him (and between possessions).
		t.flags["wind_drift"] = 0.0
		gust_left = 0.0
		return false
	every_s = 6.0 if b.phase >= 2 else 10.0
	if gust_left > 0.0:
		gust_left -= DT
		t.flags["wind_drift"] = DRIFT * signf(gust_dir.x)
		if t.on_ground:
			t.pos = world.collision.resolve(t.pos + gust_dir * PUSH_MPS * DT, t.radius)
		if gust_left <= 0.0:
			t.flags["wind_drift"] = 0.0
			world.emit("gust_end", {"actor": b.actor.id})
	else:
		gust_in -= DT
		if gust_in <= 0.0:
			gust_in = every_s
			gust_left = GUST_S
			gust_dir = Vector3.LEFT if world.rng.randf() < 0.5 else Vector3.RIGHT
			world.emit("gust", {"actor": b.actor.id, "dir": gust_dir, "s": GUST_S})
	if b.phase >= 2 and b.duel_state() in [PossessionDuel.PLAYER_OFFENSE, PossessionDuel.BOSS_OFFENSE, PossessionDuel.LOOSE_BALL]:
		storm_s -= DT
		if storm_s <= 0.0 and not b.runner.running:
			storm_s = 9.0
			b.run_event_move("storm_lightning")
			return true
	return false
