class_name EnemyBrain
extends RefCounted
## Street AI (spec §8.5, §15.9): Idle/Patrol -> Alert (sees you within 18 m
## and 120° FOV, or hears combat within 12 m) -> Engage -> Recover -> Leash
## (returns home if pulled 35 m from spawn; heals while leashing). Attack
## tokens cap simultaneous attackers. Archetype quirks live in EnemyBehaviors.

const DT: float = 1.0 / 60.0

var actor: SimActor
var world: SimWorld
var combat: CombatSystem
var balls: BallSystem
var data: Dictionary = {}
var moves: Array[Dictionary] = []
var runner: MoveRunner
var ai: Dictionary = {}
var behavior: String = "brawler"
var state: String = "idle"
var state_t: float = 0.0
var target: SimActor = null
var cooldowns: Dictionary = {}
var recover_s: float = 0.0
var stun_frames: int = 0
var post_flag: String = ""
var post_s: float = 0.0
var circle_sign: float = 1.0
var last_move: String = ""
var wander_to: Vector3 = Vector3.INF
var scratch: Dictionary = {}      # per-behavior state


func _init(a: SimActor, w: SimWorld, c: CombatSystem, b: BallSystem, d: Dictionary, mv: Array[Dictionary]) -> void:
	actor = a
	world = w
	combat = c
	balls = b
	data = d
	moves = mv
	ai = DataDB.tuning("ai")
	behavior = JU.s(d, "behavior", "brawler")
	runner = MoveRunner.new(a, w, c)
	if a.tier >= 5 and a.kind == "enemy":
		runner.speed_mult = JU.f(JU.dict(ai, "t5_common"), "recovery_mult", 0.8)
	circle_sign = 1.0 if (a.id % 2) == 0 else -1.0


func tokens() -> AttackTokenManager:
	if world.attack_tokens == null:
		world.attack_tokens = AttackTokenManager.new()
	return world.attack_tokens


func set_state(s: String) -> void:
	if s == state:
		return
	if state == "engage":
		tokens().release(actor.id)
	state = s
	state_t = 0.0


func speed() -> float:
	var sp: float = float(actor.flags.get("speed", 4.0)) * StatusEffects.speed_mult(actor)
	if world.frame < int(actor.flags.get("aura_until", -1)):
		sp *= 1.25
	return sp


func step() -> void:
	state_t += DT
	actor.desired_vel = Vector3.ZERO
	if actor.alive and world.frame >= int(actor.flags.get("despawn_frame", 1 << 40)):
		## Timed summons (Block Party, Rush Order, Fresh Load) leave.
		actor.alive = false
		if actor.has_ball and balls != null:
			var b: SimBall = balls.take_from(actor)
			if b != null:
				b.vel = Vector3(0, 3, 0)
		world.emit("summon_scattered", {"actor": actor.id})
		return
	for k: Variant in cooldowns.keys():
		cooldowns[k] = float(cooldowns[k]) - DT
	recover_s -= DT
	if not actor.alive:
		tokens().release(actor.id)
		actor.anim_state = "death"
		return
	if stun_frames > 0:
		stun_frames -= 1
		actor.flags["downed"] = bool(actor.flags.get("knocked", false)) and stun_frames > 20
		actor.anim_state = "knockdown" if bool(actor.flags.get("knocked", false)) else "hit"
		if stun_frames == 0:
			actor.flags["knocked"] = false
			actor.flags["downed"] = false
		return
	if actor.is_broken() or StatusEffects.has(actor, "frozen"):
		runner.interrupt()
		actor.anim_state = "hit"
		return
	if post_s > 0.0:
		post_s -= DT
		actor.flags[post_flag] = post_s > 0.0
		actor.anim_state = "taunt" if post_flag == "frozen" else "idle"
		return
	if runner.running:
		if not runner.step():
			_after_move(runner.move)
		return
	if EnemyBehaviors.pre_step(self):
		return
	match state:
		"dormant":
			EnemyBehaviors.dormant(self)
		"idle", "patrol":
			_idle()
		"engage":
			_engage()
		"leash":
			_leash()
		"flee":
			EnemyBehaviors.flee(self)
	_anim_locomotion()


# ------------------------------------------------------------ states

func find_target() -> SimActor:
	var best: SimActor = null
	var bd: float = 1e9
	for o: SimActor in world.actors:
		if o.alive and o.team == 0 and o.kind == "hooper":
			var d: float = o.dist_to(actor)
			if d < bd:
				bd = d
				best = o
	return best


func perceives(t: SimActor) -> bool:
	if t == null:
		return false
	var d: float = t.dist_to(actor)
	var to: Vector3 = (t.pos - actor.pos)
	to.y = 0.0
	var fov: float = deg_to_rad(JU.f(ai, "fov_deg", 120.0)) * 0.5
	var sees: bool = d <= JU.f(ai, "alert_radius_m", 18.0) and (to.length() < 0.01 or actor.forward().angle_to(to) <= fov) and not world.collision.segment_blocked(actor.center(), t.center())
	var hears: bool = d <= JU.f(ai, "hear_radius_m", 12.0) and world.frame - int(t.flags.get("last_combat_frame", -9999)) < 120
	return sees or hears


func alert(t: SimActor) -> void:
	target = t
	set_state("engage")
	world.emit("enemy_alerted", {"actor": actor.id})
	for o: SimActor in world.actors:
		if o != actor and o.team == actor.team and o.alive and o.dist_to(actor) <= JU.f(ai, "hear_radius_m", 12.0):
			var ob: EnemyBrain = o.controller as EnemyBrain
			if ob != null and (ob.state == "idle" or ob.state == "patrol"):
				ob.target = t
				ob.set_state("engage")


func _idle() -> void:
	var t: SimActor = find_target()
	if perceives(t) and not bool(actor.flags.get("passive", false)) and world.frame >= int(actor.flags.get("calm_until", -1)):
		alert(t)
		return
	if JU.b(data, "perch") or actor.flags.get("speed", 0.0) == 0.0:
		return
	if wander_to == Vector3.INF or actor.flat_pos().distance_to(Vector2(wander_to.x, wander_to.z)) < 0.5 or state_t > 6.0:
		wander_to = actor.home + Vector3(world.rng.randf_range(-3, 3), 0, world.rng.randf_range(-3, 3))
		state_t = 0.0
	go_to(wander_to, speed() * 0.35)


func _engage() -> void:
	if target == null or not target.alive:
		target = find_target()
		if target == null or not target.alive:
			set_state("idle")
			return
	if actor.pos.distance_to(actor.home) > JU.f(ai, "leash_m", 35.0) * float(actor.flags.get("leash_mult", 1.0)) * float(GameState.flags.get("enemy_leash_mult", 1.0)):
		set_state("leash")
		return
	if EnemyBehaviors.engage(self):
		return
	var d: float = actor.dist_to(target)
	actor.turn_toward(target.pos - actor.pos, 0.25)
	var has_tok: bool = tokens().has_token(actor.id, target.id)
	if not has_tok and recover_s <= 0.0:
		has_tok = tokens().request(actor, target.id)
	if has_tok:
		var m: Dictionary = pick_move(d)
		if not m.is_empty() and recover_s <= 0.0:
			start_move(m)
			return
		if d > preferred_range():
			go_to(target.pos, speed())
	elif d > JU.f(ai, "circle_max_m", 6.0) + 2.0:
		go_to(target.pos, speed())
	else:
		circle(d)


func _leash() -> void:
	actor.hp = minf(actor.hp_max, actor.hp + actor.hp_max * JU.f(ai, "leash_heal_per_s", 0.25) * DT)
	go_to(actor.home, speed())
	if actor.pos.distance_to(actor.home) < 1.0:
		actor.hp = actor.hp_max
		target = null
		set_state("idle")


func _after_move(m: Dictionary) -> void:
	recover_s = 0.4 * TierMath.multiplier(DataDB.tiers(), "ai_cooldown", actor.tier)
	tokens().release(actor.id)
	EnemyBehaviors.after_move(self, m)


# ------------------------------------------------------------ helpers

func move_usable(m: Dictionary, d: float) -> bool:
	var rng: Array = JU.a(m, "range_m")
	if rng.size() >= 2 and (d < float(rng[0]) or d > float(rng[1])):
		return false
	if float(cooldowns.get(JU.s(m, "id"), 0.0)) > 0.0:
		return false
	if not JU.b(m, "body_attack") and JU.s(m, "primitive") != "showboat" and JU.s(m, "primitive") != "summon" and JU.s(m, "primitive") != "stance" and JU.b(data, "has_ball") and not actor.has_ball and not bool(actor.flags.get("defending", false)):
		return false
	if JU.b(m, "requires_target_downed") and not bool(target.flags.get("downed", false)):
		return false
	if JU.b(m, "requires_target_ball") and not target.has_ball:
		return false
	return true


func pick_move(d: float) -> Dictionary:
	if StatusEffects.has(actor, "blind"):
		return {}
	var total: float = 0.0
	var cands: Array[Dictionary] = []
	for m: Dictionary in moves:
		if move_usable(m, d):
			cands.append(m)
			total += _w(m)
	if cands.is_empty():
		return {}
	var roll: float = world.rng.randf() * total
	for m2: Dictionary in cands:
		roll -= _w(m2)
		if roll <= 0.0:
			return m2
	return cands[cands.size() - 1]


func _w(m: Dictionary) -> float:
	var w: float = JU.f(m, "weight", 1.0)
	return w * (0.35 if JU.s(m, "id") == last_move else 1.0)


func start_move(m: Dictionary) -> void:
	last_move = JU.s(m, "id")
	cooldowns[last_move] = JU.f(m, "cooldown_s", 2.0) * TierMath.multiplier(DataDB.tiers(), "ai_cooldown", actor.tier)
	runner.start(m, target)


func preferred_range() -> float:
	var best: float = 1.4
	for m: Dictionary in moves:
		var rng: Array = JU.a(m, "range_m")
		if rng.size() >= 2:
			best = minf(best, float(rng[1]) * 0.8) if float(rng[0]) <= 0.01 else best
	return maxf(best, actor.radius + 0.8)


func go_to(p: Vector3, sp: float) -> void:
	var to: Vector3 = p - actor.pos
	to.y = 0.0
	if to.length() < 0.05:
		return
	var dir: Vector3 = to.normalized()
	if world.nav != null:
		dir = world.nav.call("steer", actor.pos, p, dir)
	actor.desired_vel = dir * sp
	actor.turn_toward(dir, 0.25)


func circle(d: float) -> void:
	var to: Vector3 = target.pos - actor.pos
	to.y = 0.0
	var tangent: Vector3 = Vector3(-to.z, 0, to.x).normalized() * circle_sign
	var radial: Vector3 = to.normalized() * clampf(d - (JU.f(ai, "circle_min_m", 4.0) + 1.0), -1.0, 1.0)
	actor.desired_vel = (tangent + radial).normalized() * speed() * 0.5
	actor.turn_toward(to, 0.2)
	if world.rng.randf() < 0.004:
		circle_sign = -circle_sign


func _anim_locomotion() -> void:
	if runner.running:
		return
	var sp: float = Vector2(actor.desired_vel.x, actor.desired_vel.z).length()
	actor.anim_speed = sp
	actor.anim_frame = 0
	actor.anim_state = "idle" if sp < 0.2 else ("run" if sp > 4.0 else "walk")
	if actor.has_ball and sp < 0.2:
		actor.anim_state = "dribble_idle"


# ------------------------------------------------------------ reactions

func on_hit(res: Dictionary) -> void:
	if not actor.alive:
		return
	var att: SimActor = world.actor_by_id(int(res.get("attacker", 0)))
	if att != null and att.team != actor.team and (state == "idle" or state == "patrol" or state == "dormant"):
		alert(att)
	EnemyBehaviors.on_hit(self, res)
	var r: String = str(res.get("result", ""))
	if r != "hit":
		return
	if runner.running and JU.b(runner.move, "taunt"):
		if actor.composure != null:
			actor.composure.force_break("stagger")
		runner.interrupt()
		return
	if bool(res.get("knockdown", false)):
		runner.interrupt()
		stun(90, true)
	elif not actor.hyper_armor and float(res.get("damage", 0.0)) >= actor.poise:
		runner.interrupt()
		stun(24 if str(res.get("weight", "")) == "heavy" else 14, false)


func on_parried(res: Dictionary) -> void:
	runner.interrupt()
	tokens().release(actor.id)
	var kd: float = float(res.get("knockdown_s", 0.0))
	if kd > 0.0:
		stun(int(kd * 60.0), true)
	else:
		stun(36, false)


func stun(frames: int, knocked: bool) -> void:
	stun_frames = maxi(stun_frames, frames)
	if knocked:
		actor.flags["knocked"] = true
