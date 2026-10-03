class_name Telegraph
extends RefCounted
## Attack wind-up readout (spec §7.5 timing, §8.1 telegraphs). Pure: reads a
## hostile actor's running move and reports how far into its startup it is,
## so views can show the "about to attack" cue and players can time
## ankle-breakers (dodge) and strips (Hands Up) on it.

const CUE_FRAMES: int = 6   # the last frames before the hit: the "now!" pulse


static func runner_of(a: SimActor) -> MoveRunner:
	var c: Object = a.controller
	if c is EnemyBrain:
		return (c as EnemyBrain).runner
	if c is BossBrain:
		return (c as BossBrain).runner
	if c is TrainingDummy:
		return (c as TrainingDummy).runner
	return null


static func read(a: SimActor) -> Dictionary:
	## {} when no attack is winding up; else progress 0..1 through startup,
	## frames_left until the hit goes active, unblockable, and "now"
	## (inside the last CUE_FRAMES).
	if a == null or not a.alive or a.team == 0:
		return {}
	var startup: int = 0
	var frame: int = 0
	var unblockable: bool = bool(a.flags.get("unblockable_flash", false))
	var r: MoveRunner = runner_of(a)
	if r != null:
		if not r.running or JU.i(r.move, "damage", 1) < 0 or JU.s(r.move, "primitive") in ["stance", "showboat", "summon", "taunt"]:
			return {}
		var left_r: int = impact_frames_left(r)
		if left_r < 0:
			return {}
		return _info(r.frame, r.frame + left_r, left_r, unblockable)
	elif a.controller is Hooper:
		## Rival hoopers (Challenger duels, Midnight's warm-up mirror).
		var h: Hooper = a.controller as Hooper
		var prim: String = JU.s(h.action_move, "primitive")
		if not (prim == "strike" or prim == "slam") or h.action_frame > JU.i(h.action_move, "startup"):
			return {}
		startup = JU.i(h.action_move, "startup")
		frame = h.action_frame
	else:
		return {}
	if startup <= 0:
		return {}
	var left: int = maxi(0, startup - frame)
	return _info(frame, startup, left, unblockable)


static func _info(frame: int, impact: int, left: int, unblockable: bool) -> Dictionary:
	return {"progress": clampf(float(frame) / float(maxi(1, impact)), 0.0, 1.0), "frames_left": left,
		"unblockable": unblockable, "now": left <= CUE_FRAMES}


static func impact_frames_left(r: MoveRunner) -> int:
	## Frames until the hit should connect, or -1 once it can't anymore.
	## Melee/area attacks connect when the wind-up ends. Travelling attacks
	## (lunge, charge, closing grab) connect when they reach the target, so
	## the cue waits for the travel too: the Hands Up / dodge moment.
	var s: int = r.startup()
	var act: int = r.active()
	var prim: String = JU.s(r.move, "primitive")
	var travel_m: float = JU.f(r.move, "lunge_m", 4.0 if prim == "lunge" else (12.0 if prim == "charge_lane" else 0.0))
	if travel_m <= 0.0 or r.target == null or act <= 0:
		return s - r.frame if r.frame <= s else -1
	if r.frame > s + act:
		return -1
	var reach: float = JU.f(JU.dict(r.move, "hitbox"), "radius", 1.4) + r.target.radius
	var per_frame: float = travel_m / float(act)
	var gap: float = maxf(0.0, r.actor.dist_to(r.target) - reach)
	var travel: int = int(ceil(gap / maxf(0.01, per_frame)))
	var into_active: int = maxi(0, r.frame - s)
	travel = mini(travel, act - into_active)   # it stops at the end of its active frames
	return maxi(0, s - r.frame) + travel
