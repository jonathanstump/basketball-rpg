class_name CombatSystem
extends RefCounted
## World system holding active hitboxes (spec §15.5). Each frame: move/follow
## hitboxes, test them against hurtboxes, resolve through DamageService, tick
## composure/hype/status. Ball events (pass hits, lob splashes, Bucket
## Blasts) are converted into hits here so every hit uses one pipeline.

const DT: float = 1.0 / 60.0

var world: SimWorld
var balls: BallSystem
var damage: DamageService
var hitboxes: Array[Hitbox] = []


func _init(w: SimWorld, b: BallSystem) -> void:
	world = w
	balls = b
	damage = DamageService.new(w, b)
	w.systems.append(self)
	w.sim_event.connect(_on_event)


func dispose() -> void:
	hitboxes.clear()
	damage = null
	balls = null


func add(hb: Hitbox) -> Hitbox:
	hitboxes.append(hb)
	return hb


func clear_owner(owner_id: int) -> void:
	hitboxes = hitboxes.filter(func(h: Hitbox) -> bool: return h.owner_id != owner_id or h.world_space)


func step(_w: SimWorld) -> void:
	for hb: Hitbox in hitboxes.duplicate():
		if hb.delay > 0:
			hb.delay -= 1
			continue
		_update_volume(hb)
		for t: SimActor in world.actors:
			if hb.frames_left <= 0:
				break
			if hb.can_hit(t, world.frame):
				hb.mark_hit(t, world.frame)
				damage.resolve(hb, t)
		hb.frames_left -= 1
		if hb.frames_left <= 0:
			hitboxes.erase(hb)
	for a: SimActor in world.actors:
		if not a.alive:
			continue
		if a.composure != null and a.composure.tick(DT, a.has_ball) == "recovered":
			world.emit("composure_recovered", {"actor": a.id})
		a.hype.tick(DT)
		var dot: float = StatusEffects.tick(a, DT)
		if dot > 0.0:
			damage.apply_raw(a, dot)
			if not a.alive:
				world.emit("actor_killed", {"actor": a.id, "attacker": 0, "kind": a.kind, "archetype": a.archetype})


func _update_volume(hb: Hitbox) -> void:
	if hb.world_space:
		var homing: float = float(hb.tags.get("homing", 0.0))
		if homing > 0.0 and hb.velocity.length() > 0.01:
			var ht: SimActor = world.actor_by_id(int(hb.tags.get("homing_target", 0)))
			if ht != null and ht.alive:
				var want: Vector3 = ht.center() - hb.volume.origin
				want.y = 0.0
				var sp: float = hb.velocity.length()
				hb.velocity = hb.velocity.lerp(want.normalized() * sp, clampf(homing * DT * 4.0, 0.0, 1.0)).normalized() * sp
		hb.volume.origin += hb.velocity * DT
		if hb.projectile and world.collision.blocked(hb.volume.origin, 0.2):
			hb.frames_left = 0
		hb.volume.radius += hb.grow_per_s * DT
		return
	var o: SimActor = world.actor_by_id(hb.owner_id)
	if o != null:
		hb.volume.origin = o.pos
		hb.volume.yaw = o.facing


# ------------------------------------------------------------ ball events

func _on_event(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"pass_hit":
			var kind: String = str(ev["kind"])
			_direct(int(ev["actor"]), int(ev["target"]), kind, 1.0)
		"lob_landed":
			for tid: Variant in (ev["targets"] as Array):
				_direct(int(ev["actor"]), int(tid), "lob", 1.0)
		"shot_missed":
			var shooter2: SimActor = world.actor_by_id(int(ev.get("actor", 0)))
			if shooter2 != null and float(shooter2.flags.get("brick_damage", 0.0)) > 0.0 and balls != null:
				var hp: SimHoop = balls.hoop_by_id(str(ev.get("hoop", "")))
				if hp != null:
					for o: SimActor in world.hostiles_of(shooter2):
						if o.flat_pos().distance_to(Vector2(hp.rim.x, hp.rim.z)) <= 3.0:
							damage.apply_raw(o, float(shooter2.flags["brick_damage"]))
		"ball_picked":
			var picker: SimActor = world.actor_by_id(int(ev.get("actor", 0)))
			if picker != null and bool(picker.flags.get("hustle", false)):
				picker.hype.add(5.0)
				picker.flags["hustle_until"] = world.frame + 180
		"bucket_blast":
			var shooter: SimActor = world.actor_by_id(int(ev["actor"]))
			if shooter != null:
				shooter.hype.gain("bucket_blast")
			for tid2: Variant in (ev["targets"] as Array):
				var hb: Hitbox = _packet(int(ev["actor"]), "bucket_blast")
				hb.damage = float(ev["damage"])
				hb.composure = float(ev["composure"])
				hb.knockdown_commons = true
				hb.weight = "heavy"
				var t: SimActor = world.actor_by_id(int(tid2))
				if t != null and t.alive:
					hb.hit_ids.append(t.id)
					damage.resolve(hb, t)


func _packet(owner_id: int, move_id: String) -> Hitbox:
	var hb: Hitbox = Hitbox.new()
	var o: SimActor = world.actor_by_id(owner_id)
	hb.owner_id = owner_id
	hb.team = o.team if o != null else -1
	hb.move_id = move_id
	hb.kind = "ball"
	hb.parryable = false
	hb.volume.origin = o.pos if o != null else Vector3.ZERO
	return hb


func _direct(owner_id: int, target_id: int, move_id: String, mult: float) -> void:
	var o: SimActor = world.actor_by_id(owner_id)
	var t: SimActor = world.actor_by_id(target_id)
	if o == null or t == null or not t.alive:
		return
	var hb: Hitbox = _packet(owner_id, move_id)
	if o.controller is Hooper:
		var m: Dictionary = (o.controller as Hooper).move_data(move_id)
		hb.damage = DamageMath.hooper_damage(m, o, HooperCombat.damage_buffs(o)) * mult
		hb.composure = JU.f(m, "composure")
		hb.weight = "heavy" if move_id == "baseball_pass" else "medium"
		hb.break_kind = "shook"
	else:
		hb.damage = float(o.flags.get("pass_damage", 20.0)) * mult
	damage.resolve(hb, t)
