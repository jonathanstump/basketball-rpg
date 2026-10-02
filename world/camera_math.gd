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
