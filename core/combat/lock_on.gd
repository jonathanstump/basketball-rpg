class_name LockOn
extends RefCounted
## Souls-style lock-on targeting (spec D2, revision 17). Pure: picks who to
## lock onto, cycles left/right through the hostiles around you relative to
## the camera, and says when the lock breaks (target down or you backed off).
## Locking is always manual; nothing here acquires a target on its own.


static func candidates(w: SimWorld, player: SimActor, range_m: float) -> Array[SimActor]:
	var out: Array[SimActor] = []
	for o: SimActor in w.hostiles_of(player):
		if o.alive and o.kind != "prop" and not bool(o.flags.get("prop_target", false)) and o.dist_to(player) <= range_m:
			out.append(o)
	return out


static func best(w: SimWorld, player: SimActor, cam_fwd: Vector3, range_m: float) -> SimActor:
	## Nearest hostile, weighted toward whoever's in front of the camera.
	var pick: SimActor = null
	var best_score: float = 1e9
	for o: SimActor in candidates(w, player, range_m):
		var to: Vector3 = o.pos - player.pos
		to.y = 0.0
		var score: float = o.dist_to(player) - to.normalized().dot(cam_fwd) * 6.0
		if score < best_score:
			best_score = score
			pick = o
	return pick


static func bearing(player: SimActor, o: SimActor, cam_fwd: Vector3) -> float:
	## Angle of `o` around the player, measured clockwise from camera forward
	## (so +1 step goes right on screen).
	var to: Vector3 = o.pos - player.pos
	to.y = 0.0
	var right: Vector3 = Vector3(-cam_fwd.z, 0.0, cam_fwd.x)
	return atan2(to.dot(right), to.dot(cam_fwd))


static func cycle(w: SimWorld, player: SimActor, current: SimActor, cam_fwd: Vector3, step: int, range_m: float) -> SimActor:
	## The next target to the right (step > 0) or left (step < 0) of the
	## current one; wraps around. Falls back to best() with no current lock.
	var list: Array[SimActor] = candidates(w, player, range_m)
	if list.is_empty():
		return current
	if current == null or not list.has(current):
		return best(w, player, cam_fwd, range_m)
	list.sort_custom(func(a: SimActor, b: SimActor) -> bool: return bearing(player, a, cam_fwd) < bearing(player, b, cam_fwd))
	var i: int = list.find(current)
	return list[posmod(i + (1 if step > 0 else -1), list.size())]


static func breaks(player: SimActor, target: SimActor, break_m: float) -> bool:
	return target == null or not target.alive or target.dist_to(player) > break_m
