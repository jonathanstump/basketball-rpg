class_name BallPasses
extends RefCounted
## PASS and lob logic (spec §7.4): chest pass ricochets back on a hit and is
## loose on a miss; baseball pass pierces 2 commons and always ends loose;
## lobs arc to a reticle and splash on landing. Wire Kicks drop when hit.

var sys: BallSystem


func _init(s: BallSystem) -> void:
	sys = s


func launch(b: SimBall, passer: SimActor, kind: String, target_point: Vector3, homing_target: SimActor) -> void:
	var pc: Dictionary = JU.dict(sys.cfg, kind)
	var start: Vector3 = passer.pos + Vector3(0, JU.f(sys.cfg, "hand_height", 1.05), 0) + passer.forward() * 0.4
	b.set_state(SimBall.State.PASS)
	b.pos = start
	b.pass_kind = kind
	b.pass_dir = (target_point - start).normalized() if target_point.distance_to(start) > 0.01 else passer.forward()
	b.pass_speed = JU.f(pc, "speed", 30.0) * float(passer.flags.get("pass_speed_mult", 1.0))
	b.pass_range_left = JU.f(pc, "range", 18.0) * float(passer.flags.get("pass_range_mult", 1.0))
	b.pierce_left = JU.i(pc, "pierce", 0)
	b.ricochets_left = int(passer.flags.get("pass_ricochets", 0))
	b.hit_ids.clear()
	b.returning = false
	b.passer_id = passer.id
	b.last_touch_id = passer.id
	b.homing_id = homing_target.id if homing_target != null else 0
	b.homing = float(passer.flags.get("pass_homing", 0.0))
	sys.world.emit("pass_released", {"ball": b.id, "actor": passer.id, "kind": kind})


func step_pass(b: SimBall, dt: float) -> void:
	var w: SimWorld = sys.world
	var passer: SimActor = w.actor_by_id(b.passer_id)
	if b.returning:
		if passer == null or not passer.alive:
			_go_loose(b, Vector3.ZERO)
			return
		var to: Vector3 = passer.pos + Vector3(0, 1.0, 0) - b.pos
		var step_len: float = JU.f(JU.dict(sys.cfg, "chest_pass"), "return_speed", 22.0) * dt
		if to.length() <= maxf(step_len, 0.6):
			if not passer.has_ball:
				sys.give(b, passer)
				w.emit("pass_returned", {"ball": b.id, "actor": passer.id})
			else:
				_go_loose(b, Vector3.ZERO)
			return
		b.pos += to.normalized() * step_len
		return
	if b.homing > 0.0 and b.homing_id != 0:
		var ht: SimActor = w.actor_by_id(b.homing_id)
		if ht != null and ht.alive:
			var want: Vector3 = (ht.center() - b.pos).normalized()
			b.pass_dir = b.pass_dir.lerp(want, clampf(b.homing * dt * 6.0, 0.0, 1.0)).normalized()
	var step: float = b.pass_speed * dt
	var a: Vector3 = b.pos
	var nxt: Vector3 = a + b.pass_dir * step
	# Wire Kicks on overhead lines.
	for wk: Dictionary in sys.wire_kicks:
		if not bool(wk["down"]) and _seg_point_dist(a, nxt, wk["pos"]) < JU.f(sys.cfg, "wire_kicks_radius", 0.7):
			wk["down"] = true
			w.emit("wire_kicks_down", {"id": wk["id"], "pos": wk["pos"], "actor": b.passer_id})
	# Actors.
	var hit: SimActor = _first_actor_hit(b, a, nxt, passer)
	if hit != null:
		b.hit_ids.append(hit.id)
		w.emit("pass_hit", {"ball": b.id, "actor": b.passer_id, "target": hit.id, "kind": b.pass_kind, "pos": b.pos})
		if b.pass_kind == "baseball_pass":
			if (hit.kind == "enemy" or hit.kind == "critter") and b.pierce_left > 0:
				b.pierce_left -= 1
			else:
				_go_loose(b, b.pass_dir * 2.0)
				return
		else:
			var next_t: SimActor = _ricochet_target(b, hit, passer) if b.ricochets_left > 0 else null
			if next_t != null:
				b.ricochets_left -= 1
				b.pos = hit.center()
				b.pass_dir = (next_t.center() - b.pos).normalized()
				b.pass_range_left = 10.0
			else:
				b.pos = hit.center()
				b.returning = true
			return
	if w.collision.segment_blocked(a, nxt) or nxt.y < w.collision.ground_height(nxt) + 0.05:
		_go_loose(b, -b.pass_dir * 3.0)
		w.emit("pass_missed", {"ball": b.id, "actor": b.passer_id})
		return
	b.pos = nxt
	b.pass_range_left -= step
	if b.pass_range_left <= 0.0:
		_go_loose(b, b.pass_dir * b.pass_speed * 0.25)
		if b.hit_ids.is_empty():
			w.emit("pass_missed", {"ball": b.id, "actor": b.passer_id})


func _first_actor_hit(b: SimBall, a: Vector3, nxt: Vector3, passer: SimActor) -> SimActor:
	var best: SimActor = null
	var best_d: float = 1e9
	var r_ball: float = JU.f(sys.cfg, "radius", 0.12)
	for o: SimActor in sys.world.actors:
		if not o.alive or o.kind == "prop" or b.hit_ids.has(o.id) or o.invulnerable:
			continue
		if passer != null and (o.id == passer.id or o.team == passer.team):
			continue
		var p2: Vector2 = Vector2(o.pos.x, o.pos.z)
		var a2: Vector2 = Vector2(a.x, a.z)
		var n2: Vector2 = Vector2(nxt.x, nxt.z)
		var seg: Vector2 = n2 - a2
		var t: float = 0.0 if seg.length_squared() < 1e-8 else clampf((p2 - a2).dot(seg) / seg.length_squared(), 0.0, 1.0)
		var closest: Vector2 = a2 + seg * t
		var y: float = lerpf(a.y, nxt.y, t)
		if closest.distance_to(p2) <= o.radius + r_ball + 0.1 and y >= o.pos.y - 0.1 and y <= o.pos.y + o.height + 0.2:
			var d: float = a2.distance_to(closest)
			if d < best_d:
				best_d = d
				best = o
	return best


func _ricochet_target(b: SimBall, from: SimActor, passer: SimActor) -> SimActor:
	var best: SimActor = null
	var bd: float = 8.0
	for o: SimActor in sys.world.actors:
		if o == from or not o.alive or b.hit_ids.has(o.id) or o.kind == "prop":
			continue
		if passer != null and o.team == passer.team:
			continue
		var d: float = o.dist_to(from)
		if d < bd:
			bd = d
			best = o
	return best


func _go_loose(b: SimBall, v: Vector3) -> void:
	b.set_state(SimBall.State.LOOSE)
	b.vel = v + Vector3(0, 1.5, 0)
	b.returning = false


static func _seg_point_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = 0.0 if ab.length_squared() < 1e-8 else clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (a + ab * t).distance_to(p)


# ------------------------------------------------------------------ lobs

func lob(b: SimBall, thrower: SimActor, target: Vector3, flight_s: float = -1.0) -> void:
	var lc: Dictionary = JU.dict(sys.cfg, "lob")
	var flat: Vector3 = target - thrower.pos
	flat.y = 0.0
	var max_r: float = JU.f(lc, "max_range_m", 16.0)
	if flat.length() > max_r:
		target = thrower.pos + flat.normalized() * max_r
	target.y = sys.world.collision.ground_height(target) + JU.f(sys.cfg, "radius", 0.12)
	var start: Vector3 = thrower.pos + Vector3(0, 1.6, 0)
	b.set_state(SimBall.State.SHOT)
	b.pos = start
	b.shot_grade = "LOB"
	b.shooter_id = thrower.id
	b.last_touch_id = thrower.id
	b.lob_damage = true
	b.flight = ShotFlight.make(start, target, JU.f(lc, "apex_m", 5.0), flight_s if flight_s > 0.0 else JU.f(lc, "time_s", 0.9))
	sys.world.emit("lob_released", {"ball": b.id, "actor": thrower.id, "target": target})


func land_lob(b: SimBall) -> void:
	var lc: Dictionary = JU.dict(sys.cfg, "lob")
	var thrower: SimActor = sys.world.actor_by_id(b.shooter_id)
	var radius: float = JU.f(lc, "radius", 2.0)
	var targets: Array[int] = []
	for o: SimActor in (sys.world.actors if b.lob_damage else [] as Array[SimActor]):
		if not o.alive or o.kind == "prop" or (thrower != null and o.team == thrower.team):
			continue
		if Vector2(o.pos.x - b.pos.x, o.pos.z - b.pos.z).length() <= radius + o.radius:
			targets.append(o.id)
	sys.world.emit("lob_landed", {"ball": b.id, "actor": b.shooter_id, "pos": b.pos, "targets": targets})
	b.set_state(SimBall.State.LOOSE)
	b.vel = b.flight.vel_at(b.flight.duration) * 0.3
	b.vel.y = 3.0
