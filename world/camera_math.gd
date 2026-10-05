class_name CameraMath
extends RefCounted
## Pure camera framing math (spec D2) so tests can check framing without a
## viewport. Yaw follows SimActor convention (forward = -Z rotated by yaw).


static func orbit_transform(focus: Vector3, yaw: float, pitch_deg: float, distance: float) -> Transform3D:
	var pitch: float = deg_to_rad(pitch_deg)
	var back: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))   # opposite of the yaw's forward
	var offset: Vector3 = back * cos(pitch) * distance + Vector3.UP * sin(pitch) * distance
	var origin: Vector3 = focus + offset
	return Transform3D(Basis.looking_at(focus - origin, Vector3.UP), origin)


static func lockon_framing(player: Vector3, target: Vector3, hoop: Vector3, use_hoop: bool, cfg: Dictionary, aspect: float = 16.0 / 9.0, target_h: float = 2.0) -> Dictionary:
	## Returns {focus, yaw, distance, pitch}. Camera sits behind the player
	## looking toward the target; searches focus bias and distance (9-14 m)
	## until player, target (and hoop) all fit in frame. Focus includes height.
	var lock: Dictionary = JU.dict(cfg, "lockon")
	var fov: float = JU.f(JU.dict(cfg, "explore"), "fov_deg", 45.0)
	var pitch: float = JU.f(lock, "pitch_deg", 38.0)
	var lift: float = JU.f(cfg, "focus_height_m", 0.9)
	var to_t: Vector3 = target - player
	to_t.y = 0.0
	var sep: float = to_t.length()
	var yaw: float = SimActor.yaw_of(to_t) if sep > 0.01 else 0.0
	var dmin: float = JU.f(lock, "distance_min_m", 9.0)
	var dmax: float = maxf(JU.f(lock, "distance_max_m", 14.0), 8.0 + target_h * 1.4)
	var base_d: float = clampf(dmin + sep * JU.f(lock, "sep_to_distance", 0.45), dmin, dmax)
	var pts: Array[Vector3] = [player, player + Vector3.UP * 1.2, target + Vector3.UP * minf(maxf(1.0, target_h * 0.7), 6.0)]
	if use_hoop:
		pts.append(hoop)
	var hw: float = JU.f(lock, "hoop_weight", 0.35) if use_hoop else 0.0
	var best: Dictionary = {}
	for frac: float in [0.35, 0.25, 0.15, 0.05]:
		var focus: Vector3 = player.lerp(target, frac)
		focus.y = player.y
		if use_hoop:
			focus = focus.lerp(Vector3(hoop.x, player.y + hoop.y * 0.4, hoop.z), hw)
		focus += Vector3.UP * lift
		var d: float = base_d
		while d <= dmax + 0.001:
			var xf: Transform3D = orbit_transform(focus, yaw, pitch, d)
			var ok: bool = true
			for p: Vector3 in pts:
				if not in_view(xf, fov, aspect, p):
					ok = false
					break
			if ok:
				return {"focus": focus, "yaw": yaw, "distance": d, "pitch": pitch}
			if best.is_empty():
				best = {"focus": focus, "yaw": yaw, "distance": dmax, "pitch": pitch}
			d += 0.5
	return best


static func in_view(cam: Transform3D, fov_deg: float, aspect: float, point: Vector3, margin: float = 0.9) -> bool:
	var proj: Projection = Projection.create_perspective(fov_deg, aspect, 0.05, 500.0)
	var local: Vector3 = cam.affine_inverse() * point
	if local.z >= -0.05:
		return false
	var clip: Vector4 = proj * Vector4(local.x, local.y, local.z, 1.0)
	var ndc: Vector2 = Vector2(clip.x, clip.y) / clip.w
	return absf(ndc.x) <= margin and absf(ndc.y) <= margin


static func explore_shape(pitch_deg: float, cfg: Dictionary) -> Dictionary:
	## Free look (playtest R2): as the camera drops toward the street the
	## orbit shortens and the look point rises, ending in an over-the-shoulder
	## view that can look up at the buildings and the skyline.
	## Returns {distance, lift, shoulder}.
	var ex: Dictionary = JU.dict(cfg, "explore")
	var hi: float = JU.f(ex, "pitch_max_deg", 65.0)
	var lo: float = JU.f(ex, "pitch_min_deg", -8.0)
	var k: float = clampf(inverse_lerp(hi, lo, pitch_deg), 0.0, 1.0)
	var e: float = k * k * (3.0 - 2.0 * k)
	return {"distance": lerpf(JU.f(ex, "distance_m", 12.0), JU.f(ex, "distance_near_m", 4.5), e),
		"lift": lerpf(JU.f(cfg, "focus_height_m", 0.9), JU.f(ex, "focus_lift_near_m", 1.8), e),
		"shoulder": JU.f(ex, "shoulder_m", 0.45) * e}


static func clamp_pitch(pitch_deg: float, cfg: Dictionary) -> float:
	var ex: Dictionary = JU.dict(cfg, "explore")
	return clampf(pitch_deg, JU.f(ex, "pitch_min_deg", -8.0), JU.f(ex, "pitch_max_deg", 65.0))


static func pull_in(focus: Vector3, yaw: float, pitch_deg: float, distance: float, col: WorldCollision, min_d: float = 2.2) -> float:
	## Longest orbit distance (<= distance) whose camera line to the focus
	## clears every wall at the height the line passes it.
	if col == null:
		return distance
	var d: float = distance
	while d > min_d:
		if line_clear(focus, orbit_transform(focus, yaw, pitch_deg, d).origin, col):
			return d
		d -= 0.5
	return min_d


static func line_clear(a: Vector3, b: Vector3, col: WorldCollision) -> bool:
	## Samples the segment every ~0.6 m; a wall only blocks where it is taller
	## than the line (so a camera can look down over a fence).
	var n: int = maxi(2, int(ceil(a.distance_to(b) / 0.6)))
	for i: int in range(1, n + 1):
		if col.blocked(a.lerp(b, float(i) / float(n)), 0.2):
			return false
	return true


static func duel_framing(player: Vector3, boss: Vector3, hoop: Vector3, cfg: Dictionary, prev_yaw: float, aspect: float = 16.0 / 9.0, boss_h: float = 3.0, boss_r: float = 1.0, col: WorldCollision = null) -> Dictionary:
	## Boss duels (playtest R5): the camera sits behind the player looking at
	## the rim, so the hoop is always ahead. If the boss is between the camera
	## and the player, swing the yaw and raise the pitch until the player
	## shows. The boss is fitted in frame when the distance allows.
	## Returns {focus, yaw, distance, pitch}.
	var du: Dictionary = JU.dict(cfg, "duel")
	var fov: float = JU.f(JU.dict(cfg, "explore"), "fov_deg", 45.0)
	var base_pitch: float = JU.f(du, "pitch_deg", 34.0)
	var to_h: Vector3 = Vector3(hoop.x - player.x, 0.0, hoop.z - player.z)
	var base_yaw: float = prev_yaw
	var close: float = JU.f(du, "close_to_hoop_m", 3.0)
	if to_h.length() > 0.01:
		## Right under the rim the direction swings wildly: blend to the old yaw.
		base_yaw = lerp_angle(prev_yaw, SimActor.yaw_of(to_h), clampf(to_h.length() / close, 0.0, 1.0))
	var chest: Vector3 = player + Vector3.UP * 1.2
	var pts: Array[Vector3] = [chest, hoop, boss + Vector3.UP * minf(maxf(1.0, boss_h * 0.6), 5.0)]
	var dmin: float = JU.f(du, "distance_min_m", 8.5)
	var dmax: float = JU.f(du, "distance_max_m", 14.0)
	var fallback: Dictionary = {}
	## Walls (pinned against the fence) shorten the orbit: candidates are
	## judged at the distance the camera can actually reach, and the focus
	## slides back onto the player when there's no room behind.
	var bias0: float = JU.f(du, "hoop_bias", 0.35)
	var focus: Vector3 = Vector3.ZERO
	for cand: int in 60:
		var bias: float = [bias0, bias0 * 0.4, 0.0][cand / 20]
		var pitch: float = base_pitch + [0.0, 14.0, 26.0, 38.0][(cand / 5) % 4]
		var off: float = [0.0, 0.45, -0.45, 0.8, -0.8][cand % 5]
		focus = player.lerp(Vector3(hoop.x, player.y, hoop.z), bias)
		focus.y = player.y + JU.f(cfg, "focus_height_m", 0.9)
		var yaw: float = base_yaw + off
		var reach: float = pull_in(focus, yaw, pitch, dmax, col)   # one wall check per candidate
		var d: float = minf(dmin, reach)
		while d <= reach + 0.001:
			var xf: Transform3D = orbit_transform(focus, yaw, pitch, d)
			if not boss_hides(xf.origin, chest, boss, boss_r, boss_h):
				if fallback.is_empty():
					fallback = {"focus": focus, "yaw": yaw, "distance": d, "pitch": pitch}
				var ok: bool = true
				for p: Vector3 in pts:
					if not in_view(xf, fov, aspect, p):
						ok = false
						break
				if ok:
					return {"focus": focus, "yaw": yaw, "distance": d, "pitch": pitch}
			d += 0.5
	if not fallback.is_empty():
		return fallback
	return {"focus": focus, "yaw": base_yaw, "distance": dmax, "pitch": base_pitch + 38.0}


static func boss_hides(cam: Vector3, target: Vector3, boss: Vector3, boss_r: float, boss_h: float) -> bool:
	## True if the line from the camera to the target passes through the
	## boss's body (a vertical cylinder).
	for i: int in range(1, 12):
		var p: Vector3 = cam.lerp(target, float(i) / 12.0)
		if p.y < boss.y + boss_h and Vector2(p.x - boss.x, p.z - boss.z).length() < boss_r + 0.2:
			return true
	return false
