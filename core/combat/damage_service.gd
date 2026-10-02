class_name DamageService
extends RefCounted
## Hit resolution pipeline (spec §15.5): i-frames (Ankle Breaker / Read) ->
## Rejection -> parry window (STRIP vs ball attacks, DEFLECT vs body attacks)
## -> guard -> damage formula (§7.12) -> poise/flinch -> composure -> status
## -> events -> hitstop. Unblockables skip parry and guard.

var world: SimWorld
var balls: BallSystem
var hitstop_enabled: bool = true
var cfg: Dictionary = {}


func _init(w: SimWorld, b: BallSystem) -> void:
	world = w
	balls = b
	cfg = DataDB.tuning("combat")


func resolve(hb: Hitbox, t: SimActor) -> Dictionary:
	var att: SimActor = world.actor_by_id(hb.owner_id)
	var res: Dictionary = {"result": "", "attacker": hb.owner_id, "target": t.id, "move": hb.move_id,
		"damage": 0.0, "composure": 0.0, "broke": "", "kind": hb.kind, "unblockable": hb.unblockable}
	if bool(t.flags.get("ankle_window", false)):
		_ankle_breaker(att, t, hb, res)
		return _finish(hb, att, t, res)
	if t.invulnerable:
		res["result"] = "read" if bool(t.flags.get("read_window", false)) else "dodged"
		if res["result"] == "read":
			t.hype.gain("read")
			t.flags["read_window"] = false
		return _finish(hb, att, t, res)
	if hb.lob and bool(t.flags.get("rejecting", false)):
		_rejection(att, t, hb, res)
		return _finish(hb, att, t, res)
	if bool(t.flags.get("parry_window", false)) and hb.parryable and not hb.unblockable:
		if hb.kind == "ball":
			_strip(att, t, hb, res)
		else:
			_deflect(att, t, res)
		return _finish(hb, att, t, res)
	if hb.projectile and int(t.flags.get("deflect_projectiles", 0)) > 0:
		t.flags["deflect_projectiles"] = int(t.flags["deflect_projectiles"]) - 1
		res["result"] = "reflected"
		return _finish(hb, att, t, res)
	var dmg: float = hb.damage * _crit(att, hb, res) * _buffs(att, t)
	dmg *= 1.0 - DamageMath.actor_dr(t)
	var guarded: bool = bool(t.flags.get("guarding", false)) and not hb.unblockable and not hb.grab and _frontal(t, att, hb)
	if guarded:
		var stab: float = float(t.flags.get("guard_stability", 1.0))
		t.wind.drain(dmg * JU.f(JU.dict(cfg, "guard"), "wind_per_damage", 0.8) / stab)
		dmg *= JU.f(JU.dict(cfg, "guard"), "chip", 0.25)
		res["result"] = "guard_break" if t.wind.value <= 0.0 else "guarded"
	else:
		res["result"] = "hit"
	_apply_damage(t, dmg, res)
	if t.composure != null and hb.composure > 0.0 and res["result"] != "guarded":
		var comp: float = hb.composure * float(att.flags.get("composure_mult", 1.0) if att != null else 1.0)
		if att != null and world.frame <= int(att.flags.get("hesi_until", -1)):
			comp *= 2.0
			att.flags["hesi_until"] = -1
		res["composure"] = comp
		res["broke"] = t.composure.add(comp, hb.break_kind)
	if not hb.status.is_empty() and res["result"] == "hit":
		StatusEffects.apply(t, hb.status, float(t.flags.get("status_resist", 0.0)))
	res["knockdown"] = hb.knockdown or (hb.knockdown_commons and t.kind == "enemy")
	if res["result"] == "hit" and att != null:
		if bool(hb.tags.get("steal", false)) and t.has_ball and balls != null and not bool(t.flags.get("unstealable", false)) and not att.has_ball:
			var sb: SimBall = balls.take_from(t)
			if sb != null:
				balls.give(sb, att)
				world.emit("ball_stolen", {"actor": att.id, "target": t.id, "ball": sb.id, "home": sb.home_id})
		if hb.tags.has("knockback_m") and t.kind != "boss":
			var away: Vector3 = t.pos - (att.pos if att != null else hb.volume.center())
			away.y = 0.0
			if away.length() > 0.01:
				t.pos = world.collision.resolve(t.pos + away.normalized() * float(hb.tags["knockback_m"]), t.radius)
		if hb.tags.has("snatch_pct"):
			world.emit("tokens_snatched", {"actor": att.id, "target": t.id, "pct": float(hb.tags["snatch_pct"])})
	res["weight"] = hb.weight
	return _finish(hb, att, t, res)


# ------------------------------------------------------------ outcomes

func _ankle_breaker(att: SimActor, t: SimActor, hb: Hitbox, res: Dictionary) -> void:
	res["result"] = "ankle_breaker"
	var ab: Dictionary = JU.dict(cfg, "ankle_breaker")
	var comp: float = JU.f(ab, "composure", 35.0) * DamageMath.stat_scale(t.stat("handles"))
	res["composure"] = comp
	if att != null and att.composure != null:
		res["broke"] = att.composure.add(comp, "shook")
	if att != null and att.kind == "enemy":
		res["knockdown_s"] = JU.f(ab, "knockdown_s", 1.5)
	t.hype.gain("ankle_breaker", float(t.flags.get("ankle_hype_mult", 1.0)))
	t.flags["ankle_window"] = false
	hb.hit_ids.append(t.id)


func _strip(att: SimActor, t: SimActor, hb: Hitbox, res: Dictionary) -> void:
	res["result"] = "strip"
	var p: Dictionary = JU.dict(cfg, "parry")
	var comp: float = JU.f(p, "strip_composure", 30.0) * DamageMath.stat_scale(t.stat("hands"))
	res["composure"] = comp
	if att != null:
		if att.composure != null:
			res["broke"] = att.composure.add(comp, "stagger")
		if att.has_ball and balls != null and not bool(att.flags.get("unstealable", false)):
			var b: SimBall = balls.take_from(att)
			if b != null:
				var dir: Vector3 = t.pos - att.pos
				dir.y = 0.0
				dir = dir.normalized() if dir.length() > 0.01 else -att.forward()
				var fly: float = JU.f(JU.dict(cfg, "street"), "strip_fly_m", 5.0)
				b.pos = att.center()
				b.vel = dir * fly * 0.9 + Vector3(0, 4.0, 0)
				b.last_touch_id = t.id
				if att.kind == "enemy":
					att.flags["disarmed"] = true
				res["ball"] = b.id
		var claw: float = float(t.flags.get("strip_damage", 0.0))
		if claw > 0.0:
			_apply_damage(att, claw, {})
	t.hype.gain("strip")
	hb.frames_left = 0


func _deflect(att: SimActor, t: SimActor, res: Dictionary) -> void:
	res["result"] = "deflect"
	var comp: float = JU.f(JU.dict(cfg, "parry"), "deflect_composure", 20.0) * DamageMath.stat_scale(t.stat("hands"))
	res["composure"] = comp
	if att != null and att.composure != null:
		res["broke"] = att.composure.add(comp, "stagger")


func _rejection(att: SimActor, t: SimActor, hb: Hitbox, res: Dictionary) -> void:
	res["result"] = "rejection"
	hb.frames_left = 0
	var comp: float = 40.0 if bool(hb.tags.get("statement", false)) else 20.0
	res["composure"] = comp
	if att != null and att.composure != null:
		res["broke"] = att.composure.add(comp, "stagger")
	var ball_id: int = int(hb.tags.get("ball", 0))
	if ball_id != 0 and balls != null:
		for b: SimBall in balls.balls:
			if b.id == ball_id:
				var holder: SimActor = world.actor_by_id(b.holder_id) if b.state == SimBall.State.HELD else null
				if holder != null:
					holder.has_ball = false
				if not t.has_ball:
					balls.give(b, t)
				else:
					b.set_state(SimBall.State.LOOSE)
					b.vel = t.forward() * 4.0 + Vector3(0, 3, 0)
	t.hype.gain("strip")


# ------------------------------------------------------------ helpers

func _crit(att: SimActor, hb: Hitbox, res: Dictionary) -> float:
	if hb.crit > 1.0:
		res["crit"] = true
		return hb.crit
	if att == null or att.kind != "hooper":
		return 1.0
	var c: Dictionary = JU.dict(cfg, "crit")
	var chance: float = JU.f(c, "base_chance", 0.05) + float(att.flags.get("crit_bonus", 0.0))
	if world.rng.randf() < chance:
		res["crit"] = true
		return JU.f(c, "mult", 1.5)
	return 1.0


func _buffs(att: SimActor, t: SimActor) -> float:
	var m: float = 1.0
	if bool(t.flags.get("disarmed", false)):
		m *= JU.f(JU.dict(cfg, "street"), "disarmed_damage_taken", 1.3)
	if att != null:
		if StatusEffects.has(att, "trash_talked"):
			m *= 0.75
		m *= float(att.flags.get("damage_taken_mult_vs", 1.0))
	m *= float(t.flags.get("damage_taken_mult", 1.0))
	if t.team == 0 and t.kind == "hooper" and Settings.get_bool("rookie_mode"):
		m *= JU.f(JU.dict(DataDB.tuning("player"), "rookie"), "enemy_damage_mult", 0.75)
	return m


func _frontal(t: SimActor, att: SimActor, hb: Hitbox) -> bool:
	var src: Vector3 = att.pos if att != null else hb.volume.center()
	var to: Vector3 = src - t.pos
	to.y = 0.0
	return to.length() < 0.01 or t.forward().dot(to.normalized()) > 0.0


func apply_raw(t: SimActor, dmg: float) -> void:
	## Damage outside a hit (status DoT, falls, punishes).
	_apply_damage(t, dmg, {})


func _apply_damage(t: SimActor, dmg: float, res: Dictionary) -> void:
	if t.flags.has("fixed_damage") and dmg > 0.0:
		dmg = float(t.flags["fixed_damage"])
	if t.team == 0 and t.kind == "hooper" and DebugConsole.god_mode:
		dmg = 0.0
	if t.team != 0 and DebugConsole.one_hit:
		dmg = t.hp + 1.0
	if not res.is_empty():
		res["damage"] = dmg
	t.hp -= dmg
	if t.hp <= 0.0 and bool(t.flags.get("rose_ready", false)):
		t.hp = 1.0
		t.flags["rose_ready"] = false
		world.emit("rose_saved", {"actor": t.id})
	if t.hp <= 0.0 and t.alive:
		t.hp = 0.0
		if bool(t.flags.get("cannot_die", false)):
			t.hp = 1.0
			return
		t.alive = false
		if not res.is_empty():
			res["killed"] = true


func _finish(hb: Hitbox, att: SimActor, t: SimActor, res: Dictionary) -> Dictionary:
	var r: String = str(res["result"])
	t.flags["last_combat_frame"] = world.frame
	if att != null:
		att.flags["last_combat_frame"] = world.frame
	if t.controller != null and t.controller.has_method("on_hit"):
		t.controller.call("on_hit", res)
	if att != null and (r == "strip" or r == "deflect" or r == "ankle_breaker" or r == "rejection") and att.controller != null and att.controller.has_method("on_parried"):
		att.controller.call("on_parried", res)
	if str(res.get("broke", "")) != "":
		var broken_actor: SimActor = t if (r == "hit" or r == "guarded" or r == "guard_break") else att
		if broken_actor != null:
			world.emit("composure_broken", {"actor": broken_actor.id, "kind": res["broke"]})
	world.emit("hit_resolved", res)
	if bool(res.get("killed", false)):
		world.emit("actor_killed", {"actor": t.id, "attacker": hb.owner_id, "kind": t.kind, "archetype": t.archetype})
	if hitstop_enabled and r != "dodged":
		world.hitstop = maxi(world.hitstop, hb.hitstop_frames() if r != "ankle_breaker" else 2)
	return res
