class_name BossBrain
extends RefCounted
## Boss AI (spec §9.2, §15.9): every think tick, filter moves by phase, tier,
## cooldown, range and possession; pick by weight with a penalty on recently
## used moves; run possession behaviors — clear the ball, walk to the paint,
## Statement Dunk, showboat, contest your shots, chase loose balls.

const DT: float = 1.0 / 60.0

var actor: SimActor
var world: SimWorld
var combat: CombatSystem
var balls: BallSystem
var boss: Dictionary = {}
var hoop: SimHoop
var duel: PossessionDuel = null
var runner: MoveRunner
var phase: int = 1
var moves: Array[Dictionary] = []
var stationary: bool = false
var cooldowns: Dictionary = {}
var recent: Array[String] = []
var recover_s: float = 0.5
var think_s: float = 0.0
var aggro_until: int = -1
var target: SimActor = null
var paint_pos: Vector3 = Vector3.ZERO
var t5_done: bool = false
var statement_cd_mult: float = 1.0
var repeats_left: int = 0
var hold_s: float = 0.0
const HOLD_LIMIT_S: float = 10.0
var last_move: Dictionary = {}
var history: Array[String] = []    # every move started (gimmicks replay these)
var gimmick: RefCounted = null    # optional per-boss script (on_step/on_event hooks)


func _init(a: SimActor, w: SimWorld, c: CombatSystem, b: BallSystem, boss_data: Dictionary, h: SimHoop) -> void:
	actor = a
	world = w
	combat = c
	balls = b
	boss = boss_data
	hoop = h
	runner = MoveRunner.new(a, w, c)
	runner.balls = b
	paint_pos = h.floor_point() + h.facing * 2.0 if h != null else a.pos
	set_phase(1)


func dispose() -> void:
	gimmick = null
	runner = null


func set_phase(p: int) -> void:
	phase = p
	moves = BossGating.moves_for_phase(boss, p, actor.tier)
	var ps: Array[Dictionary] = BossGating.phases(boss, actor.tier)
	var rules: Dictionary = JU.dict(ps[p - 1], "rules") if p - 1 < ps.size() else {}
	stationary = JU.b(rules, "stationary")
	if not actor.flags.has("base_speed"):
		actor.flags["base_speed"] = float(actor.flags.get("speed", 4.0))
	actor.flags["speed"] = float(actor.flags["base_speed"]) * JU.f(rules, "speed_mult", 1.0)
	actor.flags["damage_taken_mult"] = JU.f(rules, "damage_taken_mult", 1.0)
	actor.flags["phase_damage_mult"] = JU.f(rules, "damage_mult", 1.0)
	statement_cd_mult = JU.f(rules, "statement_cd_mult", 1.0)
	if rules.has("scale"):
		actor.flags["scale"] = JU.f(rules, "scale", 1.0)
		actor.height = JU.f(BossGating.base_stats(boss), "height_m", 4.0) * JU.f(rules, "scale", 1.0)
	cooldowns.clear()


func duel_state() -> String:
	return duel.state if duel != null else PossessionDuel.BOSS_OFFENSE if actor.has_ball else PossessionDuel.PLAYER_OFFENSE


func step() -> void:
	actor.desired_vel = Vector3.ZERO
	for k: Variant in cooldowns.keys():
		cooldowns[k] = float(cooldowns[k]) - DT
	recover_s -= DT
	if target == null or not target.alive:
		target = _find_target()
	if gimmick != null and gimmick.has_method("on_step") and bool(gimmick.call("on_step", self)):
		return
	var st: String = duel_state()
	if st == PossessionDuel.GAME_POINT or st == PossessionDuel.VICTORY:
		runner.interrupt()
		actor.anim_state = "shook"
		return
	if st == PossessionDuel.PHASE_TRANSITION:
		runner.interrupt()
		actor.invulnerable = true
		actor.anim_state = "transition"
		return
	actor.invulnerable = false
	if actor.is_broken() or StatusEffects.has(actor, "frozen"):
		runner.interrupt()
		actor.anim_state = "shook" if actor.is_shook() else "stagger"
		return
	if runner.running:
		runner.step()
		if not runner.running and repeats_left > 0 and target != null:
			repeats_left -= 1
			runner.start(last_move, target)
			if repeats_left == 0 and JU.b(last_move, "curve_last"):
				runner.state["curve"] = true
		return
	if st == PossessionDuel.CHECK or st == PossessionDuel.DEFEAT:
		if not stationary:
			_walk(paint_pos, 1.0)
		actor.anim_state = "idle"
		return
	if actor.has_ball and st == PossessionDuel.BOSS_OFFENSE:
		hold_s += DT
		if hold_s > HOLD_LIMIT_S and recover_s <= 0.0 and _force_ball_move():
			return
	else:
		hold_s = 0.0
	think_s -= DT
	if think_s > 0.0 or recover_s > 0.0:
		_position(st)
		return
	think_s = JU.f(DataDB.tuning("ai"), "think_interval_s", 0.2)
	var m: Dictionary = pick_move()
	if not m.is_empty():
		start_move(m)
	else:
		_position(st)


func _find_target() -> SimActor:
	for o: SimActor in world.actors:
		if o.alive and o.team == 0 and o.kind == "hooper":
			return o
	return null


func usable(m: Dictionary) -> bool:
	if target == null:
		return false
	if float(cooldowns.get(JU.s(m, "id"), 0.0)) > 0.0 or JU.f(m, "weight", 1.0) <= 0.0:
		return false
	var d: float = actor.dist_to(target) - actor.radius
	var rng: Array = JU.a(m, "range_m")
	if rng.size() >= 2 and (d < float(rng[0]) or d > float(rng[1])):
		return false
	match JU.s(m, "possession", "any"):
		"with_ball":
			if not actor.has_ball:
				return false
		"without_ball":
			if actor.has_ball:
				return false
	if JU.b(m, "needs_paint") and not stationary and actor.flat_pos().distance_to(Vector2(paint_pos.x, paint_pos.z)) > 3.0:
		return false
	if JU.s(m, "primitive") == "statement_dunk" and duel != null and not duel.boss_cleared:
		return false
	return true


func pick_move() -> Dictionary:
	if StatusEffects.has(actor, "blind"):
		return {}
	var cands: Array[Dictionary] = []
	var total: float = 0.0
	for m: Dictionary in moves:
		if usable(m):
			cands.append(m)
			total += weight_of(m)
	if cands.is_empty():
		return {}
	var roll: float = world.rng.randf() * total
	for m2: Dictionary in cands:
		roll -= weight_of(m2)
		if roll <= 0.0:
			return m2
	return cands[cands.size() - 1]


func weight_of(m: Dictionary) -> float:
	var w: float = JU.f(m, "weight", 1.0)
	var id: String = JU.s(m, "id")
	if recent.has(id):
		w *= 0.3 if recent[recent.size() - 1] == id else 0.6
	if world.frame < aggro_until and JU.s(m, "primitive") != "showboat":
		w *= 1.5
	if actor.has_ball and duel_state() == PossessionDuel.BOSS_OFFENSE:
		## With the ball, bosses look to score: favor lobs / dunks / showboats.
		if JU.s(m, "primitive") != "statement_dunk":
			w *= 2.0 if JU.s(m, "possession") == "with_ball" else 0.6
	return w


func start_move(m: Dictionary) -> void:
	var id: String = JU.s(m, "id")
	recent.append(id)
	if recent.size() > 3:
		recent.pop_front()
	cooldowns[id] = JU.f(m, "cooldown_s", 3.0) * TierMath.multiplier(DataDB.tiers(), "ai_cooldown", actor.tier) * (statement_cd_mult if JU.s(m, "primitive") == "statement_dunk" else 1.0)
	recover_s = 0.35 * TierMath.multiplier(DataDB.tiers(), "ai_cooldown", actor.tier)
	last_move = m
	repeats_left = maxi(0, JU.i(m, "repeat", 1) - 1)
	history.append(id)
	if history.size() > 8:
		history.pop_front()
	runner.start(m, target)


func _force_ball_move() -> bool:
	## Boss possession clock: after holding too long it must put the ball up
	## (Statement Dunk if it can, else a lob regardless of range).
	var lob: Dictionary = {}
	var dunk: Dictionary = {}
	for m: Dictionary in moves:
		if JU.s(m, "possession") != "with_ball":
			continue
		if JU.s(m, "primitive") == "statement_dunk" and usable(m) and dunk.is_empty():
			dunk = m
		if JU.s(m, "primitive") == "lob" and lob.is_empty():
			lob = m
	var pick: Dictionary = lob if not lob.is_empty() else dunk
	if pick.is_empty() or target == null:
		return false
	start_move(pick)
	hold_s = 0.0
	return true


func run_event_move(id: String) -> void:
	var m: Dictionary = DataDB.move(JU.s(boss, "id"), id)
	if not m.is_empty():
		runner.interrupt()
		last_move = m
		repeats_left = maxi(0, JU.i(m, "repeat", 1) - 1)
		history.append(id)
		runner.start(m, target)


func _position(st: String) -> void:
	if stationary or target == null:
		if target != null:
			actor.turn_toward(target.pos - actor.pos, 0.08)
		actor.anim_state = "idle"
		return
	match st:
		PossessionDuel.BOSS_OFFENSE:
			_walk(paint_pos, 1.0)
		PossessionDuel.LOOSE_BALL:
			for b: SimBall in balls.balls:
				if b.state == SimBall.State.LOOSE:
					_walk(b.pos, 1.0)
					return
			_walk(target.pos, 0.6)
		_:
			# Defend: stay between the player and the rim, about 2 m off them.
			var guard: Vector3 = target.pos + (hoop.floor_point() - target.pos).normalized() * 2.2 if hoop != null else target.pos
			_walk(guard, 0.9)
	actor.turn_toward(target.pos - actor.pos, 0.15)


func _walk(p: Vector3, speed_k: float) -> void:
	var to: Vector3 = p - actor.pos
	to.y = 0.0
	if to.length() < 0.4:
		actor.anim_state = "idle"
		return
	actor.desired_vel = to.normalized() * float(actor.flags.get("speed", 4.0)) * speed_k
	actor.anim_state = "walk"


func on_hit(_res: Dictionary) -> void:
	pass


func on_parried(res: Dictionary) -> void:
	if str(res.get("result", "")) in ["strip", "rejection"]:
		runner.interrupt()
		recover_s = 0.8
