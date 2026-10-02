class_name BagMoves
extends RefCounted
## Bag Move implementations (spec §10.7), keyed by `impl` in bag_moves.json.
## Each runs as a Hooper action "bag_<impl>" (frame data in hooper.json) and
## applies its effect from frame(). Lingering effects (Orbit, Iso, Toll Booth)
## are timed flags ticked by HooperStyle.


static func action_for(h: Hooper, impl: String) -> String:
	var id: String = "bag_" + impl
	return id if not h.move_data(id).is_empty() else "bag_generic"


static func frame(h: Hooper, impl: String, combat: CombatSystem, balls: BallSystem, mod: RefCounted) -> void:
	var a: SimActor = h.actor
	var m: Dictionary = h.action_move
	var f: int = h.action_frame
	var s: int = JU.i(m, "startup")
	var act: int = JU.i(m, "active")
	var w: SimWorld = combat.world
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
			if f > s and f <= s + act:
				a.facing = wrapf(a.facing + TAU / float(maxi(1, act)), -PI, PI)
		"hesi":
			if f == 1:
				a.flags["hesi_until"] = w.frame + int(JU.f(m, "buff_s", 1.0) * 60.0)
		"orbit":
			if f == 1:
				a.flags["orbit_until"] = w.frame + int(JU.f(m, "duration_s", 5.0) * 60.0)
		"dash_strike":
			a.invulnerable = f > s and f <= s + act
			if f > s and f <= s + act:
				a.desired_vel = h.action_dir * JU.f(m, "distance_m", 7.0) / (float(act) / 60.0)
			if f == s + 1:
				var hb: Hitbox = _circle(h, combat, m, act, 1.0)
				hb.volume = HitVolume.from_dict(JU.dict(m, "hitbox"))
				hb.volume.origin = a.pos
				hb.volume.yaw = a.facing
		"self_oop":
			if f == 1:
				h.jump(3.0)
			if f == s + 1:
				_circle(h, combat, m, act, JU.f(JU.dict(m, "hitbox"), "radius", 3.5)).knockdown_commons = true
				w.emit("screen_punch", {"actor": a.id})
		"euro_glide":
			a.invulnerable = f <= s + act
			if f <= s + act:
				var zig: Vector3 = Vector3(h.action_dir.z, 0, -h.action_dir.x) * (0.6 if f < (s + act) / 2 else -0.6)
				a.desired_vel = (h.action_dir + zig).normalized() * JU.f(m, "distance_m", 6.0) / (float(s + act) / 60.0)
		"rainbow_lob":
			if f == s + 1:
				for k: int in 3:
					var p: Vector3 = a.pos + a.forward() * (6.0 + 3.0 * float(k))
					var hb2: Hitbox = _circle(h, combat, m, 4, JU.f(JU.dict(m, "hitbox"), "radius", 2.2))
					hb2.world_space = true
					hb2.volume.origin = p
					hb2.delay = 50 + k * 10
					w.emit("telegraph_circle", {"actor": a.id, "pos": p, "radius": hb2.volume.radius, "delay_s": float(hb2.delay) / 60.0, "move": "bag_rainbow_lob"})
		"bass_drop":
			for k2: int in 3:
				if f == s + 1 + k2 * 10:
					var ring: Hitbox = _circle(h, combat, m, 60, 0.6)
					ring.volume = HitVolume.from_dict({"shape": "ring", "radius": 0.6, "width": 0.8, "height": 0.6})
					ring.volume.origin = a.pos
					ring.world_space = true
					ring.grow_per_s = 10.0
		"tunnel":
			if f == s:
				var t: SimActor = h.lock_target if h.lock_target != null else w.nearest_hostile(a, JU.f(m, "range_m", 6.0))
				if t != null and t.dist_to(a) <= JU.f(m, "range_m", 6.0) + 2.0:
					a.pos = w.collision.resolve(t.pos - t.forward() * (t.radius + 1.0), a.radius)
					a.face_dir(t.pos - a.pos)
					if t.composure != null:
						var br: String = t.composure.add(JU.f(m, "composure", 40.0), "shook")
						if br != "":
							w.emit("composure_broken", {"actor": t.id, "kind": br})
					w.emit("popup", {"text": "TUNNEL!", "pos": t.pos, "style": "style"})
		"chest_pound":
			if f == s + act:
				a.hp = minf(a.hp_max, a.hp + a.hp_max * JU.f(m, "heal_pct", 0.15))
				w.emit("healed", {"actor": a.id, "amount": a.hp_max * JU.f(m, "heal_pct", 0.15)})
		"toll_booth":
			if f == 1:
				a.flags["deflect_projectiles"] = 1
				a.flags["toll_booth_until"] = w.frame + int(JU.f(m, "duration_s", 3.0) * 60.0)
		"steam_fake":
			if f == s + 1:
				_status_area(w, a, JU.f(m, "radius", 6.0), 360.0, {"blind": JU.f(m, "blind_s", 2.0)})
		"trash_talk":
			if f == s + 1:
				_status_area(w, a, JU.f(m, "radius", 10.0), 360.0, {"trash_talked": JU.f(m, "duration_s", 15.0)})
		"showstopper":
			if f == s + 1:
				_status_area(w, a, JU.f(m, "radius", 10.0), JU.f(m, "angle", 60.0), {"frozen": JU.f(m, "freeze_s", 2.0)})
		"iso":
			if f == 1:
				a.flags["iso_until"] = w.frame + int(JU.f(m, "duration_s", 3.0) * 60.0)
				w.emit("iso_started", {"actor": a.id, "duration_s": JU.f(m, "duration_s", 3.0)})
		_:
			if f == 1:
				w.emit("bag_move_unimplemented", {"actor": a.id, "impl": impl})
	if mod != null and f == 1:
		w.emit("bag_move_used", {"actor": a.id, "impl": impl})


static func tick(h: Hooper, combat: CombatSystem) -> void:
	## Lingering Bag Move effects.
	var a: SimActor = h.actor
	var w: SimWorld = combat.world
	if w.frame < int(a.flags.get("orbit_until", -1)) and w.frame % 20 == 0:
		var m: Dictionary = h.move_data("bag_orbit")
		_circle(h, combat, m, 6, JU.f(JU.dict(m, "hitbox"), "radius", 1.8))
	a.flags["ankle_window_mult"] = 2.0 if w.frame < int(a.flags.get("iso_until", -1)) else 1.0
	if a.flags.has("toll_booth_until") and w.frame >= int(a.flags["toll_booth_until"]):
		a.flags.erase("toll_booth_until")
		a.flags["deflect_projectiles"] = 0


static func _status_area(w: SimWorld, a: SimActor, radius: float, angle_deg: float, status: Dictionary) -> void:
	for o: SimActor in w.hostiles_of(a):
		var to: Vector3 = o.pos - a.pos
		to.y = 0.0
		if to.length() > radius + o.radius:
			continue
		if angle_deg < 359.0 and to.length() > 0.1 and rad_to_deg(a.forward().angle_to(to)) > angle_deg * 0.5:
			continue
		StatusEffects.apply(o, status, 0.0)


static func _circle(h: Hooper, combat: CombatSystem, m: Dictionary, frames: int, radius: float) -> Hitbox:
	var a: SimActor = h.actor
	var hb: Hitbox = Hitbox.new()
	hb.owner_id = a.id
	hb.team = a.team
	hb.move_id = JU.s(m, "id")
	hb.volume = HitVolume.from_dict({"shape": "circle", "radius": radius, "height": JU.f(JU.dict(m, "hitbox"), "height", 1.6)})
	hb.volume.origin = a.pos
	hb.frames_left = maxi(1, frames)
	hb.damage = DamageMath.hooper_damage(m, a, HooperCombat.damage_buffs(a, m))
	hb.composure = JU.f(m, "composure")
	hb.kind = JU.s(m, "type", "ball")
	hb.weight = JU.s(m, "hit_weight", "medium")
	hb.knockdown_commons = JU.b(m, "knockdown_commons")
	hb.status = JU.dict(m, "status")
	return combat.add(hb)
