class_name FerrymanGimmick
extends RefCounted
## The Ferryman (spec §9.3): TIDE. Every 20 s (8 s in the T5 Storm) the deck
## tilts: you and loose balls slide downhill and a wave washes across
## (knockback). Pushed off the rail = heavy damage, back on deck. Undertow
## pulls you toward the rail.

const DT: float = 1.0 / 60.0
const TIDE_EVERY_S: float = 20.0
const STORM_EVERY_S: float = 8.0
const TILT_S: float = 3.5
const SLIDE_MPS: float = 2.4
const WAVE_PUSH_M: float = 3.0
const OVERBOARD_PCT: float = 0.2

var brain: BossBrain
var world: SimWorld
var half: Vector2 = Vector2(9, 8)
var tide_s: float = TIDE_EVERY_S
var tilt_left_s: float = 0.0
var tilt_dir: Vector3 = Vector3.ZERO
var storm: bool = false
var undertow_until: int = -1
var overboards: int = 0


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	var size: Array = JU.a(JU.dict(b.boss, "arena"), "size_m")
	if size.size() >= 2:
		half = Vector2(float(size[0]), float(size[1])) * 0.5
	world.sim_event.connect(_on_event)


func on_step(b: BossBrain) -> bool:
	var t: SimActor = b.target
	var live: bool = b.duel_state() in [PossessionDuel.PLAYER_OFFENSE, PossessionDuel.BOSS_OFFENSE, PossessionDuel.LOOSE_BALL]
	if t == null or not live:
		return false
	if world.frame < undertow_until:
		var side: float = signf(t.pos.x) if absf(t.pos.x) > 0.1 else 1.0
		t.pos = world.collision.resolve(t.pos + Vector3(side, 0, 0) * 2.6 * DT, t.radius)
	if tilt_left_s > 0.0:
		tilt_left_s -= DT
		if t.on_ground:
			t.pos = world.collision.resolve(t.pos + tilt_dir * SLIDE_MPS * DT, t.radius)
		for ball: SimBall in b.balls.balls:
			if ball.state == SimBall.State.LOOSE:
				ball.vel += tilt_dir * SLIDE_MPS * 2.0 * DT
		_check_overboard(t)
		return false
	tide_s -= DT
	if tide_s <= 0.0:
		tide_s = STORM_EVERY_S if storm else TIDE_EVERY_S
		tilt_left_s = TILT_S
		tilt_dir = Vector3(1, 0, 0) if world.rng.randf() < 0.5 else Vector3(-1, 0, 0)
		world.emit("floor_tilt", {"actor": b.actor.id, "dir": tilt_dir})
		wave(t)
	return false


func wave(t: SimActor) -> void:
	## A wave washes across the deck downhill: knockback unless airborne.
	world.emit("wave", {"actor": brain.actor.id, "dir": tilt_dir})
	if t.on_ground and t.alive:
		t.pos = t.pos + tilt_dir * WAVE_PUSH_M
		_check_overboard(t)
		t.pos = world.collision.resolve(t.pos, t.radius)


func _check_overboard(t: SimActor) -> void:
	if absf(t.pos.x) > half.x + 1.8:
		overboards += 1
		brain.combat.damage.apply_raw(t, t.hp_max * OVERBOARD_PCT)
		t.pos = Vector3(0, 0, half.y * 0.3)
		t.vel = Vector3.ZERO
		world.emit("overboard", {"actor": t.id, "pos": t.pos})
		world.emit("popup", {"text": "MAN OVERBOARD!", "pos": t.pos, "style": "bad"})


func _on_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"move_started":
			if int(ev["actor"]) == brain.actor.id and str(ev["move"]) == "undertow":
				undertow_until = world.frame + 90
		"t5_event":
			storm = true
			tide_s = minf(tide_s, STORM_EVERY_S)
