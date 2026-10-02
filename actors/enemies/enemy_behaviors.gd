class_name EnemyBehaviors
extends RefCounted
## Archetype quirks layered on EnemyBrain (spec §8.1-§8.4): Showboat taunts,
## Big Man dunk-on-you, Sniper perches, Hype Man aura + flight, Pickpocket
## theft and escape, critter swarms/flee/dives, Breaker freeze, Fixie turn,
## Pigeon Keeper whistles, Tourist flashes, Bootleg ambush, disarmed run-back.

const DT: float = 1.0 / 60.0


static func pre_step(b: EnemyBrain) -> bool:
	## Runs before the state machine; return true to skip it this frame.
	var a: SimActor = b.actor
	if bool(a.flags.get("disarmed", false)) and b.balls != null and b.state == "engage":
		for ball: SimBall in b.balls.balls:
			if ball.home_id == a.id and ball.state == SimBall.State.LOOSE:
				b.go_to(ball.pos, b.speed() * 1.1)
				a.anim_state = "run"
				return true
	match b.behavior:
		"hype_man":
			_hype_aura(b)
		"tourist":
			_tourist(b)
			return true
		"static":
			a.desired_vel = Vector3.ZERO
			return true
	return false


static func engage(b: EnemyBrain) -> bool:
	## Archetype movement during Engage; return true if it handled the frame.
	var a: SimActor = b.actor
	var t: SimActor = b.target
	var d: float = a.dist_to(t)
	match b.behavior:
		"sniper":
			a.turn_toward(t.pos - a.pos, 0.2)
			var m: Dictionary = b.pick_move(d)
			if not m.is_empty() and b.recover_s <= 0.0:
				b.start_move(m)
			elif d < 4.0:
				b.go_to(a.pos + (a.pos - t.pos).normalized() * 3.0, b.speed())
			elif a.pos.distance_to(a.home) > 2.0:
				b.go_to(a.home, b.speed())
			return true
		"hype_man", "flee":
			if b.behavior == "hype_man" and d < 2.0:
				return false
			if d < 9.0:
				b.go_to(a.pos + (a.pos - t.pos).normalized() * 4.0, b.speed())
			return true
		"pickpocket":
			if a.has_ball:
				b.set_state("flee")
				b.scratch["flee_t"] = 0.0
				return true
		"keeper":
			if d < 5.0:
				b.go_to(a.pos + (a.pos - t.pos).normalized() * 3.0, b.speed())
				var m2: Dictionary = b.pick_move(d)
				if not m2.is_empty() and b.recover_s <= 0.0:
					b.start_move(m2)
				return true
	return false


static func flee(b: EnemyBrain) -> void:
	var a: SimActor = b.actor
	var t: SimActor = b.target if b.target != null else b.find_target()
	b.scratch["flee_t"] = float(b.scratch.get("flee_t", 0.0)) + DT
	var tired: bool = float(b.scratch["flee_t"]) > float(a.flags.get("tire_s", 6.0))
	if t != null:
		var away: Vector3 = a.pos - t.pos
		away.y = 0.0
		b.go_to(a.pos + away.normalized() * 4.0, b.speed() * (0.4 if tired else 1.0))
		if b.behavior == "pickpocket" and a.has_ball and t.dist_to(a) > 30.0:
			var ball: SimBall = b.balls.take_from(a)
			if ball != null:
				ball.set_state(SimBall.State.DEAD)
			a.alive = false
			a.flags["escaped"] = true
			b.world.emit("pickpocket_escaped", {"actor": a.id, "home": ball.home_id if ball != null else 0})
			return
	if b.behavior == "swarm" and float(b.scratch["flee_t"]) > 1.5:
		b.set_state("engage")
	if b.behavior == "pickpocket" and not a.has_ball:
		b.set_state("engage")


static func dormant(b: EnemyBrain) -> void:
	var a: SimActor = b.actor
	a.anim_state = "idle"
	var t: SimActor = b.find_target()
	if t != null and (t.dist_to(a) <= 2.2 or a.hp < a.hp_max):
		b.world.emit("bootleg_revealed", {"actor": a.id})
		b.alert(t)


static func after_move(b: EnemyBrain, m: Dictionary) -> void:
	if JU.f(m, "freeze_after_s") > 0.0:
		b.post_flag = "frozen"
		b.post_s = JU.f(m, "freeze_after_s")
		b.actor.flags["damage_taken_mult"] = 1.5
	elif JU.f(m, "turn_after_s") > 0.0:
		b.post_flag = "turning"
		b.post_s = JU.f(m, "turn_after_s")
		b.actor.flags["ball_security"] = -1.0
		b.actor.flags["damage_taken_mult"] = 1.3
	else:
		b.actor.flags["damage_taken_mult"] = 1.0
		b.actor.flags["ball_security"] = 0.0


static func on_hit(b: EnemyBrain, res: Dictionary) -> void:
	var a: SimActor = b.actor
	if str(res.get("result", "")) != "hit":
		return
	if b.behavior == "swarm":
		b.set_state("flee")
		b.scratch["flee_t"] = 0.0
	if b.behavior == "pickpocket" and a.has_ball:
		var ball: SimBall = b.balls.take_from(a)
		if ball != null:
			ball.vel = Vector3(0, 4, 0) - a.forward() * 2.0
		b.set_state("engage")


static func _hype_aura(b: EnemyBrain) -> void:
	var a: SimActor = b.actor
	var box_id: int = int(a.flags.get("boombox_id", 0))
	var box: SimActor = b.world.actor_by_id(box_id) if box_id != 0 else null
	var active: bool = box_id == 0 or (box != null and box.alive)
	a.flags["aura_active"] = active
	if box != null and box.alive:
		box.pos = a.pos + a.right() * 0.6 + Vector3(0, 0, 0)
	if not active:
		return
	var r: float = float(a.flags.get("aura_radius", 8.0))
	for o: SimActor in b.world.actors:
		if o != a and o.team == a.team and o.alive and o.dist_to(a) <= r:
			o.flags["aura_until"] = b.world.frame + 2


static func _tourist(b: EnemyBrain) -> void:
	var a: SimActor = b.actor
	var t: SimActor = b.find_target()
	b.scratch["t"] = float(b.scratch.get("t", 0.0)) + DT
	if t == null:
		return
	a.turn_toward(t.pos - a.pos, 0.1)
	var d: float = t.dist_to(a)
	var since: float = float(b.scratch["t"])
	if d <= 7.0 and since > 4.0:
		b.scratch["t"] = 0.0
		b.world.emit("flash_cue", {"actor": a.id})
		b.scratch["flash_at"] = b.world.frame + 24
	if int(b.scratch.get("flash_at", -1)) == b.world.frame:
		StatusEffects.apply(t, {"blind": float(a.flags.get("flash_s", 1.0))}, float(t.flags.get("status_resist", 0.0)))
		b.world.emit("camera_flash", {"actor": a.id, "target": t.id})
	if b.wander_to == Vector3.INF or a.flat_pos().distance_to(Vector2(b.wander_to.x, b.wander_to.z)) < 0.5:
		b.wander_to = a.home + Vector3(b.world.rng.randf_range(-4, 4), 0, b.world.rng.randf_range(-4, 4))
	b.go_to(b.wander_to, b.speed() * 0.4)
