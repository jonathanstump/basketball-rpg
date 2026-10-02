class_name EnemySpawner
extends RefCounted
## Owns a scene's spawn records (spec §8.5): spawns enemies with tier,
## respawns commons on rest (never Crew Captains, Bootlegs or challengers),
## handles summons and the Hype Man's boombox, and computes rewards on death.

var world: SimWorld
var combat: CombatSystem
var balls: BallSystem
var records: Array[Dictionary] = []   # {enemy, pos, tier, opts, actor_id, respawns}
var summoned: Dictionary = {}         # actor id -> summoner id


func _init(w: SimWorld, c: CombatSystem, b: BallSystem) -> void:
	world = w
	combat = c
	balls = b
	w.sim_event.connect(_on_event)


func add(enemy_id: String, pos: Vector3, tier: int, opts: Dictionary = {}) -> SimActor:
	var kind: String = JU.s(EnemyFactory.def(enemy_id), "kind")
	var rec: Dictionary = {"enemy": enemy_id, "pos": pos, "tier": tier, "opts": opts, "actor_id": 0,
		"respawns": not bool(opts.get("captain", false)) and kind != "elite" and not bool(opts.get("no_respawn", false))}
	records.append(rec)
	return _spawn(rec)


func _spawn(rec: Dictionary) -> SimActor:
	var a: SimActor = EnemyFactory.spawn(world, combat, balls, str(rec["enemy"]), rec["pos"], int(rec["tier"]), rec["opts"])
	if a == null:
		return null
	rec["actor_id"] = a.id
	if JU.b(EnemyFactory.def(str(rec["enemy"])), "boombox"):
		var box: SimActor = EnemyFactory.spawn(world, combat, balls, "boombox", a.pos + Vector3(0.6, 0, 0), int(rec["tier"]))
		a.flags["boombox_id"] = box.id
		box.flags["owner_id"] = a.id
		world.emit("enemy_spawned", {"actor": box.id, "enemy": "boombox"})
	world.emit("enemy_spawned", {"actor": a.id, "enemy": rec["enemy"]})
	return a


func actor_of(rec: Dictionary) -> SimActor:
	return world.actor_by_id(int(rec["actor_id"]))


func respawn_commons() -> int:
	## Rest at a bodega: every respawnable dead (or missing) enemy comes back.
	var n: int = 0
	for rec: Dictionary in records:
		var a: SimActor = actor_of(rec)
		if a != null and a.alive:
			a.pos = rec["pos"]
			a.hp = a.hp_max
			var br: EnemyBrain = a.controller as EnemyBrain
			if br != null:
				br.set_state("idle")
			continue
		if not bool(rec["respawns"]):
			continue
		if a != null:
			world.remove_actor(a)
		_spawn(rec)
		n += 1
	world.attack_tokens = null
	return n


func alive_count() -> int:
	var n: int = 0
	for rec: Dictionary in records:
		var a: SimActor = actor_of(rec)
		if a != null and a.alive:
			n += 1
	return n


func _on_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"summon":
			var who: SimActor = world.actor_by_id(int(ev["actor"]))
			if who == null:
				return
			for i: int in int(ev.get("count", 1)):
				var off: Vector3 = Vector3(world.rng.randf_range(-2.5, 2.5), 0, world.rng.randf_range(-2.5, 2.5))
				var s: SimActor = EnemyFactory.spawn(world, combat, balls, str(ev["archetype"]), who.pos + off, who.tier)
				if s != null:
					summoned[s.id] = who.id
					(s.controller as EnemyBrain).alert((who.controller as EnemyBrain).target if who.controller is EnemyBrain else null)
					world.emit("enemy_spawned", {"actor": s.id, "enemy": ev["archetype"], "summoned": true})
		"tokens_snatched":
			var gull: SimActor = world.actor_by_id(int(ev["actor"]))
			var amount: int = int(floor(float(GameState.tokens) * float(ev["pct"])))
			if gull != null and amount > 0:
				GameState.add_tokens(-amount)
				gull.flags["snatched_tokens"] = int(gull.flags.get("snatched_tokens", 0)) + amount
		"pickpocket_escaped":
			# Lost & found (spec §7.9): the ball waits at the nearest bodega; fight on with a spare.
			var home: int = int(ev.get("home", 0))
			GameState.set_flag("lost_and_found", GameState.current_district)
			if home != 0:
				balls.queue_spare(home, 0.5)
		"actor_killed":
			var id: int = int(ev["actor"])
			var a: SimActor = world.actor_by_id(id)
			if a == null or a.team == 0:
				return
			_scatter_summons(id)
			if a.flags.has("owner_id"):
				return
			world.emit("enemy_defeated", EnemyRewards.compute(a, world.rng))


func _scatter_summons(summoner_id: int) -> void:
	for sid: Variant in summoned.keys():
		if int(summoned[sid]) == summoner_id:
			var s: SimActor = world.actor_by_id(int(sid))
			if s != null and s.alive:
				var br: EnemyBrain = s.controller as EnemyBrain
				if br != null:
					br.set_state("flee")
				s.flags["despawn_in"] = 90
				s.alive = false
				world.emit("summon_scattered", {"actor": s.id})
