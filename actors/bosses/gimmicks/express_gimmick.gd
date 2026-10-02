class_name ExpressGimmick
extends RefCounted
## The Express (spec §9.3): Phase 2 "Decouple" — two rear cars break off and
## attack on their own. Shared HP: damage to a car comes off the Express.
## T5 "Rush Hour Crowd": commuter silhouettes fill lanes (block movement only).

const CROWD_S: float = 12.0

var brain: BossBrain
var world: SimWorld
var cars: Array[SimActor] = []
var crowd_until: int = -1


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	world.sim_event.connect(_on_event)


func on_step(b: BossBrain) -> bool:
	if crowd_until >= 0 and world.frame >= crowd_until:
		crowd_until = -1
		world.collision.remove_tag("crowd")
		world.emit("crowd_cleared", {"actor": b.actor.id})
	for c: SimActor in cars:
		c.flags["shook_mirror"] = b.actor.is_broken()
	return false


func _on_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"duel_phase_changed":
			if int(ev.get("phase", 1)) >= 2 and cars.is_empty():
				decouple()
		"hit_resolved":
			var t: SimActor = world.actor_by_id(int(ev["target"]))
			if t != null and cars.has(t) and float(ev.get("damage", 0.0)) > 0.0:
				brain.combat.damage.apply_raw(brain.actor, float(ev["damage"]))
				t.hp = t.hp_max
				world.emit("car_hit", {"actor": t.id, "boss": brain.actor.id, "damage": ev["damage"]})
		"arena_event":
			if int(ev["actor"]) == brain.actor.id and str(ev["event"]) == "rush_hour_crowd":
				crowd()
		"duel_victory":
			for c: SimActor in cars:
				c.alive = false
				world.emit("car_removed", {"actor": c.id})
				world.remove_actor(c)
			cars.clear()


func decouple() -> void:
	var a: SimActor = brain.actor
	var charge: Dictionary = DataDB.move(JU.s(brain.boss, "id"), "car_charge")
	for i: int in 2:
		var c: SimActor = SimActor.new()
		c.kind = "boss_part"
		c.archetype = "express_car"
		c.display_name = "Express Car"
		c.team = a.team
		c.tier = a.tier
		c.radius = 1.0
		c.height = 3.0
		c.hp_max = 99999.0
		c.hp = c.hp_max
		c.poise = 9999.0
		c.hyper_armor = true
		c.flags["cannot_die"] = true
		c.flags["speed"] = 3.5
		c.flags["base_damage"] = 40.0
		c.pos = world.collision.resolve(a.pos + Vector3(-4.0 + 8.0 * float(i), 0, 3.0), c.radius)
		world.add_actor(c)
		c.controller = CarBrain.new(c, world, brain, charge, 2.5 + 1.5 * float(i))
		cars.append(c)
		world.emit("car_decoupled", {"actor": c.id, "boss": a.id})


func crowd() -> void:
	## Commuters stand in two lanes across the court for a while.
	world.collision.remove_tag("crowd")
	var half: Vector2 = Vector2(JU.a(JU.dict(brain.boss, "arena"), "size_m")[0], JU.a(JU.dict(brain.boss, "arena"), "size_m")[1]) * 0.5
	for lane: float in [-half.x * 0.5, half.x * 0.5]:
		for k: int in 4:
			var z: float = -half.y * 0.6 + float(k) * half.y * 0.45
			world.collision.add_block(Vector2(lane - 0.4, z - 0.4), Vector2(lane + 0.4, z + 0.4), 1.9, "crowd")
			world.emit("commuter", {"pos": Vector3(lane, 0, z)})
	crowd_until = world.frame + int(CROWD_S * 60.0)


class CarBrain:
	extends RefCounted
	## A decoupled car: lines up on the target's lane and charges.
	var actor: SimActor
	var world: SimWorld
	var runner: MoveRunner
	var charge: Dictionary
	var cooldown_s: float

	func _init(a: SimActor, w: SimWorld, b: BossBrain, m: Dictionary, delay_s: float) -> void:
		actor = a
		world = w
		charge = m
		cooldown_s = delay_s
		runner = MoveRunner.new(a, w, b.combat)

	func step() -> void:
		actor.desired_vel = Vector3.ZERO
		if bool(actor.flags.get("shook_mirror", false)):
			runner.interrupt()
			return
		cooldown_s -= 1.0 / 60.0
		if runner.running:
			runner.step()
			return
		var t: SimActor = null
		for o: SimActor in world.actors:
			if o.alive and o.team == 0 and o.kind == "hooper":
				t = o
		if t == null or charge.is_empty():
			return
		actor.turn_toward(t.pos - actor.pos, 0.1)
		if cooldown_s <= 0.0:
			cooldown_s = 4.0
			runner.start(charge, t)
