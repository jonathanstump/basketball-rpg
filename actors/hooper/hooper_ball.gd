class_name HooperBall
extends RefCounted
## Hooper module for ball actions (spec §7.4, §7.6): jumper with the 2K-style
## meter, chest pass (tap Y) / baseball pass (hold Y >= 36f), lob (shoot with
## no hoop in range). Exposes meter + windows for the shot meter UI.

var sys: BallSystem
var meter: float = -1.0             # -1 = not gathering
var windows: ShotWindows = null
var shot_hoop: SimHoop = null
var gather_rate: float = 1.0 / 33.0
var last_grade: String = ""
var last_release: float = 0.0
var last_contest: float = 0.0
var hold_frames: int = 0
var run_kind: String = ""           # revision 9: "" | "run" | "sprint" when the shot started on the move
var run_speed: float = 0.0
var cancelled: bool = false        # revision 13: the gather ended without a release (hit mid-shot)


func _init(s: BallSystem) -> void:
	sys = s


static func gather_frames(gather_s: float) -> float:
	return gather_s * 60.0


func try_start(h: Hooper) -> bool:
	var a: SimActor = h.actor
	var inp: ActorInput = a.input
	if not a.has_ball or not a.on_ground:
		return false
	if inp.peek("shoot"):
		inp.pressed("shoot")
		var hoop: SimHoop = sys.hoop_in_range(a)
		if hoop != null:
			shot_hoop = hoop
			_note_run(h)
			return h.begin("shot_gather", hoop.rim - a.pos, self)
		return h.begin("lob", a.forward(), self)
	if inp.peek("heavy"):
		inp.pressed("heavy")
		return h.begin("chest_pass", a.forward(), self)
	return false


func on_begin(h: Hooper) -> void:
	match h.action:
		"shot_gather":
			meter = 0.0
			cancelled = false
			var item: Dictionary = DataDB.ball(str(h.actor.flags.get("ball_item", "ball_rec")))
			var gs: float = JU.f(item, "gather_s", JU.f(DataDB.tuning("shooting"), "gather_s", 0.55))
			gs *= float(h.actor.flags.get("gather_mult", 1.0))
			gather_rate = 1.0 / maxf(1.0, gather_frames(gs))
			windows = ShotResolver.compute_windows(_ctx(h, 0.0))
		"chest_pass":
			hold_frames = 0


func on_frame(h: Hooper) -> void:
	var a: SimActor = h.actor
	a.desired_vel = Vector3.ZERO
	match h.action:
		"shot_gather":
			_gather(h)
		"chest_pass":
			if a.input.is_held("heavy"):
				hold_frames += 1
			if h.action_frame == JU.i(h.action_move, "startup"):
				if a.input.is_held("heavy"):
					h.begin("pass_charge", h.action_dir, self, false)
				else:
					_fire_pass(h, "chest_pass")
		"pass_charge":
			_face_aim(h)
			if a.input.is_held("heavy"):
				hold_frames += 1
				if h.action_frame >= 110:
					_release_charge(h)
			else:
				_release_charge(h)
		"baseball_pass":
			_face_aim(h)
			if h.action_frame == JU.i(h.action_move, "startup"):
				_fire_pass(h, "baseball_pass")
		"lob":
			if h.action_frame == JU.i(h.action_move, "startup"):
				sys.lob_ball(a, _lob_target(h))


func on_end(_h: Hooper, ended: String) -> void:
	if ended == "shot_gather":
		cancelled = meter >= 0.0   # release() clears the meter first
		meter = -1.0
		run_kind = ""


func _note_run(h: Hooper) -> void:
	## Shooting on the move (revision 9): you keep your feet moving through
	## the gather, but the timing windows shrink (tuning shooting.modifiers).
	var a: SimActor = h.actor
	var cfg: Dictionary = DataDB.tuning("shooting")
	run_speed = Vector2(a.vel.x, a.vel.z).length()
	run_kind = ""
	if a.input.move.length() > 0.2 and run_speed >= JU.f(cfg, "run_min_speed", 4.0):
		run_kind = "sprint" if h.sprinting else "run"


# ------------------------------------------------------------ shooting

func _gather(h: Hooper) -> void:
	var a: SimActor = h.actor
	if shot_hoop != null:
		a.turn_toward(shot_hoop.rim - a.pos, 0.4)
	if run_kind != "" and a.input.move.length() > 0.2:
		a.desired_vel = a.input.move3().normalized() * run_speed * JU.f(DataDB.tuning("shooting"), "run_carry", 0.7)
	meter += gather_rate
	var c: Array = contest(a)
	windows = ShotResolver.compute_windows(_ctx(h, float(c[0])))
	if not a.input.is_held("shoot") or meter >= 1.0:
		release(h)


func release(h: Hooper) -> String:
	var a: SimActor = h.actor
	var c: Array = contest(a)
	var contest_v: float = float(c[0])
	var ctx: ShotContext = _ctx(h, contest_v)
	windows = ShotResolver.compute_windows(ctx)
	var grade: String = ShotResolver.grade(meter, windows, contest_v)
	last_grade = grade
	last_release = meter
	last_contest = contest_v
	var blocker: SimActor = c[1] if grade == ShotResolver.REJECTED else null
	sys.shoot(a, shot_hoop, grade, windows.zone, blocker)
	meter = -1.0
	h.begin("shot_release", a.forward(), self)
	return grade


func contest(a: SimActor) -> Array:
	## [max contest 0..1, best defender or null]
	var best: float = 0.0
	var who: SimActor = null
	for o: SimActor in sys.world.hostiles_of(a):
		if o.is_broken() or bool(o.flags.get("downed", false)):
			continue
		var cv: float = ShotResolver.contest_of(a.pos, o.pos, o.forward(), o.contest_radius * float(o.flags.get("contest_mult", 1.0)))
		if cv > best:
			best = cv
			who = o
	return [best, who]


func _ctx(h: Hooper, contest_v: float) -> ShotContext:
	var a: SimActor = h.actor
	var dist: float = shot_hoop.flat_distance(a.pos) if shot_hoop != null else 5.0
	var ctx: ShotContext = ShotContext.make(a.stat("jumper") + int(a.flags.get("jumper_bonus", 0)), dist, contest_v)
	ctx.stepback = h.stepback_timer_s > 0.0
	ctx.on_run = run_kind
	ctx.takeover = bool(a.flags.get("takeover", false))
	ctx.wide_open = _wide_open(a)
	ctx.wind_ratio = a.wind.ratio()
	ctx.wind_drift = float(a.flags.get("wind_drift", 0.0))
	var item: Dictionary = DataDB.ball(str(a.flags.get("ball_item", "ball_rec")))
	ctx.window_mult = float(a.flags.get("shot_window_mult", 1.0)) * JU.f(JU.dict(item, "props"), "shot_window_mult", 1.0)
	if StatusEffects.has(a, "glare"):
		ctx.window_mult *= 0.6
	ctx.perfect_bonus = float(a.flags.get("perfect_bonus", 0.0))
	if a.hp < a.hp_max * 0.3:
		ctx.window_mult *= float(a.flags.get("low_heart_window_mult", 1.0))
	ctx.rookie = a.team == 0 and a.kind == "hooper" and Settings.get_bool("rookie_mode")
	return ctx


func _wide_open(a: SimActor) -> bool:
	for o: SimActor in sys.world.hostiles_of(a):
		if o.kind == "boss" and o.is_shook():
			return true
	return false


# ------------------------------------------------------------ passes / lobs

func _release_charge(h: Hooper) -> void:
	var total_hold: int = hold_frames
	if total_hold >= JU.i(h.move_data("baseball_pass"), "hold_frames", 36):
		var extra: float = JU.f(h.move_data("baseball_pass"), "wind") - JU.f(h.move_data("chest_pass"), "wind")
		h.actor.wind.spend(maxf(0.0, extra))
		h.begin("baseball_pass", h.action_dir, self, false)
	else:
		_fire_pass(h, "chest_pass")
		h.begin("pass_recovery", h.action_dir, self)


func aim_target(a: SimActor, range_m: float) -> Dictionary:
	## {point, actor}: lock target, else aim-assisted hostile / Wire Kicks in a
	## cone ahead, else straight ahead at hand height.
	var hooper: Hooper = a.controller as Hooper
	if hooper != null and hooper.lock_target != null and hooper.lock_target.alive:
		return {"point": hooper.lock_target.center(), "actor": hooper.lock_target}
	var hand: Vector3 = a.pos + Vector3(0, JU.f(sys.cfg, "hand_height", 1.05), 0)
	var cone: float = deg_to_rad(JU.f(sys.cfg, "aim_assist_deg", 25.0))
	var best_ang: float = cone
	var out: Dictionary = {"point": hand + a.forward() * range_m, "actor": null}
	if a.team == 0 and not Settings.get_bool("pass_aim_assist"):
		return out
	for o: SimActor in sys.world.hostiles_of(a):
		var to: Vector3 = o.center() - hand
		if to.length() > range_m:
			continue
		var ang: float = a.forward().angle_to(Vector3(to.x, 0, to.z))
		if ang < best_ang:
			best_ang = ang
			out = {"point": o.center(), "actor": o}
	for wk: Dictionary in sys.wire_kicks:
		if bool(wk["down"]):
			continue
		var p: Vector3 = wk["pos"]
		var to2: Vector3 = p - hand
		if to2.length() > range_m:
			continue
		var ang2: float = a.forward().angle_to(Vector3(to2.x, 0, to2.z))
		if ang2 < best_ang:
			best_ang = ang2
			out = {"point": p, "actor": null}
	return out


func _face_aim(h: Hooper) -> void:
	var t: Dictionary = aim_target(h.actor, 30.0)
	h.actor.turn_toward((t["point"] as Vector3) - h.actor.pos, 0.3)


func _fire_pass(h: Hooper, kind: String) -> void:
	var a: SimActor = h.actor
	var rng: float = JU.f(JU.dict(sys.cfg, kind), "range", 18.0)
	var t: Dictionary = aim_target(a, rng)
	var target_actor: SimActor = t["actor"]
	a.turn_toward((t["point"] as Vector3) - a.pos, PI)
	sys.pass_ball(a, kind, t["point"], target_actor)


func _lob_target(h: Hooper) -> Vector3:
	var a: SimActor = h.actor
	if h.lock_target != null and h.lock_target.alive:
		return h.lock_target.pos
	if a.input.aim != Vector3.ZERO:
		return a.input.aim
	return a.pos + a.forward() * JU.f(JU.dict(sys.cfg, "lob"), "default_range_m", 10.0)
