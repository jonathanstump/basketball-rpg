class_name ChallengerBrain
extends InputSource
## Drives a Hooper through ActorInput (spec §15.9) for Pickup Challengers,
## Deuce, Pops, Midnight P1 — and the QA bot on the player's side. Policy:
## approach, probe with strikes, crossover on the opponent's windup, shoot
## when open, Hands Up on telegraphs, chase loose balls. Skill scales with
## tier: reaction chance, shot timing error, aggression.

var skill: float = 0.5            # 0..1
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var opponent_id: int = 0
var hoop_id: String = ""
var _release_at: float = -1.0
var _release_err: float = 0.0
var _cooldown: int = 0
var _reacted_to: int = -1
var aggressive: bool = true
var _spot: Vector3 = Vector3.ZERO
var _stuck: int = 0
var _still: int = 0
var _pinned: int = 0
var _pin_pos: Vector3 = Vector3.ZERO
var _last_pos: Vector3 = Vector3.ZERO
var passive_frames: int = 0       # holds fire for a while (QA warm-up)
var duel: PossessionDuel = null   # court rules awareness (boss duels, challengers)
var _contest_late: bool = false


static func for_tier(tier: int, seed_value: int = 7) -> ChallengerBrain:
	var c: ChallengerBrain = ChallengerBrain.new()
	c.skill = clampf(0.25 + 0.1 * float(tier), 0.3, 0.98)
	c.rng.seed = seed_value
	return c


func fill(input: ActorInput, a: SimActor, w: SimWorld) -> void:
	input.move = Vector2.ZERO
	for act: String in ["shoot", "dodge", "hands_up", "heavy"]:
		if input.is_held(act) and act != "shoot":
			input.release(act)
	if not a.alive:
		return
	_cooldown -= 1
	if passive_frames > 0:
		passive_frames -= 1
		_cooldown = maxi(_cooldown, 2)
	var h: Hooper = a.controller as Hooper
	var opp: SimActor = _opponent(a, w)
	if h == null:
		return
	if opp == null:
		return
	if duel != null and _duel_rules(input, a, h):
		return
	## Pinned in a corner by a big body: break out toward the court center.
	if a.pos.distance_to(_pin_pos) < 0.05:
		_pinned += 1
	else:
		_pinned = 0
		_pin_pos = a.pos
	if _pinned > 90 and h.action == "" and duel != null:
		_pinned = 0
		var out: Vector3 = -a.pos
		out.y = 0.0
		var side: Vector3 = out.normalized().rotated(Vector3.UP, deg_to_rad(rng.randf_range(-50.0, 50.0)))
		input.move = Vector2(side.x, side.z)
		input.press("dodge")
		_spot = Vector3.ZERO
		return
	if _react_to_threat(input, a, opp, w):
		return
	if h.action == "shot_gather":
		_manage_shot(input, a, h)
		return
	if a.has_ball:
		_offense(input, a, opp, h, w)
	else:
		_defense(input, a, opp, w)


func _opponent(a: SimActor, w: SimWorld) -> SimActor:
	var o: SimActor = w.actor_by_id(opponent_id) if opponent_id != 0 else null
	if o != null and o.alive:
		return o
	o = w.nearest_hostile(a, 60.0)
	if o != null:
		opponent_id = o.id
	return o


func _threat_frame(opp: SimActor) -> int:
	## Frames until the opponent's attack goes active (or -1 if none pending).
	if opp.controller is EnemyBrain:
		var r: MoveRunner = (opp.controller as EnemyBrain).runner
		if r.running and r.frame <= r.startup():
			return r.startup() - r.frame
	if opp.controller is Hooper:
		var oh: Hooper = opp.controller as Hooper
		var prim: String = JU.s(oh.action_move, "primitive")
		if (prim == "strike" or prim == "slam") and oh.action_frame <= JU.i(oh.action_move, "startup"):
			return JU.i(oh.action_move, "startup") - oh.action_frame
	if opp.controller is BossBrain:
		var br: MoveRunner = (opp.controller as BossBrain).runner
		if br.running and br.frame <= br.startup():
			return br.startup() - br.frame
	if opp.controller is TrainingDummy:
		var tr: MoveRunner = (opp.controller as TrainingDummy).runner
		if tr.running and tr.frame <= tr.startup():
			return tr.startup() - tr.frame
	return -1


func _react_to_threat(input: ActorInput, a: SimActor, opp: SimActor, w: SimWorld) -> bool:
	if opp.controller is BossBrain and _reject_statement(input, a, opp, w):
		return true
	if opp.controller is BossBrain and _contest_boss_shot(input, a, opp, w):
		return true
	var tf: int = _threat_frame(opp)
	if tf < 0 or opp.dist_to(a) > 4.5:
		return false
	var key: int = w.frame - tf
	if tf == 5 and _reacted_to != key:
		_reacted_to = key
		if rng.randf() > skill:
			return false
		var side: Vector3 = (a.pos - opp.pos).cross(Vector3.UP).normalized()
		input.move = Vector2(side.x, side.z)
		var unblockable: bool = bool(opp.flags.get("unblockable_flash", false))
		if a.has_ball or unblockable:
			input.press("dodge")
		else:
			input.press("hands_up")
		return true
	return false


func _contest_boss_shot(input: ActorInput, a: SimActor, opp: SimActor, w: SimWorld) -> bool:
	## R7: close out on a boss's shot gather, hands up on the release.
	var br: MoveRunner = (opp.controller as BossBrain).runner
	if not br.running or JU.s(br.move, "primitive") != "boss_shot" or a.has_ball:
		return false
	var left: int = br.startup() - br.frame
	if left < 0:
		return false
	if opp.dist_to(a) - opp.radius > 1.2:
		_move(input, a, opp.pos)
	## A human doesn't nail every release: half the good reads are early (altered).
	var key: int = w.frame - left + 200000
	if _reacted_to != key and (left == 7 or left == 2):
		if left == 7:
			_contest_late = rng.randf() < skill * 0.5
		if (left == 2) == _contest_late:
			_reacted_to = key
			if rng.randf() < skill:
				input.press("hands_up")
	return true


func _reject_statement(input: ActorInput, a: SimActor, opp: SimActor, w: SimWorld) -> bool:
	## Statement Dunk cue: Jump + Hands Up so the Rejection is live as it lands.
	var br: MoveRunner = (opp.controller as BossBrain).runner
	if not br.running or JU.s(br.move, "primitive") != "statement_dunk" or opp.dist_to(a) > 5.0:
		return false
	if br.frame < br.startup() - 7:
		_move(input, a, opp.pos)
		return true
	if br.frame != br.startup() - 7:
		return false
	var key: int = w.frame + 100000
	if _reacted_to == key or rng.randf() > skill:
		return false
	_reacted_to = key
	input.press("jump")
	input.press("hands_up")
	w.emit("bot_reject_attempt", {"actor": a.id})
	return true


func _duel_rules(input: ActorInput, a: SimActor, h: Hooper) -> bool:
	## Court rules: wait out CHECK/transitions, clear the ball past the arc.
	match duel.state:
		PossessionDuel.CHECK, PossessionDuel.PHASE_TRANSITION, PossessionDuel.VICTORY, PossessionDuel.DEFEAT:
			input.release("shoot")
			return true
		PossessionDuel.PLAYER_OFFENSE:
			if a.has_ball and not duel.player_cleared and h.action == "":
				var hoop: SimHoop = _hoop(h)
				if hoop != null:
					var out: Vector3 = a.pos - hoop.floor_point()
					out.y = 0.0
					_move(input, a, hoop.floor_point() + out.normalized() * 7.8)
					return true
	return false


func _offense(input: ActorInput, a: SimActor, opp: SimActor, h: Hooper, w: SimWorld) -> void:
	var hoop: SimHoop = _hoop(h)
	var to_opp: Vector3 = opp.pos - a.pos
	to_opp.y = 0.0
	if hoop != null:
		var d_hoop: float = hoop.flat_distance(a.pos)
		var mod: HooperBall = _ball_module(h)
		var contest: float = float(mod.contest(a)[0]) if mod != null else 0.0
		if h.stepback_timer_s > 0.0 and d_hoop < 8.5 and _cooldown <= 0:
			## Fire right out of the stepback (it beats long contests).
			contest = 0.0
		elif d_hoop < 7.5 and contest >= 0.35 + 0.2 * (1.0 - skill) and _cooldown <= 0 and h.action == "" and rng.randf() < 0.04 * skill:
			## Contested: create space with a stepback.
			var away: Vector3 = (a.pos - opp.pos)
			away.y = 0.0
			var f: Vector3 = a.forward()
			input.move = Vector2(-f.x, -f.z) if away.length() < 0.1 else Vector2(away.normalized().x, away.normalized().z)
			input.press("dodge")
			return
		if d_hoop < 7.5 and contest < 0.35 + 0.2 * (1.0 - skill) and _cooldown <= 0:
			input.press("shoot")
			input.held["shoot"] = true
			_release_at = _pick_release(mod)
			_cooldown = 60
			return
		if _spot == Vector3.ZERO:
			_spot = hoop.floor_point() + hoop.facing * 5.0
		var dest: Vector3 = _spot
		if opp.is_shook() or opp.flags.get("downed", false):
			dest = hoop.floor_point() + hoop.facing * 2.5
		if a.pos.distance_to(dest) < 1.2:
			_stuck += 1
		## Pinned (walled by the defender / a corner): slip out sideways.
		if a.pos.distance_to(_last_pos) < 0.02 and a.pos.distance_to(dest) >= 1.2:
			_still += 1
		else:
			_still = 0
		_last_pos = a.pos
		if _still > 45:
			_still = 0
			_spot = hoop.floor_point() + hoop.facing.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-80.0, 80.0))) * rng.randf_range(4.0, 7.5)
			input.press("dodge")
			return
		if _stuck > 50:
			## Contested at the spot: try another angle around the arc.
			_stuck = 0
			_spot = hoop.floor_point() + hoop.facing.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-75.0, 75.0))) * rng.randf_range(4.0, 7.2)
		if to_opp.length() < 2.4 and _cooldown <= 0 and aggressive and rng.randf() < 0.5:
			## Attack off the dribble to break ankles / stagger the defender.
			input.press("light" if rng.randf() < 0.7 else "dodge")
			_cooldown = int(lerpf(40.0, 18.0, skill))
			return
		_move(input, a, dest)
		return
	if to_opp.length() > 1.6:
		_move(input, a, opp.pos)
	elif _cooldown <= 0 and aggressive:
		input.press("light")
		_cooldown = int(lerpf(30.0, 12.0, skill))


func _defense(input: ActorInput, a: SimActor, opp: SimActor, w: SimWorld) -> void:
	for hb: SimBall in _balls(a, w):
		## Somebody else (a summoned crew member) ran off with our ball: get it back.
		if hb.state == SimBall.State.HELD and hb.holder_id != opp.id and hb.holder_id != a.id:
			var thief: SimActor = w.actor_by_id(hb.holder_id)
			if thief != null and thief.team != a.team and thief.alive and thief.dist_to(a) < 16.0:
				_move(input, a, thief.pos)
				if thief.dist_to(a) < 2.0 and _cooldown <= 0:
					input.press("light")
					_cooldown = 20
				return
	for b: SimBall in (_balls(a, w)):
		if b.state == SimBall.State.LOOSE and b.pos.distance_to(a.pos) < 14.0:
			_move(input, a, b.pos)
			if b.pos.distance_to(a.pos) < 2.8 and _cooldown <= 0:
				input.press("dodge")
				_cooldown = 30
			return
	var d: float = opp.dist_to(a)
	var save_wind: bool = opp.controller is BossBrain and opp.has_ball and a.wind.value < 40.0
	if d > 1.4:
		_move(input, a, opp.pos)
	elif _cooldown <= 0 and not save_wind:
		input.press("heavy" if opp.has_ball and rng.randf() < 0.4 else "light")
		_cooldown = int(lerpf(36.0, 14.0, skill))


func _manage_shot(input: ActorInput, _a: SimActor, h: Hooper) -> void:
	var mod: HooperBall = _ball_module(h)
	if mod == null or mod.meter < 0.0:
		return
	## Aim at the live window center (gusts move it mid-gather), keeping the
	## per-shot timing error picked when the shot started.
	var target: float = clampf((mod.windows.center if mod.windows != null else 0.82) + _release_err, 0.05, 0.99)
	if mod.meter >= target:
		input.release("shoot")
	else:
		input.held["shoot"] = true


func _pick_release(mod: HooperBall) -> float:
	var center: float = mod.windows.center if mod != null and mod.windows != null else 0.82
	_release_err = rng.randfn(0.0, lerpf(0.09, 0.012, skill))
	return clampf(center + _release_err, 0.05, 0.99)


func _move(input: ActorInput, a: SimActor, dest: Vector3) -> void:
	var to: Vector3 = dest - a.pos
	to.y = 0.0
	if to.length() > 0.3:
		input.move = Vector2(to.x, to.z).normalized()


func _hoop(h: Hooper) -> SimHoop:
	var mod: HooperBall = _ball_module(h)
	if mod == null:
		return null
	if hoop_id != "":
		return mod.sys.hoop_by_id(hoop_id)
	return mod.sys.hoop_in_range(h.actor) if mod.sys.hoops.size() > 0 else null


func _ball_module(h: Hooper) -> HooperBall:
	for m: RefCounted in h.modules:
		if m is HooperBall:
			return m
	return null


func _balls(a: SimActor, _w: SimWorld) -> Array[SimBall]:
	var h: Hooper = a.controller as Hooper
	var mod: HooperBall = _ball_module(h) if h != null else null
	return mod.sys.balls if mod != null else ([] as Array[SimBall])
