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
var _cooldown: int = 0
var _reacted_to: int = -1
var aggressive: bool = true


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
	var h: Hooper = a.controller as Hooper
	var opp: SimActor = _opponent(a, w)
	if h == null:
		return
	if opp == null:
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
	if opp.controller is TrainingDummy:
		var tr: MoveRunner = (opp.controller as TrainingDummy).runner
		if tr.running and tr.frame <= tr.startup():
			return tr.startup() - tr.frame
	return -1


func _react_to_threat(input: ActorInput, a: SimActor, opp: SimActor, w: SimWorld) -> bool:
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


func _offense(input: ActorInput, a: SimActor, opp: SimActor, h: Hooper, w: SimWorld) -> void:
	var hoop: SimHoop = _hoop(h)
	var to_opp: Vector3 = opp.pos - a.pos
	to_opp.y = 0.0
	if hoop != null:
		var d_hoop: float = hoop.flat_distance(a.pos)
		var mod: HooperBall = _ball_module(h)
		var contest: float = float(mod.contest(a)[0]) if mod != null else 0.0
		if d_hoop < 7.5 and contest < 0.35 + 0.2 * (1.0 - skill) and _cooldown <= 0:
			input.press("shoot")
			input.held["shoot"] = true
			_release_at = _pick_release(mod)
			_cooldown = 60
			return
		var dest: Vector3 = hoop.floor_point() + hoop.facing * 5.0
		if opp.is_shook() or opp.flags.get("downed", false):
			dest = hoop.floor_point() + hoop.facing * 2.5
		_move(input, a, dest)
		return
	if to_opp.length() > 1.6:
		_move(input, a, opp.pos)
	elif _cooldown <= 0 and aggressive:
		input.press("light")
		_cooldown = int(lerpf(30.0, 12.0, skill))


func _defense(input: ActorInput, a: SimActor, opp: SimActor, w: SimWorld) -> void:
	for b: SimBall in (_balls(a, w)):
		if b.state == SimBall.State.LOOSE and b.pos.distance_to(a.pos) < 14.0:
			_move(input, a, b.pos)
			if b.pos.distance_to(a.pos) < 2.8 and _cooldown <= 0:
				input.press("dodge")
				_cooldown = 30
			return
	var d: float = opp.dist_to(a)
	if d > 1.4:
		_move(input, a, opp.pos)
	elif _cooldown <= 0:
		input.press("heavy" if opp.has_ball and rng.randf() < 0.4 else "light")
		_cooldown = int(lerpf(36.0, 14.0, skill))


func _manage_shot(input: ActorInput, _a: SimActor, h: Hooper) -> void:
	var mod: HooperBall = _ball_module(h)
	if mod == null or mod.meter < 0.0:
		return
	if mod.meter >= _release_at:
		input.release("shoot")
	else:
		input.held["shoot"] = true


func _pick_release(mod: HooperBall) -> float:
	var center: float = mod.windows.center if mod != null and mod.windows != null else 0.82
	var err: float = rng.randfn(0.0, lerpf(0.09, 0.012, skill))
	return clampf(center + err, 0.05, 0.99)


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
