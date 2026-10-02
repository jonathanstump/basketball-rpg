class_name BallPhysics
extends RefCounted
## LOOSE-ball physics (spec §15.6): gravity, bounce 0.78, damping, walls,
## torus rim and backboard collisions. Deterministic and frame-stepped.


static func step_loose(b: SimBall, col: WorldCollision, hoops: Array[SimHoop], cfg: Dictionary, dt: float) -> void:
	var r: float = JU.f(cfg, "radius", 0.12)
	b.vel.y -= JU.f(cfg, "gravity", 14.0) * dt
	b.vel *= maxf(0.0, 1.0 - JU.f(cfg, "air_damping_per_s", 0.05) * dt)
	b.pos += b.vel * dt
	_collide_hoops(b, hoops, cfg, r)
	_collide_walls(b, col, r)
	var g: float = col.ground_height(b.pos - Vector3(0, r, 0))
	if b.pos.y - r < g:
		b.pos.y = g + r
		if b.vel.y < -0.8:
			b.vel.y = -b.vel.y * JU.f(cfg, "bounce", 0.78)
			var fr: float = JU.f(cfg, "ground_friction", 0.82)
			b.vel.x *= fr
			b.vel.z *= fr
			b.bounces += 1
		else:
			b.vel.y = 0.0
			var k: float = maxf(0.0, 1.0 - JU.f(cfg, "roll_friction_per_s", 1.6) * dt)
			b.vel.x *= k
			b.vel.z *= k


static func _collide_walls(b: SimBall, col: WorldCollision, r: float) -> void:
	var fixed: Vector3 = col.resolve(b.pos - Vector3(0, r, 0), r)
	fixed.y = b.pos.y
	var push: Vector3 = fixed - b.pos
	push.y = 0.0
	if push.length() > 0.0001:
		var n: Vector3 = push.normalized()
		b.pos = fixed
		var vn: float = b.vel.dot(n)
		if vn < 0.0:
			b.vel -= n * vn * 1.6


static func _collide_hoops(b: SimBall, hoops: Array[SimHoop], cfg: Dictionary, r: float) -> void:
	var rim_cfg: Dictionary = JU.dict(cfg, "rim")
	var tube: float = JU.f(rim_cfg, "tube", 0.02)
	for h: SimHoop in hoops:
		if not h.enabled:
			continue
		var d: Vector3 = b.pos - h.rim
		if d.length() > h.radius + 1.2:
			continue
		var flat: Vector3 = Vector3(d.x, 0.0, d.z)
		if flat.length() > 0.0001:
			var q: Vector3 = h.rim + flat.normalized() * h.radius
			var diff: Vector3 = b.pos - q
			var dist: float = diff.length()
			if dist < r + tube and dist > 0.0001:
				var n: Vector3 = diff / dist
				b.pos = q + n * (r + tube)
				var vn: float = b.vel.dot(n)
				if vn < 0.0:
					b.vel -= n * vn * 1.55
		if h.kind == "regulation":
			_collide_board(b, h, JU.f(rim_cfg, "backboard_offset", 0.38), r)


static func _collide_board(b: SimBall, h: SimHoop, offset: float, r: float) -> void:
	var board: Vector3 = h.rim - h.facing * offset
	var side: Vector3 = Vector3(h.facing.z, 0.0, -h.facing.x)
	var rel: Vector3 = b.pos - board
	var depth: float = rel.dot(h.facing)
	if depth >= r or depth < -0.15:
		return
	if absf(rel.dot(side)) > 0.9 or rel.y < -0.15 or rel.y > 0.95:
		return
	b.pos += h.facing * (r - depth)
	var vn: float = b.vel.dot(h.facing)
	if vn < 0.0:
		b.vel -= h.facing * vn * 1.5
