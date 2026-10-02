class_name SimWorld
extends RefCounted
## Fixed-step (60 Hz) gameplay simulation. Holds actors and collision, steps
## controllers, integrates motion. Pure: no scene tree, so tests and QA bots
## can run it frame-exactly headless (spec §15.5 CombatSim).

signal sim_event(ev: Dictionary)

const DT: float = 1.0 / 60.0

var frame: int = 0
var actors: Array[SimActor] = []
var collision: WorldCollision = WorldCollision.new()
var gravity: float = 24.0
var hitstop: int = 0               # frames the whole sim is frozen (§7.14)
var events: Array[Dictionary] = [] # events emitted during the last step
var systems: Array[RefCounted] = [] # extra per-frame systems (ball, hitboxes...), each has step(world)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var attack_tokens: AttackTokenManager = null
var nav: RefCounted = null          # optional navigator with steer(from, to, dir) -> Vector3
var _next_id: int = 1


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value
	gravity = JU.f(DataDB.tuning("player"), "gravity", 24.0) if DataDB != null else 24.0


var _stepping: bool = false
var _pending_remove: Array[SimActor] = []


func add_actor(a: SimActor) -> SimActor:
	a.id = _next_id
	_next_id += 1
	actors.append(a)
	if a.home == Vector3.ZERO:
		a.home = a.pos
	return a


func remove_actor(a: SimActor) -> void:
	## Deferred while stepping so controller/system loops never skip actors.
	if _stepping:
		_pending_remove.append(a)
	else:
		actors.erase(a)


func actor_by_id(id: int) -> SimActor:
	for a: SimActor in actors:
		if a.id == id:
			return a
	return null


func dispose() -> void:
	## Breaks actor <-> controller reference cycles so RefCounted state frees.
	for a: SimActor in actors:
		a.controller = null
		a.input_source = null
	actors.clear()
	nav = null
	attack_tokens = null
	for s: RefCounted in systems:
		if s.has_method("dispose"):
			s.call("dispose")
	systems.clear()
	events.clear()
	for c: Dictionary in sim_event.get_connections():
		sim_event.disconnect(c["callable"])


func emit(type: String, data: Dictionary = {}) -> void:
	var ev: Dictionary = data.duplicate()
	ev["type"] = type
	ev["frame"] = frame
	events.append(ev)
	sim_event.emit(ev)


func step() -> void:
	_stepping = true
	_step_inner()
	_stepping = false
	for a: SimActor in _pending_remove:
		actors.erase(a)
	_pending_remove.clear()


func _step_inner() -> void:
	events.clear()
	if hitstop > 0:
		hitstop -= 1
		frame += 1
		return
	for a: SimActor in actors:
		a.input.frame = frame
		if a.input_source != null:
			a.input_source.fill(a.input, a, self)
	for a: SimActor in actors:
		if a.controller != null and a.controller.has_method("step"):
			a.controller.call("step")
	for a: SimActor in actors:
		integrate(a)
	separate_bodies()
	for s: RefCounted in systems:
		s.call("step", self)
	frame += 1


func step_n(n: int) -> void:
	for _i: int in n:
		step()


func integrate(a: SimActor) -> void:
	a.landed = false
	a.vel.x = a.desired_vel.x
	a.vel.z = a.desired_vel.z
	var ground: float = collision.ground_height(a.pos)
	if a.on_ground and a.vel.y <= 0.0:
		a.vel.y = 0.0
	else:
		a.vel.y -= gravity * a.gravity_scale * DT
	var next: Vector3 = a.pos + a.vel * DT
	next = collision.resolve(next, a.radius)
	ground = collision.ground_height(next)
	if next.y <= ground and a.vel.y <= 0.0:
		if not a.on_ground:
			a.landed = true
		next.y = ground
		a.vel.y = 0.0
		a.on_ground = true
		a.frames_since_ground = 0
	elif next.y > ground + 0.01:
		if a.on_ground and a.vel.y <= 0.0 and next.y - ground <= WorldCollision.STEP_HEIGHT:
			next.y = ground  # walking down a curb/step
		else:
			a.on_ground = false
	if not a.on_ground:
		a.frames_since_ground += 1
	a.ground_y = ground
	a.pos = next


func separate_bodies() -> void:
	## Pushes overlapping bodies apart (spec: commons and bosses are solid).
	## Heavier bodies move less; props and ghosts (flag "ghost") are ignored.
	var n: int = actors.size()
	for i: int in n:
		var a: SimActor = actors[i]
		if not a.alive or a.kind == "prop" or bool(a.flags.get("ghost", false)):
			continue
		for j: int in range(i + 1, n):
			var b: SimActor = actors[j]
			if not b.alive or b.kind == "prop" or bool(b.flags.get("ghost", false)):
				continue
			if absf(a.pos.y - b.pos.y) > maxf(a.height, b.height):
				continue
			var d: Vector2 = Vector2(b.pos.x - a.pos.x, b.pos.z - a.pos.z)
			var min_d: float = a.radius + b.radius
			var dist: float = d.length()
			if dist >= min_d:
				continue
			var nrm: Vector2 = d / dist if dist > 0.0001 else Vector2(1, 0)
			var ma: float = _mass(a)
			var mb: float = _mass(b)
			var push: float = min_d - dist
			var fa: float = mb / (ma + mb)
			a.pos -= Vector3(nrm.x, 0, nrm.y) * push * fa
			b.pos += Vector3(nrm.x, 0, nrm.y) * push * (1.0 - fa)
			a.pos = collision.resolve(a.pos, a.radius)
			b.pos = collision.resolve(b.pos, b.radius)


static func _mass(a: SimActor) -> float:
	if a.kind == "boss":
		return 1000.0
	return float(a.flags.get("mass", 1.0 + a.radius))


func hostiles_of(a: SimActor) -> Array[SimActor]:
	var out: Array[SimActor] = []
	for o: SimActor in actors:
		if o != a and o.alive and o.team != a.team and o.kind != "prop":
			out.append(o)
	return out


func nearest_hostile(a: SimActor, max_dist: float = 1e9) -> SimActor:
	var best: SimActor = null
	var bd: float = max_dist
	for o: SimActor in hostiles_of(a):
		var d: float = a.dist_to(o)
		if d < bd:
			bd = d
			best = o
	return best
