class_name BucketBlast
extends RefCounted
## Crate-hoop shockwave (spec §7.9): 6 m radius around the crate's base hits
## every hostile; damage/composure/knockdown are applied by combat.


static func targets(w: SimWorld, center: Vector3, radius: float, shooter_team: int) -> Array[int]:
	var out: Array[int] = []
	for o: SimActor in w.actors:
		if not o.alive or o.team == shooter_team or o.kind == "prop":
			continue
		if Vector2(o.pos.x - center.x, o.pos.z - center.z).length() <= radius:
			out.append(o.id)
	return out
