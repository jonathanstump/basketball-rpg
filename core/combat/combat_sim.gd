class_name CombatSim
extends RefCounted
## Headless, deterministic combat harness (spec §15.5): a SimWorld with ball
## and combat systems; spawns fully-equipped hoopers and steps frames without
## rendering. Used by unit tests, boss sims and QA bots.

var world: SimWorld
var balls: BallSystem
var combat: CombatSystem
var spawner: EnemySpawner
var events: Array[Dictionary] = []


func _init(seed_value: int = 1) -> void:
	world = SimWorld.new(seed_value)
	world.collision.set_bounds(Vector2(-200, -200), Vector2(200, 200))
	balls = BallSystem.new(world)
	combat = CombatSystem.new(world, balls)
	spawner = EnemySpawner.new(world, combat, balls)
	world.sim_event.connect(func(ev: Dictionary) -> void: events.append(ev))


static func equip_hooper(w: SimWorld, b: BallSystem, c: CombatSystem, a: SimActor, ball_item: String = "ball_rec", with_ball: bool = true) -> Hooper:
	## Gives an actor the full shared Hooper (§15.5): ball, combat and style
	## modules. Used for the player, Pickup Challengers, Deuce, Pops, Midnight P1.
	var h: Hooper = Hooper.new(a, w)
	a.controller = h
	h.add_module(HooperStyle.new(c, b, a))
	h.add_module(HooperCombat.new(c, b))
	h.add_module(HooperBall.new(b))
	BallProps.apply(a, ball_item)
	var qw: Dictionary = JU.dict(DataDB.tuning("player"), "quarter_water")
	a.flags["qw"] = JU.i(qw, "start_charges", 3)
	a.flags["qw_heal_pct"] = JU.f(qw, "heal_pct", 0.35)
	if with_ball:
		b.give(b.spawn_ball(ball_item, a.pos, a), a)
	return h


func hooper(pos: Vector3 = Vector3.ZERO, stats: Dictionary = {}, with_ball: bool = true, team: int = 0) -> Hooper:
	var a: SimActor = SimActor.new()
	a.kind = "hooper"
	a.team = team
	a.pos = pos
	a.stats = stats if not stats.is_empty() else JU.dict(DataDB.archetype("two_way"), "stats").duplicate()
	world.add_actor(a)
	var h: Hooper = equip_hooper(world, balls, combat, a, "ball_rec", with_ball)
	a.input_source = ScriptedInput.new()
	return h


func dummy(pos: Vector3, mode: String = "passive") -> TrainingDummy:
	return TrainingDummy.spawn(world, combat, pos, mode)


func enemy(id: String, pos: Vector3, tier: int = 1, opts: Dictionary = {}) -> SimActor:
	return spawner.add(id, pos, tier, opts)


func brain(a: SimActor) -> EnemyBrain:
	return a.controller as EnemyBrain


func run(frames: int) -> void:
	world.step_n(frames)


func count(type: String) -> int:
	var n: int = 0
	for e: Dictionary in events:
		if str(e["type"]) == type:
			n += 1
	return n


func last(type: String) -> Dictionary:
	for i: int in range(events.size() - 1, -1, -1):
		if str(events[i]["type"]) == type:
			return events[i]
	return {}


func results() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for e: Dictionary in events:
		if str(e["type"]) == "hit_resolved":
			out.append(str(e["result"]))
	return out


func dispose() -> void:
	world.dispose()
