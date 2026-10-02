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
