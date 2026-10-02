class_name BagMoves
extends RefCounted
## Bag Move implementations (spec §10.7), keyed by `impl` in bag_moves.json.
## Each runs as a Hooper action "bag_<impl>" (frame data in hooper.json, or a
## generic 6/12/10 action) and applies its effect from frame().


static func action_for(h: Hooper, impl: String) -> String:
	var id: String = "bag_" + impl
	return id if not h.move_data(id).is_empty() else "bag_generic"


static func frame(h: Hooper, impl: String, combat: CombatSystem, balls: BallSystem, mod: RefCounted) -> void:
	var a: SimActor = h.actor
	var m: Dictionary = h.action_move
	var f: int = h.action_frame
	var s: int = JU.i(m, "startup")
	var act: int = JU.i(m, "active")
	a.desired_vel = Vector3.ZERO
	match impl:
		"snatchback":
			if f == 1:
				a.flags["deflect_projectiles"] = 1
				if not a.has_ball:
					for b: SimBall in balls.balls:
						if (b.state == SimBall.State.LOOSE or b.state == SimBall.State.PASS) and b.pos.distance_to(a.pos) < 8.0:
							balls.give(b, a)
							break
			if f > s and f <= s + act:
				a.desired_vel = -a.forward() * JU.f(m, "distance_m", 4.0) / (float(act) / 60.0)
		"spin_cycle":
			var hits: int = JU.i(m, "hits", 3)
			var gap: int = JU.i(m, "hit_gap", 8)
			for i: int in hits:
				if f == s + 1 + i * gap:
					_circle(h, combat, m, gap, JU.f(JU.dict(m, "hitbox"), "radius", 2.0))
			a.facing = wrapf(a.facing + TAU / float(maxi(1, act)), -PI, PI) if f > s and f <= s + act else a.facing
		"hesi":
			if f == 1:
				a.flags["hesi_until"] = combat.world.frame + int(JU.f(m, "buff_s", 1.0) * 60.0)
		_:
			# TODO(spec §10.7): remaining Bag Moves land in M7.
			if f == 1:
				combat.world.emit("bag_move_unimplemented", {"actor": a.id, "impl": impl})
	if mod != null and f == 1:
		combat.world.emit("bag_move_used", {"actor": a.id, "impl": impl})


static func _circle(h: Hooper, combat: CombatSystem, m: Dictionary, frames: int, radius: float) -> Hitbox:
	var a: SimActor = h.actor
	var hb: Hitbox = Hitbox.new()
	hb.owner_id = a.id
	hb.team = a.team
	hb.move_id = JU.s(m, "id")
	hb.volume = HitVolume.from_dict({"shape": "circle", "radius": radius, "height": JU.f(JU.dict(m, "hitbox"), "height", 1.6)})
	hb.volume.origin = a.pos
	hb.frames_left = maxi(1, frames)
	hb.damage = DamageMath.hooper_damage(m, a, HooperCombat.damage_buffs(a))
	hb.composure = JU.f(m, "composure")
	hb.kind = JU.s(m, "type", "ball")
	hb.weight = JU.s(m, "hit_weight", "medium")
	hb.knockdown_commons = JU.b(m, "knockdown_commons")
	hb.status = JU.dict(m, "status")
	return combat.add(hb)
