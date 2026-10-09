class_name EnemyDefense
extends RefCounted
## Revision 12: street enemies answer punch spam. Each hit from a hooper
## inside `streak_window_s` grows a streak; past `min_hits` every hit rolls a
## reaction (chance grows per hit and per tier) that cancels the hitstun:
## - parry: a short parry window; your next punch is DEFLECTed (you stagger),
##   and a deflect turns straight into a counter.
## - dodge: i-frames and a slide out of the string.
## - counter: hyper armor plus its fastest usable attack, right now.
## Tuning: data/tuning/ai.json → defense. Bosses don't use this.

var cfg: Dictionary = {}
var enabled: bool = false
var mult: float = 1.0
var streak: int = 0
var last_hit_frame: int = -9999
var cooldown_until: int = -1
var reaction: String = ""          # "" | parry | dodge | counter
var frames_left: int = 0
var dodge_vel: Vector3 = Vector3.ZERO


func _init(ai: Dictionary, data: Dictionary) -> void:
	cfg = JU.dict(ai, "defense")
	enabled = JU.strs(cfg, "kinds").has(JU.s(data, "kind", "common")) and not JU.strs(cfg, "skip_behaviors").has(JU.s(data, "behavior", "brawler"))
	mult = JU.f(data, "defense_mult", 1.0)


static func chance(c: Dictionary, hits: int, tier: int, m: float) -> float:
	var need: int = JU.i(c, "min_hits", 3)
	if hits < need:
		return 0.0
	var p: float = JU.f(c, "base", 0.25) + JU.f(c, "per_hit", 0.15) * float(hits - need)
	p *= 1.0 + JU.f(c, "per_tier", 0.08) * float(maxi(0, tier - 1))
	return clampf(p * m, 0.0, JU.f(c, "max", 0.85))


func on_hit(b: EnemyBrain, res: Dictionary) -> bool:
	## Returns true when it reacted (the brain skips the hitstun).
	if not enabled or not b.actor.alive or b.actor.is_broken():
		return false
	if b.runner.running and JU.b(b.runner.move, "taunt"):
		return false
	var r: String = str(res.get("result", ""))
	var att: SimActor = b.world.actor_by_id(int(res.get("attacker", 0)))
	if att == null or att.kind != "hooper":
		return false
	if r == "deflect" and reaction == "parry":
		_end(b)
		_start(b, "counter", att)
		return true
	if r != "hit" or bool(res.get("knockdown", false)):
		return false
	var f: int = b.world.frame
	streak = streak + 1 if f - last_hit_frame <= int(JU.f(cfg, "streak_window_s", 1.0) * 60.0) else 1
	last_hit_frame = f
	if f < cooldown_until or reaction != "":
		return false
	if b.world.rng.randf() >= chance(cfg, streak, b.actor.tier, mult):
		return false
	_start(b, pick(b, att), att)
	return true


func pick(b: EnemyBrain, att: SimActor) -> String:
	var w: Dictionary = JU.dict(cfg, "weights")
	var kinds: Array[String] = ["parry", "dodge"]
	if not counter_move(b, att).is_empty():
		kinds.append("counter")
	var total: float = 0.0
	for k: String in kinds:
		total += JU.f(w, k, 1.0)
	var roll: float = b.world.rng.randf() * total
	for k2: String in kinds:
		roll -= JU.f(w, k2, 1.0)
		if roll <= 0.0:
			return k2
	return kinds[kinds.size() - 1]


static func counter_move(b: EnemyBrain, att: SimActor) -> Dictionary:
	## Its fastest usable attack, ignoring cooldowns (move damage comes from
	## the enemy def, so moves don't carry it).
	var d: float = b.actor.dist_to(att)
	var best: Dictionary = {}
	for m: Dictionary in b.moves:
		if JU.s(m, "primitive") in ["summon", "showboat", "stance"] or JU.b(m, "taunt") or JU.b(m, "requires_target_downed"):
			continue
		var rng: Array = JU.a(m, "range_m")
		if rng.size() >= 2 and (d < float(rng[0]) or d > float(rng[1]) + 0.5):
			continue
		if not JU.b(m, "body_attack") and JU.b(b.data, "has_ball") and not b.actor.has_ball:
			continue
		if best.is_empty() or JU.i(m, "startup") < JU.i(best, "startup"):
			best = m
	return best


func _start(b: EnemyBrain, kind: String, att: SimActor) -> void:
	var a: SimActor = b.actor
	b.runner.interrupt()
	b.stun_frames = 0
	a.flags["knocked"] = false
	a.flags["downed"] = false
	streak = 0
	cooldown_until = b.world.frame + int(JU.f(cfg, "cooldown_s", 2.0) * 60.0)
	reaction = kind
	var to_att: Vector3 = att.pos - a.pos
	to_att.y = 0.0
	if to_att.length() > 0.01:
		a.face_dir(to_att)
	match kind:
		"parry":
			frames_left = JU.i(cfg, "parry_f", 20)
			a.flags["parry_window"] = true
		"dodge":
			frames_left = JU.i(cfg, "dodge_f", 16)
			a.invulnerable = true
			var side: float = 1.0 if b.world.rng.randf() < 0.5 else -1.0
			var away: Vector3 = (-to_att.normalized() if to_att.length() > 0.01 else -a.forward()).rotated(Vector3.UP, side * deg_to_rad(55.0))
			dodge_vel = away * JU.f(cfg, "dodge_m", 2.5) / maxf(1.0, float(frames_left)) * 60.0
		"counter":
			frames_left = 0
			var m: Dictionary = counter_move(b, att)
			if m.is_empty():
				reaction = ""
			else:
				b.last_move = JU.s(m, "id")
				b.runner.start(m, att)
				a.hyper_armor = true
	b.world.emit("enemy_defended", {"actor": a.id, "kind": kind, "attacker": att.id})


func step(b: EnemyBrain) -> bool:
	## Runs before the brain's state machine; true while it drives the actor.
	var a: SimActor = b.actor
	match reaction:
		"":
			return false
		"counter":
			if not b.runner.running:
				a.hyper_armor = bool(a.flags.get("base_hyper_armor", false))
				reaction = ""
			return false
	frames_left -= 1
	if reaction == "dodge":
		a.desired_vel = dodge_vel
		a.anim_state = "defensive_slide"
	else:
		a.anim_state = "guard"
	if frames_left <= 0:
		_end(b)
	return true


func _end(b: EnemyBrain) -> void:
	b.actor.flags["parry_window"] = false
	b.actor.invulnerable = false
	reaction = ""
	frames_left = 0
