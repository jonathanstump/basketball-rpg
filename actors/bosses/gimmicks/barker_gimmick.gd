class_name BarkerGimmick
extends RefCounted
## The Barker (spec §9.3): mirror clones. "Step Right Up" spawns clones that
## look identical but cast no shadow; hitting one shatters it and stuns you
## 0.5 s. Shell Game (T2) shuffles the real one among the clones. Phase 2
## "Tilt": the floor tilts every 15 s and you and loose balls slide.

const DT: float = 1.0 / 60.0
const CLONE_LIFE_S: float = 14.0
const TILT_EVERY_S: float = 15.0
const TILT_FOR_S: float = 4.0
const TILT_SPEED: float = 2.2

var brain: BossBrain
var world: SimWorld
var clones: Array[SimActor] = []
var tilt_dir: Vector3 = Vector3.ZERO
var tilt_timer_s: float = TILT_EVERY_S
var tilt_left_s: float = 0.0


func _init(b: BossBrain) -> void:
	brain = b
	world = b.world
	world.sim_event.connect(_on_event)


func on_step(b: BossBrain) -> bool:
	_tick_clones()
	if b.phase >= 2:
		_tick_tilt(b)
	return false


func _on_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"mirror_requested":
			if int(ev["actor"]) == brain.actor.id:
				var m: Dictionary = DataDB.move(JU.s(brain.boss, "id"), str(ev["move"]))
				if clones.is_empty() or not JU.b(m, "shuffle"):
					spawn_clones(JU.i(m, "clones", 3))
				shuffle()
		"hit_resolved":
			var t: SimActor = world.actor_by_id(int(ev["target"]))
			if t != null and t.kind == "clone" and clones.has(t):
				shatter(t, world.actor_by_id(int(ev["attacker"])))
		"duel_phase_changed", "duel_victory", "duel_check":
			clear_clones()


func spawn_clones(n: int) -> void:
	clear_clones()
	var a: SimActor = brain.actor
	for i: int in n:
		var c: SimActor = SimActor.new()
		c.kind = "clone"
		c.archetype = a.archetype
		c.display_name = a.display_name
		c.team = a.team
		c.tier = a.tier
		c.radius = a.radius
		c.height = a.height
		c.hp_max = 1.0
		c.hp = 1.0
		c.poise = 0.0
		c.flags["speed"] = float(a.flags.get("speed", 4.0)) * 0.8
		c.flags["base_damage"] = 20.0
		c.flags["clone_until"] = world.frame + int(CLONE_LIFE_S * 60.0)
		var ang: float = TAU * float(i + 1) / float(n + 1)
		c.pos = world.collision.resolve(a.pos + Vector3(cos(ang), 0, sin(ang)) * 3.5, c.radius)
		c.facing = a.facing
		world.add_actor(c)
		c.controller = CloneBrain.new(c, world, brain)
		clones.append(c)
		world.emit("boss_clone_spawned", {"actor": c.id, "boss": a.id})


func shuffle() -> void:
	## The real one swaps places with a random clone (follow the shadow).
	if clones.is_empty():
		return
	var c: SimActor = clones[world.rng.randi() % clones.size()]
	var p: Vector3 = brain.actor.pos
	brain.actor.pos = c.pos
	c.pos = p
	world.emit("shell_game", {"actor": brain.actor.id})


func shatter(c: SimActor, attacker: SimActor) -> void:
	_remove(c)
	world.emit("clone_shattered", {"actor": c.id, "pos": c.pos})
	if attacker != null and attacker.kind == "hooper":
		StatusEffects.apply(attacker, {"rooted": 0.5})
		world.emit("popup", {"text": "WRONG ONE!", "pos": attacker.pos, "style": "bad"})


func clear_clones() -> void:
	for c: SimActor in clones.duplicate():
		_remove(c)
		world.emit("clone_shattered", {"actor": c.id, "pos": c.pos, "quiet": true})


func _remove(c: SimActor) -> void:
	c.alive = false
	c.hp = 0.0
	clones.erase(c)
	world.remove_actor(c)


func _tick_clones() -> void:
	for c: SimActor in clones.duplicate():
		if world.frame >= int(c.flags.get("clone_until", 0)) or not c.alive:
			_remove(c)
			world.emit("clone_shattered", {"actor": c.id, "pos": c.pos, "quiet": true})


func _tick_tilt(b: BossBrain) -> void:
	if tilt_left_s > 0.0:
		tilt_left_s -= DT
		var t: SimActor = b.target
		if t != null and t.on_ground:
			t.pos = world.collision.resolve(t.pos + tilt_dir * TILT_SPEED * DT, t.radius)
		for ball: SimBall in b.balls.balls:
			if ball.state == SimBall.State.LOOSE:
				ball.vel += tilt_dir * TILT_SPEED * 2.0 * DT
		if tilt_left_s <= 0.0:
			world.emit("floor_tilt", {"actor": b.actor.id, "dir": Vector3.ZERO})
		return
	tilt_timer_s -= DT
	if tilt_timer_s <= 0.0:
		tilt_timer_s = TILT_EVERY_S
		tilt_left_s = TILT_FOR_S
		var dirs: Array[Vector3] = [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
		tilt_dir = dirs[world.rng.randi() % dirs.size()]
		world.emit("floor_tilt", {"actor": b.actor.id, "dir": tilt_dir})


class CloneBrain:
	extends RefCounted
	## A mirror clone: drifts toward you and swipes. One hit shatters it.
	var actor: SimActor
	var world: SimWorld
	var runner: MoveRunner
	var cooldown_s: float = 1.0
	var swipe: Dictionary = {}

	func _init(a: SimActor, w: SimWorld, boss_brain: BossBrain) -> void:
		actor = a
		world = w
		runner = MoveRunner.new(a, w, boss_brain.combat)
		swipe = DataDB.move(JU.s(boss_brain.boss, "id"), "clone_swipe")

	func step() -> void:
		actor.desired_vel = Vector3.ZERO
		cooldown_s -= 1.0 / 60.0
		if runner.running:
			runner.step()
			return
		var t: SimActor = null
		for o: SimActor in world.actors:
			if o.alive and o.team == 0 and o.kind == "hooper":
				t = o
		if t == null:
			return
		var to: Vector3 = t.pos - actor.pos
		to.y = 0.0
		actor.turn_toward(to, 0.15)
		if to.length() < 2.4 and cooldown_s <= 0.0 and not swipe.is_empty():
			cooldown_s = 2.2
			runner.start(swipe, t)
		elif to.length() > 1.6:
			actor.desired_vel = to.normalized() * float(actor.flags.get("speed", 3.5))
			actor.anim_state = "walk"
		else:
			actor.anim_state = "idle"
