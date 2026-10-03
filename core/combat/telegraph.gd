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
		if not r.in_startup() or JU.i(r.move, "damage", 1) < 0 or JU.s(r.move, "primitive") in ["stance", "showboat", "summon", "taunt"]:
			return {}
		startup = r.startup()
		frame = r.frame
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
	return {"progress": clampf(float(frame) / float(startup), 0.0, 1.0), "frames_left": left,
		"unblockable": unblockable, "now": left <= CUE_FRAMES}
