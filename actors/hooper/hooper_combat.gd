class_name HooperCombat
extends RefCounted
## Hooper module for §7.4/§7.5 attacks and defense. With the ball: dribble
## strike chain (X×4), Euro Step (sprint+X), Tomahawk (jump+X), Dunk (sprint
## at a hoop + A), Dunk Finisher (RT on a downed/SHOOK common). Without:
## Shove, Reach-in, Hands Up (tap parry / hold guard), Rejection (jump+LB),
## Hustle Dive (B at a loose ball).

const CHAIN_CANCEL_FRAMES: int = 4   # recovery frames before the next chain hit may start
const DODGE_CANCEL_FRAMES: int = 6

var combat: CombatSystem
var balls: BallSystem
var dunk_hoop: SimHoop = null


func _init(c: CombatSystem, b: BallSystem) -> void:
	combat = c
	balls = b


static func damage_buffs(a: SimActor, move: Dictionary = {}) -> float:
	var m: float = float(a.flags.get("damage_mult", 1.0)) * float(a.flags.get("buff_damage_mult", 1.0))
	if a.hp >= a.hp_max - 0.01:
		m *= float(a.flags.get("full_heart_damage_mult", 1.0))
	var prim: String = JU.s(move, "primitive")
	if prim == "strike" and JU.s(move, "stat") == "handles":
		m *= float(a.flags.get("dribble_damage_mult", 1.0))
	elif prim == "slam" or prim == "finisher" or prim == "dunk":
		m *= float(a.flags.get("dunk_damage_mult", 1.0))
	if bool(a.flags.get("takeover", false)):
		m *= JU.f(JU.dict(DataDB.tuning("combat"), "takeover"), "damage_mult", 1.25)
	return m


func try_start(h: Hooper) -> bool:
	var a: SimActor = h.actor
	var inp: ActorInput = a.input
	if a.has_ball:
		if not a.on_ground and inp.peek("light"):
			inp.pressed("light")
			return h.begin("tomahawk", a.forward(), self)
		if not a.on_ground:
			return false
		if inp.peek("jump") and h.sprinting:
			var hoop: SimHoop = _dunkable_hoop(h)
			if hoop != null:
				inp.pressed("jump")
				dunk_hoop = hoop
				return h.begin("dunk", hoop.rim - a.pos, self)
		if try_finisher(h):
			return true
		if inp.peek("light"):
			inp.pressed("light")
			return h.begin("euro_step" if h.sprinting else "pound", a.forward(), self)
		return false
	if inp.peek("hands_up") and (not a.on_ground or inp.peek("jump")):
		inp.pressed("hands_up")
		if inp.peek("jump"):
			inp.pressed("jump")
		return h.begin("rejection", a.forward(), self)
	if not a.on_ground:
		return false
	if inp.peek("hands_up"):
		inp.pressed("hands_up")
		return h.begin("hands_up", a.forward(), self)
	if inp.peek("dodge") and _dive_ball(h) != null:
		inp.pressed("dodge")
		var b: SimBall = _dive_ball(h)
		return h.begin("hustle_dive", b.pos - a.pos, self)
	if inp.peek("light"):
		inp.pressed("light")
		return h.begin("shove", a.forward(), self)
	if inp.peek("heavy"):
		inp.pressed("heavy")
		return h.begin("reach_in", a.forward(), self)
	return false


func on_begin(h: Hooper) -> void:
	var a: SimActor = h.actor
	match h.action:
		"hands_up":
			var w: float = StatFormulas.parry_window_frames(a.stat("hands") + int(a.flags.get("parry_bonus", 0)), JU.f(JU.dict(DataDB.tuning("combat"), "parry"), "base_window_frames", 10.0))
			if a.team == 0 and Settings.get_bool("rookie_mode"):
				w *= 1.25
			w += float(a.flags.get("parry_bonus_frames", 0.0))
			h.action_move = h.action_move.duplicate()
			h.action_move["active"] = int(w)
			h.action_total = int(w) + JU.i(h.action_move, "recovery", 18)
		"rejection":
			if a.on_ground:
				h.jump(1.0)
		"tomahawk":
			a.vel.y = minf(a.vel.y, -2.0)
	if JU.f(h.action_move, "lunge_m") > 0.0 and h.lock_target != null:
		a.turn_toward(h.lock_target.pos - a.pos, PI)
		h.action_dir = a.forward()


func on_frame(h: Hooper) -> void:
	var a: SimActor = h.actor
	var m: Dictionary = h.action_move
	var f: int = h.action_frame
	var s: int = JU.i(m, "startup")
	var act: int = JU.i(m, "active")
	a.desired_vel = Vector3.ZERO
	match JU.s(m, "primitive"):
		"strike":
			_strike_frame(h, m, f, s, act)
		"slam":
			a.vel.y = minf(a.vel.y, -14.0) if f > 2 and not a.on_ground else a.vel.y
			if f == s + 1:
				_hitbox(h, m, act)
		"finisher":
			_finisher_leap(h, f, s)
			if f == s + 1:
				_hitbox(h, m, act)
		"dunk":
			_dunk_frame(h, f, s, act)
		"swipe":
			if f == s + 1:
				_reach_in(h)
		"parry":
			if f <= act:
				a.flags["parry_window"] = true
			elif a.input.is_held("hands_up"):
				h.begin("guard", a.forward(), self)
		"guard":
			if not a.input.is_held("hands_up"):
				h.end_action()
				return
			a.flags["guarding"] = true
			h.guarding = true
			a.desired_vel = a.input.move3().limit_length(1.0) * 2.0
			if h.lock_target != null:
				a.turn_toward(h.lock_target.pos - a.pos, 0.3)
		"rejection":
			a.flags["rejecting"] = f > s and f <= s + act
			a.desired_vel = a.vel * Vector3(1, 0, 1)
		"dive":
			if f <= s + act:
				a.desired_vel = h.action_dir * 3.0 / (float(s + act) / 60.0)
			a.flags["pickup_bonus"] = 0.6
			if a.has_ball:
				h.end_action()


func on_end(h: Hooper, ended: String) -> void:
	h.actor.flags.erase("pickup_bonus")
	h.actor.flags.erase("finisher_target")
	h.guarding = false
	if ended == "reach_in" and bool(h.actor.flags.get("reach_missed", false)):
		h.actor.flags["reach_missed"] = false
		h.begin("off_balance", h.actor.forward(), null)


# ------------------------------------------------------------ strikes

func _strike_frame(h: Hooper, m: Dictionary, f: int, s: int, act: int) -> void:
	var a: SimActor = h.actor
	var lunge: float = JU.f(m, "lunge_m")
	if f <= s + act and lunge > 0.0:
		a.desired_vel = h.action_dir * lunge / (float(s + act) / 60.0)
	var hits: int = maxi(1, JU.i(m, "hits", 1))
	var gap: int = JU.i(m, "hit_gap", act)
	for i: int in hits:
		if f == s + 1 + i * gap:
			_hitbox(h, m, gap if hits > 1 else act)
	if f > s + act:
		var rec_f: int = f - s - act
		var nxt: String = JU.s(m, "next")
		if nxt != "" and rec_f >= CHAIN_CANCEL_FRAMES and a.input.peek("light") and a.has_ball:
			a.input.pressed("light")
			h.begin(nxt, a.forward(), self)
			return
		if rec_f >= DODGE_CANCEL_FRAMES and a.input.peek("dodge"):
			h.end_action()


func _hitbox(h: Hooper, m: Dictionary, frames: int) -> Hitbox:
	var a: SimActor = h.actor
	var hb: Hitbox = Hitbox.new()
	hb.owner_id = a.id
	hb.team = a.team
	hb.move_id = JU.s(m, "id")
	hb.volume = HitVolume.from_dict(JU.dict(m, "hitbox"))
	hb.volume.origin = a.pos
	hb.volume.yaw = a.facing
	hb.frames_left = maxi(1, frames)
	hb.damage = DamageMath.hooper_damage(m, a, damage_buffs(a, m))
	hb.composure = JU.f(m, "composure")
	hb.kind = JU.s(m, "type", "ball")
	hb.weight = JU.s(m, "hit_weight", "light")
	hb.break_kind = JU.s(m, "break_kind", "shook")
	hb.knockdown_commons = JU.b(m, "knockdown_commons") or (a.flags.has("knockdown_chance") and combat.world.rng.randf() < float(a.flags["knockdown_chance"]))
	hb.crit = JU.f(m, "crit", 1.0)
	var on_hit: Variant = a.flags.get("on_hit_status", {})
	if on_hit is Dictionary:
		hb.status = on_hit
	return combat.add(hb)


# ------------------------------------------------------------ dunks

func _dunkable_hoop(h: Hooper) -> SimHoop:
	var a: SimActor = h.actor
	var reach: float = StatFormulas.dunk_range(a.stat("bounce"), JU.f(h.move_data("dunk"), "range_m", 3.5)) * float(a.flags.get("dunk_range_mult", 1.0))
	for hp: SimHoop in balls.hoops:
		if not hp.enabled:
			continue
		var to: Vector3 = hp.floor_point() - a.pos
		to.y = 0.0
		if to.length() <= reach and (to.length() < 0.5 or a.forward().dot(to.normalized()) > 0.5):
			return hp
	return null


func _dunk_frame(h: Hooper, f: int, s: int, act: int) -> void:
	var a: SimActor = h.actor
	if dunk_hoop == null:
		h.end_action()
		return
	var under: Vector3 = dunk_hoop.rim - dunk_hoop.facing * 0.1
	var rise_frames: float = float(s + act)
	if f <= s + act:
		var u: float = float(f) / rise_frames
		var flat: Vector3 = a.pos.lerp(Vector3(under.x, a.pos.y, under.z), clampf(u * 1.4, 0.0, 1.0))
		a.pos.x = flat.x
		a.pos.z = flat.z
		a.vel.y = 0.0
		a.on_ground = false
		a.pos.y = a.ground_y + (dunk_hoop.rim.y - 1.4 - a.ground_y) * sin(u * PI * 0.5)
		a.turn_toward(dunk_hoop.rim - a.pos, 0.5)
	if f == s + act:
		a.flags["dunk_poster"] = false
		combat.world.emit("dunk_attempt", {"actor": a.id, "hoop": dunk_hoop.id})
		if not bool(a.flags.get("dunk_blocked", false)):
			balls.dunk(a, dunk_hoop)
		a.flags["dunk_blocked"] = false


func try_finisher(h: Hooper) -> bool:
	## Interact with the ball near a downed / SHOOK common. Also cancels the
	## tail of a crossover or stepback (Hooper._dodge_frame), so the ankle
	## you just took turns straight into the slam.
	var a: SimActor = h.actor
	if not a.has_ball or not a.input.peek("interact") or a.input.peek("bag_move"):
		return false
	var t: SimActor = finisher_target(combat.world, a, h.move_data("dunk_finisher"))
	if t == null:
		return false
	a.input.pressed("interact")
	if h.action != "":
		h.end_action()
	a.flags["finisher_target"] = t.id
	return h.begin("dunk_finisher", t.pos - a.pos, self)


static func finisher_reach(move: Dictionary) -> float:
	## How far the Dunk Finisher will leap to an open enemy (seek_m), never
	## less than its hit range.
	return maxf(JU.f(move, "seek_m", 0.0), JU.f(move, "range_m", 2.2))


static func finisher_target(w: SimWorld, a: SimActor, move: Dictionary) -> SimActor:
	## The nearest downed / SHOOK street enemy within reach.
	var best: SimActor = null
	var bd: float = finisher_reach(move)
	for o: SimActor in w.hostiles_of(a):
		if o.kind != "enemy" and o.kind != "critter":
			continue
		var d: float = o.dist_to(a)
		if (bool(o.flags.get("downed", false)) or o.is_shook()) and d <= bd:
			best = o
			bd = d
	return best


func _finisher_leap(h: Hooper, f: int, s: int) -> void:
	## Close the gap during the wind-up so the slam lands from seek range.
	var a: SimActor = h.actor
	var t: SimActor = combat.world.actor_by_id(int(a.flags.get("finisher_target", 0)))
	if t == null or not t.alive or f > s:
		return
	var to: Vector3 = t.pos - a.pos
	to.y = 0.0
	a.turn_toward(to, PI)
	var gap: float = to.length() - (t.radius + a.radius + 0.3)
	if gap > 0.0:
		a.desired_vel = to.normalized() * minf(gap / (float(s - f + 1) * Hooper.DT), JU.f(h.action_move, "leap_speed_max", 16.0))


# ------------------------------------------------------------ defense

func _reach_in(h: Hooper) -> void:
	var a: SimActor = h.actor
	var vol: HitVolume = HitVolume.from_dict(JU.dict(h.action_move, "hitbox"))
	vol.origin = a.pos
	vol.yaw = a.facing
	a.flags["reach_missed"] = true
	for o: SimActor in combat.world.hostiles_of(a):
		var showboating: bool = bool(o.flags.get("showboat", false))
		if not o.has_ball or not vol.hits(o) or (o.flags.has("move") and not showboating) or bool(o.flags.get("unstealable", false)):
			continue
		var chance: float = JU.f(h.action_move, "steal_chance", 0.35) + float(a.stat("hands") - 10) * JU.f(JU.dict(DataDB.tuning("combat"), "reach_in"), "hands_per_pt", 0.01) + float(a.flags.get("steal_bonus", 0.0))
		chance -= float(o.flags.get("ball_security", 0.0))
		if showboating:
			chance = 1.0
		if combat.world.rng.randf() < chance:
			var b: SimBall = balls.take_from(o)
			if b != null:
				balls.give(b, a)
				o.flags["disarmed"] = true
				a.hype.gain("strip")
				a.flags["reach_missed"] = false
				if showboating and o.composure != null:
					var comp: float = JU.f(JU.dict(DataDB.tuning("combat"), "parry"), "strip_composure", 30.0) * JU.f(JU.dict(DataDB.tuning("bosses"), "duel"), "showboat_strip_mult", 2.0)
					if o.composure.add(comp, "stagger") != "":
						combat.world.emit("composure_broken", {"actor": o.id, "kind": "stagger"})
					o.flags["showboat"] = false
				combat.world.emit("steal", {"actor": a.id, "target": o.id, "showboat": showboating})
		return


func _dive_ball(h: Hooper) -> SimBall:
	var a: SimActor = h.actor
	var reach: float = JU.f(h.move_data("hustle_dive"), "range_m", 3.0)
	for b: SimBall in balls.balls:
		if b.state == SimBall.State.LOOSE and Vector2(b.pos.x - a.pos.x, b.pos.z - a.pos.z).length() <= reach and b.pos.y < 1.5:
			return b
	return null
