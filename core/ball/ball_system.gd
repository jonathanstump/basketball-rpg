class_name BallSystem
extends RefCounted
## Every ball and hoop in a SimWorld (spec §15.6, §7.6, §7.9). Registered as a
## world system so it steps after actors move. Outcomes are events; combat
## (M3) and duels (M5) react to them.

const DT: float = 1.0 / 60.0

var world: SimWorld
var cfg: Dictionary = {}
var balls: Array[SimBall] = []
var hoops: Array[SimHoop] = []
var wire_kicks: Array[Dictionary] = []   # {id, pos, down}
var passes: BallPasses
var return_on_make: bool = true          # streets: a make comes back to the shooter
var bucket_blasts_enabled: bool = true
var _next_id: int = 1
var _pending_spares: Array[Dictionary] = []  # {actor, t}


func _init(w: SimWorld) -> void:
	world = w
	cfg = DataDB.tuning("ball")
	passes = BallPasses.new(self)
	w.systems.append(self)


func dispose() -> void:
	passes = null
	balls.clear()
	hoops.clear()


# ------------------------------------------------------------ registry

func spawn_ball(item_id: String, pos: Vector3, home: SimActor = null) -> SimBall:
	var b: SimBall = SimBall.new()
	b.id = _next_id
	_next_id += 1
	b.item_id = item_id
	b.pos = pos
	b.home_id = home.id if home != null else 0
	b.set_state(SimBall.State.LOOSE)
	balls.append(b)
	return b


func give(b: SimBall, a: SimActor) -> void:
	if a.has_ball:
		return
	b.set_state(SimBall.State.HELD)
	b.holder_id = a.id
	b.last_touch_id = a.id
	b.vel = Vector3.ZERO
	a.has_ball = true
	a.flags["ball_item"] = b.item_id


func take_from(a: SimActor) -> SimBall:
	## Removes the held ball from an actor (it stays at the hand position).
	var b: SimBall = ball_of(a)
	if b != null:
		b.set_state(SimBall.State.LOOSE)
	a.has_ball = false
	return b


func ball_of(a: SimActor) -> SimBall:
	for b: SimBall in balls:
		if b.state == SimBall.State.HELD and b.holder_id == a.id:
			return b
	return null


func add_hoop(h: SimHoop) -> SimHoop:
	hoops.append(h)
	return h


func hoop_by_id(id: String) -> SimHoop:
	for h: SimHoop in hoops:
		if h.id == id:
			return h
	return null


func add_wire_kicks(id: String, pos: Vector3) -> void:
	wire_kicks.append({"id": id, "pos": pos, "down": false})


func hoop_in_range(a: SimActor) -> SimHoop:
	var best: SimHoop = null
	var bd: float = JU.f(JU.dict(cfg, "shot"), "max_range_m", 11.5)
	for h: SimHoop in hoops:
		if not h.enabled:
			continue
		var d: float = h.flat_distance(a.pos)
		if d <= bd:
			bd = d
			best = h
	return best


func in_combat(a: SimActor, radius: float = 20.0) -> bool:
	for o: SimActor in world.actors:
		if o.alive and o.team != a.team and (o.kind == "enemy" or o.kind == "boss") and o.dist_to(a) <= radius:
			return true
	return false


# ------------------------------------------------------------ actions

func pass_ball(a: SimActor, kind: String, target_point: Vector3, homing_target: SimActor = null) -> SimBall:
	var b: SimBall = ball_of(a)
	if b == null:
		return null
	a.has_ball = false
	passes.launch(b, a, kind, target_point, homing_target)
	return b


func lob_ball(a: SimActor, target: Vector3) -> SimBall:
	var b: SimBall = ball_of(a)
	if b == null:
		return null
	a.has_ball = false
	passes.lob(b, a, target)
	return b


func shoot(a: SimActor, hoop: SimHoop, grade: String, zone: String, blocker: SimActor = null) -> SimBall:
	var b: SimBall = ball_of(a)
	if b == null:
		return null
	a.has_ball = false
	var sc: Dictionary = JU.dict(cfg, "shot")
	var start: Vector3 = a.pos + Vector3(0, JU.f(sc, "release_height", 2.0), 0) + a.forward() * 0.3
	b.set_state(SimBall.State.SHOT)
	b.pos = start
	b.shot_grade = grade
	b.shot_zone = zone
	b.shot_hoop = hoop.id
	b.shooter_id = a.id
	b.last_touch_id = a.id
	b.lob_damage = false
	b.blocker_id = blocker.id if blocker != null else 0
	var dist: float = hoop.flat_distance(a.pos)
	var dur: float = JU.f(sc, "flight_min_s", 0.55) + dist * JU.f(sc, "flight_per_m", 0.05)
	var apex: float = JU.f(sc, "apex_extra_m", 1.8) + dist * 0.08
	var end: Vector3 = hoop.rim + Vector3(0, 0.05, 0)
	match grade:
		ShotResolver.GOOD:
			end = hoop.rim + hoop.facing * (hoop.radius * 0.4) + Vector3(0, 0.08, 0)
		ShotResolver.NEAR_MISS:
			end = hoop.rim + hoop.facing * (hoop.radius + 0.06) + Vector3(0, 0.12, 0)
		ShotResolver.BRICK:
			var short: bool = (a.id + world.frame) % 3 == 0
			end = hoop.rim + hoop.facing * (0.9 if short else -0.32) + Vector3(0, -0.6 if short else 0.35, 0)
		ShotResolver.REJECTED:
			end = start + a.forward() * 0.9 + Vector3(0, 0.6, 0)
			dur = JU.f(sc, "reject_flight_s", 0.15)
			apex = 0.2
	b.flight = ShotFlight.make(start, end, apex, dur)
	world.emit("shot_released", {"ball": b.id, "actor": a.id, "grade": grade, "zone": zone, "hoop": hoop.id})
	return b


func dunk(a: SimActor, hoop: SimHoop) -> SimBall:
	## Scripted dunk finish: straight into the net, scored as a make.
	var b: SimBall = ball_of(a)
	if b == null:
		return null
	a.has_ball = false
	b.set_state(SimBall.State.IN_NET)
	b.pos = hoop.rim
	b.vel = Vector3(0, -3.0, 0)
	b.shot_grade = "DUNK"
	b.shot_zone = "dunk"
	b.shot_hoop = hoop.id
	b.shooter_id = a.id
	b.last_touch_id = a.id
	world.emit("shot_released", {"ball": b.id, "actor": a.id, "grade": "DUNK", "zone": "dunk", "hoop": hoop.id})
	_on_make(b, hoop, a)
	return b


# ------------------------------------------------------------ stepping

func step(_w: SimWorld) -> void:
	for h: SimHoop in hoops:
		if h.cooldown_s > 0.0:
			h.cooldown_s = maxf(0.0, h.cooldown_s - DT)
	for b: SimBall in balls.duplicate():
		b.state_time += DT
		match b.state:
			SimBall.State.HELD:
				_step_held(b)
			SimBall.State.PASS:
				passes.step_pass(b, DT)
			SimBall.State.SHOT:
				_step_shot(b)
			SimBall.State.IN_NET:
				_step_in_net(b)
			SimBall.State.LOOSE:
				BallPhysics.step_loose(b, world.collision, hoops, cfg, DT)
				b.loose_time += DT
				_check_lost(b)
				if b.state == SimBall.State.LOOSE:
					_try_pickup(b)
	_step_spares()
	balls = balls.filter(func(x: SimBall) -> bool: return x.state != SimBall.State.DEAD)


func _step_held(b: SimBall) -> void:
	var a: SimActor = world.actor_by_id(b.holder_id)
	if a == null or not a.alive:
		b.set_state(SimBall.State.LOOSE)
		b.vel = Vector3(0, 2.0, 0)
		if a != null:
			a.has_ball = false
		return
	var phase: float = float(world.frame) * 0.25
	b.pos = a.pos + a.right() * 0.28 + a.forward() * 0.15 + Vector3(0, 0.12 + absf(cos(phase)) * 0.75, 0)


func _step_shot(b: SimBall) -> void:
	var done: bool = b.flight.advance(DT)
	b.pos = b.flight.current()
	if not done:
		return
	if b.shot_grade == "LOB":
		passes.land_lob(b)
		return
	var hoop: SimHoop = hoop_by_id(b.shot_hoop)
	var shooter: SimActor = world.actor_by_id(b.shooter_id)
	match b.shot_grade:
		ShotResolver.PERFECT, ShotResolver.GOOD:
			b.set_state(SimBall.State.IN_NET)
			b.pos = hoop.rim
			b.vel = Vector3(0, -2.5, 0)
			_on_make(b, hoop, shooter)
		ShotResolver.REJECTED:
			var blocker: SimActor = world.actor_by_id(b.blocker_id)
			world.emit("shot_rejected", {"ball": b.id, "actor": b.shooter_id, "blocker": b.blocker_id})
			if blocker != null and blocker.alive and not blocker.has_ball:
				give(b, blocker)
			else:
				b.set_state(SimBall.State.LOOSE)
				b.vel = -(shooter.forward() if shooter != null else Vector3.FORWARD) * 5.0 + Vector3(0, 3, 0)
		_:
			b.set_state(SimBall.State.LOOSE)
			var out: Vector3 = hoop.facing if hoop != null else Vector3.BACK
			var side: Vector3 = Vector3(out.z, 0, -out.x) * (0.8 if (b.id + world.frame) % 2 == 0 else -0.8)
			b.vel = (out * 2.5 + side + Vector3(0, 3.5, 0)) if b.shot_grade == ShotResolver.NEAR_MISS else (out * 4.0 + side * 1.5 + Vector3(0, 2.0, 0))
			var apex_t: float = b.vel.y / JU.f(cfg, "gravity", 14.0)
			var rebound: Vector3 = b.pos + Vector3(b.vel.x, 0, b.vel.z) * apex_t + Vector3(0, b.vel.y * apex_t * 0.5, 0)
			world.emit("shot_missed", {"ball": b.id, "actor": b.shooter_id, "grade": b.shot_grade, "hoop": b.shot_hoop, "rebound_pos": rebound, "rebound_t": apex_t})


func _on_make(b: SimBall, hoop: SimHoop, shooter: SimActor) -> void:
	var ev: Dictionary = {"ball": b.id, "actor": b.shooter_id, "grade": b.shot_grade, "zone": b.shot_zone, "hoop": hoop.id, "hoop_kind": hoop.kind, "net": hoop.net}
	world.emit("shot_made", ev)
	if hoop.kind != "crate" or shooter == null:
		return
	if in_combat(shooter):
		if bucket_blasts_enabled and hoop.is_ready():
			fire_bucket_blast(hoop, shooter)
	elif not hoop.first_make_paid:
		hoop.first_make_paid = true
		var tokens: int = int(JU.f(DataDB.tuning("economy"), "crate_hoop_tokens", 25.0) * float(hoop.tier))
		world.emit("crate_first_make", {"hoop": hoop.id, "actor": shooter.id, "tokens": tokens})


func fire_bucket_blast(hoop: SimHoop, shooter: SimActor) -> Array[int]:
	var bb: Dictionary = JU.dict(DataDB.tuning("combat"), "bucket_blast")
	var radius: float = JU.f(bb, "radius_m", 6.0) * float(shooter.flags.get("bucket_blast_radius_mult", 1.0))
	var targets: Array[int] = BucketBlast.targets(world, hoop.floor_point(), radius, shooter.team)
	hoop.cooldown_s = JU.f(bb, "cooldown_s", 20.0)
	world.emit("bucket_blast", {"hoop": hoop.id, "actor": shooter.id, "pos": hoop.floor_point(), "radius": radius, "targets": targets,
		"damage": JU.f(bb, "damage", 60.0), "composure": JU.f(bb, "composure", 40.0)})
	return targets


func _step_in_net(b: SimBall) -> void:
	b.pos += b.vel * DT
	if b.state_time < JU.f(JU.dict(cfg, "shot"), "in_net_s", 0.35):
		return
	var shooter: SimActor = world.actor_by_id(b.shooter_id)
	if return_on_make and shooter != null and shooter.alive and not shooter.has_ball:
		give(b, shooter)
		world.emit("ball_returned", {"ball": b.id, "actor": shooter.id})
	else:
		b.set_state(SimBall.State.LOOSE)
		b.vel = Vector3(0, -1.0, 0)


func _try_pickup(b: SimBall) -> void:
	if b.state_time < 0.12:
		return
	var best: SimActor = null
	var best_slack: float = 0.0
	var base_r: float = JU.f(cfg, "pickup_radius", 0.75)
	for a: SimActor in world.actors:
		if not a.alive or a.has_ball or a.kind == "prop" or a.kind == "critter" or bool(a.flags.get("no_pickup", false)):
			continue
		if b.pos.y - a.pos.y > JU.f(cfg, "pickup_max_height", 1.7) + float(a.flags.get("pickup_reach", 0.0)):
			continue
		var d: float = Vector2(a.pos.x - b.pos.x, a.pos.z - b.pos.z).length()
		var slack: float = base_r + float(a.flags.get("pickup_bonus", 0.0)) - d
		if slack > best_slack:
			best_slack = slack
			best = a
	if best != null:
		give(b, best)
		best.flags["disarmed"] = false
		world.emit("ball_picked", {"ball": b.id, "actor": best.id})


func _check_lost(b: SimBall) -> void:
	var reason: String = ""
	if world.collision.in_water(b.pos):
		reason = "water"
	elif world.collision.out_of_bounds(b.pos) or b.pos.y < -20.0:
		reason = "out_of_bounds"
	elif b.loose_time > JU.f(cfg, "lost_ball_s", 10.0):
		var home: SimActor = world.actor_by_id(b.home_id)
		if home != null and not home.has_ball:
			reason = "unreachable"
	if reason == "":
		return
	b.set_state(SimBall.State.DEAD)
	world.emit("ball_lost", {"ball": b.id, "reason": reason, "home": b.home_id})
	if b.home_id != 0:
		_pending_spares.append({"actor": b.home_id, "t": 0.0 if reason == "unreachable" else JU.f(cfg, "oob_respawn_s", 1.0)})


func _step_spares() -> void:
	for s: Dictionary in _pending_spares.duplicate():
		s["t"] = float(s["t"]) - DT
		if float(s["t"]) > 0.0:
			continue
		_pending_spares.erase(s)
		var a: SimActor = world.actor_by_id(int(s["actor"]))
		if a != null and a.alive and not a.has_ball:
			var spare: SimBall = spawn_ball(JU.s(cfg, "spare_ball", "ball_rec"), a.pos, a)
			give(spare, a)
			world.emit("spare_ball", {"ball": spare.id, "actor": a.id})
