class_name BossSplit
extends RefCounted
## A boss that splits into parts with shared HP (The Express's Decouple,
## The General's Dismount): each part runs one move on a timer; damage to a
## part comes off the boss.

var brain: BossBrain
var world: SimWorld
var parts: Array[SimActor] = []


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world


func spawn(count: int, move_id: String, archetype: String, size: Vector2, look_scale: float = 0.8) -> void:
	var a: SimActor = brain.actor
	var m: Dictionary = DataDB.move(JU.s(brain.boss, "id"), move_id)
	for i: int in count:
		var c: SimActor = SimActor.new()
		c.kind = "boss_part"
		c.archetype = archetype
		c.display_name = a.display_name
		c.team = a.team
		c.tier = a.tier
		c.radius = size.x
		c.height = size.y
		c.hp_max = 99999.0
		c.hp = c.hp_max
		c.poise = 9999.0
		c.hyper_armor = true
		c.flags["cannot_die"] = true
		c.flags["speed"] = 3.5
		c.flags["base_damage"] = 40.0
		c.flags["look_scale"] = look_scale
		var ang: float = TAU * float(i + 1) / float(count + 1)
		c.pos = world.collision.resolve(a.pos + Vector3(cos(ang) * 4.0, 0, 3.0 + sin(ang)), c.radius)
		world.add_actor(c)
		c.controller = PartBrain.new(c, world, brain, m, 2.0 + 1.5 * float(i))
		parts.append(c)
		world.emit("car_decoupled", {"actor": c.id, "boss": a.id})


func on_hit(ev: Dictionary) -> bool:
	## Returns true when the hit landed on one of the parts.
	var t: SimActor = world.actor_by_id(int(ev["target"]))
	if t == null or not parts.has(t) or float(ev.get("damage", 0.0)) <= 0.0:
		return false
	brain.combat.damage.apply_raw(brain.actor, float(ev["damage"]))
	t.hp = t.hp_max
	world.emit("car_hit", {"actor": t.id, "boss": brain.actor.id, "damage": ev["damage"]})
	return true


func sync() -> void:
	for c: SimActor in parts:
		c.flags["shook_mirror"] = brain.actor.is_broken()


func clear() -> void:
	for c: SimActor in parts:
		c.alive = false
		world.emit("car_removed", {"actor": c.id})
		world.remove_actor(c)
	parts.clear()


class PartBrain:
	extends RefCounted
	## A split-off part: faces the target and runs its move on a timer.
	var actor: SimActor
	var world: SimWorld
	var runner: MoveRunner
	var move: Dictionary
	var cooldown_s: float

	func _init(a: SimActor, w: SimWorld, b: BossBrain, m: Dictionary, delay_s: float) -> void:
		actor = a
		world = w
		move = m
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
		if t == null or move.is_empty():
			return
		actor.turn_toward(t.pos - actor.pos, 0.1)
		if cooldown_s <= 0.0:
			cooldown_s = 4.0
			runner.start(move, t)
