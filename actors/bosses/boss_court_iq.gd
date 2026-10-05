class_name BossCourtIQ
extends RefCounted
## A boss's basketball brain (playtest R7), driven by BossBrain:
## - Offense (boss has the ball): pick a shot from its shot mix, get to the
##   spot (driving through you: Body and Heart slow it down), gather with a
##   telegraph, release. Stationary phases shoot from where they sit.
## - Defense (you have the ball): guard distance from `pressure`, close out
##   on your shot gather, reach for the ball by `gamble`.
## - Loose balls: chase speed from `ball_hunger`.

const DT: float = 1.0 / 60.0

var brain: BossBrain:   # weak: the brain owns us (no RefCounted cycle)
	get:
		return _brain.get_ref() as BossBrain
var _brain: WeakRef
var profile: Dictionary = {}
var r7: Dictionary = {}
var plan: String = ""          # shot kind being worked toward ("" = none)
var spot: Vector3 = Vector3.ZERO
var plan_s: float = 0.0
var reach_cd_s: float = 0.0
var harass_cd_s: float = 0.0   # with the ball: time until it may swing at you again
var shots_taken: int = 0


func _init(b: BossBrain) -> void:
	_brain = weakref(b)
	profile = BossHoops.profile(b.boss)
	r7 = JU.dict(JU.dict(DataDB.tuning("bosses"), "duel"), "r7")


func reset() -> void:
	plan = ""
	plan_s = 0.0


# ------------------------------------------------------------ offense

func pick_kind() -> String:
	var a: SimActor = brain.actor
	var hoop: SimHoop = brain.hoop
	if brain.stationary or hoop == null:
		return zone_kind(hoop.flat_distance(a.pos) if hoop != null else 5.0)
	var mix: Dictionary = JU.dict(profile, "shot_mix")
	var total: float = 0.0
	for k: String in BossHoops.SHOT_KINDS:
		if k == "dunk" and dunk_move().is_empty():
			continue
		total += JU.f(mix, k)
	if total <= 0.0:
		return "mid"
	var roll: float = brain.world.rng.randf() * total
	for k2: String in BossHoops.SHOT_KINDS:
		if k2 == "dunk" and dunk_move().is_empty():
			continue
		roll -= JU.f(mix, k2)
		if roll <= 0.0:
			return k2
	return "mid"


static func zone_kind(dist_m: float) -> String:
	if dist_m < 3.0:
		return "layup"
	return "mid" if dist_m < 6.75 else "three"


func dunk_move() -> Dictionary:
	for m: Dictionary in brain.moves:
		if JU.s(m, "primitive") == "statement_dunk":
			return m
	return {}


func spot_for(kind: String) -> Vector3:
	var hoop: SimHoop = brain.hoop
	var sp: Dictionary = JU.dict(JU.dict(r7, "shot"), "spot_m")
	var d: float = JU.f(sp, "layup" if kind == "dunk" else kind, 4.6)
	var ang: float = deg_to_rad(brain.world.rng.randf_range(-60.0, 60.0)) if kind == "mid" or kind == "three" else 0.0
	return hoop.floor_point() + hoop.facing.rotated(Vector3.UP, ang) * d


func step_offense() -> bool:
	## Returns true when it drove the boss this frame.
	var a: SimActor = brain.actor
	if not a.has_ball or brain.hoop == null or brain.target == null:
		reset()
		return false
	if plan == "":
		plan = pick_kind()
		spot = a.pos if brain.stationary else spot_for(plan)
		plan_s = 0.0
	plan_s += DT
	var cleared: bool = brain.duel == null or brain.duel.boss_cleared
	var there: bool = brain.stationary or a.flat_pos().distance_to(Vector2(spot.x, spot.z)) < 0.8
	if cleared and (there or plan_s > JU.f(JU.dict(r7, "shot"), "approach_max_s", 4.5)):
		if not there and not brain.stationary:
			plan = "dunk" if plan == "dunk" and _in_paint() else zone_kind(brain.hoop.flat_distance(a.pos))
		return shoot(plan)
	if brain.stationary:
		a.turn_toward(brain.target.pos - a.pos, 0.1)
		a.anim_state = "idle"
		return true
	_drive(spot)
	return true


func _in_paint() -> bool:
	return brain.actor.flat_pos().distance_to(Vector2(brain.paint_pos.x, brain.paint_pos.z)) <= 3.0


func shoot(kind: String) -> bool:
	var a: SimActor = brain.actor
	plan = ""
	shots_taken += 1
	if kind == "dunk":
		var dm: Dictionary = dunk_move()
		if not dm.is_empty():
			brain.start_move(dm)
			return true
		kind = "layup"
	var sc: Dictionary = JU.dict(r7, "shot")
	var m: Dictionary = {"id": "boss_shot", "name": "Shot", "primitive": "boss_shot", "shot_kind": kind,
		"startup": JU.i(JU.dict(sc, "gather_f"), kind, 30), "active": 1, "recovery": JU.i(sc, "recovery_f", 24), "damage": 0}
	a.turn_toward(brain.hoop.floor_point() - a.pos, PI)
	brain.runner.start(m, null)
	brain.runner.dir = a.forward()
	return true


func _drive(to: Vector3) -> void:
	## Walk to the spot; bodying up the player slows the boss (playtest R7:
	## your Body and Heart vs its Strength).
	var a: SimActor = brain.actor
	var dir: Vector3 = to - a.pos
	dir.y = 0.0
	if dir.length() < 0.05:
		return
	dir = dir.normalized()
	var mult: float = body_up_mult(a, brain.target, dir, rating("strength"), r7)
	a.desired_vel = dir * float(a.flags.get("speed", 4.0)) * mult
	a.turn_toward(dir, 0.2)
	a.anim_state = "walk"


static func body_up_mult(a: SimActor, p: SimActor, dir: Vector3, strength: float, cfg: Dictionary) -> float:
	if p == null or not p.alive:
		return 1.0
	var bu: Dictionary = JU.dict(cfg, "body_up")
	var to_p: Vector3 = p.pos - a.pos
	to_p.y = 0.0
	if to_p.length() > a.radius + p.radius + JU.f(bu, "radius_pad_m", 0.5) or to_p.normalized().dot(dir) < 0.3:
		return 1.0
	var resist: float = JU.f(bu, "body_w", 0.5) * clampf(float(p.stat("body") - 10) / 50.0, 0.0, 1.0) + JU.f(bu, "heart_w", 0.3) * clampf(p.hp / maxf(1.0, p.hp_max), 0.0, 1.0)
	return clampf(0.5 + strength / 100.0 * 0.6 - resist, JU.f(bu, "min_mult", 0.25), 1.0)


func rating(key: String) -> float:
	return BossHoops.rating(profile, key)


# ------------------------------------------------------------ defense

func defend() -> void:
	## Stay between the player and the rim at a distance set by `pressure`;
	## close out hard when they gather a shot.
	var a: SimActor = brain.actor
	var t: SimActor = brain.target
	var hoop: SimHoop = brain.hoop
	if t == null or hoop == null:
		return
	var gathering: bool = t.controller is Hooper and (t.controller as Hooper).action == "shot_gather"
	var gm: PackedFloat32Array = JU.floats(r7, "guard_m")
	var gap: float = lerpf(gm[0] if gm.size() > 0 else 3.0, gm[1] if gm.size() > 1 else 1.2, BossHoops.tendency(profile, "pressure"))
	if gathering:
		gap = 0.6
	var guard: Vector3 = t.pos + (hoop.floor_point() - t.pos).normalized() * (gap + a.radius)
	var to: Vector3 = guard - a.pos
	to.y = 0.0
	if to.length() > 0.4:
		a.desired_vel = to.normalized() * float(a.flags.get("speed", 4.0)) * (JU.f(r7, "closeout_speed", 1.35) if gathering else 0.9)
		a.anim_state = "walk"
	else:
		a.anim_state = "idle"
	a.turn_toward(t.pos - a.pos, 0.15)


func try_reach() -> bool:
	## Gamble for the ball: a short telegraphed swipe. A hit is a steal roll
	## (DuelController); a crossover through it is an ankle-breaker as usual.
	var a: SimActor = brain.actor
	var t: SimActor = brain.target
	var rc: Dictionary = JU.dict(r7, "reach")
	if t == null or not t.has_ball or reach_cd_s > 0.0:
		return false
	if a.dist_to(t) - a.radius > JU.f(rc, "range_m", 2.2):
		return false
	if brain.world.rng.randf() > BossHoops.tendency(profile, "gamble") * JU.f(rc, "gamble_k", 0.35):
		return false
	reach_cd_s = JU.f(rc, "cooldown_s", 2.5)
	brain.runner.start({"id": "boss_reach", "name": "Reach", "primitive": "melee_arc", "startup": JU.i(rc, "startup", 14),
		"active": JU.i(rc, "active", 5), "recovery": JU.i(rc, "recovery", 18), "dmg_mult": 0.15, "hit_weight": "light",
		"reach_steal": true, "hitbox": {"shape": "arc", "radius": a.radius + 1.4, "angle": 100.0}}, t)
	return true


func steal_chance(player: SimActor) -> float:
	var rc: Dictionary = JU.dict(r7, "reach")
	var handles: float = clampf(float(player.stat("handles") - 10) / 50.0, 0.0, 1.0)
	return clampf(JU.f(rc, "steal_base", 0.35) * rating("steal") / 50.0 * (1.0 - 0.5 * handles), 0.05, 0.85)


func loose_speed() -> float:
	var hs: PackedFloat32Array = JU.floats(r7, "hunger_speed")
	return lerpf(hs[0] if hs.size() > 0 else 0.6, hs[1] if hs.size() > 1 else 1.45, BossHoops.tendency(profile, "ball_hunger"))


func tick() -> void:
	reach_cd_s -= DT
	harass_cd_s -= DT
