class_name SimFixture
extends RefCounted
## Test helpers: build a SimWorld with hoopers driven by ScriptedInput.


static func world(seed_value: int = 1) -> SimWorld:
	var w: SimWorld = SimWorld.new(seed_value)
	w.collision.set_bounds(Vector2(-100, -100), Vector2(100, 100))
	return w


static func hooper(w: SimWorld, pos: Vector3 = Vector3.ZERO, stats: Dictionary = {}, team: int = 0) -> Hooper:
	var a: SimActor = SimActor.new()
	a.kind = "hooper"
	a.team = team
	a.pos = pos
	a.has_ball = true
	a.stats = stats if not stats.is_empty() else JU.dict(DataDB.archetype("two_way"), "stats").duplicate()
	w.add_actor(a)
	var h: Hooper = Hooper.new(a, w)
	a.controller = h
	a.input_source = ScriptedInput.new()
	return h


static func script_of(h: Hooper) -> ScriptedInput:
	return h.actor.input_source as ScriptedInput


static func stats_with(overrides: Dictionary) -> Dictionary:
	var s: Dictionary = JU.dict(DataDB.archetype("two_way"), "stats").duplicate()
	for k: Variant in overrides.keys():
		s[k] = overrides[k]
	return s


static func with_balls(w: SimWorld) -> BallSystem:
	return BallSystem.new(w)


static func ball_hooper(w: SimWorld, sys: BallSystem, pos: Vector3 = Vector3.ZERO, stats: Dictionary = {}) -> Hooper:
	## Hooper holding a real SimBall, with the ball module attached.
	var h: Hooper = hooper(w, pos, stats)
	h.actor.has_ball = false
	var b: SimBall = sys.spawn_ball("ball_rec", pos, h.actor)
	sys.give(b, h.actor)
	h.add_module(HooperBall.new(sys))
	return h


static func dummy(w: SimWorld, pos: Vector3, kind: String = "enemy") -> SimActor:
	var a: SimActor = SimActor.new()
	a.kind = kind
	a.team = 1
	a.pos = pos
	a.hp = 500.0
	a.hp_max = 500.0
	a.radius = 0.45
	a.height = 1.8
	w.add_actor(a)
	return a


static func ball_module(h: Hooper) -> HooperBall:
	for m: RefCounted in h.modules:
		if m is HooperBall:
			return m
	return null
