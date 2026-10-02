class_name MovePrimitives
extends RefCounted
## Per-frame behavior of the 17 move primitives (spec §9.2). Every boss and
## enemy move is one primitive + data. World-scale effects that need a game
## layer (summon, arena_event, statement_dunk, mirror) emit events that the
## duel/boss systems consume.

const DT: float = 1.0 / 60.0


static func frame(r: MoveRunner) -> void:
	var m: Dictionary = r.move
	var prim: String = JU.s(m, "primitive", "melee_arc")
	var s: int = r.startup()
	var first_active: bool = r.frame == s + 1
	if r.frame <= s and r.target != null and JU.b(m, "track", true):
		r.actor.turn_toward(r.target.pos - r.actor.pos, 0.12)
		r.dir = r.actor.forward()
		if JU.b(m, "axis_snap"):
			## Tracks: charges only run along the painted lanes (world axes).
			r.dir = Vector3(signf(r.dir.x), 0, 0) if absf(r.dir.x) > absf(r.dir.z) else Vector3(0, 0, signf(r.dir.z))
		if JU.b(m, "lateral"):
			## Sidewinder: rush sideways across the target's line.
			var side: Vector3 = r.actor.forward().cross(Vector3.UP).normalized()
			r.dir = side * (1.0 if side.dot(r.target.pos - r.actor.pos) >= 0.0 else -1.0)
	if r.in_active() and r.target != null and (JU.f(m, "curve_deg") > 0.0 or bool(r.state.get("curve", false))):
		## Curving charge: bend toward the target a little each frame.
		var want: Vector3 = (r.target.pos - r.actor.pos)
		want.y = 0.0
		if want.length() > 0.1:
			var ang: float = r.dir.signed_angle_to(want.normalized(), Vector3.UP)
			r.dir = r.dir.rotated(Vector3.UP, clampf(ang, -deg_to_rad(maxf(1.5, JU.f(m, "curve_deg"))), deg_to_rad(maxf(1.5, JU.f(m, "curve_deg")))))
	if JU.f(m, "pull_mps") > 0.0 and r.in_active() and r.target != null and r.target.alive:
		## Gravity Well style pull toward the user.
		var to_me: Vector3 = r.actor.pos - r.target.pos
		to_me.y = 0.0
		if to_me.length() > r.actor.radius + r.target.radius + 0.3:
			r.target.pos = r.world.collision.resolve(r.target.pos + to_me.normalized() * JU.f(m, "pull_mps") * DT, r.target.radius)
	match prim:
		"melee_arc":
			_multi(r, m, {"shape": "arc", "radius": 1.8, "angle": 120.0})
		"lunge", "charge_lane":
			if JU.b(m, "feint") and r.frame == s / 2:
				r.actor.desired_vel = -r.dir * 6.0
				r.world.emit("feint", {"actor": r.actor.id})
			if r.in_active():
				var dist: float = JU.f(m, "lunge_m", 4.0 if prim == "lunge" else 12.0)
				r.actor.desired_vel = r.dir * dist / maxf(1.0, float(r.active())) * 60.0
				r.actor.hyper_armor = prim == "charge_lane" or JU.b(m, "hyper_armor")
			if first_active:
				r.make_hitbox(_vol(m, {"shape": "arc" if prim == "lunge" else "box", "radius": 1.4, "angle": 140.0, "length": 1.6, "width": 2.2}), r.active())
		"grab":
			if r.in_active() and JU.f(m, "lunge_m") > 0.0:
				r.actor.desired_vel = r.dir * JU.f(m, "lunge_m") / maxf(1.0, float(r.active())) * 60.0
			if first_active:
				var hb: Hitbox = r.make_hitbox(_vol(m, {"shape": "sphere", "radius": 1.3, "forward": 1.0}), r.active())
				hb.grab = true
				hb.knockdown = JU.b(m, "knockdown", true)
		"projectile":
			if first_active:
				_projectile(r, m, r.dir)
				for i: int in JU.i(m, "spread", 0):
					var off: float = deg_to_rad(JU.f(m, "spread_deg", 15.0) * float(i + 1) * (1.0 if i % 2 == 0 else -1.0))
					_projectile(r, m, r.dir.rotated(Vector3.UP, off))
		"lob":
			if first_active:
				var count: int = maxi(1, JU.i(m, "count", 1))
				for i2: int in count:
					var p: Vector3 = r.target.pos if r.target != null else r.actor.pos + r.dir * 8.0
					if i2 > 0:
						p += Vector3(r.world.rng.randf_range(-3, 3), 0, r.world.rng.randf_range(-3, 3))
					var flight: float = JU.f(m, "flight_s", 1.1) + 0.25 * float(i2)
					var hb_l: Hitbox = _delayed_circle(r, m, p, flight, true)
					if i2 == 0 and JU.b(m, "uses_ball") and r.balls != null and r.actor.has_ball:
						var ball: SimBall = r.balls.lob_ball(r.actor, p, flight, false)
						if ball != null:
							hb_l.tags["ball"] = ball.id
							r.world.emit("ball_thrown", {"actor": r.actor.id, "ball": ball.id})
		"ring_wave":
			if first_active:
				var hb2: Hitbox = r.make_hitbox({"shape": "ring", "radius": 0.6, "width": 0.7, "height": JU.f(m, "ring_height", 0.55)}, int(JU.f(m, "ring_max_m", 9.0) / JU.f(m, "ring_speed", 9.0) * 60.0))
				hb2.world_space = true
				hb2.grow_per_s = JU.f(m, "ring_speed", 9.0)
				hb2.parryable = false
		"slam_circle":
			_multi(r, m, {"shape": "circle", "radius": 3.0, "forward": 1.0, "height": 2.0})
		"line_sweep":
			if first_active:
				var hb3: Hitbox = r.make_hitbox(_vol(m, {"shape": "box", "length": 12.0, "width": 1.2, "height": 1.2}), r.active())
				hb3.world_space = true
				hb3.volume.yaw = r.actor.facing + deg_to_rad(JU.f(m, "sweep_deg", 90.0) * 0.5)
				r.state["sweep"] = hb3
			if r.in_active() and r.state.has("sweep"):
				var hb4: Hitbox = r.state["sweep"]
				hb4.volume.yaw -= deg_to_rad(JU.f(m, "sweep_deg", 90.0)) / maxf(1.0, float(r.active()))
		"zone":
			if first_active:
				var c: Vector3 = r.target.pos if r.target != null else r.actor.pos + r.dir * 4.0
				var hb5: Hitbox = _world_circle(r, m, c, int(JU.f(m, "duration_s", 6.0) * 60.0))
				hb5.rehit_frames = 30
				hb5.parryable = false
				hb5.tags["no_flinch"] = true   # puddles / rain / fire: chip + status, no stunlock
				r.world.emit("zone_spawned", {"actor": r.actor.id, "move": JU.s(m, "id"), "pos": c, "radius": hb5.volume.radius, "duration_s": JU.f(m, "duration_s", 6.0), "zone": JU.s(m, "zone", "puddle")})
		"summon":
			if first_active:
				r.world.emit("summon", {"actor": r.actor.id, "archetype": JU.s(m, "summon", "ball_hog"), "count": JU.i(m, "count", 2), "duration_s": JU.f(m, "duration_s", 0.0)})
		"arena_event":
			if first_active:
				r.world.emit("arena_event", {"actor": r.actor.id, "event": JU.s(m, "event", JU.s(m, "id")), "move": m})
				_pattern(r, m)
		"showboat":
			r.actor.flags["showboat"] = r.in_active() or r.frame <= r.startup()
			if r.frame == r.total - 1:
				r.actor.flags["showboat"] = false
				if JU.f(m, "buff_mult") > 0.0:
					## e.g. Chest Pound: a finished showboat buffs damage for a while.
					r.actor.flags["buff_mult"] = JU.f(m, "buff_mult")
					r.actor.flags["buff_until"] = r.world.frame + int(JU.f(m, "buff_s", 10.0) * 60.0)
				r.world.emit("showboat_completed", {"actor": r.actor.id, "move": JU.s(m, "id")})
		"statement_dunk":
			if r.frame == 1:
				r.world.emit("statement_dunk_started", {"actor": r.actor.id, "move": JU.s(m, "id")})
			if first_active:
				var hb6: Hitbox = r.make_hitbox(_vol(m, {"shape": "circle", "radius": 2.5, "height": 4.0}), r.active())
				hb6.lob = true
				hb6.tags["statement"] = true
				if r.balls != null and r.actor.has_ball:
					var sb: SimBall = r.balls.ball_of(r.actor)
					if sb != null:
						hb6.tags["ball"] = sb.id
			if r.frame == r.total - 1:
				r.world.emit("statement_dunk_finished", {"actor": r.actor.id})
		"reposition":
			r.actor.invulnerable = r.in_active()
			if r.frame == s + r.active():
				_reposition(r, m)
				if m.has("hitbox"):
					r.make_hitbox(_vol(m, {"shape": "circle", "radius": 2.5, "height": 2.0}), 6)
		"mirror":
			if first_active:
				r.world.emit("mirror_requested", {"actor": r.actor.id, "move": JU.s(m, "id")})
		"stance":
			var on: bool = r.frame > s and r.frame <= s + r.active()
			r.actor.flags[JU.s(m, "stance", "shell")] = on
			r.actor.flags["guarding"] = on and JU.s(m, "stance", "shell") in ["hedge", "guard", "shell"]
			r.actor.hyper_armor = on and JU.b(m, "hyper_armor", true)
			if JU.s(m, "stance", "shell") == "shell" and JU.b(m, "full_block"):
				## Shell Up: frontal hits do nothing, guard never breaks, slow turning.
				r.actor.flags["guard_chip"] = 0.0 if on else 0.25
				r.actor.flags["guard_stability"] = 999.0 if on else 1.0
				r.actor.flags["turn_mult"] = JU.f(m, "turn_mult", 0.3) if on else 1.0


static func _multi(r: MoveRunner, m: Dictionary, defaults: Dictionary) -> void:
	## One or more hits (hits / hit_gap); Tier 5+ commons add a combo hit.
	var hits: int = maxi(1, JU.i(m, "hits", 1))
	if JU.b(m, "combo") and r.actor.tier >= 5 and r.actor.kind == "enemy":
		hits += 1
	var gap: int = JU.i(m, "hit_gap", r.active())
	for i: int in hits:
		if r.frame == r.startup() + 1 + i * gap:
			r.make_hitbox(_vol(m, defaults), gap if hits > 1 else r.active())


static func _vol(m: Dictionary, defaults: Dictionary) -> Dictionary:
	var v: Dictionary = defaults.duplicate()
	var hb: Dictionary = JU.dict(m, "hitbox")
	for k: Variant in hb.keys():
		v[k] = hb[k]
	return v


static func _projectile(r: MoveRunner, m: Dictionary, dir: Vector3) -> void:
	var pd: Dictionary = JU.dict(m, "projectile")
	var speed: float = JU.f(pd, "speed", 18.0)
	var rng: float = JU.f(pd, "range", 18.0)
	var hb: Hitbox = r.make_hitbox({"shape": "sphere", "radius": JU.f(pd, "radius", 0.45), "height": 0.9, "y_offset": 0.6}, int(rng / speed * 60.0))
	hb.world_space = true
	hb.projectile = true
	hb.velocity = dir * speed
	hb.tags["homing"] = JU.f(pd, "homing", 0.0)
	hb.tags["homing_target"] = r.target.id if r.target != null else 0


static func _world_circle(r: MoveRunner, m: Dictionary, c: Vector3, frames: int) -> Hitbox:
	var hb: Hitbox = r.make_hitbox(_vol(m, {"shape": "circle", "radius": 2.0, "height": 2.5}), frames)
	hb.world_space = true
	hb.volume.origin = c
	hb.volume.forward = 0.0
	return hb


static func _delayed_circle(r: MoveRunner, m: Dictionary, c: Vector3, delay_s: float, is_lob: bool) -> Hitbox:
	var hb: Hitbox = _world_circle(r, m, c, 4)
	hb.delay = int(delay_s * 60.0)
	hb.lob = is_lob and JU.b(m, "rejectable", is_lob)
	r.world.emit("telegraph_circle", {"actor": r.actor.id, "pos": c, "radius": hb.volume.radius, "delay_s": delay_s, "move": JU.s(m, "id")})
	return hb


static func _pattern(r: MoveRunner, m: Dictionary) -> void:
	## Generic hazard patterns for arena events: random circles, grid, lane.
	var pat: Dictionary = JU.dict(m, "pattern")
	if pat.is_empty():
		return
	var center: Vector3 = r.target.pos if r.target != null else r.actor.pos
	var kind: String = JU.s(pat, "kind", "random")
	var n: int = JU.i(pat, "count", 6)
	var spread: float = JU.f(pat, "spread_m", 6.0)
	if kind == "safe_lane":
		_safe_lane(r, m, pat, center, spread)
		return
	for i: int in n:
		var p: Vector3 = center
		match kind:
			"grid":
				var cols: int = maxi(1, int(sqrt(float(n))))
				p = center + Vector3(float(i % cols) - float(cols) * 0.5, 0, float(i / cols) - float(cols) * 0.5) * (spread / float(cols)) * 2.0
			"lane":
				p = center + Vector3(spread * (float(i) / float(maxi(1, n - 1)) - 0.5) * 2.0, 0, 0)
			_:
				p = center + Vector3(r.world.rng.randf_range(-spread, spread), 0, r.world.rng.randf_range(-spread, spread))
		_delayed_circle(r, m, p, JU.f(pat, "delay_s", 1.0) + JU.f(pat, "stagger_s", 0.15) * float(i), false)


static func _safe_lane(r: MoveRunner, m: Dictionary, pat: Dictionary, center: Vector3, spread: float) -> void:
	## Full-area hazard grid with one open column (e.g. Bridge Collapse).
	var step_m: float = JU.f(pat, "step_m", 3.0)
	var cols: int = int(spread * 2.0 / step_m) + 1
	var safe: int = r.world.rng.randi() % cols
	r.world.emit("safe_lane", {"actor": r.actor.id, "x": center.x - spread + float(safe) * step_m, "width": step_m})
	for cx: int in cols:
		if cx == safe:
			continue
		for rz: int in cols:
			var p: Vector3 = center + Vector3(-spread + float(cx) * step_m, 0, -spread + float(rz) * step_m)
			_delayed_circle(r, m, p, JU.f(pat, "delay_s", 1.5) + JU.f(pat, "stagger_s", 0.1) * float(rz), false)


static func _reposition(r: MoveRunner, m: Dictionary) -> void:
	var to: String = JU.s(m, "to", "behind_target")
	var p: Vector3 = r.actor.pos
	match to:
		"behind_target":
			if r.target != null:
				p = r.target.pos - r.target.forward() * 2.5
		"home":
			p = r.actor.home
		"random":
			p = r.actor.home + Vector3(r.world.rng.randf_range(-6, 6), 0, r.world.rng.randf_range(-6, 6))
	r.actor.pos = r.world.collision.resolve(p, r.actor.radius)
	if r.target != null:
		r.actor.face_dir(r.target.pos - r.actor.pos)
